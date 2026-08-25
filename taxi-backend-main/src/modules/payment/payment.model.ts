import { HydratedDocument, Model, Schema, Types, model, models } from "mongoose";

export const PAYMENT_STATUSES = ["CREATED", "SUCCESS", "FAILED"] as const;
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

export type PaymentEntity = {
  ride_id: Types.ObjectId;
  customer_id: Types.ObjectId;
  amount: number;
  order_id: string;
  payment_id?: string | null;
  status: PaymentStatus;
  createdAt?: Date;
  updatedAt?: Date;
};

export type PaymentDocument = HydratedDocument<PaymentEntity>;

const paymentSchema = new Schema<PaymentEntity>(
  {
    ride_id: { type: Schema.Types.ObjectId, ref: "Ride", required: true, index: true },
    customer_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    amount: { type: Number, required: true, min: 0 },
    order_id: { type: String, required: true, unique: true, index: true },
    payment_id: { type: String, default: null },
    status: { type: String, enum: PAYMENT_STATUSES, default: "CREATED", index: true },
  },
  {
    collection: "payments",
    timestamps: true,
  }
);

paymentSchema.index({ customer_id: 1, createdAt: -1 });
paymentSchema.index({ ride_id: 1, status: 1 });
/** Same Razorpay payment_id must not create duplicate success records. */
paymentSchema.index(
  { payment_id: 1 },
  { unique: true, sparse: true, partialFilterExpression: { payment_id: { $type: "string" } } }
);

export const PaymentModel = model<PaymentEntity>("Payment", paymentSchema);

export type WalletEntity = {
  user_id: Types.ObjectId;
  balance: number;
  total_earned: number;
  createdAt?: Date;
  updatedAt?: Date;
};

const walletSchema = new Schema<WalletEntity>(
  {
    user_id: { type: Schema.Types.ObjectId, ref: "User", required: true, unique: true, index: true },
    balance: { type: Number, default: 0, min: 0 },
    total_earned: { type: Number, default: 0, min: 0 },
  },
  {
    collection: "wallets",
    timestamps: true,
  }
);

export const WalletModel =
  (models.Wallet as Model<WalletEntity> | undefined) ?? model<WalletEntity>("Wallet", walletSchema);
