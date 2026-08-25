import { HydratedDocument, Schema, model } from "mongoose";

export type VehicleTypeEntity = {
  name: string;
  code?: string;
  per_km_rate: number;
  max_passengers: number;
  is_active: boolean;
  createdAt?: Date;
  updatedAt?: Date;
};

export type VehicleTypeDocument = HydratedDocument<VehicleTypeEntity>;

const vehicleTypeSchema = new Schema<VehicleTypeEntity>(
  {
    name: { type: String, required: true, unique: true, trim: true },
    code: { type: String, trim: true, uppercase: true, sparse: true, unique: true },
    per_km_rate: { type: Number, required: true, min: 0 },
    max_passengers: { type: Number, required: true, min: 1 },
    is_active: { type: Boolean, default: true },
  },
  {
    collection: "vehicle_types",
    timestamps: true,
  }
);

vehicleTypeSchema.index({ is_active: 1 });

export const VehicleTypeModel = model<VehicleTypeEntity>("VehicleType", vehicleTypeSchema);
