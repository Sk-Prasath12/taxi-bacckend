import { z } from "zod";

export const registerEmailSchema = z.object({
  body: z.object({
    name: z.string().min(2, "Name must be at least 2 characters"),
    email: z.string().email(),
    phone: z.string().min(7, "Phone number is required"),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const verifyOtpSchema = z.object({
  body: z.object({
    email: z.string().email(),
    otp: z.string().regex(/^\d{6}$/, "OTP must be 6 digits"),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const setPasswordSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const customerLoginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const updateCustomerProfileSchema = z.object({
  body: z
    .object({
      name: z.string().min(2, "Name must be at least 2 characters").optional(),
      phone: z.string().min(7, "Phone number is required").optional(),
    })
    .refine((value) => value.name !== undefined || value.phone !== undefined, {
      message: "At least one field (name or phone) is required",
    }),
  params: z.object({}),
  query: z.object({}),
});

export const forgotPasswordEmailSchema = z.object({
  body: z.object({
    email: z.string().email(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const forgotPasswordVerifyOtpSchema = z.object({
  body: z.object({
    email: z.string().email(),
    otp: z.string().regex(/^\d{6}$/, "OTP must be 6 digits"),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const forgotPasswordSetPasswordSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const changePasswordSchema = z.object({
  body: z.object({
    email: z.string().email(),
    oldPassword: z.string().min(8),
    newPassword: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});
