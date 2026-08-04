require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const axios = require("axios");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const rideService = require("../../src/modules/customer/ride/ride.service");
const { UserModel } = require("../../src/modules/users/users.model");
const { RideModel } = require("../../src/modules/customer/ride/ride.model");
const { VehicleTypeModel } = require("../../src/modules/vehicle-type/vehicle-type.model");
const zoneService = require("../../src/modules/operational-zone/operational-zone.service");
const socket = require("../../src/socket/socket");

describe("ride.service", () => {
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

  it("rejects requestRide when customerId missing", async () => {
    await expectHttpError(
      rideService.requestRide(undefined, 1, 1, "A", 2, 2, "B", new mongoose.Types.ObjectId().toString()),
      401,
      "Unauthorized"
    );
  });

  it("rejects requestRide when vehicle type id is invalid", async () => {
    sinon.stub(UserModel, "findOne").resolves({ is_blocked: false });
    sinon.stub(zoneService, "validateRideLocations").resolves();
    sinon.stub(RideModel, "findOne").resolves(null);

    await expectHttpError(
      rideService.requestRide("cust1", 1, 1, "A", 2, 2, "B", "bad-id"),
      400,
      "Invalid vehicle type"
    );
  });

  it("rejects requestRide when active ride already exists", async () => {
    sinon.stub(UserModel, "findOne").resolves({ is_blocked: false });
    sinon.stub(zoneService, "validateRideLocations").resolves();
    sinon.stub(RideModel, "findOne").resolves({ id: "active1" });

    await expectHttpError(
      rideService.requestRide("cust1", 1, 1, "A", 2, 2, "B", new mongoose.Types.ObjectId().toString()),
      409,
      "active ride"
    );
  });

  it("creates ride using OSRM fallback metrics when API fails", async () => {
    const vehicleTypeId = new mongoose.Types.ObjectId().toString();
    const rideDoc = {
      id: "r1",
      customer_id: "cust1",
      vehicle_type_id: vehicleTypeId,
      driver_id: null,
      pickup: { lat: 1, lng: 1, address: "A" },
      drop: { lat: 2, lng: 2, address: "B" },
      distance_km: 10,
      duration_min: 15,
      fare: 150,
      payment_mode: "CASH",
      payment_status: "PENDING",
      otp: 1000,
      otp_verified: false,
      status: "PENDING_CONFIRMATION",
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    sinon.stub(UserModel, "findOne").onFirstCall().resolves({ is_blocked: false }).onSecondCall().resolves(null);
    sinon.stub(zoneService, "validateRideLocations").resolves();
    sinon.stub(RideModel, "findOne").resolves(null);
    sinon.stub(VehicleTypeModel, "findById").resolves({ id: vehicleTypeId, name: "Sedan", per_km_rate: 15 });
    sinon.stub(axios, "get").rejects(new Error("osrm down"));
    sinon.stub(RideModel, "create").resolves(rideDoc);
    const emitStub = sinon.stub(socket, "emitToDrivers");

    const out = await rideService.requestRide("cust1", 1, 1, "A", 2, 2, "B", vehicleTypeId);

    expect(out.distance_km).to.equal(10);
    expect(out.duration_min).to.equal(15);
    expect(out.fare).to.equal(150);
    expect(emitStub.calledOnce).to.equal(true);
  });

  it("rejects confirmRide for wrong state transition", async () => {
    const id = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves({
      id,
      customer_id: "cust1",
      status: "SEARCHING_DRIVER",
    });

    await expectHttpError(rideService.confirmRide("cust1", id), 400, "pending confirmation");
  });

  it("active/status/cancel/invoice/history branches", async () => {
    await expectHttpError(rideService.getActiveRide(undefined), 401, "Unauthorized");
    await expectHttpError(rideService.getRideStatus("cust1", "bad-id"), 400, "Invalid ride id");

    sinon.stub(RideModel, "findOne").returns({
      sort: async () => null,
    });
    const none = await rideService.getActiveRide("cust1");
    expect(none.message).to.include("No active ride");

    sinon.restore();
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves({
      id: rideId,
      customer_id: "cust1",
      status: "COMPLETED",
      save: sinon.stub().resolves(),
    });
    await expectHttpError(rideService.cancelRide("cust1", rideId), 400, "cannot be cancelled");

    sinon.restore();
    sinon.stub(RideModel, "findById").resolves(null);
    await expectHttpError(rideService.getCustomerRideInvoice("cust1", rideId), 404, "Ride not found");

    sinon.restore();
    sinon.stub(RideModel, "find").returns({
      sort: async () => [],
    });
    const hist = await rideService.getRideHistory("cust1");
    expect(hist.rides).to.deep.equal([]);
  });

  it("covers confirmRide branches for not-found, ownership, fare recalc and payment fallback", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById")
      .onFirstCall()
      .resolves(null)
      .onSecondCall()
      .resolves({ id: rideId, customer_id: "other", status: "PENDING_CONFIRMATION" })
      .onThirdCall()
      .resolves({
        id: rideId,
        customer_id: "cust1",
        status: "PENDING_CONFIRMATION",
        fare: 0,
        distance_km: 5,
        vehicle_type_id: new mongoose.Types.ObjectId().toString(),
        payment_mode: null,
        save: sinon.stub().resolves(),
      });
    sinon.stub(VehicleTypeModel, "findById").resolves({ per_km_rate: 20 });
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit: sinon.spy() }) });
    sinon.stub(socket, "joinRideRoomForUser").returns();

    await expectHttpError(rideService.confirmRide("cust1", rideId), 404, "Ride not found");
    await expectHttpError(rideService.confirmRide("cust1", rideId), 403, "not allowed");
    const out = await rideService.confirmRide("cust1", rideId);
    expect(out.ride.fare).to.equal(100);
    expect(out.ride.payment_mode).to.equal("CASH");
  });

  it("covers ride ownership errors in status/cancel/invoice", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves({
      id: rideId,
      customer_id: "other",
      status: "PENDING_CONFIRMATION",
      pickup: {},
      drop: {},
    });
    await expectHttpError(rideService.getRideStatus("cust1", rideId), 403, "not allowed");
    await expectHttpError(rideService.cancelRide("cust1", rideId), 403, "not allowed");
    await expectHttpError(rideService.getCustomerRideInvoice("cust1", rideId), 403, "not allowed");
  });

  it("covers cancel success and ride history mapping with driver details", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves({
      id: rideId,
      customer_id: "cust1",
      status: "SEARCHING_DRIVER",
      save: sinon.stub().resolves(),
    });
    const cancelled = await rideService.cancelRide("cust1", rideId);
    expect(cancelled.message).to.include("cancelled");

    sinon.restore();
    sinon.stub(RideModel, "find").returns({
      sort: async () => [{
        id: rideId,
        customer_id: "cust1",
        driver_id: new mongoose.Types.ObjectId().toString(),
        vehicle_type_id: new mongoose.Types.ObjectId().toString(),
        pickup: { lat: 1, lng: 1 },
        drop: { lat: 2, lng: 2 },
        distance_km: 5,
        duration_min: 10,
        fare: 100,
        payment_mode: "ONLINE",
        payment_status: "SUCCESS",
        otp: 1111,
        otp_verified: true,
        status: "COMPLETED",
        createdAt: new Date(),
        updatedAt: new Date(),
      }],
    });
    sinon.stub(UserModel, "findOne").resolves({
      id: "d1",
      name: "Driver",
      phone: "999",
      driver_status: "ONLINE",
    });
    const hist = await rideService.getRideHistory("cust1");
    expect(hist.rides[0].driver.name).to.equal("Driver");
  });

  it("covers getRideStatus/cancel/getInvoice ride-not-found branches", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();
    sinon.stub(RideModel, "findById").resolves(null);
    await expectHttpError(rideService.getRideStatus("cust1", rideId), 404, "Ride not found");
    await expectHttpError(rideService.cancelRide("cust1", rideId), 404, "Ride not found");
    await expectHttpError(rideService.getCustomerRideInvoice("cust1", rideId), 404, "Ride not found");
  });

  it("covers requestRide invalid vehicleType and OSRM invalid routes", async () => {
    const vehicleTypeId = new mongoose.Types.ObjectId().toString();

    sinon.stub(UserModel, "findOne").resolves({ is_blocked: false });
    sinon.stub(zoneService, "validateRideLocations").resolves();
    sinon.stub(RideModel, "findOne").resolves(null);
    sinon.stub(VehicleTypeModel, "findById").resolves(null);
    await expectHttpError(
      rideService.requestRide("cust1", 1, 1, "A", 2, 2, "B", vehicleTypeId),
      400,
      "Invalid vehicle type"
    );

    sinon.restore();
    sinon.stub(UserModel, "findOne").resolves({ is_blocked: false });
    sinon.stub(zoneService, "validateRideLocations").resolves();
    sinon.stub(RideModel, "findOne").resolves(null);
    sinon.stub(VehicleTypeModel, "findById").resolves({ id: vehicleTypeId, name: "Sedan", per_km_rate: 15 });

    const rideDoc = {
      id: "r1",
      customer_id: "cust1",
      vehicle_type_id: vehicleTypeId,
      driver_id: null,
      pickup: { lat: 1, lng: 1, address: "A" },
      drop: { lat: 2, lng: 2, address: "B" },
      distance_km: 10,
      duration_min: 15,
      fare: 150,
      payment_mode: "CASH",
      payment_status: "PENDING",
      otp: 1000,
      otp_verified: false,
      status: "PENDING_CONFIRMATION",
      createdAt: new Date(),
      updatedAt: new Date(),
    };

    sinon.stub(axios, "get").resolves({ data: { routes: [] } });
    sinon.stub(RideModel, "create").resolves(rideDoc);
    sinon.stub(socket, "emitToDrivers").resolves();

    const out = await rideService.requestRide("cust1", 1, 1, "A", 2, 2, "B", vehicleTypeId);
    expect(out.distance_km).to.equal(10);
    expect(out.duration_min).to.equal(15);
    expect(out.fare).to.equal(150);
  });

  it("covers confirmRide payment_mode option branch", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();

    sinon.stub(RideModel, "findById").resolves({
      id: rideId,
      customer_id: "cust1",
      status: "PENDING_CONFIRMATION",
      fare: 50,
      distance_km: 1,
      vehicle_type_id: new mongoose.Types.ObjectId().toString(),
      payment_mode: null,
      pickup: {},
      drop: {},
      otp_verified: false,
      save: sinon.stub().resolves(),
    });
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit: sinon.spy() }) });
    sinon.stub(socket, "joinRideRoomForUser").returns();

    const out = await rideService.confirmRide("cust1", rideId, { payment_mode: "ONLINE" });
    expect(out.ride.payment_mode).to.equal("ONLINE");
    expect(out.ride.payment_status).to.equal("PENDING");
  });

  it("covers getCustomerRideInvoice driver null vs present", async () => {
    const rideId = new mongoose.Types.ObjectId().toString();

    sinon.stub(RideModel, "findById")
      .onFirstCall()
      .resolves({
      id: rideId,
      customer_id: "cust1",
      driver_id: null,
      pickup: { address: "P" },
      drop: { address: "D" },
      distance_km: 5,
      duration_min: undefined,
      fare: 123,
      payment_mode: undefined,
      payment_status: undefined,
      createdAt: new Date(),
      })
      .onSecondCall()
      .resolves({
        id: rideId,
        customer_id: "cust1",
        driver_id: new mongoose.Types.ObjectId().toString(),
        pickup: { address: "P" },
        drop: { address: "D" },
        distance_km: 5,
        duration_min: 20,
        fare: 123,
        payment_mode: "ONLINE",
        payment_status: "SUCCESS",
        createdAt: new Date(),
      });

    const outNullDriver = await rideService.getCustomerRideInvoice("cust1", rideId);
    expect(outNullDriver.driver).to.equal(null);
    expect(outNullDriver.payment_mode).to.equal("CASH");

    sinon.stub(UserModel, "findOne").resolves({
      id: "d1",
      name: "Driver",
      phone: null,
      driver_status: "ONLINE",
    });

    const outWithDriver = await rideService.getCustomerRideInvoice("cust1", rideId);
    expect(outWithDriver.driver.name).to.equal("Driver");
    expect(outWithDriver.driver.status).to.equal("ONLINE");
  });
});
