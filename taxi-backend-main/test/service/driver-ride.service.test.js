require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/driver/ride/driver-ride.service");
const { UserModel } = require("../../src/modules/users/users.model");
const { RideModel } = require("../../src/modules/customer/ride/ride.model");
const socket = require("../../src/socket/socket");
const financeService = require("../../src/modules/finance/finance.service");
const invoiceService = require("../../src/modules/invoice/invoice.service");

describe("driver-ride.service", () => {
  const expectHttpError = async (promise, statusCode, text) => {
    try {
      await promise;
      throw new Error("Expected promise to fail");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(statusCode);
      expect(error.message).to.include(text);
    }
  };

  afterEach(() => {
    sinon.restore();
  });

  it("rejects acceptIncomingRide when unauthorized driver", async () => {
    await expectHttpError(service.acceptIncomingRide(undefined, new mongoose.Types.ObjectId().toString()), 401, "Unauthorized");
  });

  it("rejects duplicate ride acceptance", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({
      _id: "driver1",
      id: "driver1",
      is_blocked: false,
      is_driver_verified: true,
      driver_verification_status: "APPROVED",
    });
    sinon.stub(RideModel, "findById").resolves({
      id: rideId,
      status: "SEARCHING_DRIVER",
      driver_id: "driver2",
    });

    await expectHttpError(service.acceptIncomingRide("driver1", rideId), 409, "already accepted");
  });

  it("rejects verifyRideOtpAndStartRide for wrong OTP", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({
      id: "driver1",
      _id: "driver1",
    });
    sinon.stub(RideModel, "findById").resolves({
      id: rideId,
      driver_id: "driver1",
      status: "ARRIVED_AT_PICKUP",
      otp_verified: false,
      otp: 9876,
    });

    await expectHttpError(service.verifyRideOtpAndStartRide("driver1", rideId, 1111), 400, "Invalid OTP");
  });

  it("completes in-transit ride and emits updates", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    const ride = {
      id: rideId,
      customer_id: "cust1",
      driver_id: "driver1",
      status: "IN_TRANSIT",
      payment_mode: "CASH",
      payment_status: "PENDING",
      fare: 120,
      pickup: { lat: 1, lng: 1 },
      drop: { lat: 2, lng: 2 },
      distance_km: 4,
      duration_min: 10,
      createdAt: new Date(),
      save: sinon.stub().resolves(),
    };

    sinon.stub(UserModel, "findOne").resolves({
      id: "driver1",
      _id: "driver1",
    });
    sinon.stub(financeService, "processRidePayment").resolves();
    sinon.stub(invoiceService, "generateInvoice").resolves();
    sinon.stub(RideModel, "findById").resolves(ride);
    const emitCustomerStub = sinon.stub(socket, "emitToCustomer");
    const emitRideStub = sinon.stub(socket, "emitToRide");

    const out = await service.markRideDropped("driver1", rideId);

    expect(out.status).to.equal("COMPLETED");
    expect(ride.payment_status).to.equal("SUCCESS");
    expect(emitCustomerStub.called).to.equal(true);
    expect(emitRideStub.called).to.equal(true);
  }).timeout(10000);

  it("fails status move when drop called before pickup transit", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({ id: "driver1", _id: "driver1" });
    sinon.stub(RideModel, "findById").resolves({
      id: rideId,
      driver_id: "driver1",
      status: "DRIVER_ASSIGNED",
    });

    await expectHttpError(service.markRideDropped("driver1", rideId), 400, "IN_TRANSIT");
  });

  it("rejects blocked and unverified drivers for incoming rides", async () => {
    sinon.stub(UserModel, "findOne")
      .onFirstCall()
      .resolves({
        _id: "driver1",
        id: "driver1",
        is_blocked: true,
        blocked_reason: "policy",
        is_driver_verified: true,
        driver_verification_status: "APPROVED",
      })
      .onSecondCall()
      .resolves({
        _id: "driver1",
        id: "driver1",
        is_blocked: false,
        is_driver_verified: false,
        driver_verification_status: "PENDING",
      });

    await expectHttpError(service.getIncomingRides("driver1"), 403, "blocked");
    await expectHttpError(service.getIncomingRides("driver1"), 403, "not verified");
  });

  it("covers OTP already verified and status alias branches", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({ id: "driver1", _id: "driver1" });
    sinon.stub(RideModel, "findById")
      .onFirstCall()
      .resolves({
        id: rideId,
        driver_id: "driver1",
        status: "ARRIVED_AT_PICKUP",
        otp_verified: true,
        otp: 1111,
      })
      .onSecondCall()
      .resolves({
        id: rideId,
        driver_id: "driver1",
        status: "PICKED_UP",
        customer_id: "c1",
        pickup: {},
        drop: {},
        distance_km: 1,
        fare: 10,
        payment_mode: "CASH",
        save: sinon.stub().resolves(),
      })
      .onThirdCall()
      .resolves({
        id: rideId,
        driver_id: "driver1",
        status: "PICKED_UP",
        customer_id: "c1",
        pickup: {},
        drop: {},
        distance_km: 1,
        fare: 10,
        payment_mode: "CASH",
        save: sinon.stub().resolves(),
      });
    sinon.stub(socket, "emitToCustomer");
    sinon.stub(socket, "emitToRide");

    await expectHttpError(service.verifyRideOtpAndStartRide("driver1", rideId, 1111), 400, "already verified");
    await expectHttpError(service.updateRideStatusByDriver("driver1", rideId, "BAD_STATUS"), 400, "Unsupported status");
    const out = await service.updateRideStatusByDriver("driver1", rideId, "COMPLETED");
    expect(out.status).to.equal("COMPLETED");
  });

  it("covers incoming rides success and history mapping branches", async () => {
    const driverId = new mongoose.Types.ObjectId().toString();
    const customerId = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne")
      .onFirstCall()
      .resolves({
        _id: driverId,
        id: driverId,
        is_blocked: false,
        is_driver_verified: true,
        driver_verification_status: "APPROVED",
      })
      .onSecondCall()
      .resolves({ _id: driverId, id: driverId });
    sinon.stub(RideModel, "find")
      .onFirstCall()
      .returns({
        sort: async () => [{
          id: "r1",
          pickup: { lat: 1, lng: 1 },
          drop: { lat: 2, lng: 2 },
          distance_km: 3,
          duration_min: 8,
          fare: 90,
          status: "SEARCHING_DRIVER",
          createdAt: new Date(),
        }],
      })
      .onSecondCall()
      .returns({
        sort: async () => [{
          id: "r2",
          customer_id: customerId,
          pickup: { lat: 1, lng: 1 },
          drop: { lat: 2, lng: 2 },
          distance_km: 3,
          duration_min: 8,
          fare: 90,
          status: "COMPLETED",
          createdAt: new Date(),
          updatedAt: new Date(),
        }],
      });
    UserModel.findOne.onCall(2).resolves({ id: customerId, name: "C", email: "c@x.com", phone: "9" });

    const incoming = await service.getIncomingRides(driverId);
    const history = await service.getDriverRideHistory(driverId);
    expect(incoming.rides).to.have.lengthOf(1);
    expect(history.rides[0].customer.email).to.equal("c@x.com");
  });

  it("rejects invalid ride id and unassigned ride access", async () => {
    sinon.stub(UserModel, "findOne").resolves({ id: "driver1", _id: "driver1" });
    await expectHttpError(service.markRideInTransit("driver1", "bad-id"), 400, "Invalid ride id");

    sinon.restore();
    sinon.stub(UserModel, "findOne").resolves({ id: "driver1", _id: "driver1" });
    sinon.stub(RideModel, "findById").resolves({ id: "r1", driver_id: "other", status: "PICKED_UP" });
    await expectHttpError(service.markRideInTransit("driver1", new mongoose.Types.ObjectId().toString()), 403, "not assigned");
  });

  it("covers markRidePickedUp otp-not-verified and verifyRide wrong-status", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({ id: "driver1", _id: "driver1" });
    sinon.stub(RideModel, "findById")
      .onFirstCall()
      .resolves({
        id: rideId,
        driver_id: "driver1",
        otp_verified: false,
        status: "STARTED",
      })
      .onSecondCall()
      .resolves({
        id: rideId,
        driver_id: "driver1",
        otp_verified: false,
        status: "DRIVER_ASSIGNED",
        otp: 1234,
      });
    await expectHttpError(service.markRidePickedUp("driver1", rideId), 400, "OTP must be verified");
    await expectHttpError(service.verifyRideOtpAndStartRide("driver1", rideId, 1234), 400, "ARRIVED_AT_PICKUP");
  });

  it("covers updateRideStatusByDriver alias branches", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({ id: "driver1", _id: "driver1" });
    const emitCustomer = sinon.stub(socket, "emitToCustomer");
    sinon.stub(socket, "emitToRide");
    const mkRide = () => ({
      id: rideId,
      driver_id: "driver1",
      customer_id: "c1",
      pickup: {},
      drop: {},
      distance_km: 1,
      fare: 10,
      payment_mode: "CASH",
      status: "DRIVER_ASSIGNED",
      save: sinon.stub().resolves(),
    });
    sinon.stub(RideModel, "findById")
      .onCall(0).resolves(mkRide())
      .onCall(1).resolves(mkRide())
      .onCall(2).resolves(mkRide())
      .onCall(3).resolves(mkRide());

    await service.updateRideStatusByDriver("driver1", rideId, "SEARCHING");
    await service.updateRideStatusByDriver("driver1", rideId, "ACCEPTED");
    await service.updateRideStatusByDriver("driver1", rideId, "ARRIVED");
    await service.updateRideStatusByDriver("driver1", rideId, "CANCELLED");
    expect(emitCustomer.callCount).to.equal(4);
  });
});
