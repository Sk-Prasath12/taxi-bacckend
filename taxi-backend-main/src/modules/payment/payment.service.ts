import crypto from "crypto";
import Razorpay from "razorpay";
import { env } from "../../config/env";
import { emitToRoom } from "../../socket/socket-emit.service";
import { HttpError } from "../../utils/http-error";
import { calculateCommission } from "../common/commission.service";
import { RideDocument, RideModel } from "../customer/ride/ride.model";
import { processRidePayment } from "../finance/finance.service";
import { WalletModel } from "../finance/wallet.model";
import { generateInvoice } from "../invoice/invoice.service";
import { InvoiceModel } from "../invoice/invoice.model";
import { sendPushNotification } from "../../services/notification.service";
import { UserModel } from "../users/users.model";
import { PaymentModel } from "./payment.model";
import {
  emitCustomerAndRide,
  emitRideStatusToParties,
  emitAdminRideUpdate,
} from "../../utils/ride-socket-events.util";

let razorpayClient: Razorpay | null = null;

const getRazorpayClient = () => {
  if (!razorpayClient) {
    razorpayClient = new Razorpay({
      key_id: env.RAZORPAY_KEY_ID,
      key_secret: env.RAZORPAY_KEY_SECRET,
    });
  }

  return razorpayClient;
};

const ensureCustomerId = (customerId?: string): string => {
  if (!customerId) {
    throw new HttpError(401, "Unauthorized");
  }
  return customerId;
};

/** Online payment allowed after drop OTP verified (flexible flow) or after ride completed. */
const isOnlineRidePayable = (ride: {
  status: string;
  payment_mode?: string;
  payment_status?: string;
  drop_otp_verified?: boolean;
}) => {
  if (ride.payment_mode !== "ONLINE") return false;
  if (ride.payment_status !== "PENDING") return false;
  if (ride.status === "COMPLETED") return true;
  return ride.status === "IN_TRANSIT" && ride.drop_otp_verified === true;
};

/** After Razorpay SUCCESS: credit driver wallet, complete ride, notify both apps. */
const finalizeOnlinePaymentSuccess = async (ride: RideDocument) => {
  const customerId = String(ride.customer_id);
  const rideId = String(ride.id);
  const { commission, driverAmount } = calculateCommission(ride.fare);

  const shouldCompleteRide =
    ride.payment_mode === "ONLINE" &&
    ride.payment_status === "SUCCESS" &&
    ride.drop_otp_verified === true &&
    ride.status !== "COMPLETED";

  if (shouldCompleteRide) {
    ride.status = "COMPLETED";
    await ride.save();
    console.log(`AUTO-COMPLETE RIDE ${rideId} after Razorpay payment`);
  }

  let updatedInvoice = null;
  if (ride.status === "COMPLETED") {
    await processRidePayment(ride);
    updatedInvoice = await InvoiceModel.findOneAndUpdate(
      { ride_id: ride._id },
      { payment_status: "SUCCESS" },
      { new: true }
    );
    if (!updatedInvoice) {
      try {
        await generateInvoice(ride);
        updatedInvoice = await InvoiceModel.findOneAndUpdate(
          { ride_id: ride._id },
          { payment_status: "SUCCESS" },
          { new: true }
        );
      } catch (error) {
        console.error("Invoice generation after Razorpay payment failed:", error);
      }
    }
  }

  const wallet = ride.driver_id
    ? await WalletModel.findOne({ user_id: ride.driver_id }).lean()
    : null;

  const paymentPayload = {
    ride_id: rideId,
    amount: ride.fare,
    payment_status: "SUCCESS",
    payment_mode: ride.payment_mode,
    driver_earnings: driverAmount,
    wallet_balance: wallet?.balance ?? null,
    commission,
  };

  emitCustomerAndRide(customerId, rideId, "payment_success", paymentPayload);
  void emitAdminRideUpdate("payment_updated", {
    ...paymentPayload,
    customer_id: customerId,
    driver_id: ride.driver_id ? String(ride.driver_id) : null,
    status: ride.status,
  });

  if (ride.driver_id) {
    const driverId = String(ride.driver_id);
    const driverRoom = `driver_${driverId}`;
    await emitToRoom(driverRoom, "payment_success", paymentPayload);
    await emitToRoom(driverRoom, "driver_wallet_updated", {
      ride_id: rideId,
      amount: driverAmount,
      wallet_balance: wallet?.balance ?? null,
      payment_status: "SUCCESS",
      payment_mode: ride.payment_mode,
      driver_earnings: driverAmount,
    });
    await emitToRoom(driverRoom, "wallet_updated", {
      ride_id: rideId,
      amount: driverAmount,
      wallet_balance: wallet?.balance ?? null,
      payment_status: "SUCCESS",
      payment_mode: ride.payment_mode,
      driver_earnings: driverAmount,
    });
  }

  if (updatedInvoice) {
    const invoicePayload = {
      ride_id: String(updatedInvoice.ride_id),
      payment_status: updatedInvoice.payment_status,
    };
    await emitToRoom(`customer_${customerId}`, "invoice_updated", invoicePayload);
    if (ride.driver_id) {
      await emitToRoom(`driver_${String(ride.driver_id)}`, "invoice_updated", invoicePayload);
    }
  }

  if (shouldCompleteRide) {
    const completedPayload = {
      ride_id: rideId,
      status: "COMPLETED",
      fare: ride.fare,
      payment_status: "SUCCESS",
      payment_mode: ride.payment_mode,
      driver_earnings: driverAmount,
    };
    emitCustomerAndRide(customerId, rideId, "ride_completed", completedPayload);
    emitRideStatusToParties(customerId, rideId, "COMPLETED", completedPayload);
    if (ride.driver_id) {
      const driverRoom = `driver_${String(ride.driver_id)}`;
      await emitToRoom(driverRoom, "ride_completed", completedPayload);
      await emitToRoom(driverRoom, "ride_status_update", completedPayload);
    }
  }

  return { commission, driverAmount, updatedInvoice };
};

