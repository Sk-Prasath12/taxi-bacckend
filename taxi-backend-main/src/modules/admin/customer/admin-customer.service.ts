import { isValidObjectId } from "mongoose";
import { HttpError } from "../../../utils/http-error";
import { RideModel } from "../../customer/ride/ride.model";
import { RatingModel } from "../../rating/rating.model";
import { UserModel } from "../../users/users.model";

const toPositiveInt = (value: unknown, fallback: number) => {
  const num = Number(value);
  if (!Number.isFinite(num) || num < 1) {
    return fallback;
  }
  return Math.floor(num);
};

const ensureCustomerId = (customerId: string) => {
  if (!isValidObjectId(customerId)) {
    throw new HttpError(400, "Invalid customer id");
  }
};

const getCustomerOrThrow = async (customerId: string) => {
  ensureCustomerId(customerId);

  const customer = await UserModel.findOne({ _id: customerId, role: "CUSTOMER" });
  if (!customer) {
    throw new HttpError(404, "Customer not found");
  }

  return customer;
};

export const getAdminCustomers = async (pageInput?: unknown, limitInput?: unknown, searchInput?: unknown) => {
  const page = toPositiveInt(pageInput, 1);
  const limit = Math.min(toPositiveInt(limitInput, 10), 100);
  const search = typeof searchInput === "string" ? searchInput.trim() : "";

  const query: Record<string, unknown> = { role: "CUSTOMER" };
  if (search) {
    query.$or = [{ email: { $regex: search, $options: "i" } }, { name: { $regex: search, $options: "i" } }];
  }

  const [customers, total] = await Promise.all([
    UserModel.find(query)
      .sort({ created_at: -1 })
      .skip((page - 1) * limit)
      .limit(limit),
    UserModel.countDocuments(query),
  ]);

  return {
    page,
    limit,
    total,
    total_pages: Math.ceil(total / limit) || 1,
    customers: customers.map((customer) => ({
      id: customer.id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone ?? null,
      is_blocked: customer.is_blocked,
      blocked_reason: customer.blocked_reason ?? null,
      createdAt: customer.get("created_at"),
    })),
  };
};

export const getAdminCustomerDetails = async (customerId: string) => {
  const customer = await getCustomerOrThrow(customerId);
  const [totalTrips, completedTrips, cancelledTrips, ratingSummary] = await Promise.all([
    RideModel.countDocuments({ customer_id: customer.id }),
    RideModel.countDocuments({ customer_id: customer.id, status: "COMPLETED" }),
    RideModel.countDocuments({ customer_id: customer.id, status: "CANCELLED" }),
    RatingModel.aggregate<{ average_rating: number }>([
      { $match: { to_user_id: customer._id } },
      { $group: { _id: null, average_rating: { $avg: "$rating" } } },
      { $project: { _id: 0, average_rating: { $round: ["$average_rating", 1] } } },
    ]),
  ]);

  const rating = ratingSummary[0]?.average_rating ?? 0;

  return {
    id: customer.id,
    name: customer.name,
    email: customer.email,
    phone: customer.phone ?? null,
    is_active: customer.is_active,
    is_blocked: customer.is_blocked,
    blocked_reason: customer.blocked_reason ?? null,
    createdAt: customer.get("created_at"),
    updatedAt: customer.get("updated_at"),
    stats: {
      total_trips: totalTrips,
      completed_trips: completedTrips,
      cancelled_trips: cancelledTrips,
      rating,
    },
  };
};

export const updateAdminCustomerBlockStatus = async (
  customerId: string,
  isBlocked: boolean,
  reason?: string
) => {
  if (typeof isBlocked !== "boolean") {
    throw new HttpError(400, "is_blocked must be a boolean");
  }

  const customer = await getCustomerOrThrow(customerId);

  if (isBlocked) {
    const blockedReason = reason?.trim();
    if (!blockedReason) {
      throw new HttpError(400, "Reason is required when blocking customer");
    }
    customer.is_blocked = true;
    customer.blocked_reason = blockedReason;
  } else {
    customer.is_blocked = false;
    customer.blocked_reason = undefined;
  }

  await customer.save();

  return {
    message: isBlocked ? "Customer blocked successfully" : "Customer unblocked successfully",
  };
};

/** Activate customer for booking (admin test / dummy approve). */
export const adminApproveCustomerAccount = async (customerId: string) => {
  const customer = await getCustomerOrThrow(customerId);
  customer.is_active = true;
  customer.is_blocked = false;
  customer.blocked_reason = undefined;
  await customer.save();
  return {
    id: customer.id,
    email: customer.email,
    name: customer.name,
    is_active: customer.is_active,
    is_blocked: customer.is_blocked,
    message: "Customer approved — can book rides",
  };
};

export const adminApproveCustomerByEmail = async (email: string) => {
  const normalized = email.toLowerCase().trim();
  const customer = await UserModel.findOne({ email: normalized, role: "CUSTOMER" });
  if (!customer) {
    throw new HttpError(404, "Customer not found for this email");
  }
  return adminApproveCustomerAccount(customer.id);
};

export const getAdminCustomerRideHistory = async (customerId: string) => {
  const customer = await getCustomerOrThrow(customerId);
  const rides = await RideModel.find({ customer_id: customer.id }).sort({ createdAt: -1 });

  return {
    customer: {
      id: customer.id,
      name: customer.name,
      email: customer.email,
    },
    rides: rides.map((ride) => ({
      ride_id: ride.id,
      vehicle_type_id: ride.vehicle_type_id ?? null,
      pickup: ride.pickup,
      drop: ride.drop,
      actual_drop: ride.actual_drop ?? null,
      distance_km: ride.distance_km,
      actual_distance_km: ride.actual_distance_km ?? null,
      duration_min: ride.duration_min ?? null,
      actual_duration_min: ride.actual_duration_min ?? null,
      fare: ride.fare,
      status: ride.status,
      payment_mode: ride.payment_mode ?? "CASH",
      payment_status: ride.payment_status ?? "PENDING",
      finance_processed: Boolean(ride.finance_processed),
      driver_id: ride.driver_id ?? null,
      completed_at: ride.completed_at ?? null,
      createdAt: ride.createdAt,
      updatedAt: ride.updatedAt,
    })),
  };
};
