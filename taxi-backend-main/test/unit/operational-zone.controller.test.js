require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const { HttpError } = require("../../src/utils/http-error");
const zoneController = require("../../src/modules/operational-zone/operational-zone.controller");
const zoneService = require("../../src/modules/operational-zone/operational-zone.service");

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

describe("operational-zone.controller", () => {
  afterEach(() => sinon.restore());

  it("createOperationalZoneController rejects when adminId missing and returns on service error", async () => {
    const next = sinon.spy();
    const res = mockRes();

    await zoneController.createOperationalZoneController({ body: {}, authUser: undefined }, res, next);
    expect(next.called).to.equal(true);
    const err = next.getCall(0).args[0];
    expect(err).to.be.instanceOf(HttpError);
    expect(err.statusCode).to.equal(401);

    sinon.restore();
    sinon.stub(zoneService, "createZone").rejects(new Error("boom"));
    const next2 = sinon.spy();
    await zoneController.createOperationalZoneController(
      { body: { zone_name: "Z", coordinates: [] }, authUser: { userId: "admin1" } },
      mockRes(),
      next2
    );
    expect(next2.called).to.equal(true);
  });

  it("covers create/get/update/toggle success response branches", async () => {
    sinon.stub(zoneService, "createZone").resolves({ id: "z1" });
    let res = mockRes();
    const next = sinon.spy();
    await zoneController.createOperationalZoneController(
      { body: { zone_name: "Z", coordinates: [] }, authUser: { userId: "admin1" } },
      res,
      next
    );
    expect(res.statusCode).to.equal(201);
    expect(res.payload.success).to.equal(true);
    expect(next.called).to.equal(false);

    sinon.stub(zoneService, "getAllZones").resolves([{ id: "z1" }]);
    res = mockRes();
    await zoneController.getOperationalZonesController({}, res, next);
    expect(res.statusCode).to.equal(200);
    expect(res.payload.data).to.have.length(1);

    sinon.stub(zoneService, "updateZone").resolves({ id: "z1" });
    res = mockRes();
    await zoneController.updateOperationalZoneController(
      { params: { id: "z1" }, body: { zone_name: "Z2", coordinates: [] } },
      res,
      next
    );
    expect(res.statusCode).to.equal(200);

    sinon.stub(zoneService, "toggleZoneStatus").resolves({ id: "z1", is_active: true });
    res = mockRes();
    await zoneController.toggleOperationalZoneStatusController(
      { params: { id: "z1" }, body: { is_active: true } },
      res,
      next
    );
    expect(res.statusCode).to.equal(200);
  });
});

