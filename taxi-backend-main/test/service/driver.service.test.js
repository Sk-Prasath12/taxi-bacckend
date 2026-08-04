require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/driver/driver.service");
const { UserModel } = require("../../src/modules/users/users.model");
const { DriverOtpModel } = require("../../src/modules/driver/driver.otp.model");
const passwordUtil = require("../../src/utils/password.util");
const jwtUtil = require("../../src/utils/jwt.util");
const profileService = require("../../src/modules/driver-profile/driver-profile.service");
const { WalletModel } = require("../../src/modules/finance/wallet.model");
const { DriverDueModel } = require("../../src/modules/finance/driver-due.model");

describe("driver.service", () => {
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

  it("send/verify otp validation paths", async () => {
    sinon.stub(UserModel, "findOne").resolves({ id: "d1" });
    await expectHttpError(service.sendDriverRegistrationOtp("d@d.com"), 409, "already exists");

    sinon.restore();
    sinon.stub(DriverOtpModel, "findOne").returns({ sort: async () => null });
    await expectHttpError(service.verifyDriverRegistrationOtp("d@d.com", "111111"), 400, "not found");
  });

  it("setDriverRegistrationPassword creates driver", async () => {
    sinon.stub(UserModel, "findOne").resolves(null);
    sinon.stub(DriverOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() + 10000), verified: true }),
    });
    sinon.stub(passwordUtil, "hashPassword").resolves("hash");
    sinon.stub(UserModel, "create").resolves({ id: "d1", name: "D", email: "d@d.com" });
    sinon.stub(DriverOtpModel, "deleteMany").resolves();
    sinon.stub(jwtUtil, "generateAccessToken").returns("token-d");

    const out = await service.setDriverRegistrationPassword("d@d.com", "pass");
    expect(out.token).to.equal("token-d");
    expect(out.user.role).to.equal("driver");
  });

  it("loginDriver rejects invalid credentials", async () => {
    sinon.stub(UserModel, "findOne").resolves(null);
    await expectHttpError(service.loginDriver("d@d.com", "x"), 401, "Invalid email or password");
  });

  it("profile status wallet earnings flows", async () => {
    await expectHttpError(service.getDriverProfile(undefined), 401, "Unauthorized");

    const driver = {
      id: "d1",
      _id: "d1",
      role: "DRIVER",
      name: "Driver",
      email: "d@d.com",
      phone: null,
      driver_status: "OFFLINE",
      is_active: true,
      is_blocked: false,
      is_driver_verified: true,
      driver_verification_status: "APPROVED",
      save: sinon.stub().resolves(),
    };
    sinon.stub(UserModel, "findOne").resolves(driver);
    sinon.stub(profileService, "validateDriverProfile").resolves();
    let out = await service.updateDriverStatus("d1", "ONLINE");
    expect(out.status).to.equal("ONLINE");

    sinon.stub(WalletModel, "findOne").returns({ lean: async () => ({ balance: 10, total_earned: 100 }) });
    out = await service.getDriverWallet("d1");
    expect(out.balance).to.equal(10);

    sinon.stub(DriverDueModel, "findOne")
      .onFirstCall()
      .returns({ lean: async () => ({ due_amount: 20 }) })
      .onSecondCall()
      .returns({ lean: async () => ({ due_amount: 20 }) });
    out = await service.getDriverCashEarnings("d1");
    expect(out.cashEarningsDue).to.equal(20);
    out = await service.getDriverTotalEarnings("d1");
    expect(out.totalEarnings).to.equal(120);
  });

  it("login and online status negative branches", async () => {
    sinon.stub(UserModel, "findOne").resolves({
      role: "DRIVER",
      is_active: false,
    });
    await expectHttpError(service.loginDriver("d@d.com", "x"), 403, "inactive");

    sinon.restore();
    sinon.stub(UserModel, "findOne").resolves({
      id: "d1",
      _id: "d1",
      role: "DRIVER",
      is_driver_verified: false,
      driver_verification_status: "PENDING",
    });
    await expectHttpError(service.updateDriverStatus("d1", "ONLINE"), 403, "not verified");
  });

  it("covers verify otp invalid/expired and registration duplicate/email-unverified", async () => {
    sinon.stub(DriverOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() - 1000), otp: "111111", save: async () => {} }),
    });
    await expectHttpError(service.verifyDriverRegistrationOtp("d@d.com", "111111"), 400, "expired");

    sinon.restore();
    sinon.stub(DriverOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() + 60000), otp: "222222", save: async () => {} }),
    });
    await expectHttpError(service.verifyDriverRegistrationOtp("d@d.com", "111111"), 400, "Invalid OTP");

    sinon.restore();
    sinon.stub(UserModel, "findOne")
      .onFirstCall()
      .resolves({ id: "d1" })
      .onSecondCall()
      .resolves(null);
    await expectHttpError(service.setDriverRegistrationPassword("d@d.com", "x"), 409, "already exists");
    sinon.stub(DriverOtpModel, "findOne").returns({ sort: async () => null });
    await expectHttpError(service.setDriverRegistrationPassword("d@d.com", "x"), 400, "not verified");
  });

  it("covers login invalid password and profile/wallet unauthorized branches", async () => {
    sinon.stub(UserModel, "findOne").resolves({
      id: "d1",
      role: "DRIVER",
      is_active: true,
      password_hash: "hash",
    });
    sinon.stub(passwordUtil, "comparePassword").resolves(false);
    await expectHttpError(service.loginDriver("d@d.com", "bad"), 401, "Invalid email or password");

    await expectHttpError(service.getDriverWallet(undefined), 401, "Unauthorized");
    await expectHttpError(service.getDriverCashEarnings(undefined), 401, "Unauthorized");
    await expectHttpError(service.getDriverTotalEarnings(undefined), 401, "Unauthorized");
  });

  it("covers verify otp success branch", async () => {
    const save = sinon.stub().resolves();
    sinon.stub(DriverOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() + 60000), otp: "111111", verified: false, save }),
    });
    await service.verifyDriverRegistrationOtp("d@d.com", "111111");
    expect(save.calledOnce).to.equal(true);
  });

  it("covers setDriverRegistrationPassword verified OTP expired and deriveNameFromEmail fallback", async () => {
    sinon.stub(UserModel, "findOne").resolves(null);
    sinon.stub(DriverOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() - 1000), verified: true }),
    });
    await expectHttpError(service.setDriverRegistrationPassword("!!!@a.com", "pass"), 400, "Verified OTP has expired");

    sinon.restore();
    sinon.stub(UserModel, "findOne").resolves(null);
    sinon.stub(DriverOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() + 10000), verified: true }),
    });
    sinon.stub(passwordUtil, "hashPassword").resolves("hash");
    const createStub = sinon.stub(UserModel, "create").resolves({ id: "d1", name: "Driver", email: "!!!@a.com" });
    sinon.stub(DriverOtpModel, "deleteMany").resolves();
    sinon.stub(jwtUtil, "generateAccessToken").returns("token-d");

    const out = await service.setDriverRegistrationPassword("!!!@a.com", "pass");
    expect(out.user.role).to.equal("driver");
    expect(createStub.firstCall.args[0].name).to.equal("Driver");
    expect(out.user.name).to.equal("Driver");
  });

  it("covers getDriverProfile driver-not-found and OFFLINE status default", async () => {
    sinon.stub(UserModel, "findOne").resolves(null);
    await expectHttpError(service.getDriverProfile("d_missing"), 404, "Driver not found");

    sinon.restore();
    sinon.stub(UserModel, "findOne").resolves({
      id: "d1",
      name: "Driver",
      email: "d@d.com",
      phone: undefined,
      driver_status: undefined,
      is_active: true,
      is_blocked: false,
    });
    const out = await service.getDriverProfile("d1");
    expect(out.status).to.equal("OFFLINE");
    expect(out.phone).to.equal(null);
  });
});
