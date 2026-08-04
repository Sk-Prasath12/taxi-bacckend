require("ts-node/register/transpile-only");
const { expect } = require("chai");
const http = require("http");

const socketModule = require("../../src/socket/socket");

describe("socket core helpers", () => {
  it("safe emits before initialization", () => {
    delete require.cache[require.resolve("../../src/socket/socket")];
    const fresh = require("../../src/socket/socket");
    fresh.emitToCustomer("c1", "evt", { ok: true });
    fresh.emitToRide("r1", "evt", { ok: true });
    fresh.joinRideRoomForUser("u1", "r1");
  });

  it("getIo is accessible once initialized", () => {
    try {
      const io = socketModule.getIo();
      expect(io).to.exist;
    } catch (error) {
      expect(String(error.message)).to.include("Socket.io not initialized");
    }
  });

  it("initializeSocketServer is idempotent and emit helpers are safe", async () => {
    const server = http.createServer();
    const io1 = socketModule.initializeSocketServer(server);
    const io2 = socketModule.initializeSocketServer(server);
    expect(io1).to.equal(io2);

    socketModule.emitToDrivers("event_a", { ok: true });
    socketModule.emitToCustomer("customer-1", "event_b", { ok: true });
    socketModule.emitToRide("ride-1", "event_c", { ok: true });
    socketModule.joinRideRoomForUser("user-1", "ride-1");

    await new Promise((resolve) => io1.close(() => server.close(() => resolve())));
  });
});
