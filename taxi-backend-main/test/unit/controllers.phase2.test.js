require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const authController = require("../../src/modules/auth/auth.controller");
const authService = require("../../src/modules/auth/auth.service");
const paymentController = require("../../src/modules/payment/payment.controller");
const paymentService = require("../../src/modules/payment/payment.service");
const financeController = require("../../src/modules/finance/finance.controller");
const financeService = require("../../src/modules/finance/finance.service");
const vehicleTypeController = require("../../src/modules/vehicle-type/vehicle-type.controller");
const vehicleTypeService = require("../../src/modules/vehicle-type/vehicle-type.service");
const withdrawController = require("../../src/modules/withdraw/withdraw.controller");
const withdrawService = require("../../src/modules/withdraw/withdraw.service");
const notificationController = require("../../src/modules/notification/notification.controller");
const { UserModel } = require("../../src/modules/users/users.model");
const zoneController = require("../../src/modules/operational-zone/operational-zone.controller");
const zoneService = require("../../src/modules/operational-zone/operational-zone.service");
const ratingController = require("../../src/modules/rating/rating.controller");
const ratingService = require("../../src/modules/rating/rating.service");
const ticketController = require("../../src/modules/support/ticket.controller");
const ticketService = require("../../src/modules/support/ticket.service");
const customerController = require("../../src/modules/customer/customer.controller");
const customerService = require("../../src/modules/customer/customer.service");
const driverController = require("../../src/modules/driver/driver.controller");
const driverService = require("../../src/modules/driver/driver.service");
const adminCustomerController = require("../../src/modules/admin/customer/admin-customer.controller");
const adminCustomerService = require("../../src/modules/admin/customer/admin-customer.service");
const adminController = require("../../src/modules/admin/admin.controller");
const invoiceController = require("../../src/modules/invoice/invoice.controller");
const { InvoiceModel } = require("../../src/modules/invoice/invoice.model");

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

