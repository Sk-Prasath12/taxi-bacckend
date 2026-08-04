import { NextFunction, Request, Response } from "express";
import { UserRole } from "../modules/users/users.types";
import { HttpError } from "../utils/http-error";

export const requireRole = (allowedRoles: UserRole[]) => {
  return (req: Request, _res: Response, next: NextFunction) => {
    if (!req.authUser) {
      return next(new HttpError(401, "Unauthorized"));
    }

    const userRole = String(req.authUser.role).toUpperCase();
    const normalizedAllowedRoles = allowedRoles.map((role) => String(role).toUpperCase());

    if (!normalizedAllowedRoles.includes(userRole)) {
      return next(new HttpError(403, "Forbidden"));
    }

    return next();
  };
};
