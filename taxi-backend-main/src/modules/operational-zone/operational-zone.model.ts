import { HydratedDocument, Schema, Types, model } from "mongoose";

export type GeoCoordinate = [number, number];

export type OperationalZoneEntity = {
  zone_name: string;
  polygon: {
    type: "Polygon";
    coordinates: GeoCoordinate[][];
  };
  is_active: boolean;
  created_by: Types.ObjectId;
};

export type OperationalZoneDocument = HydratedDocument<OperationalZoneEntity>;

const operationalZoneSchema = new Schema<OperationalZoneEntity>(
  {
    zone_name: {
      type: String,
      required: true,
      trim: true,
    },
    polygon: {
      type: {
        type: String,
        enum: ["Polygon"],
        required: true,
      },
      coordinates: {
        type: [[[Number]]],
        required: true,
      },
    },
    is_active: {
      type: Boolean,
      default: true,
    },
    created_by: {
      type: Schema.Types.ObjectId,
      required: true,
      ref: "User",
    },
  },
  {
    collection: "operational_zones",
    timestamps: true,
  }
);

operationalZoneSchema.index({ polygon: "2dsphere" });
operationalZoneSchema.index({ is_active: 1, createdAt: -1 });

export const OperationalZoneModel = model<OperationalZoneEntity>(
  "OperationalZone",
  operationalZoneSchema
);
