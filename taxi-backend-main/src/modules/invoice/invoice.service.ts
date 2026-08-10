import { Types } from "mongoose";
import { emitToRoom } from "../../socket/socket-emit.service";
import { calculateCommission } from "../common/commission.service";
import { RideDocument, RideModel } from "../customer/ride/ride.model";
import { HttpError } from "../../utils/http-error";
import { InvoiceModel } from "./invoice.model";

const toInvoiceResponse = (invoice: {
  ride_id: Types.ObjectId;
  distance_km: number;
  fare: number;
  commission: number;
  driver_earning: number;
  payment_mode: string;
  payment_status: string;
}) => ({
  ride_id: String(invoice.ride_id),
  distance_km: invoice.distance_km,
  fare: invoice.fare,
  commission: invoice.commission,
  driver_earning: invoice.driver_earning,
  payment_mode: invoice.payment_mode,
  payment_status: invoice.payment_status,
});

export const generateInvoice = async (rideInput: RideDocument) => {
  const ride = await RideModel.findById(rideInput._id);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }
  if (ride.status !== "COMPLETED") {
    throw new HttpError(400, "Invoice can be generated only for completed rides");
  }
  if (!ride.driver_id || !ride.payment_mode || !ride.payment_status) {
    throw new HttpError(400, "Invalid ride data for invoice generation");
  }

  const existing = await InvoiceModel.findOne({ ride_id: ride._id });
  if (existing) {
    return toInvoiceResponse(existing);
  }

  const { commission, driverAmount } = calculateCommission(ride.fare);

  const paymentMode = ride.payment_mode;
  const paymentStatus = paymentMode === "CASH" ? "SUCCESS" : "PENDING";

  try {
    const invoice = await InvoiceModel.create({
      ride_id: ride._id,
      customer_id: ride.customer_id,
      driver_id: ride.driver_id,
      distance_km: ride.distance_km,
      fare: ride.fare,
      commission,
      driver_earning: driverAmount,
      payment_mode: paymentMode,
      payment_status: paymentStatus,
    });

    await emitToRoom(`customer_${String(ride.customer_id)}`, "invoice_generated", toInvoiceResponse(invoice));
    await emitToRoom(`driver_${String(ride.driver_id)}`, "invoice_generated", toInvoiceResponse(invoice));

    return toInvoiceResponse(invoice);
  } catch (error: any) {
    // In case of race-condition duplicate invoice creation, fall back to existing.
    if (error?.code === 11000) {
      const existingAfterRace = await InvoiceModel.findOne({ ride_id: ride._id });
      if (existingAfterRace) {
        return toInvoiceResponse(existingAfterRace);
      }
    }
    throw error;
  }
};

export const updateInvoicePaymentStatusToSuccess = async (rideId: Types.ObjectId) => {
  const updated = await InvoiceModel.findOneAndUpdate(
    { ride_id: rideId },
    { payment_status: "SUCCESS" },
    { new: true }
  );

  if (!updated) {
    return null;
  }

  await emitToRoom(`customer_${String(updated.customer_id)}`, "invoice_updated", toInvoiceResponse(updated));
  await emitToRoom(`driver_${String(updated.driver_id)}`, "invoice_updated", toInvoiceResponse(updated));

  return toInvoiceResponse(updated);
};