export const createPaymentOrder = async (customerIdInput: string | undefined, rideId?: string) => {
  const customerId = ensureCustomerId(customerIdInput);
  if (!rideId) {
    throw new HttpError(400, "ride_id is required");
  }

  const ride = await RideModel.findById(rideId);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }
  if (String(ride.customer_id) !== customerId) {
    throw new HttpError(403, "You are not allowed to pay for this ride");
  }
  if (!isOnlineRidePayable(ride)) {
    throw new HttpError(400, "Ride is not in a payable state. Complete drop OTP verification first.");
  }
  if (ride.payment_status === "SUCCESS") {
    throw new HttpError(409, "Payment is already completed for this ride");
  }

  const existingCreated = await PaymentModel.findOne({
    ride_id: ride._id,
    status: "CREATED",
  }).sort({ createdAt: -1 });

  if (existingCreated?.order_id) {
    return {
      order_id: existingCreated.order_id,
      amount: Math.round(ride.fare * 100),
      currency: "INR",
      key: env.RAZORPAY_KEY_ID,
      reused: true,
    };
  }

  if (!ride.fare || ride.fare <= 0) {
    throw new HttpError(400, "Invalid fare for payment");
  }

  const amount = Math.round(ride.fare * 100);
  const razorpay = getRazorpayClient();
  let order: { id: string; amount: number; currency: string };
  try {
    const createdOrder = await razorpay.orders.create({
      amount,
      currency: "INR",
      receipt: String(ride.id),
    });
    order = {
      id: createdOrder.id,
      amount: Number(createdOrder.amount),
      currency: String(createdOrder.currency),
    };
  } catch (err) {
    console.error("RAZORPAY ORDER ERROR:", err);
    throw new HttpError(502, "Failed to create Razorpay order");
  }
  console.log("ORDER CREATED:", order.id);

  await PaymentModel.create({
    ride_id: ride._id,
    customer_id: ride.customer_id,
    amount: ride.fare,
    order_id: order.id,
    status: "CREATED",
  });

  return {
    order_id: order.id,
    amount: order.amount,
    currency: order.currency,
    key: env.RAZORPAY_KEY_ID,
  };
};

type VerifyPaymentInput = {
  ride_id?: string;
  order_id?: string;
  payment_id?: string;
  signature?: string;
};

