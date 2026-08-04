const http = require("http");
const request = require("supertest");
const { expect } = require("chai");
const { app } = require("../src/app");
const { connectDatabase, disconnectDatabase } = require("../src/database/mongoose");
const { VehicleTypeModel } = require("../src/modules/vehicle-type/vehicle-type.model");
const { OperationalZoneModel } = require("../src/modules/operational-zone/operational-zone.model");
const { UserModel } = require("../src/modules/users/users.model");
const { RideModel } = require("../src/modules/customer/ride/ride.model");
const { hashPassword } = require("../src/utils/password.util");
const { initializeSocketServer } = require("../src/socket/socket");

const API_BASE = "/api";

const CUSTOMER_EMAIL = "customer01@yopmail.com";
const CUSTOMER_PASSWORD = "12345678";
const DRIVER_EMAIL = "driver04@yopmail.com";
const DRIVER_PASSWORD = "driver112233";

let CUSTOMER_TOKEN = "";
let DRIVER_TOKEN = "";
let testHttpServer;

let rideId = "";

const BASE_RIDE_PAYLOAD = {
  pickup_lat: 12.97598,
  pickup_lng: 80.2212,
  pickup_address: "Phoenix Mall, Velachery Main Rd, Chennai",
  drop_lat: 12.9268,
  drop_lng: 80.1203,
  drop_address: "VIT Chennai, Kelambakkam, Chennai",
  payment_mode: "CASH",
};

const extractRideId = (body) => {
  if (!body || typeof body !== "object") {
    return "";
  }
  if (typeof body.ride_id === "string" && body.ride_id) {
    return body.ride_id;
  }
  if (typeof body.rideId === "string" && body.rideId) {
    return body.rideId;
  }
  if (body.data && typeof body.data === "object") {
    if (typeof body.data.ride_id === "string" && body.data.ride_id) {
      return body.data.ride_id;
    }
    if (typeof body.data.rideId === "string" && body.data.rideId) {
      return body.data.rideId;
    }
  }
  return "";
};

const getVehicleTypeId = (body) => {
  if (!body || typeof body !== "object") {
    return "";
  }
  const candidates = Array.isArray(body)
    ? body
    : Array.isArray(body.data)
      ? body.data
      : Array.isArray(body.vehicle_types)
        ? body.vehicle_types
        : Array.isArray(body.vehicleTypes)
          ? body.vehicleTypes
          : [];
  const first = candidates[0];
  if (!first || typeof first !== "object") {
    return "";
  }
  return first.id || first.vehicle_type_id || "";
};

const withTimeout = async (promise, ms, timeoutMessage) => {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(timeoutMessage)), ms);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
};

const ensureTestUsers = async () => {
  const [customerPasswordHash, driverPasswordHash] = await Promise.all([
    hashPassword(CUSTOMER_PASSWORD),
    hashPassword(DRIVER_PASSWORD),
  ]);

  await UserModel.updateOne(
    { email: CUSTOMER_EMAIL.toLowerCase().trim(), role: "CUSTOMER" },
    {
      $set: {
        name: "Test Customer",
        email: CUSTOMER_EMAIL.toLowerCase().trim(),
        password_hash: customerPasswordHash,
        is_active: true,
        is_blocked: false,
      },
      $unset: {
        blocked_reason: 1,
      },
    },
    { upsert: true }
  );

  await UserModel.updateOne(
    { email: DRIVER_EMAIL.toLowerCase().trim(), role: "DRIVER" },
    {
      $set: {
        name: "Test Driver",
        email: DRIVER_EMAIL.toLowerCase().trim(),
        password_hash: driverPasswordHash,
        is_active: true,
        is_blocked: false,
        driver_status: "OFFLINE",
        is_driver_verified: true,
        driver_verification_status: "APPROVED",
      },
      $unset: {
        blocked_reason: 1,
      },
    },
    { upsert: true }
  );
};

