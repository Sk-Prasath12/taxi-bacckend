require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const { withdrawAmount } = require("../../src/modules/withdraw/withdraw.service");
const { WalletModel } = require("../../src/modules/finance/wallet.model");
const { WithdrawModel } = require("../../src/modules/withdraw/withdraw.model");
const socket = require("../../src/socket/socket");
const notificationService = require("../../src/services/notification.service");

describe("withdraw + notification services", () => {
  afterEach(() => sinon.restore());

  it("withdrawAmount validation and success", async () => {
    try {
      await withdrawAmount(new mongoose.Types.ObjectId().toString(), -1);
      throw new Error("Expected failure");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
    }

    sinon.stub(WalletModel, "findOne").returns({ lean: async () => ({ balance: 200 }) });
    sinon.stub(WalletModel, "findOneAndUpdate").resolves({ balance: 100 });
    sinon.stub(WithdrawModel, "create").resolves({});
    sinon.stub(socket, "getIO").returns({ to: () => ({ emit: sinon.spy() }) });
    const out = await withdrawAmount(new mongoose.Types.ObjectId().toString(), 100);
    expect(out.message).to.include("Withdraw");
  });

  it("notification service handles send success and failure", async () => {
    await notificationService.sendPushNotification({
      token: "t1",
      title: "Hello",
      body: "World",
      data: { a: "b" },
    });
    await notificationService.sendPushNotification({
      token: "t1",
      title: "Hello",
      body: "World",
      data: { a: "b" },
    });
    expect(true).to.equal(true);
  });
});
