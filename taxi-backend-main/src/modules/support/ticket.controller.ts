import { NextFunction, Request, Response } from "express";
import {
  createTicket,
  getAllTicketsForAdmin,
  getMyTickets,
  getTicketById,
  replyToTicket,
  updateTicketStatus,
} from "./ticket.service";
import { TicketStatus } from "./ticket.model";

const getAuthUser = (req: Request) => ({
  userId: req.authUser?.userId as string,
  role: req.authUser?.role as "ADMIN" | "CUSTOMER" | "DRIVER",
});

export const createTicketController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await createTicket(getAuthUser(req), {
      subject: req.body.subject as string,
      description: req.body.description as string,
      category: req.body.category,
      ride_id: req.body.ride_id as string | undefined,
    });
    return res.status(201).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getMyTicketsController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getMyTickets(getAuthUser(req));
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getTicketByIdController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ticketId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await getTicketById(getAuthUser(req), ticketId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const replyToTicketController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ticketId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await replyToTicket(getAuthUser(req), ticketId, req.body.message as string);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const getAdminTicketsController = async (_req: Request, res: Response, next: NextFunction) => {
  try {
    const data = await getAllTicketsForAdmin();
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const updateTicketStatusController = async (req: Request, res: Response, next: NextFunction) => {
  try {
    const ticketId = Array.isArray(req.params.id) ? req.params.id[0] : req.params.id;
    const data = await updateTicketStatus(ticketId, req.body.status as TicketStatus);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

