import { z } from "zod";
import { TICKET_CATEGORIES, TICKET_STATUSES } from "./ticket.model";

const objectIdRegex = /^[a-fA-F0-9]{24}$/;

export const createTicketSchema = z.object({
  body: z.object({
    subject: z.string().trim().min(1, "subject is required"),
    description: z.string().trim().min(1, "description is required"),
    category: z.enum(TICKET_CATEGORIES),
    ride_id: z.string().regex(objectIdRegex, "Invalid ride id").optional(),
  }),
  params: z.object({}).optional(),
  query: z.object({}).optional(),
});

export const ticketIdParamSchema = z.object({
  body: z.object({}).optional(),
  params: z.object({
    id: z.string().regex(objectIdRegex, "Invalid ticket id"),
  }),
  query: z.object({}).optional(),
});

export const ticketReplySchema = z.object({
  body: z.object({
    message: z.string().trim().min(1, "message is required"),
  }),
  params: z.object({
    id: z.string().regex(objectIdRegex, "Invalid ticket id"),
  }),
  query: z.object({}).optional(),
});

export const ticketStatusUpdateSchema = z.object({
  body: z.object({
    status: z.enum(TICKET_STATUSES),
  }),
  params: z.object({
    id: z.string().regex(objectIdRegex, "Invalid ticket id"),
  }),
  query: z.object({}).optional(),
});

