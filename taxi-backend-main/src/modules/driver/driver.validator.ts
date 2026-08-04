import { z } from "zod";

export const driverRegisterEmailSchema = z.object({
  body: z.object({
    email: z.string().email(),
  }),
  params: z.object({}),
  query: z.object({}),
});

/** Legacy/mobile one-shot register (email + password + optional name/phone). */
export const driverRegisterSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
    name: z.string().min(1).optional(),
    phone: z.string().optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverRefreshTokenSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverVerifyOtpSchema = z.object({
  body: z.object({
    email: z.string().email(),
    otp: z.string().regex(/^\d{6}$/, "OTP must be 6 digits"),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverSetPasswordSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverForgotPasswordEmailSchema = z.object({
  body: z.object({
    email: z.string().email(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverForgotPasswordVerifyOtpSchema = z.object({
  body: z.object({
    email: z.string().email(),
    otp: z.string().regex(/^[0-9]{6}$/, "OTP must be 6 digits"),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverForgotPasswordSetPasswordSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverLoginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const driverStatusSchema = z.object({
  body: z.object({
    status: z.enum(["ONLINE", "OFFLINE", "BUSY"]),
  }),
  params: z.object({}),
  query: z.object({}),
});
