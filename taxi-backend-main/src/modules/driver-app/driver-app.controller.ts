import { NextFunction, Request, Response } from "express";
import {
  acceptRideRequest,
  calculateFareEstimate,
  cancelRide,
  changeDriverPassword,
  completeRide,
  confirmPickup,
  createDriverPayment,
  createSupportTicket,
  createVehicle,
  createWalletWithdrawRequest,
  fetchAvailableRides,
  fetchCurrentRide,
  fetchDriverLocation,
  fetchDriverProfile,
  fetchDriverRating,
  fetchDriverStatus,
  fetchEarningsSummary,
  fetchFareDetails,
  fetchDriverVehicle,
  fetchNearbyDrivers,
  fetchNotifications,
  fetchRideHistory,
  fetchRideHistoryById,
  fetchRideRequestDetails,
  fetchSupportTickets,
  fetchWalletBalance,
  fetchWalletTransactions,
  getDriverSettings,
  goDriverOffline,
  goDriverOnline,
  loginDriver,
  logoutDriver,
  rejectRideRequest,
  refreshDriverToken,
  registerDriver,
  registerDriverPhoto,
  registerDriverVehicleDocs,
  registerDevice,
  requestPasswordReset,
  resetDriverPassword,
  resendDriverOtp,
  rideArrived,
  startRide,
  submitDriverRating,
  updateDriverProfile,
  updateDriverSettings,
  updateVehicle,
  walletAddMoney,
  walletWithdrawHistory,
  verifyDriverOtp,
  paymentConfirm,
  paymentRefund,
  getPassengerRating,
  replySupportTicket,
} from "./driver-app.service";

const userIdFromRequest = (req: Request) => req.authUser?.userId as string;

export const registerDriverController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await registerDriver(req.body);
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const loginController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await loginDriver(req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const logoutController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await logoutDriver(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const refreshTokenController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await refreshDriverToken(req.body.refreshToken);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const forgotPasswordController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await requestPasswordReset(req.body.email);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const resetPasswordController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await resetDriverPassword(req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const verifyOtpController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await verifyDriverOtp(req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const resendOtpController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await resendDriverOtp(req.body.phone);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getDriverProfileController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchDriverProfile(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const updateDriverProfileController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await updateDriverProfile(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const uploadDriverPhotoController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await registerDriverPhoto(userIdFromRequest(req), req.body.photo_url);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const changePasswordController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await changeDriverPassword(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const submitVehicleController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await createVehicle(userIdFromRequest(req), req.body);
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getDriverVehicleController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchDriverVehicle(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const updateDriverVehicleController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await updateVehicle(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const uploadVehicleDocsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await registerDriverVehicleDocs(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const goOnlineController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await goDriverOnline(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const goOfflineController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await goDriverOffline(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getDriverStatusController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchDriverStatus(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const syncDriverLocationController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchDriverLocation(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getDriverLocationController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchDriverLocation(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getNearbyDriversController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchNearbyDrivers(req.query);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAvailableRidesController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchAvailableRides(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRideRequestDetailsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rideId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await fetchRideRequestDetails(userIdFromRequest(req), rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const acceptRideRequestController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await acceptRideRequest(userIdFromRequest(req), req.body.ride_id);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const rejectRideRequestController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await rejectRideRequest(userIdFromRequest(req), req.body.ride_id);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const cancelRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await cancelRide(userIdFromRequest(req), req.body.ride_id);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const rideArrivedController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await rideArrived(userIdFromRequest(req), req.body.ride_id);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const startRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await startRide(userIdFromRequest(req), req.body.ride_id);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const pickupConfirmController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await confirmPickup(userIdFromRequest(req), req.body.ride_id);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const completeRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await completeRide(userIdFromRequest(req), req.body.ride_id);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getCurrentRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchCurrentRide(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const calculateFareController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await calculateFareEstimate(req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getFareDetailsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rideId = Array.isArray(req.params.ride_id) ? req.params.ride_id[0] : req.params.ride_id;
    const data = await fetchFareDetails(userIdFromRequest(req), rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getWalletBalanceController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchWalletBalance(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getWalletTransactionsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchWalletTransactions(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const walletAddMoneyController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await walletAddMoney(userIdFromRequest(req), req.body.amount);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const requestWalletWithdrawController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await createWalletWithdrawRequest(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getWalletWithdrawHistoryController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await walletWithdrawHistory(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const createPaymentController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await createDriverPayment(userIdFromRequest(req), req.body);
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const confirmPaymentController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await paymentConfirm(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const refundPaymentController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await paymentRefund(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const submitRatingController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await submitDriverRating(userIdFromRequest(req), req.body);
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getDriverRatingController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchDriverRating(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getPassengerRatingController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getPassengerRating(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRideHistoryController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchRideHistory(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getRideHistoryByIdController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const rideId = Array.isArray(req.params.ride_id) ? req.params.ride_id[0] : req.params.ride_id;
    const data = await fetchRideHistoryById(userIdFromRequest(req), rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getEarningsSummaryController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchEarningsSummary(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const registerDeviceController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await registerDevice(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getNotificationsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchNotifications(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const createSupportTicketController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await createSupportTicket(userIdFromRequest(req), req.body);
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getSupportTicketsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await fetchSupportTickets(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const replySupportTicketController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await replySupportTicket(userIdFromRequest(req), req.body);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getSettingsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getDriverSettings(userIdFromRequest(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const updateSettingsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await updateDriverSettings(userIdFromRequest(req), req.body.settings);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
