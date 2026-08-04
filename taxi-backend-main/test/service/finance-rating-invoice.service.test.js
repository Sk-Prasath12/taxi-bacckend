require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const financeService = require("../../src/modules/finance/finance.service");
const ratingService = require("../../src/modules/rating/rating.service");
const invoiceService = require("../../src/modules/invoice/invoice.service");
const { RideModel } = require("../../src/modules/customer/ride/ride.model");
const { WalletModel } = require("../../src/modules/finance/wallet.model");
const { DriverDueModel } = require("../../src/modules/finance/driver-due.model");
const { AdminRevenueModel } = require("../../src/modules/finance/admin-revenue.model");
const { RatingModel } = require("../../src/modules/rating/rating.model");
const { InvoiceModel } = require("../../src/modules/invoice/invoice.model");
const socket = require("../../src/socket/socket");
const { HttpError } = require("../../src/utils/http-error");
const { UserModel } = require("../../src/modules/users/users.model");

describe("finance/rating/invoice services", () => {
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

  it("processRidePayment online and cash branches", async () => {
    const ride = {
      _id: "r1",
      id: "r1",
      driver_id: "d1",
      fare: 100,
      status: "COMPLETED",
      payment_status: "SUCCESS",
      payment_mode: "ONLINE",
    };
    sinon.stub(RideModel, "findById").resolves(ride);
    sinon.stub(RideModel, "findOneAndUpdate").resolves(ride);
    sinon.stub(WalletModel, "findOneAndUpdate").resolves({});
    sinon.stub(AdminRevenueModel, "create").resolves({});
    const emit = sinon.spy();
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit }) });
    await financeService.processRidePayment(ride);
    expect(emit.called).to.equal(true);

    sinon.restore();
    const cashRide = { ...ride, payment_mode: "CASH" };
    sinon.stub(RideModel, "findById").resolves(cashRide);
    sinon.stub(RideModel, "findOneAndUpdate").resolves(cashRide);
    sinon.stub(DriverDueModel, "findOneAndUpdate").resolves({});
    sinon.stub(AdminRevenueModel, "create").resolves({});
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit: sinon.spy() }) });
    await financeService.processRidePayment(cashRide);
  });

  it("finance summary/list/dashboard methods", async () => {
    sinon.stub(AdminRevenueModel, "aggregate")
      .onCall(0).resolves([{ totalRevenue: 10, onlineRevenue: 7, cashRevenue: 3 }])
      .onCall(1).resolves([{ total: 100 }])
      .onCall(2).resolves([{ _id: { year: 2026, month: 4, day: 1 }, value: 2 }])
      .onCall(3).resolves([{ _id: { year: 2026, month: 4, day: 1 }, value: 50 }])
      .onCall(4).resolves([{ total: 40 }]);
    sinon.stub(AdminRevenueModel, "find").returns({ sort: () => ({ lean: async () => [] }) });
    sinon.stub(UserModel, "countDocuments").onCall(0).resolves(5).onCall(1).resolves(10);
    sinon.stub(RideModel, "countDocuments").onCall(0).resolves(2).onCall(1).resolves(7).onCall(2).resolves(1);
    sinon.stub(RideModel, "aggregate").resolves([{ _id: { year: 2026, month: 4, day: 1 }, value: 3 }]);

    const s = await financeService.getRevenueSummary();
    expect(s.totalRevenue).to.equal(10);
    const list = await financeService.getRevenueList();
    expect(list).to.deep.equal([]);
    const dash = await financeService.getAdminDashboardMetrics();
    expect(dash.total_drivers).to.equal(5);
  });

  it("rating create and queries", async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves(null);
    await expectHttpError(
      ratingService.createRating({ userId, role: "CUSTOMER" }, { ride_id: "r1", rating: 5 }),
      404,
      "Ride not found"
    );

    const ride = { _id: "r1", status: "COMPLETED", customer_id: userId, driver_id: "d1" };
    sinon.restore();
    sinon.stub(RideModel, "findById").resolves(ride);
    sinon.stub(RatingModel, "findOne").resolves(null);
    sinon.stub(RatingModel, "create").resolves({});
    const out = await ratingService.createRating(
      { userId, role: "CUSTOMER" },
      { ride_id: "r1", rating: 5, review: "good" }
    );
    expect(out.message).to.include("submitted");

    const findStub = sinon.stub(RatingModel, "find");
    findStub.onCall(0).returns({
      sort: () => ({
        lean: async () => [{ rating: 4, review: "", from_role: "DRIVER", from_user_id: "d1", ride_id: "r1" }],
      }),
    });
    findStub.onCall(1).returns({
      sort: () => ({
        lean: async () => [],
      }),
    });
    const mine = await ratingService.getRatingsForUser(userId);
    expect(mine).to.have.length(1);
    sinon.stub(RatingModel, "aggregate").resolves([]);
    const avg = await ratingService.getAverageRating(userId);
    expect(avg.average_rating).to.equal(0);

    const all = await ratingService.getAllRatings({ role: "DRIVER", rating: "5" });
    expect(all).to.deep.equal([]);

    await expectHttpError(
      ratingService.createRating({ userId, role: "ADMIN" }, { ride_id: "r1", rating: 4 }),
      403,
      "Only customer or driver"
    );
  });

  it("rating.createRating covers status/ownership/duplicate/target branches", async () => {
    const userId = new mongoose.Types.ObjectId().toString();
    const otherUserId = new mongoose.Types.ObjectId().toString();
    const driverUserId = new mongoose.Types.ObjectId().toString();
    const otherDriverUserId = new mongoose.Types.ObjectId().toString();

    sinon.stub(RideModel, "findById")
      .onFirstCall()
      .resolves({ _id: "r1", status: "PENDING_CONFIRMATION", customer_id: userId, driver_id: "d1" })
      .onSecondCall()
      .resolves({ _id: "r2", status: "COMPLETED", customer_id: otherUserId, driver_id: "d1" })
      .onThirdCall()
      .resolves({ _id: "r3", status: "COMPLETED", customer_id: userId, driver_id: "d1" })
      .onCall(3)
      .resolves({ _id: "r4", status: "COMPLETED", customer_id: userId, driver_id: null })
      .onCall(4)
      .resolves({ _id: "r5", status: "COMPLETED", customer_id: userId, driver_id: otherDriverUserId })
      .onCall(5)
      .resolves({ _id: "r6", status: "COMPLETED", customer_id: null, driver_id: driverUserId });

    // RatingModel.findOne is only reached for the scenarios where we pass status + ownership checks
    // (r3 -> already rated, r4 -> cannot determine rating target, r6 -> cannot determine rating target)
    sinon.stub(RatingModel, "findOne")
      .onCall(0).resolves({ _id: "already" })
      .onCall(1).resolves(null)
      .onCall(2).resolves(null);
    sinon.stub(RatingModel, "create").resolves({});

    await expectHttpError(
      ratingService.createRating({ userId, role: "CUSTOMER" }, { ride_id: "r1", rating: 5 }),
      400,
      "Only completed rides"
    );

    await expectHttpError(
      ratingService.createRating({ userId, role: "CUSTOMER" }, { ride_id: "r2", rating: 5 }),
      403,
      "not allowed"
    );

    await expectHttpError(
      ratingService.createRating({ userId, role: "CUSTOMER" }, { ride_id: "r3", rating: 5 }),
      409,
      "already submitted rating"
    );

    // fromRole CUSTOMER, but driver_id missing => cannot determine rating target
    await expectHttpError(
      ratingService.createRating({ userId, role: "CUSTOMER" }, { ride_id: "r4", rating: 5 }),
      400,
      "Cannot determine rating target"
    );

    // fromRole DRIVER, but driver_id mismatch => not allowed
    await expectHttpError(
      ratingService.createRating({ userId: driverUserId, role: "DRIVER" }, { ride_id: "r5", rating: 5 }),
      403,
      "not allowed"
    );

    // fromRole DRIVER, driver_id match, but customer_id missing => cannot determine rating target
    await expectHttpError(
      ratingService.createRating({ userId: driverUserId, role: "DRIVER" }, { ride_id: "r6", rating: 5 }),
      400,
      "Cannot determine rating target"
    );
  });

  it("rating.getAverageRating/getAllRatings branches for present/empty filters", async () => {
    const userId = new mongoose.Types.ObjectId().toString();

    sinon.stub(RatingModel, "aggregate").resolves([]);
    const avgEmpty = await ratingService.getAverageRating(userId);
    expect(avgEmpty.average_rating).to.equal(0);

    sinon.restore();
    sinon.stub(RatingModel, "aggregate").resolves([{ average_rating: 4.2, total_reviews: 3 }]);
    const avgPresent = await ratingService.getAverageRating(userId);
    expect(avgPresent.average_rating).to.equal(4.2);

    // getAllRatings: filters undefined => query remains {}
    sinon.restore();
    const findStub = sinon.stub(RatingModel, "find").returns({ sort: () => ({ lean: async () => [] }) });
    const allNoFilters = await ratingService.getAllRatings(undefined);
    expect(allNoFilters).to.deep.equal([]);
    expect(findStub.firstCall.args[0]).to.deep.equal({});

    // getAllRatings: role only branch
    sinon.restore();
    sinon.stub(RatingModel, "find").returns({ sort: () => ({ lean: async () => [] }) });
    await ratingService.getAllRatings({ role: "DRIVER" });

    // getAllRatings: rating only branch
    sinon.restore();
    const findStub2 = sinon.stub(RatingModel, "find").returns({ sort: () => ({ lean: async () => [] }) });
    await ratingService.getAllRatings({ rating: "5" });
    expect(findStub2.firstCall.args[0]).to.have.property("rating");
  });

  it("invoice generate and update paths", async () => {
    sinon.stub(RideModel, "findById").resolves(null);
    await expectHttpError(invoiceService.generateInvoice({ _id: "r1" }), 404, "Ride not found");

    sinon.restore();
    const ride = {
      _id: "r1",
      id: "r1",
      status: "COMPLETED",
      driver_id: "d1",
      customer_id: "c1",
      payment_mode: "ONLINE",
      payment_status: "PENDING",
      distance_km: 10,
      fare: 100,
    };
    sinon.stub(RideModel, "findById").resolves(ride);
    sinon.stub(InvoiceModel, "findOne").resolves(null);
    sinon.stub(InvoiceModel, "create").resolves({
      ride_id: "r1",
      distance_km: 10,
      fare: 100,
      commission: 20,
      driver_earning: 80,
      payment_mode: "ONLINE",
      payment_status: "PENDING",
      customer_id: "c1",
      driver_id: "d1",
    });
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit: sinon.spy() }) });
    const created = await invoiceService.generateInvoice({ _id: "r1" });
    expect(created.ride_id).to.equal("r1");

    sinon.stub(InvoiceModel, "findOneAndUpdate").resolves(null);
    const upd = await invoiceService.updateInvoicePaymentStatusToSuccess(new mongoose.Types.ObjectId());
    expect(upd).to.equal(null);

    sinon.restore();
    sinon.stub(RideModel, "findById").resolves({
      _id: "r1",
      status: "COMPLETED",
      driver_id: "d1",
      customer_id: "c1",
      payment_mode: "CASH",
      payment_status: "SUCCESS",
      distance_km: 5,
      fare: 60,
      id: "r1",
    });
    sinon.stub(InvoiceModel, "findOne").resolves({
      ride_id: "r1",
      distance_km: 5,
      fare: 60,
      commission: 12,
      driver_earning: 48,
      payment_mode: "CASH",
      payment_status: "SUCCESS",
    });
    const existing = await invoiceService.generateInvoice({ _id: "r1" });
    expect(existing.payment_status).to.equal("SUCCESS");

    sinon.restore();
    sinon.stub(InvoiceModel, "findOneAndUpdate").resolves({
      ride_id: "r2",
      customer_id: "c2",
      driver_id: "d2",
      distance_km: 8,
      fare: 120,
      commission: 24,
      driver_earning: 96,
      payment_mode: "ONLINE",
      payment_status: "SUCCESS",
    });
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit: sinon.spy() }) });
    const upd2 = await invoiceService.updateInvoicePaymentStatusToSuccess(new mongoose.Types.ObjectId());
    expect(upd2.payment_status).to.equal("SUCCESS");

    sinon.restore();
    sinon.stub(RideModel, "findById").resolves({
      _id: "r3",
      status: "PENDING_CONFIRMATION",
      driver_id: "d3",
      payment_mode: "ONLINE",
      payment_status: "PENDING",
    });
    await expectHttpError(invoiceService.generateInvoice({ _id: "r3" }), 400, "only for completed rides");

    sinon.restore();
    sinon.stub(RideModel, "findById").resolves({
      _id: "r4",
      status: "COMPLETED",
      driver_id: null,
      payment_mode: null,
      payment_status: null,
    });
    await expectHttpError(invoiceService.generateInvoice({ _id: "r4" }), 400, "Invalid ride data");

    sinon.restore();
    sinon.stub(RideModel, "findById").resolves({
      _id: "r5",
      status: "COMPLETED",
      id: "r5",
      driver_id: "d5",
      customer_id: "c5",
      payment_mode: "ONLINE",
      payment_status: "PENDING",
      distance_km: 7,
      fare: 140,
    });
    sinon.stub(InvoiceModel, "findOne")
      .onFirstCall()
      .resolves(null)
      .onSecondCall()
      .resolves({
        ride_id: "r5",
        distance_km: 7,
        fare: 140,
        commission: 28,
        driver_earning: 112,
        payment_mode: "ONLINE",
        payment_status: "PENDING",
      });
    sinon.stub(InvoiceModel, "create").rejects({ code: 11000 });
    const raced = await invoiceService.generateInvoice({ _id: "r5" });
    expect(raced.ride_id).to.equal("r5");
  });
});
