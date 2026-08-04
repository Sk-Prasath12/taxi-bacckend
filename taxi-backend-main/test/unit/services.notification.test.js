require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const firebaseModule = require("../../src/config/firebase");
const firebaseAdmin = firebaseModule.default || firebaseModule;

describe("src/services/notification.service", () => {
  afterEach(() => sinon.restore());

  it("sends push and logs success (covers try success + default data)", async () => {
    const sendStub = sinon.stub().resolves();
    const logStub = sinon.stub(console, "log");
    const errorStub = sinon.stub(console, "error");

    const firebase = require("../../src/config/firebase");
    const adminObj = firebase.default || firebase;
    const originalDescriptor = Object.getOwnPropertyDescriptor(adminObj, "messaging");
    Object.defineProperty(adminObj, "messaging", {
      configurable: true,
      value: () => ({ send: sendStub }),
    });

    delete require.cache[require.resolve("../../src/services/notification.service")];
    const { sendPushNotification } = require("../../src/services/notification.service");
    await sendPushNotification({ token: "t1", title: "Title", body: "Body" });

    expect(logStub.called).to.equal(true);
    expect(errorStub.called).to.equal(false);
    expect(sendStub.calledOnce).to.equal(true);

    if (originalDescriptor) {
      Object.defineProperty(adminObj, "messaging", originalDescriptor);
    }
  });

  it("handles send failure (covers catch branch)", async () => {
    const sendStub = sinon.stub().rejects(new Error("FCM send failed"));
    const errStub = sinon.stub(console, "error");

    const firebase = require("../../src/config/firebase");
    const adminObj = firebase.default || firebase;
    const originalDescriptor = Object.getOwnPropertyDescriptor(adminObj, "messaging");
    Object.defineProperty(adminObj, "messaging", {
      configurable: true,
      value: () => ({ send: sendStub }),
    });

    delete require.cache[require.resolve("../../src/services/notification.service")];
    const { sendPushNotification } = require("../../src/services/notification.service");
    await sendPushNotification({
      token: "t1",
      title: "Title",
      body: "Body",
      data: { ride_id: "r1" },
    });

    expect(errStub.called).to.equal(true);
    expect(sendStub.calledOnce).to.equal(true);

    if (originalDescriptor) {
      Object.defineProperty(adminObj, "messaging", originalDescriptor);
    }
  });
});

