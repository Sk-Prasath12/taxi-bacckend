import { NextFunction, Request, Response } from "express";
import jwt from "jsonwebtoken";
import { verifyAccessToken } from "../utils/jwt.util";
import { HttpError } from "../utils/http-error";

export const requireAuth = (req: Request, _res: Response, next: NextFunction) => {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return next(new HttpError(401, "Unauthorized"));
  }

  const raw = authHeader.slice(7).trim();
  if (!raw || raw === "undefined" || raw === "null") {
    return next(new HttpError(401, "Missing access token (check REST Client: run Admin login first, then use @adminAccessToken)"));
  }

  try {
    const payload = verifyAccessToken(raw);

    if (payload.type !== "access") {
      return next(new HttpError(401, "Invalid access token"));
    }

    req.authUser = { userId: payload.sub, role: payload.role };
    return next();
  } catch (error) {
    if (error instanceof jwt.TokenExpiredError) {
      return next(new HttpError(401, "Access token expired — log in again"));
    }
    if (error instanceof jwt.JsonWebTokenError) {
      return next(new HttpError(401, "Invalid access token — copy data.accessToken from login, or re-run Admin login"));
    }
    return next(new HttpError(401, "Invalid or expired token"));
  }
};
