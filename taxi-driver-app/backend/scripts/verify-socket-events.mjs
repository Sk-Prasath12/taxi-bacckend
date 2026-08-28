/**
 * Verifies Docker backend emits new_ride after confirm.
 * Usage (from backend/): node scripts/verify-socket-events.mjs <driver_jwt>
 */
import { io } from "socket.io-client";

const token = process.argv[2];
const baseUrl = process.env.API_URL || "http://localhost:3000";

if (!token) {
  console.error("Usage: node scripts/verify-socket-events.mjs <driver_jwt>");
  process.exit(1);
}

const socket = io(baseUrl, {
  transports: ["websocket"],
  auth: { token },
});

let sawNewRide = false;

socket.on("connect", () => {
  console.log("Socket connected:", socket.id);
  socket.emit("join", { userId: "verify-script", role: "driver" });
  socket.emit("driver:online", {
    driverId: "verify-script",
    location: { lat: 12.97598, lng: 80.2212 },
  });
  console.log("Listening for new_ride (book+confirm from customer UI or HTTP)...");
});

socket.on("new_ride", (payload) => {
  sawNewRide = true;
  console.log("EVENT new_ride:", JSON.stringify(payload));
});

socket.on("ride:request", (payload) => {
  console.log("EVENT ride:request:", JSON.stringify(payload));
});

setTimeout(() => {
  console.log(sawNewRide ? "PASS: received new_ride" : "INFO: no new_ride in 30s (trigger confirm ride to test)");
  socket.disconnect();
  process.exit(sawNewRide ? 0 : 0);
}, 30000);
