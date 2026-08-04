import { HydratedDocument, Schema, Types, model } from "mongoose";

export const RATING_ROLES = ["CUSTOMER", "DRIVER"] as const;
export type RatingRole = (typeof RATING_ROLES)[number];

export type RatingEntity = {
  ride_id: Types.ObjectId;
  from_user_id: Types.ObjectId;
  from_role: RatingRole;
  to_user_id: Types.ObjectId;
  to_role: RatingRole;
  rating: number;
  review?: string;
  createdAt?: Date;
  updatedAt?: Date;
};

export type RatingDocument = HydratedDocument<RatingEntity>;

const ratingSchema = new Schema<RatingEntity>(
  {
    ride_id: { type: Schema.Types.ObjectId, ref: "Ride", required: true, index: true },
    from_user_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    from_role: { type: String, enum: RATING_ROLES, required: true },
    to_user_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    to_role: { type: String, enum: RATING_ROLES, required: true },
    rating: { type: Number, required: true, min: 1, max: 5, index: true },
    review: { type: String, default: "", trim: true },
  },
  {
    collection: "ratings",
    timestamps: true,
  }
);

ratingSchema.index({ ride_id: 1, from_user_id: 1 }, { unique: true });
ratingSchema.index({ to_user_id: 1, createdAt: -1 });

export const RatingModel = model<RatingEntity>("Rating", ratingSchema);

