import { Request, Response, NextFunction } from "express";
import { AnyZodObject } from "zod";
import { HttpError } from "../utils/http-error";

export const validate =
  (schema: AnyZodObject) => (req: Request, _res: Response, next: NextFunction) => {
    const validation = schema.safeParse({
      // GET (and some other) requests have no JSON body; Zod z.object({}) rejects undefined.
      body: req.body ?? {},
      params: req.params,
      query: req.query ?? {},
    });

    if (!validation.success) {
      return next(
        new HttpError(400, validation.error.issues[0]?.message || "Validation failed")
      );
    }

    return next();
  };
