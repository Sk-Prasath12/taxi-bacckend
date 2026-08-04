import { Types, isValidObjectId } from "mongoose";
import { getIO } from "../../socket/socket";
import { HttpError } from "../../utils/http-error";
import { RideModel } from "../customer/ride/ride.model";
import { UserRole } from "../users/users.types";
import { TicketMessageModel } from "./ticket-message.model";
import { TicketCategory, TicketModel, TicketStatus } from "./ticket.model";

type AuthUser = {
  userId: string;
  role: UserRole;
};

type CreateTicketPayload = {
  subject: string;
  description: string;
  category: TicketCategory;
  ride_id?: string;
};

const toTicketResponse = (ticket: any) => ({
  id: String(ticket._id),
  creator_id: String(ticket.user_id),
  role: ticket.role,
  customer_id: ticket.customer_id ? String(ticket.customer_id) : null,
  driver_id: ticket.driver_id ? String(ticket.driver_id) : null,
  subject: ticket.subject,
  description: ticket.description,
  category: ticket.category,
  status: ticket.status,
  ride_id: ticket.ride_id ? String(ticket.ride_id) : null,
  createdAt: ticket.createdAt,
  updatedAt: ticket.updatedAt,
});

const toMessageResponse = (message: any, ticketOwnerRole: "CUSTOMER" | "DRIVER") => ({
  sender_id: String(message.sender_id),
  sender_role: message.sender_role,
  sender_user_role: message.sender_role === "USER" ? ticketOwnerRole : "ADMIN",
  message: message.message,
  createdAt: message.createdAt,
});

const ensureSupportedUserRole = (role?: UserRole) => {
  if (role !== "CUSTOMER" && role !== "DRIVER" && role !== "ADMIN") {
    throw new HttpError(403, "Forbidden");
  }
};

const ensureTicketOwnership = (ticket: any, user: AuthUser) => {
  if (user.role === "ADMIN") {
    return;
  }
  if (String(ticket.user_id) !== user.userId) {
    throw new HttpError(403, "You are not allowed to access this ticket");
  }
};

export const createTicket = async (user: AuthUser, payload: CreateTicketPayload) => {
  ensureSupportedUserRole(user.role);
  if (user.role === "ADMIN") {
    throw new HttpError(403, "Admin cannot create support tickets from this endpoint");
  }

  const { subject, description, category, ride_id } = payload;

  let rideRef: Types.ObjectId | null = null;
  let customerId: Types.ObjectId | null =
    user.role === "CUSTOMER" ? new Types.ObjectId(user.userId) : null;
  let driverId: Types.ObjectId | null = user.role === "DRIVER" ? new Types.ObjectId(user.userId) : null;
  let rideSnapshot: Record<string, unknown> | null = null;

  if (ride_id) {
    if (!isValidObjectId(ride_id)) {
      throw new HttpError(400, "Invalid ride id");
    }
    const ride = await RideModel.findById(ride_id);
    if (!ride) {
      throw new HttpError(404, "Ride not found");
    }

    if (user.role === "CUSTOMER" && String(ride.customer_id) !== user.userId) {
      throw new HttpError(403, "You are not allowed to create ticket for this ride");
    }
    if (user.role === "DRIVER" && (!ride.driver_id || String(ride.driver_id) !== user.userId)) {
      throw new HttpError(403, "You are not allowed to create ticket for this ride");
    }

    rideRef = ride._id;
    customerId = ride.customer_id;
    driverId = ride.driver_id ?? null;
    rideSnapshot = {
      fare: ride.fare,
      distance_km: ride.distance_km,
      payment_mode: ride.payment_mode,
      ride_status: ride.status,
    };
  }

  const ticket = await TicketModel.create({
    user_id: new Types.ObjectId(user.userId),
    role: user.role,
    ride_id: rideRef,
    customer_id: customerId,
    driver_id: driverId,
    subject,
    description,
    category,
    ride_snapshot: rideSnapshot,
  });

  await TicketMessageModel.create({
    ticket_id: ticket._id,
    sender_id: new Types.ObjectId(user.userId),
    sender_role: "USER",
    message: description,
  });

  getIO().to(`${user.role.toLowerCase()}_${user.userId}`).emit("ticket_created", {
    ticket_id: String(ticket._id),
    status: ticket.status,
  });

  return toTicketResponse(ticket);
};

export const getMyTickets = async (user: AuthUser) => {
  ensureSupportedUserRole(user.role);
  if (user.role === "ADMIN") {
    throw new HttpError(403, "Forbidden");
  }

  const tickets = await TicketModel.find({ user_id: new Types.ObjectId(user.userId) })
    .sort({ createdAt: -1 })
    .lean();

  return tickets.map(toTicketResponse);
};

export const getAllTicketsForAdmin = async () => {
  const tickets = await TicketModel.find().sort({ createdAt: -1 }).lean();
  return tickets.map(toTicketResponse);
};

export const getTicketById = async (user: AuthUser, ticketId: string) => {
  ensureSupportedUserRole(user.role);
  if (!isValidObjectId(ticketId)) {
    throw new HttpError(400, "Invalid ticket id");
  }

  const ticket = await TicketModel.findById(ticketId).lean();
  if (!ticket) {
    throw new HttpError(404, "Ticket not found");
  }

  ensureTicketOwnership(ticket, user);

  const messages = await TicketMessageModel.find({ ticket_id: ticket._id }).sort({ createdAt: 1 }).lean();

  return {
    ticket: toTicketResponse(ticket),
    messages: messages.map((message) => toMessageResponse(message, ticket.role)),
  };
};

export const replyToTicket = async (user: AuthUser, ticketId: string, message: string) => {
  ensureSupportedUserRole(user.role);
  if (!isValidObjectId(ticketId)) {
    throw new HttpError(400, "Invalid ticket id");
  }

  const ticket = await TicketModel.findById(ticketId);
  if (!ticket) {
    throw new HttpError(404, "Ticket not found");
  }

  ensureTicketOwnership(ticket, user);

  const senderRole = user.role === "ADMIN" ? "ADMIN" : "USER";
  const createdMessage = await TicketMessageModel.create({
    ticket_id: ticket._id,
    sender_id: new Types.ObjectId(user.userId),
    sender_role: senderRole,
    message,
  });

  if (user.role === "ADMIN" && ticket.status === "OPEN") {
    ticket.status = "IN_PROGRESS";
    await ticket.save();
  }

  getIO().to(`${ticket.role.toLowerCase()}_${String(ticket.user_id)}`).emit("ticket_replied", {
    ticket_id: String(ticket._id),
    sender_role: senderRole,
  });

  return {
    ticket: toTicketResponse(ticket),
    message: toMessageResponse(createdMessage, ticket.role),
  };
};

export const updateTicketStatus = async (ticketId: string, status: TicketStatus) => {
  if (!isValidObjectId(ticketId)) {
    throw new HttpError(400, "Invalid ticket id");
  }

  const ticket = await TicketModel.findByIdAndUpdate(ticketId, { status }, { new: true });
  if (!ticket) {
    throw new HttpError(404, "Ticket not found");
  }

  getIO().to(`${ticket.role.toLowerCase()}_${String(ticket.user_id)}`).emit("ticket_replied", {
    ticket_id: String(ticket._id),
    status: ticket.status,
  });

  return toTicketResponse(ticket);
};

