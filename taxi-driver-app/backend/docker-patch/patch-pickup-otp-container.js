/**
 * Fix false "Invalid OTP":
 * 1) Do not regenerate pickup OTP on every arrived call.
 * 2) Idempotent arrived when already ARRIVED_AT_PICKUP.
 * 3) Compare OTP as numbers in verifyRideOtpAndStartRide.
 */
const fs = require("fs");

const servicePath = "/app/src/modules/driver/ride/driver-ride.service.ts";

if (!fs.existsSync(servicePath)) {
  console.error("Missing", servicePath);
  process.exit(1);
}

let src = fs.readFileSync(servicePath, "utf8");
const before = src;

const arrivedBlock = `export const markRideArrivedAtPickup = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);

  if (ride.status !== "DRIVER_ASSIGNED" && ride.status !== "ARRIVED_AT_PICKUP") {
    throw new HttpError(400, "Ride must be assigned before marking arrived");
  }

  if (ride.status === "ARRIVED_AT_PICKUP") {
    return {
      message: "Driver already at pickup location",
      ride_id: ride.id,
      status: ride.status,
      otp: ride.otp,
    };
  }

  if (ride.otp == null || ride.otp === undefined || Number(ride.otp) < 1000) {
    ride.otp = generateRideOtp();
  }
  ride.otp_verified = false;
  ride.status = "ARRIVED_AT_PICKUP";
  await ride.save();`;

if (src.includes("export const markRideArrivedAtPickup = async")) {
  src = src.replace(
    /export const markRideArrivedAtPickup = async[\s\S]*?await ride\.save\(\);/,
    arrivedBlock
  );
}

src = src.replace(
  "if (ride.otp !== otpInput) {",
  "if (Number(ride.otp) !== Number(otpInput)) {"
);

if (src === before) {
  console.log("pickup-otp patch: no changes (already patched?)");
  process.exit(0);
}

fs.writeFileSync(servicePath, src);
console.log("pickup-otp patch: OK — restart container: docker restart taxi_app_backend");
