require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const mongoose = require("mongoose");
const { connectDatabase, disconnectDatabase } = require("../../src/database/mongoose");
const { logger } = require("../../src/config/logger");

describe("mongoose database connection helpers", () => {
  afterEach(() => sinon.restore());

  it("connectDatabase retries and succeeds before max retries", async () => {
    const setTimeoutStub = sinon.stub(global, "setTimeout").callsFake((cb) => {
      cb();
      return 0;
    });

    const connectStub = sinon.stub(mongoose, "connect");
    connectStub.onFirstCall().rejects(new Error("fail1"));
    connectStub.onSecondCall().rejects(new Error("fail2"));
    connectStub.onThirdCall().resolves();

    const infoStub = sinon.stub(logger, "info");
    const errorStub = sinon.stub(logger, "error");

    await connectDatabase();

    expect(connectStub.called).to.equal(true);
    expect(errorStub.callCount).to.equal(2);
    expect(infoStub.calledOnce).to.equal(true);
    expect(setTimeoutStub.called).to.equal(true);
  });

  it("connectDatabase throws after max retries exhausted", async () => {
    sinon.stub(global, "setTimeout").callsFake((cb) => {
      cb();
      return 0;
    });

    const connectStub = sinon.stub(mongoose, "connect").rejects(new Error("fail"));
    sinon.stub(logger, "info");
    const errorStub = sinon.stub(logger, "error");

    let thrown = null;
    try {
      await connectDatabase();
    } catch (e) {
      thrown = e;
    }

    expect(thrown).to.be.instanceOf(Error);
    expect(thrown.message).to.include("Unable to connect to MongoDB after retries");
    // retries increments on each failure, so logger.error should be called MAX_RETRIES times.
    expect(errorStub.callCount).to.equal(5);
    expect(connectStub.callCount).to.equal(5);
  });

  it("disconnectDatabase closes connection and logs", async () => {
    sinon.stub(mongoose.connection, "close").resolves();
    const infoStub = sinon.stub(logger, "info");

    await disconnectDatabase();

    expect(infoStub.called).to.equal(true);
    expect(mongoose.connection.close.calledOnce).to.equal(true);
  });
});

