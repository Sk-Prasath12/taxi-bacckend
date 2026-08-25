import { isValidObjectId, Types } from "mongoose";
import { HttpError } from "../../utils/http-error";
import { verifyAccessToken, generateAccessToken, verifyRefreshToken } from "../../utils/jwt.util";
import { comparePassword, hashPassword } from "../../utils/password.util";
import { UserModel } from "../users/users.model";
import {
  getDriverCashEarnings,
  getDriverProfile,
  getDriverTotalEarnings,
  getDriverWallet,
  loginDriver as coreLoginDriver,
  sendDriverForgotPasswordOtp,
  sendDriverRegistrationOtp,
  setDriverForgotPasswordPassword,
  setDriverRegistrationPassword,
  updateDriverStatus,
  verifyDriverForgotPasswordOtp,
  verifyDriverRegistrationOtp,
} from "../driver/driver.service";
import { createOrUpdateProfile, getProfile } from "../driver-profile/driver-profile.service";
import { DriverDocumentModel } from "../driver-documents/driver-document.model";
import {
  acceptIncomingRide,
  getDriverRideHistory,
  getIncomingRides,
  markRideArrivedAtPickup,
  markRideDropped,
  markRidePickedUp,
  verifyRideOtpAndStartRide,
} from "../driver/ride/driver-ride.service";
import { RideModel } from "../customer/ride/ride.model";
import { WithdrawModel } from "../withdraw/withdraw.model";
import { RatingModel } from "../rating/rating.model";
import { TicketMessageModel } from "../support/ticket-message.model";
import { TicketModel } from "../support/ticket.model";

const driverLocationMap = new Map<string, { latitude: number; longitude: number; updatedAt: string }>();
const driverSettingsMap = new Map<string, Record<string, unknown>>();
const driverDeviceMap = new Map<string, { device_token: string; platform: string; updatedAt: string }>();

const ensureDriver = async (userId: string) => {
  const driver = await UserModel.findOne({ _id: userId, role: "DRIVER" });
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }
  return driver;
};

export const registerDriver = async (payload: any) => {
  await sendDriverRegistrationOtp(payload.email);
  await verifyDriverRegistrationOtp(payload.email, "123456");
  return await setDriverRegistrationPassword(payload.email, payload.password);
};

export const loginDriver = async (payload: any) => {
  return await coreLoginDriver(payload.email, payload.password);
};

export const logoutDriver = async (_userId: string) => ({ success: true, message: "Logged out" });

export const refreshDriverToken = async (refreshToken: string) => {
  const payload = verifyRefreshToken(refreshToken);
  if (payload.type !== "refresh") {
    throw new HttpError(401, "Invalid refresh token");
  }
  if (payload.role !== "DRIVER") {
    throw new HttpError(403, "Invalid driver token");
  }
  const driver = await UserModel.findOne({ _id: payload.sub, role: "DRIVER" });
  if (!driver || !driver.is_active) {
    throw new HttpError(401, "Invalid refresh token");
  }
  return { success: true, accessToken: generateAccessToken(payload.sub, "DRIVER") };
};

export const requestPasswordReset = async (email: string) => {
  await sendDriverForgotPasswordOtp(email);
  return { success: true, message: "OTP sent successfully" };
};

export const resetDriverPassword = async (payload: any) => {
  await verifyDriverForgotPasswordOtp(payload.email, payload.token);
  return await setDriverForgotPasswordPassword(payload.email, payload.newPassword);
};

export const verifyDriverOtp = async (payload: any) => {
  const identifier = payload.email ?? payload.phone;
  if (!identifier) {
    throw new HttpError(400, "email or phone is required");
  }
  await verifyDriverForgotPasswordOtp(identifier, payload.otp);
  return { success: true, message: "OTP verified successfully" };
};

export const resendDriverOtp = async (phone: string) => {
  await sendDriverForgotPasswordOtp(phone);
  return { success: true, message: "OTP resent successfully" };
};

