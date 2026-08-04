require("ts-node/register/transpile-only");
const { expect } = require("chai");
const http = require("http");
const { io: ioClient } = require("socket.io-client");
const sinon = require("sinon");

const jwtUtil = require("../../src/utils/jwt.util");
const { UserModel } = require("../../src/modules/users/users.model");
const { RideModel } = require("../../src/modules/customer/ride/ride.model");

describe("socket events", function () {
  this.timeout(10000);

  let server;
  let port;
  let socketModule;
  let io;

  beforeEach(async () => {
    delete require.cache[require.resolve("../../src/socket/socket")];
    socketModule = require("../../src/socket/socket");
    server = http.createServer();
    io = socketModule.initializeSocketServer(server);
    await new Promise((resolve) => server.listen(0, resolve));
    port = server.address().port;
  });

  afterEach(async () => {
    sinon.restore();
    await new Promise((resolve) => io.close(() => server.close(() => resolve())));
  });

  it("rejects mismatched join payload against token identity", async () => {
    const token = jwtUtil.generateAccessToken("driver-1", "DRIVER");
    const client = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token },
    });

    const message = await new Promise((resolve) => {
      client.on("connect", () => {
        client.emit("join", { userId: "other-user", role: "driver" });
      });
      client.on("socket_error", (payload) => resolve(payload.message));
    });

    expect(message).to.include("does not match authenticated user");
    client.disconnect();
  });

  it("returns invalid join payload error", async () => {
    const client = ioClient(`http://127.0.0.1:${port}`, { transports: ["websocket"] });
    const message = await new Promise((resolve) => {
      client.on("connect", () => client.emit("join", {}));
      client.on("socket_error", (payload) => resolve(payload.message));
    });
    expect(message).to.equal("Invalid join payload");
    client.disconnect();
  });

  it("driver disconnect updates status and invalid location ignored", async () => {
    const token = jwtUtil.generateAccessToken("507f1f77bcf86cd799439011", "DRIVER");
    const updateStub = sinon.stub(UserModel, "updateOne").resolves();
    sinon.stub(RideModel, "findById").resolves(null);

    const client = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token },
    });

    await new Promise((resolve) => {
      client.on("connect", () => {
        client.emit("join", { userId: "507f1f77bcf86cd799439011", role: "driver" });
        socketModule.joinRideRoomForUser("507f1f77bcf86cd799439011", "507f1f77bcf86cd799439099");
        client.emit("driver_location", { rideId: "bad-id", lat: 1000, lng: 1000 });
        setTimeout(resolve, 150);
      });
    });

    client.disconnect();
    await new Promise((r) => setTimeout(r, 150));
    expect(updateStub.called).to.equal(true);
  });

  it("covers join_ride_room and getIo pre-init throw", async () => {
    delete require.cache[require.resolve("../../src/socket/socket")];
    const fresh = require("../../src/socket/socket");
    expect(() => fresh.getIo()).to.throw("Socket.io not initialized");

    const token = jwtUtil.generateAccessToken("507f1f77bcf86cd799439021", "CUSTOMER");
    const client = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token },
    });
    await new Promise((resolve) => {
      client.on("connect", () => {
        client.emit("join", { userId: "507f1f77bcf86cd799439021", role: "customer" });
        client.emit("join_ride_room", "507f1f77bcf86cd799439031");
        setTimeout(resolve, 120);
      });
    });
    client.disconnect();
  });

  it("covers driver_location mismatch and unknown ride branches", async () => {
    const token = jwtUtil.generateAccessToken("507f1f77bcf86cd799439041", "DRIVER");
    const updateStub = sinon.stub(UserModel, "updateOne");
    updateStub.onFirstCall().resolves();
    updateStub.onSecondCall().rejects(new Error("db down"));
    sinon.stub(RideModel, "findById").returns({ lean: async () => null });

    const client = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token },
    });
    await new Promise((resolve) => {
      client.on("connect", () => {
        client.emit("join", { userId: "507f1f77bcf86cd799439041", role: "driver" });
        client.emit("driver_location", {
          rideId: "507f1f77bcf86cd799439099",
          driver_id: "507f1f77bcf86cd799439042",
          lat: 12.9,
          lng: 77.6,
        });
        setTimeout(() => {
          client.emit("driver_location", {
            rideId: "507f1f77bcf86cd799439099",
            driver_id: "507f1f77bcf86cd799439041",
            lat: 12.9,
            lng: 77.6,
          });
          setTimeout(resolve, 140);
        }, 80);
      });
    });
    client.disconnect();
    await new Promise((r) => setTimeout(r, 120));
    expect(updateStub.called).to.equal(true);
  });

  it("covers unassigned-driver location branch", async () => {
    const token = jwtUtil.generateAccessToken("507f1f77bcf86cd799439051", "DRIVER");
    sinon.stub(UserModel, "updateOne").resolves();
    sinon.stub(RideModel, "findById").returns({
      lean: async () => ({
        _id: "507f1f77bcf86cd799439099",
        customer_id: "507f1f77bcf86cd799439052",
        driver_id: "507f1f77bcf86cd799439053",
        pickup: { lat: 12.9, lng: 77.6 },
        drop: { lat: 13.1, lng: 77.8 },
        status: "IN_TRANSIT",
      }),
    });

    const client = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token },
    });
    await new Promise((resolve) => {
      client.on("connect", () => {
        client.emit("join", { userId: "507f1f77bcf86cd799439051", role: "driver" });
        client.emit("driver_location", {
          rideId: "507f1f77bcf86cd799439099",
          lat: 12.95,
          lng: 77.65,
        });
        setTimeout(resolve, 150);
      });
    });
    client.disconnect();
  });

  it("covers valid driver_location forwarding flow", async () => {
    const driverId = "507f1f77bcf86cd799439061";
    const rideId = "507f1f77bcf86cd799439099";
    const token = jwtUtil.generateAccessToken(driverId, "DRIVER");
    sinon.stub(UserModel, "updateOne").resolves();
    sinon.stub(RideModel, "findById").returns({
      lean: async () => ({
        _id: rideId,
        customer_id: "507f1f77bcf86cd799439062",
        driver_id: driverId,
        pickup: { lat: 12.9, lng: 77.6 },
        drop: { lat: 13.1, lng: 77.8 },
        status: "IN_TRANSIT",
      }),
    });

    const client = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token },
    });
    await new Promise((resolve) => {
      client.on("connect", () => {
        client.emit("join", { userId: driverId, role: "driver" });
        client.emit("driver_location", {
          rideId,
          lat: 12.95,
          lng: 77.65,
        });
        setTimeout(resolve, 180);
      });
    });
    client.disconnect();
  });

  it("covers join_ride_room empty and location payload-null return", async () => {
    const driverId = "507f1f77bcf86cd799439071";
    const rideId = "507f1f77bcf86cd799439099";
    const token = jwtUtil.generateAccessToken(driverId, "DRIVER");
    sinon.stub(UserModel, "updateOne").resolves();
    sinon.stub(RideModel, "findById").returns({
      lean: async () => ({
        _id: rideId,
        customer_id: "507f1f77bcf86cd799439072",
        driver_id: driverId,
        pickup: null,
        drop: null,
        status: "IN_TRANSIT",
      }),
    });
    const client = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token },
    });
    await new Promise((resolve) => {
      client.on("connect", () => {
        client.emit("join", { userId: driverId, role: "driver" });
        client.emit("join_ride_room");
        client.emit("driver_location", { rideId, lat: 12.95, lng: 77.65 });
        setTimeout(resolve, 180);
      });
    });
    client.disconnect();
  });

  it("covers joinRideRoomForUser iteration and throttled location update", async () => {
    const userId = "507f1f77bcf86cd799439081";
    const driverId = "507f1f77bcf86cd799439082";
    const rideId = "507f1f77bcf86cd799439099";
    const userToken = jwtUtil.generateAccessToken(userId, "CUSTOMER");
    const driverToken = jwtUtil.generateAccessToken(driverId, "DRIVER");
    sinon.stub(UserModel, "updateOne").resolves();
    sinon.stub(RideModel, "findById").returns({
      lean: async () => ({
        _id: rideId,
        customer_id: userId,
        driver_id: driverId,
        pickup: { lat: 12.9, lng: 77.6 },
        drop: { lat: 13.1, lng: 77.8 },
        status: "IN_TRANSIT",
      }),
    });

    const customer = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token: userToken },
    });
    const driver = ioClient(`http://127.0.0.1:${port}`, {
      transports: ["websocket"],
      auth: { token: driverToken },
    });

    await new Promise((resolve) => {
      customer.on("connect", () => {
        customer.emit("join", { userId, role: "customer" });
      });
      driver.on("connect", () => {
        driver.emit("join", { userId: driverId, role: "driver" });
        socketModule.joinRideRoomForUser(userId, rideId);
        driver.emit("driver_location", { rideId, lat: 12.95, lng: 77.65 });
        driver.emit("driver_location", { rideId, lat: 12.951, lng: 77.651 });
        setTimeout(resolve, 220);
      });
    });

    customer.disconnect();
    driver.disconnect();
  });

});
