import { HttpError } from "../../utils/http-error";
import { UserModel } from "./users.model";

export const saveFcmToken = async (userId: string | undefined, fcmToken: string) => {
  if (!userId) {
    throw new HttpError(401, "Unauthorized");
  }

  const normalizedToken = fcmToken.trim();
  if (!normalizedToken) {
    throw new HttpError(400, "fcm_token is required");
  }

  const user = await UserModel.findByIdAndUpdate(
    userId,
    { fcm_token: normalizedToken },
    { new: true }
  );

  if (!user) {
    throw new HttpError(404, "User not found");
  }

  return { message: "FCM token saved successfully" };
};
import { createUser, findUserByEmail } from "./users.repository";
import { UserEntity } from "./users.types";

export const usersService = {
  create: async (payload: UserEntity) => createUser(payload),
  findByEmail: async (email: string) => findUserByEmail(email),
};