export const fetchDriverProfile = async (userId: string) => {
  const [driver, profile] = await Promise.all([getDriverProfile(userId), getProfile(userId)]);
  return { ...driver, driver_profile: profile };
};

export const updateDriverProfile = async (userId: string, payload: any) => {
  const driver = await ensureDriver(userId);
  if (typeof payload.name === "string" && payload.name.trim().length > 0) {
    driver.name = payload.name.trim();
  }
  if (typeof payload.phone === "string" && payload.phone.trim().length > 0) {
    driver.phone = payload.phone.trim();
  }
  await driver.save();
  const updated = await createOrUpdateProfile(userId, {
    phone: payload.phone,
    address: payload.bio,
  });
  return {
    success: true,
    message: "Driver profile updated",
    profile: updated,
    name: driver.name,
    phone: driver.phone,
  };
};

export const registerDriverPhoto = async (userId: string, photoUrl: string) => {
  const driver = await ensureDriver(userId);
  (driver as any).avatar_url = photoUrl;
  await driver.save();
  return { success: true, message: "Driver photo updated", photo_url: photoUrl };
};

export const changeDriverPassword = async (userId: string, payload: any) => {
  const driver = await ensureDriver(userId);
  const isValid = await comparePassword(payload.oldPassword, driver.password_hash);
  if (!isValid) {
    throw new HttpError(400, "Old password is incorrect");
  }
  driver.password_hash = await hashPassword(payload.newPassword);
  await driver.save();
  return { success: true, message: "Driver password changed successfully" };
};

export const createVehicle = async (userId: string, payload: any) => {
  const updated = await createOrUpdateProfile(userId, {
    vehicle_model: `${payload.make} ${payload.model}`.trim(),
    vehicle_color: payload.color,
    vehicle_reg_number: payload.plate_number,
  });
  return { success: true, message: "Vehicle saved", vehicle: updated };
};

export const fetchDriverVehicle = async (userId: string) => {
  const profile = await getProfile(userId);
  if (!profile) {
    return { vehicle: null };
  }
  const docsCount = await DriverDocumentModel.countDocuments({ user_id: new Types.ObjectId(userId) });
  return {
    vehicle: {
      vehicle_model: profile.vehicle_model,
      plate_number: profile.vehicle_reg_number,
      color: profile.vehicle_color,
      vehicle_type_id: profile.vehicle_type_id,
      documents_uploaded: docsCount > 0,
    },
  };
};

export const updateVehicle = async (userId: string, payload: any) => {
  const updated = await createOrUpdateProfile(userId, {
    vehicle_model:
      payload.make || payload.model
        ? `${payload.make ?? ""} ${payload.model ?? ""}`.trim()
        : undefined,
    vehicle_color: payload.color,
    vehicle_reg_number: payload.plate_number,
  });
  return { success: true, message: "Vehicle updated", vehicle: updated };
};

export const registerDriverVehicleDocs = async (userId: string, payload: any) => {
  if (!payload.document_url || typeof payload.document_url !== "string") {
    throw new HttpError(400, "document_url is required");
  }
  const documentType = payload.document_type === "VEHICLE" ? "VEHICLE" : "PERSONAL";
  const created = await DriverDocumentModel.create({
    user_id: new Types.ObjectId(userId),
    document_type: documentType,
    file_url: payload.document_url,
    file_key: payload.document_url,
    status: "PENDING",
  });
  return { success: true, message: "Vehicle document uploaded", document_id: String(created._id) };
};

export const goDriverOnline = async (userId: string) => await updateDriverStatus(userId, "ONLINE");
export const goDriverOffline = async (userId: string) => await updateDriverStatus(userId, "OFFLINE");

export const fetchDriverStatus = async (userId: string) => {
  const driver = await ensureDriver(userId);
  return { success: true, status: driver.driver_status ?? "OFFLINE", updatedAt: new Date().toISOString() };
};

