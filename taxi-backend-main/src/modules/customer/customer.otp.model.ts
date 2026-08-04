import { HydratedDocument, Schema, model } from "mongoose";

export type CustomerOtpEntity = {
  purpose?: "REGISTER" | "FORGOT_PASSWORD";
  name?: string;
  email: string;
  phone?: string;
  otp: string;
  expiresAt: Date;
  verified: boolean;
  createdAt?: Date;
};

export type CustomerOtpDocument = HydratedDocument<CustomerOtpEntity>;

const customerOtpSchema = new Schema<CustomerOtpEntity>(
  {
    purpose: {
      type: String,
      enum: ["REGISTER", "FORGOT_PASSWORD"],
      default: "REGISTER",
      index: true,
    },
    name: { type: String, required: false, trim: true },
    email: { type: String, required: true, lowercase: true, trim: true, index: true },
    phone: { type: String, required: false, trim: true },
    otp: { type: String, required: true },
    expiresAt: { type: Date, required: true },
    verified: { type: Boolean, default: false },
  },
  {
    collection: "email_otps",
    timestamps: { createdAt: true, updatedAt: false },
  }
);

customerOtpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export const CustomerOtpModel = model<CustomerOtpEntity>("CustomerOtp", customerOtpSchema);
