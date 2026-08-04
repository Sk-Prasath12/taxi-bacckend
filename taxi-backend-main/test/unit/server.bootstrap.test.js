require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

describe("server bootstrap", () => {
  const serverPath = "../../src/server";
  const dbModule = require("../../src/database/mongoose");
  const { DriverDocumentModel } = require("../../src/modules/driver-documents/driver-document.model");
  const socketModule = require("../../src/socket/socket");
  const loggerModule = require("../../src/config/logger");
  const http = require("http");

  const loadServerFresh = () => {
    delete require.cache[require.resolve(serverPath)];
    return require(serverPath);
  };

  afterEach(() => {
    sinon.restore();
    delete require.cache[require.resolve(serverPath)];
  });

  it("does not auto-start when NODE_ENV is test", () => {
    const oldEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = "test";
    const connectStub = sinon.stub(dbModule, "connectDatabase").resolves();
    loadServerFresh();
    expect(connectStub.called).to.equal(false);
    process.env.NODE_ENV = oldEnv;
  });

  it("starts server, initializes socket and handles shutdown", async () => {
    const oldEnv = process.env.NODE_ENV;
    process.env.NODE_ENV = "development";

    sinon.stub(dbModule, "connectDatabase").resolves();
    const disconnectStub = sinon.stub(dbModule, "disconnectDatabase").resolves();
    sinon.stub(DriverDocumentModel, "syncIndexes").resolves([{ created: "idx" }]);
    sinon.stub(socketModule, "initializeSocketServer");
    sinon.stub(loggerModule.logger, "info");
    sinon.stub(loggerModule.logger, "error");

    const onStub = sinon.stub(process, "on");
    const exitStub = sinon.stub(process, "exit");

    const fakeServer = {
      listen: sinon.stub().callsFake((_port, _host, cb) => cb && cb()),
      close: sinon.stub().callsFake((cb) => cb && cb()),
    };
    sinon.stub(http, "createServer").returns(fakeServer);

    loadServerFresh();
    await new Promise((resolve) => setTimeout(resolve, 10));

    const sigintHandler = onStub.getCalls().find((call) => call.args[0] === "SIGINT").args[1];
    await sigintHandler();

    expect(disconnectStub.called).to.equal(true);
    expect(exitStub.calledWith(0)).to.equal(true);
    process.env.NODE_ENV = oldEnv;
  });
});