export const fetchDriverLocation = async (userId: string, payload?: any) => {
  if (payload) {
    const entry = {
      latitude: payload.latitude,
      longitude: payload.longitude,
      updatedAt: new Date().toISOString(),
    };
    driverLocationMap.set(userId, entry);
    return { success: true, message: "Driver location updated", location: entry };
  }
  return { success: true, location: driverLocationMap.get(userId) ?? null };
};

export const fetchNearbyDrivers = async (_query: any) => {
  const drivers = await UserModel.find({ role: "DRIVER", driver_status: "ONLINE" })
    .select("name driver_status")
    .limit(20)
    .lean();
  return {
    drivers: drivers.map((driver) => ({
      id: String(driver._id),
      name: driver.name,
      status: driver.driver_status ?? "OFFLINE",
    })),
  };
};

export const fetchAvailableRides = async (userId: string) => {
  await ensureDriver(userId);
  return await getIncomingRides(userId);
};

export const fetchRideRequestDetails = async (userId: string, rideId: string) => {
  await ensureDriver(userId);
  const ride = await RideModel.findOne({ _id: rideId, status: "SEARCHING_DRIVER", driver_id: null }).lean();
  if (!ride) {
    throw new HttpError(404, "Ride request not found");
  }
  return {
    ride_id: String(ride._id),
    pickup: ride.pickup,
    drop: ride.drop,
    fare: ride.fare,
    distance_km: ride.distance_km,
    status: ride.status,
    customer_id: String(ride.customer_id),
  };
};

export const acceptRideRequest = async (userId: string, rideId: string) =>
  await acceptIncomingRide(userId, rideId);

export const rejectRideRequest = async (userId: string, rideId: string) => {
  const { rejectIncomingRide } = await import("../driver/ride/driver-ride.service.js");
  return await rejectIncomingRide(userId, rideId);
};

export const cancelRide = async (_userId: string, rideId: string) => {
  const ride = await RideModel.findById(rideId);
  if (!ride) throw new HttpError(404, "Ride not found");
  if (ride.status === "COMPLETED" || ride.status === "CANCELLED") {
    throw new HttpError(400, "Ride cannot be cancelled");
  }
  ride.status = "CANCELLED";
  await ride.save();
  return { success: true, ride_id: rideId, message: "Ride cancelled" };
};

export const rideArrived = async (userId: string, rideId: string) =>
  await markRideArrivedAtPickup(userId, rideId);
export const startRide = async (userId: string, rideId: string) => {
  const ride = await RideModel.findOne({ _id: rideId, driver_id: new Types.ObjectId(userId) }).lean();
  if (!ride) throw new HttpError(404, "Ride not found");
  return await verifyRideOtpAndStartRide(userId, rideId, ride.otp);
};
export const confirmPickup = async (userId: string, rideId: string) =>
  await markRidePickedUp(userId, rideId);
export const completeRide = async (userId: string, rideId: string) => {
  const { completeRideAfterPayment } = await import("../driver/ride/driver-ride.service.js");
  return await completeRideAfterPayment(userId, rideId);
};

export const fetchCurrentRide = async (userId: string) => {
  await ensureDriver(userId);
  const ride = await RideModel.findOne({
    driver_id: new Types.ObjectId(userId),
    status: { $in: ["DRIVER_ASSIGNED", "ARRIVED_AT_PICKUP", "STARTED", "PICKED_UP", "IN_TRANSIT"] },
  })
    .sort({ updatedAt: -1 })
    .lean();
  return ride
    ? {
        ride_id: String(ride._id),
        status: ride.status,
        pickup: ride.pickup,
        drop: ride.drop,
        fare: ride.fare,
      }
    : { ride: null };
};

export const calculateFareEstimate = async (payload: any) => {
  const baseFare = 30;
  const distanceFare = Number(payload.distance_km ?? 0) * 12;
  const timeFare = Number(payload.duration_min ?? 0) * 1.5;
  return {
    fare_estimate: Number((baseFare + distanceFare + timeFare).toFixed(2)),
    details: { base_fare: baseFare, distance_fare: distanceFare, time_fare: timeFare },
  };
};

