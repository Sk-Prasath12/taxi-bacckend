require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

describe("otp email success flows", () => {
  afterEach(() => sinon.restore());

  it("customer otp send flows with mocked mailer", async () => {
    const nodemailer = require("nodemailer");
    const sendMail = sinon.stub().resolves();
    sinon.stub(nodemailer, "createTransport").returns({ sendMail });

    delete require.cache[require.resolve("../../src/modules/customer/customer.service")];
    const customerService = require("../../src/modules/customer/customer.service");
    const { CustomerModel } = require("../../src/modules/customer/customer.model");
    const { CustomerOtpModel } = require("../../src/modules/customer/customer.otp.model");

    sinon.stub(CustomerModel, "findOne").onFirstCall().resolves(null).onSecondCall().resolves({ role: "CUSTOMER" });
    sinon.stub(CustomerOtpModel, "create").resolves({});

    await customerService.sendRegistrationOtp("Name", "a@a.com", "999");
    await customerService.sendForgotPasswordOtp("a@a.com");
    expect(sendMail.callCount).to.equal(2);
  });

  it("driver otp send flow with mocked mailer", async () => {
    const nodemailer = require("nodemailer");
    const sendMail = sinon.stub().resolves();
    sinon.stub(nodemailer, "createTransport").returns({ sendMail });

    delete require.cache[require.resolve("../../src/modules/driver/driver.service")];
    const driverService = require("../../src/modules/driver/driver.service");
    const { UserModel } = require("../../src/modules/users/users.model");
    const { DriverOtpModel } = require("../../src/modules/driver/driver.otp.model");

    sinon.stub(UserModel, "findOne").resolves(null);
    sinon.stub(DriverOtpModel, "create").resolves({});

    await driverService.sendDriverRegistrationOtp("d@d.com");
    expect(sendMail.calledOnce).to.equal(true);
  });
});
