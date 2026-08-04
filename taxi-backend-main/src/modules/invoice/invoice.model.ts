import { HydratedDocument, Schema, Types, model } from "mongoose";

export const INVOICE_PAYMENT_MODES = ["ONLINE", "CASH"] as const;
export type InvoicePaymentMode = (typeof INVOICE_PAYMENT_MODES)[number];

export const INVOICE_PAYMENT_STATUSES = ["PENDING", "SUCCESS"] as const;
export type InvoicePaymentStatus = (typeof INVOICE_PAYMENT_STATUSES)[number];

export type InvoiceEntity = {
  ride_id: Types.ObjectId;
  customer_id: Types.ObjectId;
  driver_id: Types.ObjectId;

  distance_km: number;

  fare: number;
  commission: number;
  driver_earning: number;

  payment_mode: InvoicePaymentMode;
  payment_status: InvoicePaymentStatus;
};

export type InvoiceDocument = HydratedDocument<InvoiceEntity>;

const invoiceSchema = new Schema<InvoiceEntity>(
  {
    ride_id: { type: Schema.Types.ObjectId, ref: "Ride", required: true, unique: true, index: true },
    customer_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    driver_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },

    distance_km: { type: Number, required: true, min: 0 },

    fare: { type: Number, required: true, min: 0 },
    commission: { type: Number, required: true, min: 0 },
    driver_earning: { type: Number, required: true, min: 0 },

    payment_mode: { type: String, enum: INVOICE_PAYMENT_MODES, required: true, index: true },
    payment_status: { type: String, enum: INVOICE_PAYMENT_STATUSES, required: true, index: true },
  },
  {
    collection: "invoices",
    timestamps: true,
  }
);

invoiceSchema.index({ customer_id: 1, createdAt: -1 });
invoiceSchema.index({ driver_id: 1, createdAt: -1 });

export const InvoiceModel = model<InvoiceEntity>("Invoice", invoiceSchema);

