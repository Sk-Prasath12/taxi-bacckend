import { HydratedDocument, Schema, model } from "mongoose";

export type DriverOtpEntity = {
  purpose?: "REGISTER" | "FORGOT_PASSWORD";
  email: string;
  otp: string;
  expiresAt: Date;
  verified: boolean;
  createdAt?: Date;
};

export type DriverOtpDocument = HydratedDocument<DriverOtpEntity>;

const driverOtpSchema = new Schema<DriverOtpEntity>(
  {
    purpose: {
      type: String,
      enum: ["REGISTER", "FORGOT_PASSWORD"],
      default: "REGISTER",
      index: true,
    },
    email: { type: String, required: true, lowercase: true, trim: true, index: true },
    otp: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    verified: { type: Boolean, default: false },
  },
  {
    collection: "driver_email_otps",
    timestamps: { createdAt: true, updatedAt: false },
  }
);

driverOtpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export const DriverOtpModel = model<DriverOtpEntity>("DriverOtp", driverOtpSchema);
