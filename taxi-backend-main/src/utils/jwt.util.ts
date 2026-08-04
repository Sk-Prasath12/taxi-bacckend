import jwt, { Secret, SignOptions } from "jsonwebtoken";
import { env } from "../config/env";
import { UserRole } from "../modules/users/users.types";

type TokenType = "access" | "refresh";

type TokenPayload = {
  sub: string;
  role: UserRole;
  type: TokenType;
};

export const generateAccessToken = (userId: string, role: UserRole): string => {
  const payload: TokenPayload = { sub: userId, role, type: "access" };
  const options: SignOptions = {
    expiresIn: env.JWT_ACCESS_EXPIRES_IN as SignOptions["expiresIn"],
  };
  return jwt.sign(payload, env.JWT_ACCESS_SECRET as Secret, options);
};

export const generateRefreshToken = (userId: string, role: UserRole): string => {
  const payload: TokenPayload = { sub: userId, role, type: "refresh" };
  const options: SignOptions = {
    expiresIn: env.JWT_REFRESH_EXPIRES_IN as SignOptions["expiresIn"],
  };
  return jwt.sign(payload, env.JWT_REFRESH_SECRET as Secret, options);
};

export const verifyAccessToken = (token: string): TokenPayload => {
  return jwt.verify(token, env.JWT_ACCESS_SECRET) as TokenPayload;
};

export const verifyRefreshToken = (token: string): TokenPayload => {
  return jwt.verify(token, env.JWT_REFRESH_SECRET) as TokenPayload;
};
