import { Schema, Types, model, HydratedDocument } from "mongoose";

export const LOCATION_ROLES = ["CUSTOMER", "DRIVER"] as const;
export type LocationRole = (typeof LOCATION_ROLES)[number];

export type GeoJsonPoint = {
  type: "Point";
  coordinates: [number, number];
};

export type LocationEntity = {
  user_id: Types.ObjectId;
  role: LocationRole;
  location: GeoJsonPoint;
  lat: number;
  lng: number;
  ride_id?: Types.ObjectId;
  updated_at: Date;
};

export type LocationDocument = HydratedDocument<LocationEntity>;

const geoPointSchema = new Schema<GeoJsonPoint>(
  {
    type: { type: String, enum: ["Point"], required: true, default: "Point" },
    coordinates: { type: [Number], required: true },
  },
  { _id: false }
);

const locationSchema = new Schema<LocationEntity>(
  {
    user_id: { type: Schema.Types.ObjectId, required: true, index: true },
    role: { type: String, enum: LOCATION_ROLES, required: true },
    location: { type: geoPointSchema, required: true },
    lat: { type: Number, required: true },
    lng: { type: Number, required: true },
    ride_id: { type: Schema.Types.ObjectId, default: undefined },
    updated_at: { type: Date, required: true, default: Date.now },
  },
  {
    collection: "locations",
    timestamps: false,
  }
);

locationSchema.index({ user_id: 1, role: 1 }, { unique: true });
locationSchema.index({ location: "2dsphere" });
locationSchema.index({ lat: 1, lng: 1 });
locationSchema.index({ role: 1, updated_at: -1 });

export const LocationModel = model<LocationEntity>("Location", locationSchema);
