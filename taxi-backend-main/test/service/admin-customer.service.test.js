require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/admin/customer/admin-customer.service");
const { UserModel } = require("../../src/modules/users/users.model");
const { RideModel } = require("../../src/modules/customer/ride/ride.model");
const { RatingModel } = require("../../src/modules/rating/rating.model");

describe("admin-customer.service", () => {
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

  it("getAdminCustomers paginates and maps", async () => {
    const chain = {
      sort: () => chain,
      skip: () => chain,
      limit: async () => [
        {
          id: "c1",
          name: "C",
          email: "c@c.com",
          phone: null,
          is_blocked: false,
          blocked_reason: null,
          get: () => new Date(),
        },
      ],
    };
    sinon.stub(UserModel, "find").returns(chain);
    sinon.stub(UserModel, "countDocuments").resolves(1);

    const out = await service.getAdminCustomers("2", "5", "john");
    expect(out.page).to.equal(2);
    expect(out.limit).to.equal(5);
    expect(out.total).to.equal(1);
    expect(out.customers).to.have.length(1);
  });

  it("getAdminCustomerDetails rejects invalid id", async () => {
    await expectHttpError(service.getAdminCustomerDetails("bad"), 400, "Invalid customer id");
  });

  it("updateAdminCustomerBlockStatus enforces reason while blocking", async () => {
    const id = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({
      id,
      _id: id,
      role: "CUSTOMER",
      is_blocked: false,
      blocked_reason: null,
      save: sinon.stub().resolves(),
    });
    await expectHttpError(service.updateAdminCustomerBlockStatus(id, true, "   "), 400, "Reason is required");
  });

  it("getAdminCustomerDetails returns stats", async () => {
    const id = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({
      id,
      _id: id,
      role: "CUSTOMER",
      name: "N",
      email: "e@e.com",
      phone: null,
      is_active: true,
      is_blocked: false,
      blocked_reason: null,
      get: () => new Date(),
    });
    sinon.stub(RideModel, "countDocuments").onCall(0).resolves(10).onCall(1).resolves(7).onCall(2).resolves(3);
    sinon.stub(RatingModel, "aggregate").resolves([{ average_rating: 4.5 }]);

    const out = await service.getAdminCustomerDetails(id);
    expect(out.stats.total_trips).to.equal(10);
    expect(out.stats.rating).to.equal(4.5);
  });

  it("getAdminCustomerRideHistory maps rides", async () => {
    const id = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").resolves({
      id,
      _id: id,
      role: "CUSTOMER",
      name: "N",
      email: "e@e.com",
      get: () => new Date(),
    });
    sinon.stub(RideModel, "find").returns({
      sort: async () => [
        {
          id: "r1",
          vehicle_type_id: null,
          pickup: {},
          drop: {},
          distance_km: 2,
          duration_min: 4,
          fare: 80,
          status: "COMPLETED",
          driver_id: null,
          createdAt: new Date(),
          updatedAt: new Date(),
        },
      ],
    });
    const out = await service.getAdminCustomerRideHistory(id);
    expect(out.rides).to.have.length(1);
    expect(out.rides[0].ride_id).to.equal("r1");
  });
});
