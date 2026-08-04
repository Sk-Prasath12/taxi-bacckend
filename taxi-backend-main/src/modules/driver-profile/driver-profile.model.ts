import { HydratedDocument, Schema, Types, model } from "mongoose";

export type DriverProfileEntity = {
  user_id: Types.ObjectId;
  dob?: Date | null;
  phone?: string | null;
  address?: string | null;
  emergency_contact?: string | null;
  license_number?: string | null;
  vehicle_reg_number?: string | null;
  vehicle_type_id?: Types.ObjectId | null;
  vehicle_model?: string | null;
  vehicle_color?: string | null;
  pan_number?: string | null;
  aadhaar_number?: string | null;
  voter_id?: string | null;
  account_holder_name?: string | null;
  bank_name?: string | null;
  branch_name?: string | null;
  account_number?: string | null;
  ifsc_code?: string | null;
  account_type?: string | null;
  upi_id?: string | null;
  profile_completed: boolean;
  createdAt?: Date;
  updatedAt?: Date;
};

export type DriverProfileDocument = HydratedDocument<DriverProfileEntity>;

const driverProfileSchema = new Schema<DriverProfileEntity>(
  {
    user_id: {
      type: Schema.Types.ObjectId,
      ref: "User",
      required: true,
      unique: true,
    },
    dob: { type: Date, default: null },
    phone: { type: String, default: null, trim: true },
    address: { type: String, default: null, trim: true },
    emergency_contact: { type: String, default: null, trim: true },
    license_number: { type: String, default: null, trim: true },
    vehicle_reg_number: { type: String, default: null, trim: true },
    vehicle_type_id: { type: Schema.Types.ObjectId, ref: "VehicleType", default: null },
    vehicle_model: { type: String, default: null, trim: true },
    vehicle_color: { type: String, default: null, trim: true },
    pan_number: { type: String, default: null, trim: true, uppercase: true },
    aadhaar_number: { type: String, default: null, trim: true },
    voter_id: { type: String, default: null, trim: true },
    account_holder_name: { type: String, default: null, trim: true },
    bank_name: { type: String, default: null, trim: true },
    branch_name: { type: String, default: null, trim: true },
    account_number: { type: String, default: null, trim: true },
    ifsc_code: { type: String, default: null, trim: true, uppercase: true },
    account_type: { type: String, default: null, trim: true },
    upi_id: { type: String, default: null, trim: true },
    profile_completed: { type: Boolean, default: false },
  },
  {
    collection: "driver_profiles",
    timestamps: true,
  }
);

export const DriverProfileModel = model<DriverProfileEntity>("DriverProfile", driverProfileSchema);
