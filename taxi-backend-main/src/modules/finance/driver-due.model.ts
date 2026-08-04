import { HydratedDocument, Schema, Types, model } from "mongoose";

export type DriverDueEntity = {
  driver_id: Types.ObjectId;
  due_amount: number;
  updatedAt?: Date;
};

export type DriverDueDocument = HydratedDocument<DriverDueEntity>;

const driverDueSchema = new Schema<DriverDueEntity>(
  {
    driver_id: { type: Schema.Types.ObjectId, ref: "User", required: true, unique: true, index: true },
    due_amount: { type: Number, default: 0, min: 0 },
  },
  {
    collection: "driver_dues",
    timestamps: { createdAt: false, updatedAt: true },
  }
);

export const DriverDueModel = model<DriverDueEntity>("DriverDue", driverDueSchema);
