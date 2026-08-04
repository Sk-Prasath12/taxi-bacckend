require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const { successResponse } = require("../../src/utils/api-response");

const mockRes = () => {
  const res = {};
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (payload) => {
    res.payload = payload;
    return res;
  };
  return res;
};

describe("low-branch controller polish", () => {
  afterEach(() => sinon.restore());

  describe("notification.controller", () => {
    it("covers unauthorized, token required, user not found, and success branches", async () => {
      const next = sinon.spy();
      const res = mockRes();

      const { saveNotificationTokenController } = require("../../src/modules/notification/notification.controller");
      const { UserModel } = require("../../src/modules/users/users.model");

      await saveNotificationTokenController({ authUser: undefined, body: { token: "abc" } }, res, next);
      expect(next.calledOnce).to.equal(true);
      expect(next.firstCall.args[0]).to.be.instanceOf(HttpError);
      expect(next.firstCall.args[0].statusCode).to.equal(401);

      sinon.restore();
      const next2 = sinon.spy();
      const res2 = mockRes();
      await saveNotificationTokenController({ authUser: { userId: "u1" }, body: { token: "   " } }, res2, next2);
      expect(next2.calledOnce).to.equal(true);
      expect(next2.firstCall.args[0].statusCode).to.equal(400);

      sinon.restore();
      sinon.stub(UserModel, "findByIdAndUpdate").resolves(null);
      const next3 = sinon.spy();
      const res3 = mockRes();
      await saveNotificationTokenController({ authUser: { userId: "u1" }, body: { token: "t1" } }, res3, next3);
      expect(next3.calledOnce).to.equal(true);
      expect(next3.firstCall.args[0].statusCode).to.equal(404);

      sinon.restore();
      sinon.stub(UserModel, "findByIdAndUpdate").resolves({ id: "u1" });
      sinon.stub(console, "log").returns();
      const next4 = sinon.spy();
      const res4 = mockRes();
      await saveNotificationTokenController({ authUser: { userId: "u1" }, body: { token: "t1" } }, res4, next4);
      expect(next4.called).to.equal(false);
      expect(res4.statusCode).to.equal(200);
      expect(res4.payload).to.deep.equal(successResponse("FCM token saved"));
    });
  });

  describe("invoice.controller", () => {
    it("covers missing authUser, invoice-not-found, and success (rideId array) for customer+driver", async () => {
      const {
        getCustomerInvoiceController,
        getDriverInvoiceController,
        getAdminInvoicesController,
      } = require("../../src/modules/invoice/invoice.controller");
      const { InvoiceModel } = require("../../src/modules/invoice/invoice.model");

      const rideId1 = new mongoose.Types.ObjectId().toString();
      const rideId2 = new mongoose.Types.ObjectId().toString();

      // customer missing authUser -> 401
      let next = sinon.spy();
      let res = mockRes();
      await getCustomerInvoiceController({ authUser: undefined, params: { rideId: rideId1 } }, res, next);
      expect(next.calledOnce).to.equal(true);
      expect(next.firstCall.args[0].statusCode).to.equal(401);

      // customer invoice not found -> 404 (also covers rideId array handling)
      sinon.stub(InvoiceModel, "findOne").returns({
        select: () => ({
          lean: async () => null,
        }),
      });
      next = sinon.spy();
      res = mockRes();
      await getCustomerInvoiceController(
        { authUser: { userId: new mongoose.Types.ObjectId().toString() }, params: { rideId: [rideId1] } },
        res,
        next
      );
      expect(next.calledOnce).to.equal(true);
      expect(next.firstCall.args[0].statusCode).to.equal(404);

      // customer success
      const invoice = {
        ride_id: rideId2,
        distance_km: 10,
        fare: 100,
        commission: 20,
        driver_earning: 80,
        payment_mode: "ONLINE",
        payment_status: "SUCCESS",
      };
      sinon.restore();
      sinon.stub(InvoiceModel, "findOne").returns({
        select: () => ({
          lean: async () => invoice,
        }),
      });
      next = sinon.spy();
      res = mockRes();
      await getCustomerInvoiceController(
        { authUser: { userId: new mongoose.Types.ObjectId().toString() }, params: { rideId: [rideId2] } },
        res,
        next
      );
      expect(next.called).to.equal(false);
      expect(res.statusCode).to.equal(200);
      expect(res.payload.payment_status).to.equal("SUCCESS");

      // driver missing authUser -> 401
      sinon.restore();
      next = sinon.spy();
      res = mockRes();
      await getDriverInvoiceController({ authUser: undefined, params: { rideId: rideId1 } }, res, next);
      expect(next.calledOnce).to.equal(true);
      expect(next.firstCall.args[0].statusCode).to.equal(401);

      // admin get invoices error -> next called
      sinon.restore();
      sinon.stub(InvoiceModel, "find").throws(new Error("db down"));
      next = sinon.spy();
      res = mockRes();
      await getAdminInvoicesController({}, res, next);
      expect(next.calledOnce).to.equal(true);
    });
  });

  describe("users.controller", () => {
    it("covers saveFcmToken optional authUser branch (present + missing)", async () => {
      const usersService = require("../../src/modules/users/users.service");
      const { usersController } = require("../../src/modules/users/users.controller");

      sinon.stub(usersService, "saveFcmToken").resolves({ message: "saved" });

      const next = sinon.spy();
      const res1 = mockRes();
      await usersController.saveFcmToken({ authUser: { userId: "u1" }, body: { fcm_token: "t1" } }, res1, next);
      expect(res1.statusCode).to.equal(200);
      expect(res1.payload).to.deep.equal(successResponse("saved"));

      const res2 = mockRes();
      await usersController.saveFcmToken({ authUser: undefined, body: { fcm_token: "t2" } }, res2, next);
      expect(res2.statusCode).to.equal(200);
    });
  });

  describe("admin-customer.controller", () => {
    it("covers array param + error branch for admin actions", async () => {
      const adminController = require("../../src/modules/admin/customer/admin-customer.controller");
      const adminService = require("../../src/modules/admin/customer/admin-customer.service");

      sinon.stub(adminService, "getAdminCustomers").resolves({ data: [] });
      let next = sinon.spy();
      let res = mockRes();
      await adminController.getAdminCustomersController({ query: {} }, res, next);
      expect(res.statusCode).to.equal(200);

      sinon.restore();
      sinon.stub(adminService, "updateAdminCustomerBlockStatus").rejects(new HttpError(400, "bad"));
      next = sinon.spy();
      res = mockRes();
      await adminController.updateAdminCustomerBlockStatusController(
        { params: { id: ["c1"] }, body: { is_blocked: true, reason: "r" } },
        res,
        next
      );
      expect(next.calledOnce).to.equal(true);
      expect(next.firstCall.args[0].statusCode).to.equal(400);
    });
  });
});

