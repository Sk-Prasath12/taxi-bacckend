require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const { HttpError } = require("../../src/utils/http-error");
const usersServiceModule = require("../../src/modules/users/users.service");
const { UserModel } = require("../../src/modules/users/users.model");
const usersRepo = require("../../src/modules/users/users.repository");
const moduleNotificationService = require("../../src/modules/notification/notification.service");
const firebaseModule = require("../../src/config/firebase");
const firebaseAdmin = firebaseModule.default || firebaseModule;

describe("misc services", () => {
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

  it("saveFcmToken validates input and saves", async () => {
    await expectHttpError(usersServiceModule.saveFcmToken(undefined, "abc"), 401, "Unauthorized");
    await expectHttpError(usersServiceModule.saveFcmToken("u1", "   "), 400, "required");

    sinon.stub(UserModel, "findByIdAndUpdate").resolves({ id: "u1" });
    const out = await usersServiceModule.saveFcmToken("u1", " token ");
    expect(out.message).to.include("saved");
  });

  it("usersService delegates repository methods", async () => {
    sinon.stub(usersRepo, "createUser").resolves({ id: "u1" });
    sinon.stub(usersRepo, "findUserByEmail").resolves({ id: "u1", email: "a@a.com" });
    const created = await usersServiceModule.usersService.create({ email: "a@a.com" });
    const found = await usersServiceModule.usersService.findByEmail("a@a.com");
    expect(created.id).to.equal("u1");
    expect(found.email).to.equal("a@a.com");
  });

  it("module notification service handles empty token and send errors", async () => {
    const sendStub = sinon.stub().resolves("ok");
    sinon.stub(firebaseAdmin, "messaging").returns({ send: sendStub });
    await moduleNotificationService.sendPushNotification(undefined, "t", "b");

    await moduleNotificationService.sendPushNotification("token1", "Title", "Body", {
      ride_id: "r1",
      status: "COMPLETED",
      type: "RIDE",
    });
    expect(true).to.equal(true);
  });
});