const ensureOperationalZoneForRide = async (createdByUserId) => {
  const pickupPoint = [BASE_RIDE_PAYLOAD.pickup_lng, BASE_RIDE_PAYLOAD.pickup_lat];
  const dropPoint = [BASE_RIDE_PAYLOAD.drop_lng, BASE_RIDE_PAYLOAD.drop_lat];

  const [pickupZone, dropZone] = await Promise.all([
    OperationalZoneModel.findOne({
      is_active: true,
      polygon: {
        $geoIntersects: {
          $geometry: {
            type: "Point",
            coordinates: pickupPoint,
          },
        },
      },
    }),
    OperationalZoneModel.findOne({
      is_active: true,
      polygon: {
        $geoIntersects: {
          $geometry: {
            type: "Point",
            coordinates: dropPoint,
          },
        },
      },
    }),
  ]);

  if (pickupZone && dropZone) {
    return;
  }

  await OperationalZoneModel.create({
    zone_name: "Auto Test Zone",
    polygon: {
      type: "Polygon",
      coordinates: [[
        [80.0, 12.8],
        [80.35, 12.8],
        [80.35, 13.05],
        [80.0, 13.05],
        [80.0, 12.8],
      ]],
    },
    is_active: true,
    created_by: createdByUserId,
  });
};

const closeExistingActiveRides = async (customerId) => {
  await RideModel.updateMany(
    {
      customer_id: customerId,
      status: {
        $in: [
          "PENDING_CONFIRMATION",
          "SEARCHING_DRIVER",
          "DRIVER_ASSIGNED",
          "ARRIVED_AT_PICKUP",
          "STARTED",
          "PICKED_UP",
          "IN_TRANSIT",
        ],
      },
    },
    {
      $set: {
        status: "CANCELLED",
      },
    }
  );
};

