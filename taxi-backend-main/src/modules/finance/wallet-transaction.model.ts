import { HydratedDocument, Model, Schema, Types, model, models } from "mongoose";

export type WalletTransactionType = "RIDE_EARNING" | "WITHDRAWAL" | "ADJUSTMENT";

export type WalletTransactionEntity = {
  user_id: Types.ObjectId;
  ride_id?: Types.ObjectId | null;
  type: WalletTransactionType;
  amount: number;
  /** Net credited to withdrawable balance (ONLINE only usually). */
  balance_delta: number;
  fare?: number;
  commission?: number;
  payment_mode?: "ONLINE" | "CASH";
  payment_status?: string;
  description?: string;
  createdAt?: Date;
  updatedAt?: Date;
};

export type WalletTransactionDocument = HydratedDocument<WalletTransactionEntity>;

const walletTransactionSchema = new Schema<WalletTransactionEntity>(
  {
    user_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    ride_id: { type: Schema.Types.ObjectId, ref: "Ride", default: null, index: true },
    type: {
      type: String,
      enum: ["RIDE_EARNING", "WITHDRAWAL", "ADJUSTMENT"],
      required: true,
      index: true,
    },
    amount: { type: Number, required: true },
    balance_delta: { type: Number, required: true, default: 0 },
    fare: { type: Number, default: 0 },
    commission: { type: Number, default: 0 },
    payment_mode: { type: String, enum: ["ONLINE", "CASH"], default: undefined },
    payment_status: { type: String, default: "SUCCESS" },
    description: { type: String, default: "" },
  },
  {
    collection: "wallet_transactions",
    timestamps: true,
  }
);

/** One ride earning transaction per ride (idempotency). */
walletTransactionSchema.index(
  { ride_id: 1, type: 1 },
  {
    unique: true,
    partialFilterExpression: { ride_id: { $type: "objectId" }, type: "RIDE_EARNING" },
  }
);

export const WalletTransactionModel =
  (models.WalletTransaction as Model<WalletTransactionEntity> | undefined) ??
  model<WalletTransactionEntity>("WalletTransaction", walletTransactionSchema);
