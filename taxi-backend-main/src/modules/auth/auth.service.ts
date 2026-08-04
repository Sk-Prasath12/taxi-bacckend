import { HttpError } from "../../utils/http-error";
import { comparePassword } from "../../utils/password.util";
import { generateAccessToken, generateRefreshToken, verifyRefreshToken } from "../../utils/jwt.util";
import { findUserByEmail, findUserById } from "../users/users.repository";

export const loginUser = async (email: string, password: string) => {
  const user = await findUserByEmail(email);

  if (!user || !user.is_active) {
    throw new HttpError(401, "Invalid credentials");
  }

  const isPasswordValid = await comparePassword(password, user.password_hash);
  if (!isPasswordValid) {
    throw new HttpError(401, "Invalid credentials");
  }

  const accessToken = generateAccessToken(user.id, user.role);
  const refreshToken = generateRefreshToken(user.id, user.role);

  return {
    accessToken,
    refreshToken,
    user: {
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
      is_blocked: user.is_blocked,
      blocked_reason: user.blocked_reason ?? null,
    },
  };
};

export const refreshAccessToken = async (refreshToken: string) => {
  const payload = verifyRefreshToken(refreshToken);

  if (payload.type !== "refresh") {
    throw new HttpError(401, "Invalid refresh token");
  }

  const user = await findUserById(payload.sub);
  if (!user || !user.is_active) {
    throw new HttpError(401, "Invalid refresh token");
  }

  return {
    accessToken: generateAccessToken(user.id, user.role),
  };
};
