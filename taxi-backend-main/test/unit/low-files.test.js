require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const profileValidation = require("../../src/modules/driver-profile/driver-profile.validation");
const usersRepo = require("../../src/modules/users/users.repository");
const { UserModel } = require("../../src/modules/users/users.model");

describe("low coverage small files", () => {
  afterEach(() => sinon.restore());

  it("driver-profile validation accepts valid payload and rejects invalid formats", () => {
    const validId = new mongoose.Types.ObjectId().toString();
    const parsed = profileValidation.upsertDriverProfileSchema.parse({
      body: {
        phone: "+919999999999",
        ifsc_code: "SBIN0001234",
        aadhaar_number: "123412341234",
        pan_number: "ABCDE1234F",
        vehicle_type_id: validId,
      },
      params: {},
      query: {},
    });
    expect(parsed.body.vehicle_type_id).to.equal(validId);

    expect(() =>
      profileValidation.upsertDriverProfileSchema.parse({
        body: { phone: "12", ifsc_code: "BAD", aadhaar_number: "123", pan_number: "BADPAN" },
        params: {},
        query: {},
      })
    ).to.throw();
  });

  it("users repository delegates model methods", async () => {
    const findOneStub = sinon.stub(UserModel, "findOne").resolves({ id: "u1" });
    const findByIdStub = sinon.stub(UserModel, "findById").resolves({ id: "u1" });
    const createStub = sinon.stub(UserModel, "create").resolves({ id: "u2" });
    const byEmail = await usersRepo.findUserByEmail(" A@a.com ");
    const byId = await usersRepo.findUserById("u1");
    const created = await usersRepo.createUser({ email: "a@a.com" });
    expect(byEmail.id).to.equal("u1");
    expect(byId.id).to.equal("u1");
    expect(created.id).to.equal("u2");
    expect(findOneStub.calledOnce && findByIdStub.calledOnce && createStub.calledOnce).to.equal(true);
  });
});