describe("Taxi Ride API Tests", function () {
  this.timeout(40000);

  before(async () => {
    await withTimeout(connectDatabase(), 10000, "Database connection failed – stopping tests");
    testHttpServer = http.createServer(app);
    initializeSocketServer(testHttpServer);
    await ensureTestUsers();
    const customerUser = await UserModel.findOne({
      email: CUSTOMER_EMAIL.toLowerCase().trim(),
      role: "CUSTOMER",
    });
    if (!customerUser) {
      throw new Error("Test customer user missing after bootstrap");
    }
    await ensureOperationalZoneForRide(customerUser._id);
    await closeExistingActiveRides(customerUser._id);
    let setupError = null;
    let vehicleTypeId;

    for (let attempt = 1; attempt <= 2; attempt += 1) {
      try {
        const customerLoginRes = await request(app)
          .post(`${API_BASE}/customers/login`)
          .send({ email: CUSTOMER_EMAIL, password: CUSTOMER_PASSWORD });
        if (customerLoginRes.status !== 200 || !customerLoginRes.body?.token) {
          throw new Error(`Customer login failed with status ${customerLoginRes.status}`);
        }
        CUSTOMER_TOKEN = customerLoginRes.body.token;

        const driverLoginRes = await request(app)
          .post(`${API_BASE}/drivers/login`)
          .send({ email: DRIVER_EMAIL, password: DRIVER_PASSWORD });
        if (driverLoginRes.status !== 200 || !driverLoginRes.body?.token) {
          throw new Error(`Driver login failed with status ${driverLoginRes.status}`);
        }
        DRIVER_TOKEN = driverLoginRes.body.token;

        const vehicleTypesRes = await request(app)
          .get(`${API_BASE}/vehicle-types/active`)
          .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`);
        if (vehicleTypesRes.status !== 200) {
          throw new Error(`Vehicle types fetch failed with status ${vehicleTypesRes.status}`);
        }

        console.log("Vehicle Type Response:", vehicleTypesRes.body);
        vehicleTypeId = getVehicleTypeId(vehicleTypesRes.body);
        if (!vehicleTypeId) {
          console.log("No vehicle types found -> creating one");
          const createdVehicleType = await VehicleTypeModel.create({
            name: "Auto Test",
            per_km_rate: 20,
            max_passengers: 4,
            is_active: true,
          });
          vehicleTypeId = createdVehicleType.id || createdVehicleType._id?.toString?.() || "";
        }
        if (!vehicleTypeId) {
          throw new Error("vehicleTypeId still missing");
        }
        console.log("Using vehicleTypeId:", vehicleTypeId);

        const requestRideRes = await request(app)
          .post(`${API_BASE}/customers/rides/request`)
          .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`)
          .send({ ...BASE_RIDE_PAYLOAD, vehicle_type_id: vehicleTypeId });

        if (![200, 201].includes(requestRideRes.status)) {
          throw new Error(`Ride request failed with status ${requestRideRes.status}`);
        }

        const requestedRideId = extractRideId(requestRideRes.body);
        if (!requestedRideId) {
          throw new Error("Ride request succeeded but ride id was missing");
        }

        const confirmRes = await request(app)
          .post(`${API_BASE}/customers/rides/confirm`)
          .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`)
          .send({ ride_id: requestedRideId });

        if (![200, 201].includes(confirmRes.status)) {
          throw new Error(`Ride confirm failed with status ${confirmRes.status}`);
        }

        rideId = requestedRideId;
        console.log("Using Ride ID:", rideId);
        break;
      } catch (error) {
        setupError = error;
      }
    }

    if (!rideId) {
      const setupMessage = setupError instanceof Error ? setupError.message : "Unknown setup error";
      throw new Error(`Ride creation failed – stopping tests (${setupMessage})`);
    }
  });

  after(async () => {
    if (testHttpServer) {
      await new Promise((resolve) => testHttpServer.close(() => resolve()));
    }
    await disconnectDatabase();
  });

  it("1. Get Active Ride", async () => {
    const res = await request(app)
      .get(`${API_BASE}/customers/rides/active`)
      .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`);

    expect(res.status).to.equal(200);
    expect(res.body).to.have.property("ride_id");
    expect(res.body).to.have.property("status");
    expect(res.body).to.have.property("pickup");
    expect(res.body).to.have.property("drop");
  });

  it("2. Get Ride Status", async () => {
    const res = await request(app)
      .get(`${API_BASE}/customers/rides/${rideId}/status`)
      .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`);

    expect(res.status).to.equal(200);
    expect(res.body).to.have.property("status");
    expect(res.body).to.have.property("ride_id");
    expect(res.body).to.have.property("fare");
  });

  it("3. Driver Accept Ride", async () => {
    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/accept`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});

    expect(res.status).to.equal(200);
    expect(res.body).to.have.property("message");
    expect(res.body).to.have.property("ride_id");
  });

  it("4. Driver Arrived", async () => {
    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/arrived`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});

    expect(res.status).to.equal(200);
  });

  it("5. Verify OTP (Wrong)", async () => {
    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/verify-otp`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({ otp: 1111 });
    if (![400, 403].includes(res.status)) {
      console.log("ERROR:", res.body);
    }
    expect([400, 403]).to.include(res.status);
  });

  it("6. Verify OTP (Correct)", async () => {
    const active = await request(app)
      .get(`${API_BASE}/customers/rides/active`)
      .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`);

    const otp = active.body.otp;

    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/verify-otp`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({ otp });

    expect(res.status).to.equal(200);
  });

  it("7. Picked Up", async () => {
    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/picked-up`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});

    expect(res.status).to.equal(200);
  });

  it("8. In Transit", async () => {
    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/in-transit`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});

    expect(res.status).to.equal(200);
  });

  it("9. Drop Ride", async () => {
    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/dropped`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});

    expect(res.status).to.equal(200);
  });

  it("10. Invalid Token", async () => {
    const res = await request(app)
      .get(`${API_BASE}/customers/rides/active`)
      .set("Authorization", "Bearer INVALID");
    if (res.status !== 401) {
      console.log("ERROR:", res.body);
    }
    expect(res.status).to.equal(401);
    expect(res.body).to.be.an("object");
  });

  it("10b. Ride Request Without vehicle_type_id", async () => {
    const res = await request(app)
      .post(`${API_BASE}/customers/rides/request`)
      .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`)
      .send({ ...BASE_RIDE_PAYLOAD });

    expect([400, 422]).to.include(res.status);
  });

  it("11. No Active Ride", async () => {
    const res = await request(app)
      .get(`${API_BASE}/customers/rides/active`)
      .set("Authorization", `Bearer ${CUSTOMER_TOKEN}`);

    expect(res.body).to.have.property("message");
  });

  it("12. Wrong Flow - Picked Up Before OTP", async () => {
    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/picked-up`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});
    if (![400, 403].includes(res.status)) {
      console.log("ERROR:", res.body);
    }
    expect([400, 403]).to.include(res.status);
  });

  it("13. Duplicate Accept Ride", async () => {
    await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/accept`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});

    const res = await request(app)
      .post(`${API_BASE}/drivers/rides/${rideId}/accept`)
      .set("Authorization", `Bearer ${DRIVER_TOKEN}`)
      .send({});
    if (![400, 403, 409].includes(res.status)) {
      console.log("ERROR:", res.body);
    }
    expect([400, 403, 409]).to.include(res.status);
  });
});
