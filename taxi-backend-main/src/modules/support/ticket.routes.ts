import { Router } from "express";
import { requireAuth } from "../../middlewares/auth.middleware";
import { requireRole } from "../../middlewares/role.middleware";
import { validate } from "../../middlewares/validate.middleware";
import {
  createTicketController,
  getAdminTicketsController,
  getMyTicketsController,
  getTicketByIdController,
  replyToTicketController,
  updateTicketStatusController,
} from "./ticket.controller";
import {
  createTicketSchema,
  ticketIdParamSchema,
  ticketReplySchema,
  ticketStatusUpdateSchema,
} from "./ticket.validator";

const supportRouter = Router();
supportRouter.use(requireAuth, requireRole(["CUSTOMER", "DRIVER"]));
supportRouter.post("/tickets", validate(createTicketSchema), createTicketController);
supportRouter.get("/tickets", getMyTicketsController);
supportRouter.get("/tickets/:id", validate(ticketIdParamSchema), getTicketByIdController);
supportRouter.post("/tickets/:id/reply", validate(ticketReplySchema), replyToTicketController);

const adminSupportRouter = Router();
adminSupportRouter.use(requireAuth, requireRole(["ADMIN"]));
adminSupportRouter.get("/tickets", getAdminTicketsController);
adminSupportRouter.get("/tickets/:id", validate(ticketIdParamSchema), getTicketByIdController);
adminSupportRouter.post("/tickets/:id/reply", validate(ticketReplySchema), replyToTicketController);
adminSupportRouter.patch("/tickets/:id/status", validate(ticketStatusUpdateSchema), updateTicketStatusController);

export { supportRouter, adminSupportRouter };

