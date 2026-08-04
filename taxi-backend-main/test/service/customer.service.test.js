require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/customer/customer.service");
const { CustomerModel } = require("../../src/modules/customer/customer.model");
const { CustomerOtpModel } = require("../../src/modules/customer/customer.otp.model");
const passwordUtil = require("../../src/utils/password.util");
const jwtUtil = require("../../src/utils/jwt.util");

describe("customer.service", () => {
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

  it("sendRegistrationOtp rejects existing customer", async () => {
    sinon.stub(CustomerModel, "findOne").resolves({ id: "c1" });
    await expectHttpError(service.sendRegistrationOtp("N", "a@a.com", "1"), 409, "already exists");
  });

  it("verifyRegistrationOtp handles missing/expired/wrong otp", async () => {
    sinon.stub(CustomerOtpModel, "findOne").returns({ sort: async () => null });
    await expectHttpError(service.verifyRegistrationOtp("a@a.com", "123"), 400, "not found");

    sinon.restore();
    sinon.stub(CustomerOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() - 1000), otp: "123", save: async () => {} }),
    });
    await expectHttpError(service.verifyRegistrationOtp("a@a.com", "123"), 400, "expired");
  });

  it("setRegistrationPassword creates customer and token", async () => {
    sinon.stub(CustomerModel, "findOne").resolves(null);
    sinon.stub(CustomerOtpModel, "findOne").returns({
      sort: async () => ({
        expiresAt: new Date(Date.now() + 60000),
        name: "Test User",
        phone: "123",
      }),
    });
    sinon.stub(passwordUtil, "hashPassword").resolves("hash");
    sinon.stub(CustomerModel, "create").resolves({
      id: "c1",
      name: "Test User",
      email: "a@a.com",
      phone: "123",
    });
    sinon.stub(CustomerOtpModel, "deleteMany").resolves();
    sinon.stub(jwtUtil, "generateAccessToken").returns("token1");

    const out = await service.setRegistrationPassword("a@a.com", "pass");
    expect(out.token).to.equal("token1");
    expect(out.user.role).to.equal("customer");
  });

  it("loginCustomer validates password and role", async () => {
    sinon.stub(CustomerModel, "findOne").resolves(null);
    await expectHttpError(service.loginCustomer("a@a.com", "x"), 401, "Invalid email or password");

    sinon.restore();
    sinon.stub(CustomerModel, "findOne").resolves({
      id: "c1",
      role: "CUSTOMER",
      is_active: true,
      password_hash: "hash",
      name: "N",
      email: "a@a.com",
      phone: null,
      is_blocked: false,
      blocked_reason: null,
    });
    sinon.stub(passwordUtil, "comparePassword").resolves(false);
    await expectHttpError(service.loginCustomer("a@a.com", "x"), 401, "Invalid email or password");
  });

  it("loginCustomer role/inactive and profile not-found branches", async () => {
    sinon.stub(CustomerModel, "findOne")
      .onFirstCall()
      .resolves({ role: "ADMIN", is_active: true, password_hash: "x" })
      .onSecondCall()
      .resolves({ role: "CUSTOMER", is_active: false, password_hash: "x" });
    await expectHttpError(service.loginCustomer("a@a.com", "x"), 403, "Customer access only");
    await expectHttpError(service.loginCustomer("a@a.com", "x"), 403, "inactive");

    sinon.restore();
    sinon.stub(CustomerModel, "findById").resolves(null);
    await expectHttpError(service.getCustomerProfile("c1"), 404, "Customer not found");
    await expectHttpError(service.updateCustomerProfile("c1", "n", "1"), 404, "Customer not found");
  });

  it("profile and password-reset flows", async () => {
    await expectHttpError(service.getCustomerProfile(undefined), 401, "Unauthorized");

    const customer = {
      id: "c1",
      role: "CUSTOMER",
      name: "N",
      email: "a@a.com",
      phone: null,
      password_hash: "hash",
      save: sinon.stub().resolves(),
    };
    sinon.stub(CustomerModel, "findById").resolves(customer);
    let out = await service.getCustomerProfile("c1");
    expect(out.user.id).to.equal("c1");

    out = await service.updateCustomerProfile("c1", " New ", " 999 ");
    expect(out.message).to.include("updated");

    sinon.restore();
    sinon.stub(CustomerModel, "findById").resolves({
      ...customer,
      email: "a@a.com",
      role: "CUSTOMER",
      save: sinon.stub().resolves(),
    });
    sinon.stub(passwordUtil, "comparePassword").resolves(true);
    sinon.stub(passwordUtil, "hashPassword").resolves("newhash");
    const changed = await service.changeCustomerPassword("c1", "a@a.com", "old", "new");
    expect(changed.success).to.equal(true);
  });

  it("forgot-password and change-password negative branches", async () => {
    sinon.stub(CustomerModel, "findOne").resolves(null);
    await expectHttpError(service.sendForgotPasswordOtp("x@x.com"), 404, "Customer not found");

    sinon.restore();
    sinon.stub(CustomerModel, "findOne").resolves({ role: "CUSTOMER" });
    sinon.stub(CustomerOtpModel, "findOne").returns({ sort: async () => null });
    await expectHttpError(service.verifyForgotPasswordOtp("x@x.com", "111111"), 400, "OTP not found");

    sinon.restore();
    sinon.stub(CustomerModel, "findOne").resolves({ role: "CUSTOMER" });
    sinon.stub(CustomerOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() - 1000), verified: true }),
    });
    await expectHttpError(service.setForgotPasswordPassword("x@x.com", "pass"), 400, "expired");

    sinon.restore();
    sinon.stub(CustomerModel, "findById").resolves({
      role: "CUSTOMER",
      email: "a@a.com",
      password_hash: "hash",
      save: sinon.stub().resolves(),
    });
    await expectHttpError(service.changeCustomerPassword("c1", "b@b.com", "old", "new"), 403, "does not match");

    sinon.restore();
    sinon.stub(CustomerModel, "findById").resolves({
      role: "CUSTOMER",
      email: "a@a.com",
      password_hash: "hash",
      save: sinon.stub().resolves(),
    });
    sinon.stub(passwordUtil, "comparePassword").resolves(true);
    await expectHttpError(service.changeCustomerPassword("c1", "a@a.com", "same", "same"), 400, "must be different");

    sinon.restore();
    sinon.stub(CustomerModel, "findOne").resolves({ role: "CUSTOMER" });
    sinon.stub(CustomerOtpModel, "findOne").returns({
      sort: async () => ({ expiresAt: new Date(Date.now() + 5000), otp: "999999", verified: false }),
    });
    await expectHttpError(service.verifyForgotPasswordOtp("x@x.com", "111111"), 400, "Invalid OTP");

    sinon.restore();
    sinon.stub(CustomerModel, "findOne").resolves({ role: "CUSTOMER" });
    sinon.stub(CustomerOtpModel, "findOne").returns({ sort: async () => null });
    await expectHttpError(service.setForgotPasswordPassword("x@x.com", "pass"), 400, "Email is not verified");

    sinon.restore();
    sinon.stub(CustomerModel, "findById").resolves({
      role: "CUSTOMER",
      email: "a@a.com",
      password_hash: "hash",
    });
    sinon.stub(passwordUtil, "comparePassword").resolves(false);
    await expectHttpError(service.changeCustomerPassword("c1", "a@a.com", "bad", "new"), 400, "Old password is incorrect");
  });

  it("covers forgot-password success flow and role-mismatch branches", async () => {
    sinon.stub(CustomerModel, "findOne")
      .onFirstCall()
      .resolves({
        role: "CUSTOMER",
        email: "x@x.com",
        password_hash: "hash",
        save: sinon.stub().resolves(),
      })
      .onSecondCall()
      .resolves({ role: "ADMIN", email: "x@x.com" })
      .onThirdCall()
      .resolves({
        role: "CUSTOMER",
        email: "x@x.com",
        password_hash: "hash",
        save: sinon.stub().resolves(),
      });
    sinon.stub(CustomerOtpModel, "findOne").returns({
      sort: async () => ({
        expiresAt: new Date(Date.now() + 60000),
        verified: true,
      }),
    });
    sinon.stub(CustomerOtpModel, "deleteMany").resolves();
    sinon.stub(passwordUtil, "hashPassword").resolves("newhash");

    const out = await service.setForgotPasswordPassword("x@x.com", "newpass");
    expect(out.success).to.equal(true);
    await expectHttpError(service.setForgotPasswordPassword("x@x.com", "newpass"), 404, "Customer not found");

    sinon.restore();
    sinon.stub(CustomerModel, "findById").resolves({ role: "ADMIN" });
    await expectHttpError(service.changeCustomerPassword("c1", "a@a.com", "old", "new"), 404, "Customer not found");
  });
});