export const verifyPayment = async (customerIdInput: string | undefined, input: VerifyPaymentInput) => {
  const customerId = ensureCustomerId(customerIdInput);
  const { ride_id, order_id, payment_id, signature } = input;
  const isDevBypassEnabled =
    env.NODE_ENV === "development" && process.env.ENABLE_PAYMENT_DEV_BYPASS === "true";

  if (!ride_id || !order_id || !payment_id || !signature) {
    throw new HttpError(400, "ride_id, order_id, payment_id and signature are required");
  }

  const ride = await RideModel.findById(ride_id);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }
  if (String(ride.customer_id) !== customerId) {
    throw new HttpError(403, "You are not allowed to verify payment for this ride");
  }
  if (!isOnlineRidePayable(ride) && ride.payment_status !== "SUCCESS") {
    throw new HttpError(400, "Ride is not in a payable state");
  }
  if (ride.payment_mode !== "ONLINE") {
    throw new HttpError(400, "Payment is allowed only for ONLINE rides");
  }
  if (ride.payment_status === "SUCCESS") {
    const { commission, driverAmount } = calculateCommission(ride.fare);
    return {
      message: "Payment verified successfully",
      ride_id: String(ride.id),
      payment_status: "SUCCESS",
      commission,
      driver_amount: driverAmount,
    };
  }

  // Idempotent: same payment_id already recorded as SUCCESS elsewhere.
  const existingByPaymentId = await PaymentModel.findOne({
    payment_id,
    status: "SUCCESS",
  }).lean();
  if (existingByPaymentId) {
    if (String(existingByPaymentId.ride_id) === String(ride._id)) {
      ride.payment_status = "SUCCESS";
      await ride.save();
      const { commission, driverAmount } = calculateCommission(ride.fare);
      return {
        message: "Payment already verified",
        ride_id: String(ride.id),
        payment_status: "SUCCESS",
        commission,
        driver_amount: driverAmount,
      };
    }
    throw new HttpError(409, "This payment was already used for another ride");
  }

  if (ride.payment_status !== "PENDING") {
    throw new HttpError(400, "Payment verification is not allowed in current payment state");
  }

  const body = `${order_id}|${payment_id}`;
  const expectedSignature = crypto
    .createHmac("sha256", env.RAZORPAY_KEY_SECRET)
    .update(body)
    .digest("hex");

  console.log("VERIFY PAYMENT: signature validation started");
  if (isDevBypassEnabled) {
    console.warn("DEV PAYMENT BYPASS ENABLED");
  }

  const expectedBuffer = Buffer.from(expectedSignature, "utf8");
  const receivedBuffer = Buffer.from(signature, "utf8");
  const isValidSignature =
    expectedBuffer.length === receivedBuffer.length &&
    crypto.timingSafeEqual(expectedBuffer, receivedBuffer);

  if (!isDevBypassEnabled && !isValidSignature) {
    console.error("Payment verification failed due to signature mismatch");
    await PaymentModel.findOneAndUpdate(
      { order_id, ride_id: ride._id, customer_id: ride.customer_id },
      { status: "FAILED", payment_id },
      { upsert: false }
    );
    throw new HttpError(400, "Invalid payment signature");
  }

  const payment = await PaymentModel.findOneAndUpdate(
    { order_id, ride_id: ride._id, customer_id: ride.customer_id },
    { status: "SUCCESS", payment_id },
    { new: true }
  );

  if (!payment) {
    throw new HttpError(404, "Payment order not found");
  }

  ride.payment_status = "SUCCESS";
  await ride.save();

  console.log("PAYMENT SUCCESS FLOW START");
  const { commission, driverAmount } = await finalizeOnlinePaymentSuccess(ride);

  try {
    const customer = await UserModel.findById(String(ride.customer_id)).select("fcm_token").lean();
    const token = customer?.fcm_token?.trim();
    if (token) {
      await sendPushNotification({
        token,
        title: "Payment Successful 💰",
        body: "Thank you for riding with us",
        data: {
          type: "PAYMENT_SUCCESS",
          ride_id: String(ride.id),
        },
      });
    }
  } catch (error) {
    console.error("PAYMENT PUSH ERROR:", error);
  }

  if (ride.driver_id) {
    try {
      const driver = await UserModel.findById(String(ride.driver_id)).select("fcm_token").lean();
      const driverToken = driver?.fcm_token?.trim();
      if (driverToken) {
        await sendPushNotification({
          token: driverToken,
          title: "Payment Received 💰",
          body: `₹${driverAmount.toFixed(0)} added to your wallet`,
          data: {
            type: "PAYMENT_SUCCESS",
            ride_id: String(ride.id),
          },
        });
      }
    } catch (error) {
      console.error("DRIVER PAYMENT PUSH ERROR:", error);
    }
  }

  console.log("PAYMENT FLOW COMPLETE");

  return {
    message: "Payment verified successfully",
    ride_id: String(ride.id),
    payment_status: "SUCCESS",
    commission,
    driver_amount: driverAmount,
  };
};

