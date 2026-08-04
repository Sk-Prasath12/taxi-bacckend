import { HydratedDocument, Schema, Types, model } from "mongoose";

export const ADMIN_REVENUE_SOURCES = ["ONLINE", "CASH"] as const;
export type AdminRevenueSource = (typeof ADMIN_REVENUE_SOURCES)[number];

export type AdminRevenueEntity = {
  ride_id: Types.ObjectId;
  amount: number;
  source: AdminRevenueSource;
  createdAt?: Date;
};

export type AdminRevenueDocument = HydratedDocument<AdminRevenueEntity>;

const adminRevenueSchema = new Schema<AdminRevenueEntity>(
  {
    ride_id: { type: Schema.Types.ObjectId, ref: "Ride", required: true, unique: true, index: true },
    amount: { type: Number, required: true, min: 0 },
    source: { type: String, enum: ADMIN_REVENUE_SOURCES, required: true, index: true },
  },
  {
    collection: "admin_revenues",
    timestamps: { createdAt: true, updatedAt: false },
  }
);

adminRevenueSchema.index({ source: 1, createdAt: -1 });

export const AdminRevenueModel = model<AdminRevenueEntity>("AdminRevenue", adminRevenueSchema);
