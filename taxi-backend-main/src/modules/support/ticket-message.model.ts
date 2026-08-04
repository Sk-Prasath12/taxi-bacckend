import { HydratedDocument, Schema, Types, model } from "mongoose";

export const TICKET_MESSAGE_SENDER_ROLES = ["USER", "ADMIN"] as const;
export type TicketMessageSenderRole = (typeof TICKET_MESSAGE_SENDER_ROLES)[number];

export type TicketMessageEntity = {
  ticket_id: Types.ObjectId;
  sender_id: Types.ObjectId;
  sender_role: TicketMessageSenderRole;
  message: string;
  createdAt?: Date;
  updatedAt?: Date;
};

export type TicketMessageDocument = HydratedDocument<TicketMessageEntity>;

const ticketMessageSchema = new Schema<TicketMessageEntity>(
  {
    ticket_id: { type: Schema.Types.ObjectId, ref: "Ticket", required: true, index: true },
    sender_id: { type: Schema.Types.ObjectId, ref: "User", required: true },
    sender_role: { type: String, enum: TICKET_MESSAGE_SENDER_ROLES, required: true, index: true },
    message: { type: String, required: true, trim: true },
  },
  {
    collection: "ticket_messages",
    timestamps: true,
  }
);

ticketMessageSchema.index({ ticket_id: 1, createdAt: 1 });

export const TicketMessageModel = model<TicketMessageEntity>("TicketMessage", ticketMessageSchema);

