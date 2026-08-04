import { z } from "zod";

const objectIdSchema = z.string().regex(/^[a-fA-F0-9]{24}$/, "Invalid id");

export const authRegisterSchema = z.object({
  body: z.object({
    name: z.string().min(1),
    email: z.string().email(),
    phone: z.string().min(8),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const authLoginSchema = z.object({
  body: z.object({
    email: z.string().email(),
    password: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const authRefreshSchema = z.object({
  body: z.object({
    refreshToken: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const authForgotPasswordSchema = z.object({
  body: z.object({
    email: z.string().email(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const authResetPasswordSchema = z.object({
  body: z.object({
    email: z.string().email(),
    token: z.string().min(1),
    newPassword: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const authVerifyOtpSchema = z.object({
  body: z.object({
    phone: z.string().min(8),
    otp: z.string().length(6),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const authResendOtpSchema = z.object({
  body: z.object({
    phone: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const updateDriverProfileSchema = z.object({
  body: z.object({
    name: z.string().optional(),
    phone: z.string().optional(),
    bio: z.string().optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const uploadPhotoSchema = z.object({
  body: z.object({
    photo_url: z.string().url(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const changePasswordSchema = z.object({
  body: z.object({
    oldPassword: z.string().min(8),
    newPassword: z.string().min(8),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const vehicleAddSchema = z.object({
  body: z.object({
    make: z.string().min(1),
    model: z.string().min(1),
    year: z.number().int().min(1900).max(new Date().getFullYear() + 1),
    plate_number: z.string().min(1),
    color: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const vehicleUpdateSchema = z.object({
  body: z.object({
    vehicle_id: objectIdSchema,
    make: z.string().optional(),
    model: z.string().optional(),
    year: z.number().int().min(1900).max(new Date().getFullYear() + 1).optional(),
    plate_number: z.string().optional(),
    color: z.string().optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const uploadVehicleDocsSchema = z.object({
  body: z.object({
    vehicle_id: objectIdSchema,
    document_type: z.string().min(1),
    document_url: z.string().url(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const locationUpdateSchema = z.object({
  body: z.object({
    latitude: z.number(),
    longitude: z.number(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const rideActionSchema = z.object({
  body: z.object({
    ride_id: objectIdSchema,
  }),
  params: z.object({}),
  query: z.object({}),
});

export const rideRequestDetailsSchema = z.object({
  body: z.object({}),
  params: z.object({
    id: objectIdSchema,
  }),
  query: z.object({}),
});

export const rideIdParamSchema = z.object({
  body: z.object({}),
  params: z.object({
    ride_id: objectIdSchema,
  }),
  query: z.object({}),
});

export const fareCalculateSchema = z.object({
  body: z.object({
    pickup: z.string().min(1),
    drop: z.string().min(1),
    distance_km: z.number().positive(),
    duration_min: z.number().positive(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const fareDetailsSchema = z.object({
  body: z.object({}),
  params: z.object({
    ride_id: objectIdSchema,
  }),
  query: z.object({}),
});

export const paymentCreateSchema = z.object({
  body: z.object({
    ride_id: objectIdSchema,
  }),
  params: z.object({}),
  query: z.object({}),
});

export const paymentConfirmSchema = z.object({
  body: z.object({
    ride_id: objectIdSchema,
    payment_id: z.string().min(1),
    signature: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const paymentRefundSchema = z.object({
  body: z.object({
    payment_id: z.string().min(1),
    amount: z.number().positive(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const ratingSubmitSchema = z.object({
  body: z.object({
    ride_id: objectIdSchema,
    rating: z.number().int().min(1).max(5),
    review: z.string().optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const notificationRegisterSchema = z.object({
  body: z.object({
    device_token: z.string().min(1),
    platform: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const supportCreateTicketSchema = z.object({
  body: z.object({
    subject: z.string().min(1),
    description: z.string().min(1),
    ride_id: objectIdSchema.optional(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const supportReplyTicketSchema = z.object({
  body: z.object({
    ticket_id: objectIdSchema,
    message: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const settingsUpdateSchema = z.object({
  body: z.object({
    settings: z.record(z.any()),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const walletAddMoneySchema = z.object({
  body: z.object({
    amount: z.number().positive(),
  }),
  params: z.object({}),
  query: z.object({}),
});

export const walletWithdrawRequestSchema = z.object({
  body: z.object({
    amount: z.number().positive(),
    method: z.string().min(1),
  }),
  params: z.object({}),
  query: z.object({}),
});
