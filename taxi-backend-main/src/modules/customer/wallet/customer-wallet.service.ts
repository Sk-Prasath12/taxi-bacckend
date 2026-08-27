import { RideModel } from "../ride/ride.model";
import { WalletModel } from "../../finance/wallet.model";
import { HttpError } from "../../../utils/http-error";
import { UserModel } from "../../users/users.model";

const ensureCustomer = async (customerId?: string) => {
  if (!customerId) throw new HttpError(401, "Unauthorized");
  const customer = await UserModel.findOne({ _id: customerId, role: "CUSTOMER" });
  if (!customer) throw new HttpError(404, "Customer not found");
  return customer;
};

/** Customer prepaid/refund wallet balance (separate from ride spend history). */
export const getCustomerWalletBalance = async (customerIdInput?: string) => {
  const customer = await ensureCustomer(customerIdInput);
  const wallet = await WalletModel.findOne({ user_id: customer._id }).lean();
  return {
    balance: wallet?.balance ?? 0,
    total_earned: wallet?.total_earned ?? 0,
    updatedAt: wallet?.updatedAt ?? null,
  };
};

/**
 * Spend ledger from completed rides — powers customer wallet transaction UI.
 * Amounts are ride fares (debits / ride_payment), newest first.
 */
export const getCustomerWalletTransactions = async (
  customerIdInput?: string,
  limitInput?: number
) => {
  const customer = await ensureCustomer(customerIdInput);
  const limit = Math.min(Math.max(limitInput ?? 50, 1), 100);

  const rides = await RideModel.find({
    customer_id: customer._id,
    status: "COMPLETED",
  })
    .sort({ completed_at: -1, updatedAt: -1 })
    .limit(limit)
    .lean();

  const transactions = rides.map((ride) => {
    const pickup =
      typeof ride.pickup === "object" && ride.pickup && "address" in ride.pickup
        ? String((ride.pickup as { address?: string }).address ?? "Pickup")
        : "Pickup";
    const drop =
      typeof ride.drop === "object" && ride.drop && "address" in ride.drop
        ? String((ride.drop as { address?: string }).address ?? "Drop")
        : "Drop";
    return {
      id: `ride_${String(ride._id)}`,
      _id: `ride_${String(ride._id)}`,
      type: "ride_payment",
      transaction_type: "ride_payment",
      amount: Number(ride.fare ?? 0),
      description: `Ride · ${pickup} → ${drop}`,
      note: `Ride · ${pickup} → ${drop}`,
      ride_id: String(ride._id),
      payment_mode: ride.payment_mode ?? "CASH",
      payment_status: ride.payment_status ?? "PENDING",
      createdAt: ride.completed_at ?? ride.updatedAt ?? ride.createdAt ?? null,
    };
  });

  return { transactions, count: transactions.length };
};
