import { HydratedDocument, Schema, Types, model } from "mongoose";

export const RIDE_STATUSES = [
  "PENDING_CONFIRMATION",
  "SEARCHING_DRIVER",
  "DRIVER_ASSIGNED",
  "ARRIVED_AT_PICKUP",
  "PICKED_UP",
  "IN_TRANSIT",
  "STARTED",
  "COMPLETED",
  "CANCELLED",
] as const;

export type RideStatus = (typeof RIDE_STATUSES)[number];

export const PAYMENT_MODES = ["ONLINE", "CASH"] as const;
export type PaymentMode = (typeof PAYMENT_MODES)[number];

export const PAYMENT_STATUSES = ["PENDING", "SUCCESS", "FAILED"] as const;
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

type RideLocation = {
  lat: number;
  lng: number;
  address: string;
};

export type RideEntity = {
  customer_id: Types.ObjectId;
  vehicle_type_id?: Types.ObjectId | null;
  pickup: RideLocation;
  drop: RideLocation;
  /** Actual drop when customer exits early (may differ from booked drop). */
  actual_drop?: RideLocation;
  distance_km: number;
  duration_min?: number;
  /** GPS-tracked distance after trip starts. */
  actual_distance_km?: number;
  actual_duration_min?: number;
  fare: number;
  /** Defaults applied by schema; may be absent on legacy documents */
  payment_mode?: PaymentMode;
  payment_status?: PaymentStatus;
  finance_processed?: boolean;
  otp: number;
  otp_verified: boolean;
  drop_otp?: number;
  drop_otp_verified?: boolean;
  drop_reached?: boolean;
  trip_started_at?: Date;
  status: RideStatus;
  driver_id?: Types.ObjectId | null;
  /** Drivers who declined this request while SEARCHING_DRIVER */
  rejected_driver_ids?: Types.ObjectId[];
  createdAt?: Date;
  updatedAt?: Date;
};

export type RideDocument = HydratedDocument<RideEntity>;

const rideLocationSchema = new Schema<RideLocation>(
  {
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    address: { type: String, default: "" },
  },
  { _id: false }
);

const rideSchema = new Schema<RideEntity>(
  {
    customer_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    vehicle_type_id: {
      type: Schema.Types.ObjectId,
      ref: "VehicleType",
      default: null,
      index: true,
    },
    pickup: { type: rideLocationSchema, required: true },
    drop: { type: rideLocationSchema, required: true },
    actual_drop: { type: rideLocationSchema, default: undefined },
    distance_km: { type: Number, required: true, min: 0 },
    duration_min: { type: Number, default: 0, min: 0 },
    actual_distance_km: { type: Number, default: undefined, min: 0 },
    actual_duration_min: { type: Number, default: undefined, min: 0 },
    fare: { type: Number, required: true, min: 0, default: 0 },
    payment_mode: { type: String, enum: PAYMENT_MODES, default: "CASH" },
    payment_status: { type: String, enum: PAYMENT_STATUSES, default: "PENDING" },
    finance_processed: { type: Boolean, default: false },
    otp: { type: Number, required: true, min: 1000, max: 9999, default: 1000 },
    otp_verified: { type: Boolean, default: false },
    drop_otp: { type: Number, default: undefined, min: 1000, max: 9999 },
    drop_otp_verified: { type: Boolean, default: false },
    drop_reached: { type: Boolean, default: false },
    trip_started_at: { type: Date, default: undefined },
    status: { type: String, enum: RIDE_STATUSES, required: true, index: true },
    driver_id: { type: Schema.Types.ObjectId, ref: "User", default: null },
    rejected_driver_ids: { type: [{ type: Schema.Types.ObjectId, ref: "User" }], default: [] },
  },
  {
    collection: "rides",
    timestamps: true,
  }
);

rideSchema.index({ customer_id: 1, createdAt: -1 });

export const RideModel = model<RideEntity>("Ride", rideSchema);