describe("phase2 controller coverage", () => {
  afterEach(() => sinon.restore());

  it("covers auth controller success and failure", async () => {
    const next = sinon.spy();
    const res = mockRes();
    sinon.stub(authService, "loginUser").resolves({ accessToken: "a" });
    await authController.loginController({ body: { email: "a", password: "b" } }, res, next);
    expect(res.statusCode).to.equal(200);

    const err = new Error("bad");
    sinon.restore();
    sinon.stub(authService, "refreshAccessToken").rejects(err);
    await authController.refreshController({ body: { refreshToken: "x" } }, mockRes(), next);
    expect(next.calledWith(err)).to.equal(true);
  });

  it("covers payment/finance/vehicle controllers", async () => {
    const next = sinon.spy();
    sinon.stub(paymentService, "createPaymentOrder").resolves({ order_id: "o1" });
    sinon.stub(paymentService, "verifyPayment").resolves({ ok: true });
    let res = mockRes();
    await paymentController.createPaymentOrderController(
      { authUser: { userId: "u1" }, body: { ride_id: "r1" } },
      res,
      next
    );
    expect(res.statusCode).to.equal(200);
    res = mockRes();
    await paymentController.verifyPaymentController(
      { authUser: { userId: "u1" }, body: { ride_id: "r1", order_id: "o", payment_id: "p", signature: "s" } },
      res,
      next
    );
    expect(res.statusCode).to.equal(200);

    sinon.stub(financeService, "getRevenueSummary").resolves({ total: 1 });
    sinon.stub(financeService, "getRevenueList").resolves([]);
    sinon.stub(financeService, "getDriverDueById").resolves({ due: 0 });
    sinon.stub(financeService, "getAdminDashboardMetrics").resolves({ drivers: 1 });
    await financeController.getRevenueSummaryController({}, mockRes(), next);
    await financeController.getRevenueListController({}, mockRes(), next);
    await financeController.getDriverDueController({ params: { driverId: "d1" } }, mockRes(), next);
    await financeController.getAdminDashboardMetricsController({}, mockRes(), next);

    sinon.stub(vehicleTypeService, "getAllVehicleTypes").resolves([{ id: "v1" }]);
    sinon.stub(vehicleTypeService, "getActiveVehicleTypes").resolves([{ id: "v2" }]);
    await vehicleTypeController.getVehicleTypesController({}, mockRes(), next);
    await vehicleTypeController.getActiveVehicleTypesController({}, mockRes(), next);
  });

  it("covers withdraw and notification controllers", async () => {
    const next = sinon.spy();
    const validId = new mongoose.Types.ObjectId().toString();
    sinon.stub(withdrawService, "withdrawAmount").resolves({ ok: true });
    let res = mockRes();
    await withdrawController.withdrawWalletController(
      { authUser: { userId: validId }, body: { amount: 100 } },
      res,
      next
    );
    expect(res.statusCode).to.equal(200);

    await withdrawController.withdrawWalletController(
      { authUser: { userId: "bad-id" }, body: { amount: 10 } },
      mockRes(),
      next
    );
    expect(next.called).to.equal(true);

    sinon.stub(UserModel, "findByIdAndUpdate").resolves({ id: validId });
    res = mockRes();
    await notificationController.saveNotificationTokenController(
      { authUser: { userId: validId }, body: { token: "fcm-token" } },
      res,
      next
    );
    expect(res.statusCode).to.equal(200);
  });

  it("covers operational zone and rating controllers", async () => {
    const next = sinon.spy();
    sinon.stub(zoneService, "createZone").resolves({ id: "z1" });
    sinon.stub(zoneService, "getAllZones").resolves([]);
    sinon.stub(zoneService, "updateZone").resolves({ id: "z1" });
    sinon.stub(zoneService, "toggleZoneStatus").resolves({ id: "z1", is_active: false });

    await zoneController.createOperationalZoneController(
      { authUser: { userId: "admin1" }, body: { zone_name: "A", coordinates: [] } },
      mockRes(),
      next
    );
    await zoneController.getOperationalZonesController({}, mockRes(), next);
    await zoneController.updateOperationalZoneController(
      { params: { id: "z1" }, body: { zone_name: "B", coordinates: [] } },
      mockRes(),
      next
    );
    await zoneController.toggleOperationalZoneStatusController(
      { params: { id: "z1" }, body: { is_active: true } },
      mockRes(),
      next
    );

    sinon.stub(ratingService, "createRating").resolves({ id: "rt1" });
    sinon.stub(ratingService, "getRatingsForUser").resolves([]);
    sinon.stub(ratingService, "getAverageRating").resolves({ average: 5 });
    sinon.stub(ratingService, "getAllRatings").resolves([]);
    await ratingController.createRatingController(
      { authUser: { userId: "u1", role: "CUSTOMER" }, body: { ride_id: "r1", rating: 5 } },
      mockRes(),
      next
    );
    await ratingController.getMyRatingsController({ authUser: { userId: "u1" } }, mockRes(), next);
    await ratingController.getMyRatingSummaryController({ authUser: { userId: "u1" } }, mockRes(), next);
    await ratingController.getAdminRatingsController({ query: {} }, mockRes(), next);
  });

  it("covers ticket, customer and driver controllers", async () => {
    const next = sinon.spy();
    sinon.stub(ticketService, "createTicket").resolves({ id: "t1" });
    sinon.stub(ticketService, "getMyTickets").resolves([]);
    sinon.stub(ticketService, "getTicketById").resolves({ id: "t1" });
    sinon.stub(ticketService, "replyToTicket").resolves({ id: "t1" });
    sinon.stub(ticketService, "getAllTicketsForAdmin").resolves([]);
    sinon.stub(ticketService, "updateTicketStatus").resolves({ id: "t1", status: "RESOLVED" });
    await ticketController.createTicketController(
      { authUser: { userId: "u1", role: "CUSTOMER" }, body: { subject: "s", description: "d" } },
      mockRes(),
      next
    );
    await ticketController.getMyTicketsController({ authUser: { userId: "u1", role: "CUSTOMER" } }, mockRes(), next);
    await ticketController.getTicketByIdController(
      { authUser: { userId: "u1", role: "CUSTOMER" }, params: { id: "t1" } },
      mockRes(),
      next
    );
    await ticketController.replyToTicketController(
      { authUser: { userId: "u1", role: "CUSTOMER" }, params: { id: "t1" }, body: { message: "ok" } },
      mockRes(),
      next
    );
    await ticketController.getAdminTicketsController({}, mockRes(), next);
    await ticketController.updateTicketStatusController(
      { params: { id: "t1" }, body: { status: "RESOLVED" } },
      mockRes(),
      next
    );

    sinon.stub(customerService, "sendRegistrationOtp").resolves();
    sinon.stub(customerService, "verifyRegistrationOtp").resolves();
    sinon.stub(customerService, "setRegistrationPassword").resolves({ token: "a" });
    sinon.stub(customerService, "loginCustomer").resolves({ token: "a" });
    sinon.stub(customerService, "getCustomerProfile").resolves({ id: "c1" });
    sinon.stub(customerService, "updateCustomerProfile").resolves({ id: "c1" });
    sinon.stub(customerService, "sendForgotPasswordOtp").resolves();
    sinon.stub(customerService, "verifyForgotPasswordOtp").resolves();
    sinon.stub(customerService, "setForgotPasswordPassword").resolves({ ok: true });
    sinon.stub(customerService, "changeCustomerPassword").resolves({ ok: true });

    await customerController.customerRegisterEmailController(
      { body: { name: "n", email: "e", phone: "p" } },
      mockRes(),
      next
    );
    await customerController.customerVerifyOtpController({ body: { email: "e", otp: "1234" } }, mockRes(), next);
    await customerController.customerSetPasswordController({ body: { email: "e", password: "p" } }, mockRes(), next);
    await customerController.customerLoginController({ body: { email: "e", password: "p" } }, mockRes(), next);
    await customerController.customerGetProfileController({ authUser: { userId: "c1" } }, mockRes(), next);
    await customerController.customerUpdateProfileController(
      { authUser: { userId: "c1" }, body: { name: "new" } },
      mockRes(),
      next
    );
    await customerController.customerForgotPasswordEmailController({ body: { email: "e" } }, mockRes(), next);
    await customerController.customerForgotPasswordVerifyOtpController(
      { body: { email: "e", otp: "1234" } },
      mockRes(),
      next
    );
    await customerController.customerForgotPasswordSetPasswordController(
      { body: { email: "e", password: "p" } },
      mockRes(),
      next
    );
    await customerController.customerChangePasswordController(
      { authUser: { userId: "c1" }, body: { email: "e", oldPassword: "old", newPassword: "new" } },
      mockRes(),
      next
    );

    sinon.stub(driverService, "sendDriverRegistrationOtp").resolves();
    sinon.stub(driverService, "verifyDriverRegistrationOtp").resolves();
    sinon.stub(driverService, "setDriverRegistrationPassword").resolves({ token: "a" });
    sinon.stub(driverService, "loginDriver").resolves({ token: "a" });
    sinon.stub(driverService, "getDriverProfile").resolves({ id: "d1" });
    sinon.stub(driverService, "updateDriverStatus").resolves({ status: "ONLINE" });
    sinon.stub(driverService, "getDriverWallet").resolves({ balance: 0 });
    sinon.stub(driverService, "getDriverCashEarnings").resolves({ total: 0 });
    sinon.stub(driverService, "getDriverTotalEarnings").resolves({ total: 0 });

    await driverController.driverRegisterEmailController({ body: { email: "d" } }, mockRes(), next);
    await driverController.driverVerifyOtpController({ body: { email: "d", otp: "1234" } }, mockRes(), next);
    await driverController.driverSetPasswordController({ body: { email: "d", password: "x" } }, mockRes(), next);
    await driverController.driverLoginController({ body: { email: "d", password: "x" } }, mockRes(), next);
    await driverController.driverGetProfileController({ authUser: { userId: "d1" } }, mockRes(), next);
    await driverController.driverUpdateStatusController(
      { authUser: { userId: "d1" }, body: { status: "ONLINE" } },
      mockRes(),
      next
    );
    await driverController.driverGetWalletController({ authUser: { userId: "d1" } }, mockRes(), next);
    await driverController.driverGetCashEarningsController({ authUser: { userId: "d1" } }, mockRes(), next);
    await driverController.driverGetTotalEarningsController({ authUser: { userId: "d1" } }, mockRes(), next);
  });

  it("covers admin and admin-customer controllers plus invoice", async () => {
    const next = sinon.spy();
    sinon.stub(adminCustomerService, "getAdminCustomers").resolves({ items: [] });
    sinon.stub(adminCustomerService, "getAdminCustomerDetails").resolves({ id: "c1" });
    sinon.stub(adminCustomerService, "updateAdminCustomerBlockStatus").resolves({ ok: true });
    sinon.stub(adminCustomerService, "getAdminCustomerRideHistory").resolves({ rides: [] });

    await adminCustomerController.getAdminCustomersController({ query: {} }, mockRes(), next);
    await adminCustomerController.getAdminCustomerDetailsController({ params: { id: "c1" } }, mockRes(), next);
    await adminCustomerController.updateAdminCustomerBlockStatusController(
      { params: { id: "c1" }, body: { is_blocked: true, reason: "x" } },
      mockRes(),
      next
    );
    await adminCustomerController.getAdminCustomerRideHistoryController(
      { params: { id: "c1" } },
      mockRes(),
      next
    );

    let res = mockRes();
    await adminController.adminTestController({ authUser: { userId: "a1", role: "ADMIN" } }, res);
    expect(res.statusCode).to.equal(200);

    const chain = {
      select: () => chain,
      sort: () => chain,
      lean: async () => [{ _id: "d1", name: "Driver", email: "d@d.com", is_active: true, is_blocked: false }],
    };
    sinon.stub(UserModel, "find").returns(chain);
    await adminController.getActiveDriversController({}, mockRes(), next);
    await adminController.getVerifiedDriversController({}, mockRes(), next);

    const rideId = new mongoose.Types.ObjectId().toString();
    const userId = new mongoose.Types.ObjectId().toString();
    const invoice = {
      ride_id: rideId,
      distance_km: 10,
      fare: 100,
      commission: 20,
      driver_earning: 80,
      payment_mode: "CASH",
      payment_status: "SUCCESS",
    };
    const oneChain = {
      select: () => oneChain,
      lean: async () => invoice,
    };
    const allChain = {
      sort: () => allChain,
      select: () => allChain,
      lean: async () => [invoice],
    };
    sinon.stub(InvoiceModel, "findOne").returns(oneChain);
    sinon.stub(InvoiceModel, "find").returns(allChain);

    res = mockRes();
    await invoiceController.getCustomerInvoiceController(
      { authUser: { userId }, params: { rideId } },
      res,
      next
    );
    expect(res.statusCode).to.equal(200);
    await invoiceController.getDriverInvoiceController({ authUser: { userId }, params: { rideId } }, mockRes(), next);
    await invoiceController.getAdminInvoicesController({}, mockRes(), next);
  });
});
