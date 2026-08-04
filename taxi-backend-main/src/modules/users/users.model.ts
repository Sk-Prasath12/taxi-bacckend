import { Schema, model, HydratedDocument } from "mongoose";
import { DRIVER_STATUSES, DRIVER_VERIFICATION_STATUSES, USER_ROLES, UserEntity } from "./users.types";

export type UserDocument = HydratedDocument<UserEntity>;

const userSchema = new Schema<UserEntity>(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, lowercase: true, trim: true },
    phone: { type: String, required: false, trim: true },
    fcm_token: { type: String, required: false, trim: true },
    password_hash: { type: String, required: true },
    role: {
      type: String,
      enum: USER_ROLES,
      default: "CUSTOMER",
    },
    driver_status: {
      type: String,
      enum: DRIVER_STATUSES,
      default: undefined,
    },
    is_driver_verified: { type: Boolean, default: false },
    driver_verification_status: {
      type: String,
      enum: DRIVER_VERIFICATION_STATUSES,
      default: "PENDING",
    },
    driver_profile: { type: Schema.Types.Mixed, default: undefined },
    driver_location: {
      type: {
        type: String,
        enum: ["Point"],
      },
      coordinates: {
        type: [Number],
      },
    },
    driver_location_updated_at: { type: Date, default: undefined },
    is_active: { type: Boolean, default: true },
    is_blocked: { type: Boolean, default: false },
    blocked_reason: { type: String, default: null, trim: true },
  },
  {
    collection: "users",
    timestamps: { createdAt: "created_at", updatedAt: "updated_at" },
  }
);

userSchema.index({ email: 1 }, { unique: true });
userSchema.index({ role: 1 });
userSchema.index({ driver_location: "2dsphere" });

export const UserModel = model<UserEntity>("User", userSchema);
