require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/driver-profile/driver-profile.service");
const { UserModel } = require("../../src/modules/users/users.model");
const { VehicleTypeModel } = require("../../src/modules/vehicle-type/vehicle-type.model");
const { DriverProfileModel } = require("../../src/modules/driver-profile/driver-profile.model");

describe("driver-profile.service", () => {
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

  it("createOrUpdateProfile rejects non-driver and bad vehicle type", async () => {
    sinon.stub(UserModel, "findOne").returns({ lean: async () => null });
    await expectHttpError(service.createOrUpdateProfile("u1", {}), 404, "Driver not found");

    sinon.restore();
    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: "u1" }) });
    sinon.stub(VehicleTypeModel, "exists").resolves(null);
    await expectHttpError(
      service.createOrUpdateProfile(new mongoose.Types.ObjectId().toString(), {
        vehicle_type_id: new mongoose.Types.ObjectId().toString(),
      }),
      400,
      "vehicle_type_id"
    );
  });

  it("createOrUpdateProfile saves and syncs", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: uid }) });
    sinon.stub(VehicleTypeModel, "exists").resolves({ _id: "v1" });
    sinon.stub(UserModel, "updateOne").resolves();
    sinon.stub(DriverProfileModel, "findOneAndUpdate").resolves({
      dob: new Date(),
      phone: "999",
      address: "a",
      license_number: "L",
      vehicle_reg_number: "R",
      vehicle_type_id: new mongoose.Types.ObjectId(),
      pan_number: "PAN",
      aadhaar_number: "1234",
      account_holder_name: "H",
      account_number: "A",
      ifsc_code: "I",
      profile_completed: false,
      save: sinon.stub().resolves(),
      toObject: () => ({
        _id: new mongoose.Types.ObjectId(),
        user_id: new mongoose.Types.ObjectId(uid),
        dob: new Date(),
        phone: "999",
        address: "a",
        emergency_contact: null,
        license_number: "L",
        vehicle_reg_number: "R",
        vehicle_type_id: new mongoose.Types.ObjectId(),
        vehicle_model: null,
        vehicle_color: null,
        pan_number: "PAN",
        aadhaar_number: "1234",
        voter_id: null,
        account_holder_name: "H",
        bank_name: null,
        branch_name: null,
        account_number: "A",
        ifsc_code: "I",
        account_type: null,
        upi_id: null,
        profile_completed: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    });
    const out = await service.createOrUpdateProfile(uid, { phone: " 999 " });
    expect(out.profile_completed).to.equal(true);
  });

  it("completeProfile and validateDriverProfile paths", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: uid }) });
    sinon.stub(DriverProfileModel, "findOne").onFirstCall().resolves(null).onSecondCall().returns({ lean: async () => null });
    await expectHttpError(service.completeProfile(uid), 404, "profile not found");
    await expectHttpError(service.validateDriverProfile(uid), 403, "incomplete");
  });

  it("completeProfile missing required fields branch", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: uid }) });
    sinon.stub(DriverProfileModel, "findOne").resolves({
      dob: null,
      phone: null,
      address: null,
      license_number: null,
      vehicle_reg_number: null,
      vehicle_type_id: null,
      pan_number: null,
      aadhaar_number: null,
      account_holder_name: null,
      account_number: null,
      ifsc_code: null,
    });
    await expectHttpError(service.completeProfile(uid), 400, "Missing or invalid required fields");
  });

  it("getProfile null and completeProfile invalid vehicle type", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(DriverProfileModel, "findOne")
      .onFirstCall()
      .resolves(null)
      .onSecondCall()
      .resolves({
        dob: new Date(),
        phone: "9",
        address: "a",
        license_number: "L",
        vehicle_reg_number: "R",
        vehicle_type_id: new mongoose.Types.ObjectId(),
        pan_number: "PAN",
        aadhaar_number: "1234",
        account_holder_name: "N",
        account_number: "A",
        ifsc_code: "I",
      });
    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: uid }) });
    sinon.stub(VehicleTypeModel, "exists").resolves(null);

    const out = await service.getProfile(uid);
    expect(out).to.equal(null);
    await expectHttpError(service.completeProfile(uid), 400, "vehicle_type_id");
  });

  it("covers findOneAndUpdate null, getProfile success, and completeProfile success", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    const vehicleTypeId = new mongoose.Types.ObjectId();

    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: uid }) });
    sinon.stub(VehicleTypeModel, "exists").resolves({ _id: vehicleTypeId });
    sinon.stub(DriverProfileModel, "findOneAndUpdate").resolves(null);
    await expectHttpError(service.createOrUpdateProfile(uid, { vehicle_type_id: vehicleTypeId.toString() }), 500, "Unable to save");

    sinon.restore();
    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: uid }) });
    sinon.stub(VehicleTypeModel, "exists").resolves({ _id: vehicleTypeId });
    sinon.stub(UserModel, "updateOne").resolves();
    const doc = {
      _id: new mongoose.Types.ObjectId(),
      user_id: new mongoose.Types.ObjectId(uid),
      dob: new Date(),
      phone: "9999999999",
      address: "addr",
      emergency_contact: null,
      license_number: "L",
      vehicle_reg_number: "REG",
      vehicle_type_id: vehicleTypeId,
      vehicle_model: null,
      vehicle_color: null,
      pan_number: "ABCDE1234F",
      aadhaar_number: "123412341234",
      voter_id: null,
      account_holder_name: "Holder",
      bank_name: null,
      branch_name: null,
      account_number: "12345",
      ifsc_code: "SBIN0001234",
      account_type: null,
      upi_id: null,
      profile_completed: true,
      createdAt: new Date(),
      updatedAt: new Date(),
      save: sinon.stub().resolves(),
      toObject() {
        return this;
      },
    };
    sinon.stub(DriverProfileModel, "findOne")
      .onFirstCall()
      .resolves(doc)
      .onSecondCall()
      .resolves(doc);

    const profile = await service.getProfile(uid);
    expect(profile.id).to.be.a("string");
    const completed = await service.completeProfile(uid);
    expect(completed.profile_completed).to.equal(true);
  });

  it("covers createOrUpdateProfile optional field branches", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findOne").returns({ lean: async () => ({ id: uid }) });
    sinon.stub(UserModel, "updateOne").resolves();
    sinon.stub(DriverProfileModel, "findOneAndUpdate").resolves({
      profile_completed: true,
      save: sinon.stub().resolves(),
      toObject: () => ({
        _id: new mongoose.Types.ObjectId(),
        user_id: new mongoose.Types.ObjectId(uid),
        dob: new Date(),
        phone: "999",
        address: "A",
        emergency_contact: "E",
        license_number: "L",
        vehicle_reg_number: "R",
        vehicle_type_id: null,
        vehicle_model: "M",
        vehicle_color: "C",
        pan_number: "ABCDE1234F",
        aadhaar_number: "123412341234",
        voter_id: "V",
        account_holder_name: "H",
        bank_name: "B",
        branch_name: "BR",
        account_number: "AC",
        ifsc_code: "SBIN0001234",
        account_type: "SAVINGS",
        upi_id: "a@upi",
        profile_completed: false,
        createdAt: new Date(),
        updatedAt: new Date(),
      }),
    });
    const out = await service.createOrUpdateProfile(uid, {
      dob: new Date(),
      phone: " 999 ",
      address: "A",
      emergency_contact: "E",
      license_number: "L",
      vehicle_reg_number: "R",
      vehicle_type_id: "",
      vehicle_model: "M",
      vehicle_color: "C",
      pan_number: "abcde1234f",
      aadhaar_number: "1234 1234 1234",
      voter_id: "V",
      account_holder_name: "H",
      bank_name: "B",
      branch_name: "BR",
      account_number: "AC",
      ifsc_code: "sbin0001234",
      account_type: "SAVINGS",
      upi_id: "a@upi",
    });
    expect(out.ifsc_code).to.equal("SBIN0001234");
  });
});
