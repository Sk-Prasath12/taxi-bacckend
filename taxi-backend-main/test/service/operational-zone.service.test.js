require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/operational-zone/operational-zone.service");
const { OperationalZoneModel } = require("../../src/modules/operational-zone/operational-zone.model");

describe("operational-zone.service", () => {
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

  it("createZone validates coordinates", async () => {
    await expectHttpError(service.createZone({ zone_name: "A", coordinates: [], created_by: "x" }), 400, "at least 3");
    await expectHttpError(
      service.createZone({ zone_name: "A", coordinates: [[999, 10], [10, 10], [10, 11]], created_by: "x" }),
      400,
      "Longitude"
    );
  });

  it("createZone appends closing point and persists", async () => {
    const createStub = sinon.stub(OperationalZoneModel, "create").resolves({ id: "z1" });
    await service.createZone({
      zone_name: " Zone ",
      coordinates: [[10, 10], [11, 11], [12, 12]],
      created_by: new mongoose.Types.ObjectId().toString(),
    });
    expect(createStub.calledOnce).to.equal(true);
    const arg = createStub.firstCall.args[0];
    expect(arg.zone_name).to.equal("Zone");
    expect(arg.polygon.coordinates[0].length).to.equal(4);
  });

  it("updateZone validates id and updates name", async () => {
    await expectHttpError(service.updateZone("bad-id", { zone_name: "N" }), 400, "Invalid operational zone id");

    const zone = { zone_name: "Old", polygon: {}, save: sinon.stub().resolves() };
    sinon.stub(OperationalZoneModel, "findById").resolves(zone);
    const out = await service.updateZone(new mongoose.Types.ObjectId().toString(), { zone_name: " New " });
    expect(out.zone_name).to.equal("New");
    expect(zone.save.calledOnce).to.equal(true);
  });

  it("toggleZoneStatus updates status", async () => {
    const zone = { is_active: true, save: sinon.stub().resolves() };
    sinon.stub(OperationalZoneModel, "findById").resolves(zone);
    const out = await service.toggleZoneStatus(new mongoose.Types.ObjectId().toString(), false);
    expect(out.is_active).to.equal(false);
  });

  it("checkLocationInZone validates range and validateRideLocations handles inactive zones", async () => {
    await expectHttpError(service.checkLocationInZone(200, 10), 400, "out of range");
    sinon.stub(OperationalZoneModel, "findOne").returns({ lean: async () => null });
    await expectHttpError(
      service.validateRideLocations({ lat: 10, lng: 10 }, { lat: 11, lng: 11 }),
      400,
      "Pickup zone inactive"
    );
  });
});
