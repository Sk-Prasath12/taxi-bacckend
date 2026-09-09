import { HttpError } from "../../utils/http-error";
import { UserModel } from "./users.model";
import { createUser, findUserByEmail } from "./users.repository";
import { UserEntity } from "./users.types";

/**
 * Save FCM token for the authenticated user's app.
 * CUSTOMER → fcm_token, DRIVER → driver_fcm_token.
 * Sessions are independent: saving one never clears the other role's session or JWT.
 */
export const saveFcmToken = async (
  userId: string | undefined,
  fcmToken: string,
  roleHint?: string
) => {
  if (!userId) {
    throw new HttpError(401, "Unauthorized");
  }

  const normalizedToken = fcmToken.trim();
  if (!normalizedToken) {
    throw new HttpError(400, "fcm_token is required");
  }

  const user = await UserModel.findById(userId);
  if (!user) {
    throw new HttpError(404, "User not found");
  }

  const role = (roleHint ?? user.role ?? "CUSTOMER").toUpperCase();
  const update =
    role === "DRIVER"
      ? { driver_fcm_token: normalizedToken }
      : { fcm_token: normalizedToken };

  await UserModel.findByIdAndUpdate(userId, update, { new: true });

  return {
    message: "FCM token saved successfully",
    app: role === "DRIVER" ? "DRIVER" : "CUSTOMER",
  };
};

export const usersService = {
  create: async (payload: UserEntity) => createUser(payload),
  findByEmail: async (email: string) => findUserByEmail(email),
};
