import { HydratedDocument, Schema, Types, model } from "mongoose";

export const WITHDRAW_STATUSES = ["SUCCESS"] as const;
export type WithdrawStatus = (typeof WITHDRAW_STATUSES)[number];

export type WithdrawEntity = {
  driver_id: Types.ObjectId;
  amount: number;
  status: WithdrawStatus;
  createdAt?: Date;
};

export type WithdrawDocument = HydratedDocument<WithdrawEntity>;

const withdrawSchema = new Schema<WithdrawEntity>(
  {
    driver_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    amount: { type: Number, required: true, min: 0 },
    status: { type: String, enum: WITHDRAW_STATUSES, required: true, index: true },
  },
  {
    collection: "withdraws",
    timestamps: { updatedAt: false },
  }
);

withdrawSchema.index({ driver_id: 1, createdAt: -1 });

export const WithdrawModel = model<WithdrawEntity>("Withdraw", withdrawSchema);

