import { NextFunction, Request, Response } from "express";
import { Types } from "mongoose";
import { HttpError } from "../../utils/http-error";
import { InvoiceModel } from "./invoice.model";
import { updateInvoicePaymentStatusToSuccess } from "./invoice.service";

const invoiceResponseProjection = {
  ride_id: 1,
  distance_km: 1,
  fare: 1,
  commission: 1,
  driver_earning: 1,
  payment_mode: 1,
  payment_status: 1,
};

const toInvoiceResponse = (invoice: any) => ({
  ride_id: String(invoice.ride_id),
  distance_km: invoice.distance_km,
  fare: invoice.fare,
  commission: invoice.commission,
  driver_earning: invoice.driver_earning,
  payment_mode: invoice.payment_mode,
  payment_status: invoice.payment_status,
});

export const getCustomerInvoiceController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const authUserId = req.authUser?.userId;
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;

    if (!authUserId) {
      throw new HttpError(401, "Unauthorized");
    }

    const invoice = await InvoiceModel.findOne({
      ride_id: new Types.ObjectId(rideId),
      customer_id: new Types.ObjectId(authUserId),
    })
      .select(invoiceResponseProjection)
      .lean();

    if (!invoice) {
      throw new HttpError(404, "Invoice not found");
    }

    return res.status(200).json(toInvoiceResponse(invoice));
  } catch (error) {
    return next(error);
  }
};

export const getDriverInvoiceController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const authUserId = req.authUser?.userId;
    const rideId = Array.isArray(req.params.rideId) ? req.params.rideId[0] : req.params.rideId;

    if (!authUserId) {
      throw new HttpError(401, "Unauthorized");
    }

    const invoice = await InvoiceModel.findOne({
      ride_id: new Types.ObjectId(rideId),
      driver_id: new Types.ObjectId(authUserId),
    })
      .select(invoiceResponseProjection)
      .lean();

    if (!invoice) {
      throw new HttpError(404, "Invoice not found");
    }

    return res.status(200).json(toInvoiceResponse(invoice));
  } catch (error) {
    return next(error);
  }
};

export const getAdminInvoicesController = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const invoices = await InvoiceModel.find()
      .sort({ createdAt: -1 })
      .select(invoiceResponseProjection)
      .lean();

    return res.status(200).json(invoices.map(toInvoiceResponse));
  } catch (error) {
    return next(error);
  }
};

// Exported for completeness; not used by current endpoints.
export const _internalUpdateInvoicePaymentStatusToSuccess = updateInvoicePaymentStatusToSuccess;

