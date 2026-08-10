import { Types } from "mongoose";
import { emitToRoom } from "../../socket/socket-emit.service";
import { HttpError } from "../../utils/http-error";
import { WalletModel } from "../finance/wallet.model";
import { WithdrawModel } from "./withdraw.model";

export const withdrawAmount = async (driverId: string, amount: number) => {
  if (typeof amount !== "number" || !Number.isFinite(amount) || amount <= 0) {
    throw new HttpError(400, "Invalid amount");
  }

  const driverObjectId = new Types.ObjectId(driverId);

  const wallet = await WalletModel.findOne({ user_id: driverObjectId }).lean();
  if (!wallet) {
    throw new HttpError(404, "Wallet not found");
  }

  const updatedWallet = await WalletModel.findOneAndUpdate(
    {
      user_id: driverObjectId,
      balance: { $gte: amount },
    },
    {
      $inc: { balance: -amount },
    },
    { new: true }
  );

  if (!updatedWallet) {
    throw new HttpError(400, "Insufficient balance");
  }

  await WithdrawModel.create({
    driver_id: driverObjectId,
    amount,
    status: "SUCCESS",
  });

  await emitToRoom(`driver_${driverId}`, "wallet_updated", {
    withdrawn: amount,
  });

  return {
    message: "Withdraw successful",
    amount,
  };
};

