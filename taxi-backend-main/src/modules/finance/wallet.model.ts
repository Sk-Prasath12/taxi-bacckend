import { HydratedDocument, Model, Schema, Types, model, models } from "mongoose";

export type WalletEntity = {
  user_id: Types.ObjectId;
  balance: number;
  total_earned: number;
  createdAt?: Date;
  updatedAt?: Date;
};

export type WalletDocument = HydratedDocument<WalletEntity>;

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
