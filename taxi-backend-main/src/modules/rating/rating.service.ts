import { Types } from "mongoose";
import { HttpError } from "../../utils/http-error";
import { RideModel } from "../customer/ride/ride.model";
import { UserRole } from "../users/users.types";
import { RatingModel, RatingRole } from "./rating.model";

type AuthUser = {
  userId: string;
  role: UserRole;
};

type CreateRatingPayload = {
  ride_id: string;
  rating: number;
  review?: string;
};

const toRatingResponse = (rating: any) => ({
  id: String(rating._id),
  ride_id: String(rating.ride_id),
  from_user_id: String(rating.from_user_id),
  from_role: rating.from_role,
  to_user_id: String(rating.to_user_id),
  to_role: rating.to_role,
  rating: rating.rating,
  review: rating.review ?? "",
  createdAt: rating.createdAt,
});

const ensureRatingRole = (role: UserRole): RatingRole => {
  if (role !== "CUSTOMER" && role !== "DRIVER") {
    throw new HttpError(403, "Only customer or driver can submit ratings");
  }
  return role;
};

export const createRating = async (user: AuthUser, payload: CreateRatingPayload) => {
  const fromRole = ensureRatingRole(user.role);
  const { ride_id, rating, review } = payload;

  const ride = await RideModel.findById(ride_id);
  if (!ride) {
    throw new HttpError(404, "Ride not found");
  }
  if (ride.status !== "COMPLETED") {
    throw new HttpError(400, "Only completed rides can be rated");
  }

  if (fromRole === "CUSTOMER" && String(ride.customer_id) !== user.userId) {
    throw new HttpError(403, "You are not allowed to rate this ride");
  }
  if (fromRole === "DRIVER" && (!ride.driver_id || String(ride.driver_id) !== user.userId)) {
    throw new HttpError(403, "You are not allowed to rate this ride");
  }

  const alreadyRated = await RatingModel.findOne({
    ride_id: ride._id,
    from_user_id: new Types.ObjectId(user.userId),
  });
  if (alreadyRated) {
    throw new HttpError(409, "You have already submitted rating for this ride");
  }

  const toUserId = fromRole === "CUSTOMER" ? ride.driver_id : ride.customer_id;
  if (!toUserId) {
    throw new HttpError(400, "Cannot determine rating target for this ride");
  }
  const toRole: RatingRole = fromRole === "CUSTOMER" ? "DRIVER" : "CUSTOMER";

  await RatingModel.create({
    ride_id: ride._id,
    from_user_id: new Types.ObjectId(user.userId),
    from_role: fromRole,
    to_user_id: toUserId,
    to_role: toRole,
    rating,
    review: review?.trim() ?? "",
  });

  return { message: "Rating submitted successfully" };
};

export const getRatingsForUser = async (userId: string) => {
  const ratings = await RatingModel.find({ to_user_id: new Types.ObjectId(userId) })
    .sort({ createdAt: -1 })
    .lean();

  return ratings.map((r) => ({
    rating: r.rating,
    review: r.review ?? "",
    from_role: r.from_role,
    from_user_id: String(r.from_user_id),
    ride_id: String(r.ride_id),
    createdAt: r.createdAt,
  }));
};

export const getAverageRating = async (userId: string) => {
  const result = await RatingModel.aggregate<{ average_rating: number; total_reviews: number }>([
    { $match: { to_user_id: new Types.ObjectId(userId) } },
    {
      $group: {
        _id: null,
        average_rating: { $avg: "$rating" },
        total_reviews: { $sum: 1 },
      },
    },
    {
      $project: {
        _id: 0,
        average_rating: { $round: ["$average_rating", 1] },
        total_reviews: 1,
      },
    },
  ]);

  return (
    result[0] ?? {
      average_rating: 0,
      total_reviews: 0,
    }
  );
};

export const getAllRatings = async (filters?: { role?: string; rating?: string }) => {
  const query: Record<string, unknown> = {};

  if (filters?.role) {
    query.to_role = filters.role;
  }
  if (filters?.rating) {
    query.rating = Number(filters.rating);
  }

  const ratings = await RatingModel.find(query).sort({ createdAt: -1 }).lean();
  return ratings.map(toRatingResponse);
};

