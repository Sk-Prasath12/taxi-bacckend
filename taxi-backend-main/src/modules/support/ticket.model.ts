import { HydratedDocument, Schema, Types, model } from "mongoose";

export const SUPPORT_ROLES = ["CUSTOMER", "DRIVER"] as const;
export type SupportRole = (typeof SUPPORT_ROLES)[number];

export const TICKET_CATEGORIES = ["PAYMENT", "RIDE", "TECHNICAL", "OTHER"] as const;
export type TicketCategory = (typeof TICKET_CATEGORIES)[number];

export const TICKET_STATUSES = ["OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"] as const;
export type TicketStatus = (typeof TICKET_STATUSES)[number];

type RideSnapshot = {
  fare: number;
  distance_km: number;
  payment_mode?: "ONLINE" | "CASH";
  ride_status: string;
};

export type TicketEntity = {
  user_id: Types.ObjectId;
  role: SupportRole;
  ride_id?: Types.ObjectId | null;
  customer_id?: Types.ObjectId | null;
  driver_id?: Types.ObjectId | null;
  subject: string;
  description: string;
  category: TicketCategory;
  status: TicketStatus;
  ride_snapshot?: RideSnapshot | null;
  createdAt?: Date;
  updatedAt?: Date;
};

export type TicketDocument = HydratedDocument<TicketEntity>;

const rideSnapshotSchema = new Schema<RideSnapshot>(
  {
    fare: { type: Number, required: true, min: 0 },
    distance_km: { type: Number, required: true, min: 0 },
    payment_mode: { type: String, enum: ["ONLINE", "CASH"], required: false },
    ride_status: { type: String, required: true },
  },
  { _id: false }
);

const ticketSchema = new Schema<TicketEntity>(
  {
    user_id: { type: Schema.Types.ObjectId, ref: "User", required: true, index: true },
    role: { type: String, enum: SUPPORT_ROLES, required: true, index: true },
    ride_id: { type: Schema.Types.ObjectId, ref: "Ride", default: null, index: true },
    customer_id: { type: Schema.Types.ObjectId, ref: "User", default: null },
    driver_id: { type: Schema.Types.ObjectId, ref: "User", default: null },
    subject: { type: String, required: true, trim: true },
    description: { type: String, required: true, trim: true },
    category: { type: String, enum: TICKET_CATEGORIES, required: true, index: true },
    status: { type: String, enum: TICKET_STATUSES, default: "OPEN", index: true },
    ride_snapshot: { type: rideSnapshotSchema, default: null },
  },
  {
    collection: "tickets",
    timestamps: true,
  }
);

ticketSchema.index({ user_id: 1, createdAt: -1 });
ticketSchema.index({ ride_id: 1, status: 1 });

export const TicketModel = model<TicketEntity>("Ticket", ticketSchema);

