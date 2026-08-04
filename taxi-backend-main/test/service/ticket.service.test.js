require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/support/ticket.service");
const { RideModel } = require("../../src/modules/customer/ride/ride.model");
const { TicketModel } = require("../../src/modules/support/ticket.model");
const { TicketMessageModel } = require("../../src/modules/support/ticket-message.model");
const socket = require("../../src/socket/socket");

describe("ticket.service", () => {
  const expectHttpError = async (promise, statusCode, text) => {
    try {
      await promise;
      throw new Error("Expected failure");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(statusCode);
      expect(error.message).to.include(text);
    }
  };

  afterEach(() => sinon.restore());

  it("createTicket rejects unsupported/admin roles", async () => {
    await expectHttpError(service.createTicket({ userId: "u1", role: "USER" }, {}), 403, "Forbidden");
    await expectHttpError(service.createTicket({ userId: "u1", role: "ADMIN" }, {}), 403, "Admin cannot");
  });

  it("createTicket validates ride ownership", async () => {
    await expectHttpError(
      service.createTicket(
        { userId: new mongoose.Types.ObjectId().toString(), role: "CUSTOMER" },
        { subject: "s", description: "d", category: "RIDE_ISSUE", ride_id: "bad-id" }
      ),
      400,
      "Invalid ride id"
    );

    const userId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves({
      _id: "r1",
      customer_id: new mongoose.Types.ObjectId().toString(),
      driver_id: userId,
      fare: 100,
      distance_km: 2,
      payment_mode: "CASH",
      status: "COMPLETED",
    });
    await expectHttpError(
      service.createTicket(
        { userId, role: "CUSTOMER" },
        { subject: "s", description: "d", category: "RIDE_ISSUE", ride_id: "507f1f77bcf86cd799439011" }
      ),
      403,
      "not allowed"
    );
  });

  it("createTicket success emits event", async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves({
      _id: rideId,
      customer_id: userId,
      driver_id: null,
      fare: 100,
      distance_km: 2,
      payment_mode: "ONLINE",
      status: "COMPLETED",
    });
    sinon.stub(TicketModel, "create").resolves({
      _id: new mongoose.Types.ObjectId(),
      user_id: userId,
      role: "CUSTOMER",
      customer_id: userId,
      driver_id: null,
      subject: "s",
      description: "d",
      category: "RIDE_ISSUE",
      status: "OPEN",
      ride_id: rideId,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    sinon.stub(TicketMessageModel, "create").resolves({});
    const emit = sinon.spy();
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit }) });

    const out = await service.createTicket(
      { userId, role: "CUSTOMER" },
      { subject: "s", description: "d", category: "RIDE_ISSUE", ride_id: rideId }
    );
    expect(out.status).to.equal("OPEN");
    expect(emit.called).to.equal(true);
  });

  it("getTicketById rejects invalid and forbidden", async () => {
    await expectHttpError(service.getTicketById({ userId: "u1", role: "CUSTOMER" }, "bad"), 400, "Invalid ticket");

    const tId = new mongoose.Types.ObjectId().toString();
    sinon.stub(TicketModel, "findById").returns({
      lean: async () => ({ _id: tId, user_id: "other", role: "CUSTOMER" }),
    });
    await expectHttpError(service.getTicketById({ userId: "mine", role: "CUSTOMER" }, tId), 403, "not allowed");
  });

  it("replyToTicket handles admin in-progress transition", async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const ticket = {
      _id: new mongoose.Types.ObjectId(),
      user_id: userId,
      role: "CUSTOMER",
      customer_id: userId,
      subject: "s",
      description: "d",
      category: "RIDE_ISSUE",
      status: "OPEN",
      ride_id: null,
      createdAt: new Date(),
      updatedAt: new Date(),
      save: sinon.stub().resolves(),
    };
    sinon.stub(TicketModel, "findById").resolves(ticket);
    sinon.stub(TicketMessageModel, "create").resolves({
      sender_id: userId,
      sender_role: "ADMIN",
      message: "reply",
      createdAt: new Date(),
    });
    const emit = sinon.spy();
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit }) });

    const out = await service.replyToTicket(
      { userId: new mongoose.Types.ObjectId().toString(), role: "ADMIN" },
      ticket._id.toString(),
      "reply"
    );
    expect(out.ticket.status).to.equal("IN_PROGRESS");
    expect(ticket.save.calledOnce).to.equal(true);
    expect(emit.called).to.equal(true);
  });

  it("getMyTickets and admin listing branches", async () => {
    await expectHttpError(service.getMyTickets({ userId: "a1", role: "ADMIN" }), 403, "Forbidden");
    sinon.stub(TicketModel, "find").returns({ sort: () => ({ lean: async () => [] }) });
    const mine = await service.getMyTickets({ userId: new mongoose.Types.ObjectId().toString(), role: "CUSTOMER" });
    expect(mine).to.deep.equal([]);
    const all = await service.getAllTicketsForAdmin();
    expect(all).to.deep.equal([]);
  });

  it("getTicketById not found and updateTicketStatus branches", async () => {
    const tId = new mongoose.Types.ObjectId().toString();
    sinon.stub(TicketModel, "findById").returns({ lean: async () => null });
    await expectHttpError(service.getTicketById({ userId: "u1", role: "CUSTOMER" }, tId), 404, "Ticket not found");

    await expectHttpError(service.updateTicketStatus("bad-id", "OPEN"), 400, "Invalid ticket id");
    sinon.restore();
    sinon.stub(TicketModel, "findByIdAndUpdate").resolves(null);
    await expectHttpError(service.updateTicketStatus(tId, "OPEN"), 404, "Ticket not found");
  });
});
