require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const rideController = require("../../src/modules/customer/ride/ride.controller");
const rideService = require("../../src/modules/customer/ride/ride.service");
const driverRideController = require("../../src/modules/driver/ride/driver-ride.controller");
const driverRideService = require("../../src/modules/driver/ride/driver-ride.service");

const resFactory = () => {
  const res = {};
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (data) => {
    res.data = data;
    return res;
  };
  return res;
};

describe("ride and driver-ride controllers", () => {
  afterEach(() => sinon.restore());

  it("customer ride controllers success + error branches", async () => {
    const next = sinon.spy();
    sinon.stub(rideService, "requestRide").resolves({ ok: true });
    sinon.stub(rideService, "confirmRide").resolves({ ok: true });
    sinon.stub(rideService, "getActiveRide").resolves({ ok: true });
    sinon.stub(rideService, "getRideStatus").resolves({ ok: true });
    sinon.stub(rideService, "cancelRide").resolves({ ok: true });
    sinon.stub(rideService, "getRideHistory").resolves([]);
    sinon.stub(rideService, "getCustomerRideInvoice").resolves({ ok: true });

    await rideController.requestRideController(
      { authUser: { userId: "u1" }, body: { pickup_address: null, drop_address: undefined } },
      resFactory(),
      next
    );
    await rideController.confirmRideController(
      { authUser: { userId: "u1" }, body: { ride_id: "r1", payment_mode: "CASH" } },
      resFactory(),
      next
    );
    await rideController.getRideStatusController(
      { authUser: { userId: "u1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );
    await rideController.cancelRideController(
      { authUser: { userId: "u1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );
    await rideController.getRideHistoryController({ authUser: { userId: "u1" } }, resFactory(), next);
    await rideController.getRideInvoiceController(
      { authUser: { userId: "u1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );

    rideService.getActiveRide.restore();
    sinon.stub(rideService, "getActiveRide").rejects(new Error("boom"));
    await rideController.getActiveRideController({ authUser: { userId: "u1" } }, resFactory(), next);
    expect(next.called).to.equal(true);
  });

  it("driver ride controllers success + error branches", async () => {
    const next = sinon.spy();
    sinon.stub(driverRideService, "getIncomingRides").resolves([]);
    sinon.stub(driverRideService, "acceptIncomingRide").resolves({ ok: true });
    sinon.stub(driverRideService, "markRideArrivedAtPickup").resolves({ ok: true });
    sinon.stub(driverRideService, "markRidePickedUp").resolves({ ok: true });
    sinon.stub(driverRideService, "markRideInTransit").resolves({ ok: true });
    sinon.stub(driverRideService, "verifyRideOtpAndStartRide").resolves({ ok: true });
    sinon.stub(driverRideService, "markRideDropped").resolves({ ok: true });
    sinon.stub(driverRideService, "getDriverRideHistory").resolves([]);
    sinon.stub(driverRideService, "updateRideStatusByDriver").resolves({ ok: true });

    await driverRideController.getIncomingRidesController({ authUser: { userId: "d1" } }, resFactory(), next);
    await driverRideController.acceptIncomingRideController(
      { authUser: { userId: "d1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );
    await driverRideController.acceptIncomingRideByBodyController(
      { authUser: { userId: "d1" }, body: { ride_id: "r1" } },
      resFactory(),
      next
    );
    await driverRideController.markRideArrivedAtPickupController(
      { authUser: { userId: "d1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );
    await driverRideController.markRidePickedUpController(
      { authUser: { userId: "d1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );
    await driverRideController.markRideInTransitController(
      { authUser: { userId: "d1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );
    await driverRideController.verifyRideOtpController(
      { authUser: { userId: "d1" }, params: { rideId: ["r1"] }, body: { otp: 1234 } },
      resFactory(),
      next
    );
    await driverRideController.markRideDroppedController(
      { authUser: { userId: "d1" }, params: { rideId: ["r1"] } },
      resFactory(),
      next
    );
    await driverRideController.getDriverRideHistoryController(
      { authUser: { userId: "d1" } },
      resFactory(),
      next
    );
    await driverRideController.updateRideStatusController(
      { authUser: { userId: "d1" }, params: { rideId: ["r1"] }, body: { status: "COMPLETED" } },
      resFactory(),
      next
    );

    driverRideService.getIncomingRides.restore();
    sinon.stub(driverRideService, "getIncomingRides").rejects(new Error("x"));
    await driverRideController.getIncomingRidesController({ authUser: { userId: "d1" } }, resFactory(), next);
    expect(next.called).to.equal(true);
  });
});