export const fetchFareDetails = async (userId: string, rideId: string) => {
  await ensureDriver(userId);
  const ride = await RideModel.findOne({ _id: rideId, driver_id: new Types.ObjectId(userId) }).lean();
  if (!ride) throw new HttpError(404, "Ride not found");
  return {
    ride_id: String(ride._id),
    fare: ride.fare,
    distance_km: ride.distance_km,
    duration_min: ride.duration_min ?? 0,
    payment_mode: ride.payment_mode,
    payment_status: ride.payment_status,
  };
};

export const fetchWalletBalance = async (userId: string) => await getDriverWallet(userId);

export const fetchWalletTransactions = async (userId: string) => {
  const withdrawals = await WithdrawModel.find({ driver_id: new Types.ObjectId(userId) })
    .sort({ createdAt: -1 })
    .limit(50)
    .lean();
  return {
    transactions: withdrawals.map((item) => ({
      id: String(item._id),
      type: "DEBIT",
      amount: item.amount,
      status: item.status,
      createdAt: item.createdAt,
    })),
  };
};

export const walletAddMoney = async (_userId: string, _amount: number) => {
  throw new HttpError(501, "Driver wallet top-up is not supported");
};

export const createWalletWithdrawRequest = async (_userId: string, _payload: any) => {
  throw new HttpError(501, "Withdraw requests are handled by finance module");
};

export const walletWithdrawHistory = async (userId: string) => {
  const history = await WithdrawModel.find({ driver_id: new Types.ObjectId(userId) })
    .sort({ createdAt: -1 })
    .lean();
  return {
    history: history.map((item) => ({
      id: String(item._id),
      amount: item.amount,
      status: item.status,
      createdAt: item.createdAt,
    })),
  };
};

export const createDriverPayment = async (_userId: string, _payload: any) => {
  throw new HttpError(501, "Driver payment creation is not supported");
};
export const paymentConfirm = async (_userId: string, _payload: any) => {
  throw new HttpError(501, "Driver payment confirmation is not supported");
};
export const paymentRefund = async (_userId: string, _payload: any) => {
  throw new HttpError(501, "Driver payment refund is not supported");
};

export const submitDriverRating = async (userId: string, payload: any) => {
  const ride = await RideModel.findById(payload.ride_id).lean();
  if (!ride) throw new HttpError(404, "Ride not found");
  if (!ride.customer_id) throw new HttpError(400, "Ride customer missing");
  const created = await RatingModel.create({
    ride_id: new Types.ObjectId(payload.ride_id),
    from_user_id: new Types.ObjectId(userId),
    from_role: "DRIVER",
    to_user_id: ride.customer_id,
    to_role: "CUSTOMER",
    rating: payload.rating,
    review: payload.review ?? "",
  });
  return { success: true, rating_id: String(created._id) };
};

export const fetchDriverRating = async (userId: string) => {
  const result = await RatingModel.aggregate<{ avg: number; total: number }>([
    { $match: { to_user_id: new Types.ObjectId(userId), to_role: "DRIVER" } },
    { $group: { _id: null, avg: { $avg: "$rating" }, total: { $sum: 1 } } },
  ]);
  return { average_rating: Number((result[0]?.avg ?? 0).toFixed(1)), total_ratings: result[0]?.total ?? 0 };
};

export const getPassengerRating = async (userId: string) => {
  const lastRide = await RideModel.findOne({ driver_id: new Types.ObjectId(userId) }).sort({ updatedAt: -1 }).lean();
  if (!lastRide?.customer_id) return { average_rating: 0, total_reviews: 0 };
  const result = await RatingModel.aggregate<{ avg: number; total: number }>([
    { $match: { to_user_id: lastRide.customer_id, to_role: "CUSTOMER" } },
    { $group: { _id: null, avg: { $avg: "$rating" }, total: { $sum: 1 } } },
  ]);
  return { average_rating: Number((result[0]?.avg ?? 0).toFixed(1)), total_reviews: result[0]?.total ?? 0 };
};

export const fetchRideHistory = async (userId: string) => await getDriverRideHistory(userId);

