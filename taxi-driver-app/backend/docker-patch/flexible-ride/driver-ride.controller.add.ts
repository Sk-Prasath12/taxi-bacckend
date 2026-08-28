// Append to driver-ride.controller.ts and export from service

import { verifyDropOtpAndProceed, confirmCashReceived, completeRideAfterPayment } from "./driver-ride.service";

export const verifyDropOtpController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await verifyDropOtpAndProceed(
      req.authUser?.userId,
      req.params.rideId as string,
      req.body.otp as number
    );
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const cashReceivedController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await confirmCashReceived(req.authUser?.userId, req.params.rideId as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const completeRideController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await completeRideAfterPayment(req.authUser?.userId, req.params.rideId as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
