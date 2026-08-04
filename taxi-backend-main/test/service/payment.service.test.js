require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const crypto = require("crypto");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/payment/payment.service");
const { RideModel } = require("../../src/modules/customer/ride/ride.model");
const { PaymentModel } = require("../../src/modules/payment/payment.model");
const { InvoiceModel } = require("../../src/modules/invoice/invoice.model");
const financeService = require("../../src/modules/finance/finance.service");
const socket = require("../../src/socket/socket");
const notificationService = require("../../src/services/notification.service");
const { UserModel } = require("../../src/modules/users/users.model");
const { env } = require("../../src/config/env");

describe("payment.service", () => {
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

  it("createPaymentOrder fails on unauthorized and missing ride id", async () => {
    await expectHttpError(service.createPaymentOrder(undefined, "r1"), 401, "Unauthorized");
    await expectHttpError(service.createPaymentOrder("c1"), 400, "ride_id");
  });

  it("createPaymentOrder validates ride ownership and state", async () => {
    sinon.stub(RideModel, "findById").resolves(null);
    await expectHttpError(service.createPaymentOrder("c1", "r1"), 404, "Ride not found");

    sinon.restore();
    sinon.stub(RideModel, "findById").resolves({ customer_id: "c2" });
    await expectHttpError(service.createPaymentOrder("c1", "r1"), 403, "not allowed");

    sinon.restore();
    sinon.stub(RideModel, "findById").resolves({
      customer_id: "c1",
      status: "IN_TRANSIT",
      payment_mode: "ONLINE",
      payment_status: "PENDING",
      fare: 100,
    });
    await expectHttpError(service.createPaymentOrder("c1", "r1"), 400, "completed rides");
  });

  it("createPaymentOrder covers payment-mode/state/fare branches", async () => {
    sinon.stub(RideModel, "findById")
      .onFirstCall()
      .resolves({ customer_id: "c1", status: "COMPLETED", payment_mode: "CASH", payment_status: "PENDING", fare: 100 })
      .onSecondCall()
      .resolves({ customer_id: "c1", status: "COMPLETED", payment_mode: "ONLINE", payment_status: "SUCCESS", fare: 100 })
      .onThirdCall()
      .resolves({ customer_id: "c1", status: "COMPLETED", payment_mode: "ONLINE", payment_status: "FAILED", fare: 100 })
      .onCall(3)
      .resolves({ customer_id: "c1", status: "COMPLETED", payment_mode: "ONLINE", payment_status: "PENDING", fare: 0 });

    await expectHttpError(service.createPaymentOrder("c1", "r1"), 400, "ONLINE");
    await expectHttpError(service.createPaymentOrder("c1", "r2"), 409, "already completed");
    await expectHttpError(service.createPaymentOrder("c1", "r3"), 400, "not in payable state");
    await expectHttpError(service.createPaymentOrder("c1", "r4"), 400, "Invalid fare");
  });

  it("verifyPayment handles missing fields and invalid signature", async () => {
    await expectHttpError(service.verifyPayment("c1", { ride_id: "r1" }), 400, "required");

    const ride = {
      id: "r1",
      _id: "r1",
      customer_id: "c1",
      status: "COMPLETED",
      payment_mode: "ONLINE",
      payment_status: "PENDING",
      fare: 200,
      save: sinon.stub().resolves(),
    };
    sinon.stub(RideModel, "findById").resolves(ride);
    sinon.stub(PaymentModel, "findOneAndUpdate").resolves({ id: "p1" });

    await expectHttpError(
      service.verifyPayment("c1", {
        ride_id: "r1",
        order_id: "o1",
        payment_id: "p1",
        signature: "bad",
      }),
      400,
      "Invalid payment signature"
    );
  });

  it("verifyPayment returns short-circuit success when already paid", async () => {
    sinon.stub(RideModel, "findById").resolves({
      id: "r1",
      customer_id: "c1",
      status: "COMPLETED",
      payment_mode: "ONLINE",
      payment_status: "SUCCESS",
      fare: 100,
    });

    const out = await service.verifyPayment("c1", {
      ride_id: "r1",
      order_id: "o1",
      payment_id: "p1",
      signature: "x",
    });
    expect(out.payment_status).to.equal("SUCCESS");
    expect(out.commission).to.equal(20);
  });

  it("verifyPayment executes success flow with emits and notifications", async () => {
    const secret = env.RAZORPAY_KEY_SECRET;
    const body = "o1|p1";
    const signature = crypto.createHmac("sha256", secret).update(body).digest("hex");

    const ride = {
      id: "r1",
      _id: "r1",
      customer_id: "c1",
      driver_id: "d1",
      status: "COMPLETED",
      payment_mode: "ONLINE",
      payment_status: "PENDING",
      fare: 250,
      save: sinon.stub().resolves(),
    };
    sinon.stub(RideModel, "findById").resolves(ride);
    sinon.stub(PaymentModel, "findOneAndUpdate").resolves({ id: "pay1" });
    sinon.stub(financeService, "processRidePayment").resolves();
    sinon.stub(InvoiceModel, "findOneAndUpdate").resolves({ ride_id: "r1", payment_status: "SUCCESS" });
    const emit = sinon.spy();
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit }) });
    sinon.stub(notificationService, "sendPushNotification").resolves();
    sinon.stub(UserModel, "findById").returns({
      select: () => ({
        lean: async () => ({ fcm_token: "token-1" }),
      }),
    });

    const out = await service.verifyPayment("c1", {
      ride_id: "r1",
      order_id: "o1",
      payment_id: "p1",
      signature,
    });

    expect(out.payment_status).to.equal("SUCCESS");
    expect(ride.save.calledOnce).to.equal(true);
    expect(emit.called).to.equal(true);
  });

  it("verifyPayment covers not-found/ownership/state branches", async () => {
    sinon.stub(RideModel, "findById")
      .onFirstCall()
      .resolves(null)
      .onSecondCall()
      .resolves({ customer_id: "c2" })
      .onThirdCall()
      .resolves({ customer_id: "c1", status: "IN_TRANSIT", payment_mode: "ONLINE", payment_status: "PENDING" })
      .onCall(3)
      .resolves({ customer_id: "c1", status: "COMPLETED", payment_mode: "CASH", payment_status: "PENDING" })
      .onCall(4)
      .resolves({ customer_id: "c1", status: "COMPLETED", payment_mode: "ONLINE", payment_status: "FAILED" })
      .onCall(5)
      .resolves({
        id: "r6",
        _id: "r6",
        customer_id: "c1",
        status: "COMPLETED",
        payment_mode: "ONLINE",
        payment_status: "PENDING",
        fare: 50,
        save: sinon.stub().resolves(),
      });
    const body = "o|p";
    const signature = crypto.createHmac("sha256", env.RAZORPAY_KEY_SECRET).update(body).digest("hex");
    sinon.stub(PaymentModel, "findOneAndUpdate").onFirstCall().resolves(null);

    await expectHttpError(service.verifyPayment("c1", { ride_id: "r1", order_id: "o", payment_id: "p", signature: "s" }), 404, "Ride not found");
    await expectHttpError(service.verifyPayment("c1", { ride_id: "r2", order_id: "o", payment_id: "p", signature: "s" }), 403, "not allowed");
    await expectHttpError(service.verifyPayment("c1", { ride_id: "r3", order_id: "o", payment_id: "p", signature: "s" }), 400, "completed rides");
    await expectHttpError(service.verifyPayment("c1", { ride_id: "r4", order_id: "o", payment_id: "p", signature: "s" }), 400, "ONLINE");
    await expectHttpError(service.verifyPayment("c1", { ride_id: "r5", order_id: "o", payment_id: "p", signature: "s" }), 400, "not allowed in current");
    await expectHttpError(service.verifyPayment("c1", { ride_id: "r6", order_id: "o", payment_id: "p", signature }), 404, "Payment order not found");
  });
});
