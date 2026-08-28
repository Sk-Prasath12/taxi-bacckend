const mongoose = require("mongoose");

const vehicleDetailsSchema = new mongoose.Schema(
  {
    type: { type: String, trim: true },
    model: { type: String, trim: true },
    plateNumber: { type: String, trim: true },
    color: { type: String, trim: true }
  },
  { _id: false }
);

const driverSchema = new mongoose.Schema(
  {
    name: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    phone: { type: String, required: true, unique: true, trim: true },
    password: { type: String, required: true },
    vehicleDetails: { type: vehicleDetailsSchema, default: {} },
    isEmailVerified: { type: Boolean, default: false },
    status: { type: String, enum: ["offline", "online", "busy"], default: "offline" },
    currentLocation: {
      type: {
        type: String,
        enum: ["Point"],
        default: "Point"
      },
      coordinates: {
        type: [Number],
        default: [0, 0]
      }
    },
    walletBalance: { type: Number, default: 0 },
    is_driver_verified: { type: Boolean, default: false },
    driver_verification_status: {
      type: String,
      enum: ["NOT_SUBMITTED", "PENDING", "APPROVED", "REJECTED"],
      default: "NOT_SUBMITTED"
    },
    verification_note: { type: String, default: "" }
  },
  { timestamps: true }
);

driverSchema.index({ currentLocation: "2dsphere" });

module.exports = mongoose.model("Driver", driverSchema);