export const fetchRideHistoryById = async (userId: string, rideId: string) => {
  if (!isValidObjectId(rideId)) throw new HttpError(400, "Invalid ride id");
  const ride = await RideModel.findOne({ _id: rideId, driver_id: new Types.ObjectId(userId) }).lean();
  if (!ride) throw new HttpError(404, "Ride not found");
  return ride;
};

export const fetchEarningsSummary = async (userId: string) => {
  const [wallet, cash, total, weekly] = await Promise.all([
    getDriverWallet(userId),
    getDriverCashEarnings(userId),
    getDriverTotalEarnings(userId),
    RideModel.aggregate<{ value: number }>([
      {
        $match: {
          driver_id: new Types.ObjectId(userId),
          status: "COMPLETED",
          updatedAt: { $gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
        },
      },
      { $group: { _id: null, value: { $sum: "$fare" } } },
    ]),
  ]);
  return {
    wallet_balance: wallet.balance,
    online_earnings: total.onlineEarnings,
    cash_due: cash.cashEarningsDue,
    total_earnings: total.totalEarnings,
    weekly_earnings: weekly[0]?.value ?? 0,
  };
};

export const registerDevice = async (userId: string, payload: any) => {
  driverDeviceMap.set(userId, {
    device_token: payload.device_token,
    platform: payload.platform,
    updatedAt: new Date().toISOString(),
  });
  return { success: true, message: "Device registered" };
};

export const fetchNotifications = async (userId: string) => {
  const rides = await RideModel.find({ driver_id: new Types.ObjectId(userId) })
    .sort({ updatedAt: -1 })
    .limit(10)
    .lean();
  return {
    notifications: rides.map((ride) => ({
      id: String(ride._id),
      title: "Ride update",
      body: `Ride status: ${ride.status}`,
      createdAt: ride.updatedAt,
    })),
  };
};

export const createSupportTicket = async (userId: string, payload: any) => {
  const rideId = payload.ride_id && isValidObjectId(payload.ride_id) ? new Types.ObjectId(payload.ride_id) : null;
  const ticket = await TicketModel.create({
    user_id: new Types.ObjectId(userId),
    role: "DRIVER",
    ride_id: rideId,
    driver_id: new Types.ObjectId(userId),
    subject: payload.subject,
    description: payload.description,
    category: "OTHER",
    status: "OPEN",
  });
  return { success: true, ticket_id: String(ticket._id), status: ticket.status };
};

export const fetchSupportTickets = async (userId: string) => {
  const tickets = await TicketModel.find({ user_id: new Types.ObjectId(userId), role: "DRIVER" })
    .sort({ createdAt: -1 })
    .lean();
  return {
    tickets: tickets.map((ticket) => ({
      id: String(ticket._id),
      subject: ticket.subject,
      status: ticket.status,
      category: ticket.category,
      createdAt: ticket.createdAt,
    })),
  };
};

export const replySupportTicket = async (userId: string, payload: any) => {
  if (!isValidObjectId(payload.ticket_id)) {
    throw new HttpError(400, "Invalid ticket id");
  }
  const ticket = await TicketModel.findOne({
    _id: payload.ticket_id,
    user_id: new Types.ObjectId(userId),
    role: "DRIVER",
  }).lean();
  if (!ticket) {
    throw new HttpError(404, "Ticket not found");
  }
  const message = await TicketMessageModel.create({
    ticket_id: new Types.ObjectId(payload.ticket_id),
    sender_id: new Types.ObjectId(userId),
    sender_role: "USER",
    message: payload.message,
  });
  return { success: true, message_id: String(message._id) };
};

export const getDriverSettings = async (userId: string) => {
  return driverSettingsMap.get(userId) ?? { notifications: true, language: "en", theme: "light" };
};

export const updateDriverSettings = async (userId: string, settings: any) => {
  driverSettingsMap.set(userId, settings ?? {});
  return { success: true, message: "Settings updated", settings: driverSettingsMap.get(userId) };
};
