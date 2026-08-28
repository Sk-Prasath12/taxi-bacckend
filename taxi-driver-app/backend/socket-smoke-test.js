require("dotenv").config();
const { io } = require("socket.io-client");
const jwt = require("jsonwebtoken");

const SERVER_URL = process.env.SOCKET_URL || "http://127.0.0.1:3000";
const JWT_SECRET = process.env.JWT_SECRET || "dev-secret";
const DRIVER_ID = process.env.TEST_DRIVER_ID || "driver-demo-1";
const CUSTOMER_ID = process.env.TEST_CUSTOMER_ID || "customer-demo-1";

const token = jwt.sign({ driverId: DRIVER_ID }, JWT_SECRET, { expiresIn: "1h" });

const driver = io(SERVER_URL, { transports: ["websocket"], auth: { token } });
const customer = io(SERVER_URL, { transports: ["websocket"] });

const state = { rideId: null };

const log = (label, payload) => {
  console.log(`[test] ${label}`, payload ? JSON.stringify(payload) : "");
};

driver.on("connect", () => {
  log("driver connected", { id: driver.id });
  driver.emit(
    "driver:online",
    {
      token,
      driverId: DRIVER_ID,
      location: { lat: 12.9716, lng: 77.5946 }
    },
    (ack) => log("driver:online ack", ack)
  );
});

driver.on("ride:new", (payload) => {
  log("driver got ride:new", payload);
  state.rideId = payload.rideId;
  driver.emit("ride:accept", { rideId: state.rideId }, (ack) => {
    log("ride:accept ack", ack);
    if (ack?.success) {
      setTimeout(() => {
        driver.emit("ride:arrived", { rideId: state.rideId }, (arriveAck) => {
          log("ride:arrived ack", arriveAck);
          setTimeout(() => {
            driver.emit("ride:start", { rideId: state.rideId }, (startAck) => {
              log("ride:start ack", startAck);
              setTimeout(() => {
                driver.emit("ride:end", { rideId: state.rideId, fare: 240 }, (endAck) => {
                  log("ride:end ack", endAck);
                  setTimeout(cleanup, 500);
                });
              }, 500);
            });
          }, 500);
        });
      }, 500);
    }
  });
});

driver.on("ride:update", (payload) => log("driver got ride:update", payload));
customer.on("ride:accepted", (payload) => log("customer got ride:accepted", payload));
customer.on("ride:update", (payload) => log("customer got ride:update", payload));
customer.on("ride:payment", (payload) => log("customer got ride:payment", payload));
customer.on("ride:no_driver", (payload) => log("customer got ride:no_driver", payload));

customer.on("connect", () => {
  log("customer connected", { id: customer.id });
  customer.emit("customer:connect", { customerId: CUSTOMER_ID }, (ack) => {
    log("customer:connect ack", ack);
    customer.emit(
      "customer:ride:request",
      {
        customerId: CUSTOMER_ID,
        customerName: "Test Rider",
        pickup: { lat: 12.9717, lng: 77.5947 },
        drop: { lat: 12.9352, lng: 77.6245 },
        distance: "8.5 km"
      },
      (requestAck) => log("customer:ride:request ack", requestAck)
    );
  });
});

const cleanup = () => {
  driver.disconnect();
  customer.disconnect();
  setTimeout(() => process.exit(0), 200);
};

setTimeout(() => {
  log("timeout: ending test");
  cleanup();
}, 15000);