export const listCustomerPaymentHistory = async (customerIdInput?: string, limit = 50) => {
  const customerId = ensureCustomerId(customerIdInput);
  const payments = await PaymentModel.find({ customer_id: customerId })
    .sort({ createdAt: -1 })
    .limit(Math.min(limit, 100))
    .lean();

  return payments.map((p) => ({
    payment_id: p.payment_id ?? null,
    order_id: p.order_id,
    ride_id: String(p.ride_id),
    amount: p.amount,
    status: p.status,
    created_at: p.createdAt ?? null,
    updated_at: p.updatedAt ?? null,
  }));
};

export const listDriverPaymentHistory = async (driverIdInput?: string, limit = 50) => {
  if (!driverIdInput) throw new HttpError(401, "Unauthorized");
  const rides = await RideModel.find({
    driver_id: driverIdInput,
    payment_status: "SUCCESS",
  })
    .sort({ updatedAt: -1 })
    .limit(Math.min(limit, 100))
    .select("_id fare payment_mode payment_status updatedAt createdAt customer_id")
    .lean();

  return rides.map((ride) => ({
    ride_id: String(ride._id),
    amount: ride.fare,
    payment_mode: ride.payment_mode ?? "CASH",
    payment_status: ride.payment_status ?? "SUCCESS",
    customer_id: String(ride.customer_id),
    completed_at: ride.updatedAt ?? ride.createdAt ?? null,
  }));
};

export const listAdminPaymentHistory = async (limit = 100) => {
  const payments = await PaymentModel.find()
    .sort({ createdAt: -1 })
    .limit(Math.min(limit, 200))
    .lean();

  const rideIds = payments.map((p) => p.ride_id);
  const rides = rideIds.length
    ? await RideModel.find({ _id: { $in: rideIds } })
        .select("driver_id customer_id fare payment_mode payment_status")
        .lean()
    : [];
  const rideMap = new Map(rides.map((r) => [String(r._id), r]));

  const userIds = [
    ...new Set(
      [
        ...payments.map((p) => String(p.customer_id)),
        ...rides.map((r) => (r.driver_id ? String(r.driver_id) : "")),
      ].filter((id) => id.length > 0),
    ),
  ];
  const users = userIds.length
    ? await UserModel.find({ _id: { $in: userIds } }).select("name phone").lean()
    : [];
  const userMap = new Map(users.map((u) => [String(u._id), u]));

  return payments.map((p) => {
    const ride = rideMap.get(String(p.ride_id));
    const customer = userMap.get(String(p.customer_id));
    const driverId = ride?.driver_id ? String(ride.driver_id) : null;
    const driver = driverId ? userMap.get(driverId) : undefined;
    return {
      payment_id: p.payment_id ?? null,
      order_id: p.order_id,
      ride_id: String(p.ride_id),
      customer_id: String(p.customer_id),
      customer_name: customer?.name ?? null,
      customer_phone: customer?.phone ?? null,
      driver_id: driverId,
      driver_name: driver?.name ?? null,
      driver_phone: driver?.phone ?? null,
      amount: p.amount,
      status: p.status,
      payment_mode: ride?.payment_mode ?? null,
      ride_payment_status: ride?.payment_status ?? null,
      created_at: p.createdAt ?? null,
    };
  });
};
