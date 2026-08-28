/**
 * Flexible ride flow: no geo-fence, pickup/drop OTP, GPS fare, payment before complete.
 * Run inside taxi_app_backend: node /path/patch-flexible-ride.js && npm run build
 */
const fs = require("fs");

const modelPath = "/app/src/modules/customer/ride/ride.model.ts";
const servicePath = "/app/src/modules/driver/ride/driver-ride.service.ts";
const routesPath = "/app/src/modules/driver/ride/driver-ride.routes.ts";
const controllerPath = "/app/src/modules/driver/ride/driver-ride.controller.ts";

function patch(path, transform, label) {
  if (!fs.existsSync(path)) {
    console.error(`${label}: missing ${path}`);
    return;
  }
  const before = fs.readFileSync(path, "utf8");
  const after = transform(before);
  if (after === before) {
    console.log(`${label}: unchanged`);
    return;
  }
  fs.writeFileSync(path, after);
  console.log(`${label}: patched`);
}

const OTP_GEN = `const generateRideOtp = (): number =>
  Math.floor(Math.random() * (9999 - 1000 + 1)) + 1000;`;

patch(modelPath, (s) => {
  if (s.includes("drop_otp")) return s;
  return s
    .replace(
      "otp_verified: boolean;",
      `otp_verified: boolean;
  drop_otp?: number;
  drop_otp_verified?: boolean;
  drop_reached?: boolean;
  actual_distance_km?: number;
  actual_drop?: RideLocation;
  trip_started_at?: Date;`
    )
    .replace(
      "otp_verified: { type: Boolean, default: false },",
      `otp_verified: { type: Boolean, default: false },
    drop_otp: { type: Number, min: 1000, max: 9999 },
    drop_otp_verified: { type: Boolean, default: false },
    drop_reached: { type: Boolean, default: false },
    actual_distance_km: { type: Number, min: 0 },
    actual_drop: { type: rideLocationSchema },
    trip_started_at: { type: Date },`
    );
}, "ride.model");

patch(servicePath, (s) => {
  let out = s;
  if (!out.includes("generateRideOtp")) {
    out = out.replace(
      "const mapIncomingRide = (ride: RideDocument) => ({",
      `${OTP_GEN}

const mapIncomingRide = (ride: RideDocument) => ({`
    );
  }
  if (!out.includes("drop_otp:")) {
    out = out.replace(
      "status: ride.status,",
      `status: ride.status,
  otp: typeof ride.otp === "number" ? ride.otp : null,
  drop_otp: typeof ride.drop_otp === "number" ? ride.drop_otp : null,
  drop_otp_verified: Boolean(ride.drop_otp_verified),
  drop_reached: Boolean(ride.drop_reached),
  actual_distance_km: ride.actual_distance_km ?? ride.distance_km,`
    );
  }

  if (!out.includes("pickup_otp_generated")) {
    out = out.replace(
      `export const markRideArrivedAtPickup = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  return moveRideStatus(
    driverIdInput,
    rideIdInput,
    "DRIVER_ASSIGNED",
    "ARRIVED_AT_PICKUP",
    "Driver arrived at pickup location"
  );
};`,
      `export const markRideArrivedAtPickup = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);
  if (ride.otp == null || ride.otp === "") {
    ride.otp = generateRideOtp();
  }
  ride.otp_verified = false;
  ride.status = "ARRIVED_AT_PICKUP";
  await ride.save();
  const customerId = String(ride.customer_id);
  const payload = { ride_id: ride.id, status: "ARRIVED", otp: ride.otp, ride: mapIncomingRide(ride) };
  emitToCustomer(customerId, "pickup_otp_generated", payload);
  emitToCustomer(customerId, "driver_arrived", payload);
  emitToCustomer(customerId, "ride_status_update", payload);
  emitToRide(ride.id, "ride_status_update", payload);
  return { message: "Driver arrived, pickup OTP generated", ride_id: ride.id, status: ride.status, otp: ride.otp };
};`
    );
  }

  if (!out.includes("verifyDropOtpAndProceed")) {
    out = out.replace(
      `export const markRideDropped = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  return moveRideStatus(driverIdInput, rideIdInput, "IN_TRANSIT", "COMPLETED", "Ride dropped successfully");
};`,
      `type DropBody = { fare?: number; lat?: number; lng?: number; actual_distance_km?: number; duration_min?: number };

export const markRideDropped = async (
  driverIdInput: string | undefined,
  rideIdInput?: string,
  body: DropBody = {}
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);
  const actualKm = Number(body.actual_distance_km ?? ride.actual_distance_km ?? ride.distance_km);
  const durationMin = Number(body.duration_min ?? ride.duration_min ?? 0);
  const base = 40;
  const fare = Number(body.fare ?? Math.round(base + actualKm * 12 + durationMin * 2));
  ride.actual_distance_km = actualKm;
  ride.duration_min = durationMin;
  ride.fare = fare;
  ride.drop_reached = true;
  ride.drop_otp = generateRideOtp();
  ride.drop_otp_verified = false;
  if (typeof body.lat === "number" && typeof body.lng === "number") {
    ride.actual_drop = { lat: body.lat, lng: body.lng, address: "Actual drop" };
    ride.drop = ride.actual_drop;
  }
  ride.status = "IN_TRANSIT";
  await ride.save();
  const customerId = String(ride.customer_id);
  const payload = {
    ride_id: ride.id,
    status: "IN_TRANSIT",
    drop_otp: ride.drop_otp,
    fare: ride.fare,
    actual_distance_km: ride.actual_distance_km,
    ride: mapIncomingRide(ride),
  };
  emitToCustomer(customerId, "drop_reached", payload);
  emitToCustomer(customerId, "drop_otp_generated", payload);
  emitToCustomer(customerId, "ride_status_update", payload);
  emitToRide(ride.id, "ride_status_update", payload);
  return {
    message: "Drop reached, fare recalculated",
    ride_id: ride.id,
    status: ride.status,
    fare: ride.fare,
    drop_otp: ride.drop_otp,
  };
};

export const verifyDropOtpAndProceed = async (
  driverIdInput: string | undefined,
  rideIdInput: string | undefined,
  otpInput: number
) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);
  if (!ride.drop_reached) throw new HttpError(400, "Mark drop reached first");
  if (ride.drop_otp_verified) throw new HttpError(400, "Drop OTP already verified");
  if (ride.drop_otp !== otpInput) throw new HttpError(400, "Invalid drop OTP");
  ride.drop_otp_verified = true;
  ride.status = "COMPLETED_PENDING_PAYMENT";
  ride.payment_status = "PENDING";
  await ride.save();
  const customerId = String(ride.customer_id);
  const payload = { ride_id: ride.id, status: ride.status, fare: ride.fare, payment_status: ride.payment_status, ride: mapIncomingRide(ride) };
  emitToCustomer(customerId, "drop_otp_verified", payload);
  emitToCustomer(customerId, "payment_pending", payload);
  emitToCustomer(customerId, "ride_status_update", payload);
  emitToRide(ride.id, "payment_pending", payload);
  emitToRide(ride.id, "ride_status_update", payload);
  return { message: "Drop OTP verified", ride_id: ride.id, status: ride.status, payment_status: ride.payment_status };
};

export const confirmCashReceived = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);
  if (!ride.drop_otp_verified) throw new HttpError(400, "Drop OTP not verified");
  ride.payment_status = "SUCCESS";
  await ride.save();
  const customerId = String(ride.customer_id);
  emitToCustomer(customerId, "payment_success", { ride_id: ride.id, amount: ride.fare });
  emitToRide(ride.id, "payment_success", { ride_id: ride.id, amount: ride.fare });
  emitToDriver(String(driver.id), "payment_success", { ride_id: ride.id, amount: ride.fare });
  emitToDriver(String(driver.id), "wallet_updated", { ride_id: ride.id, amount: ride.fare });
  return { message: "Cash received", ride_id: ride.id, payment_status: "SUCCESS" };
};

export const completeRideAfterPayment = async (driverIdInput: string | undefined, rideIdInput?: string) => {
  const driver = await getDriverOrThrow(driverIdInput);
  const ride = await getRideByIdOrThrow(rideIdInput);
  ensureRideBelongsToDriver(ride, driver.id);
  if (!ride.drop_otp_verified) throw new HttpError(400, "Drop OTP not verified");
  if (ride.payment_status !== "SUCCESS") throw new HttpError(400, "Payment not completed");
  ride.status = "COMPLETED";
  await ride.save();
  if (ride.payment_mode === "CASH") {
    try {
      await processRidePayment(ride);
      await generateInvoice(ride);
    } catch (e) {
      logger.error({ e, ride_id: ride.id }, "complete cash finance failed");
    }
  }
  const customerId = String(ride.customer_id);
  const payload = { ride_id: ride.id, status: "COMPLETED", ride: mapIncomingRide(ride) };
  emitToCustomer(customerId, "ride_completed", payload);
  emitToCustomer(customerId, "ride_status_update", payload);
  emitToRide(ride.id, "ride_status_update", payload);
  return { message: "Ride completed", ride_id: ride.id, status: ride.status };
};`
    );

    out = out.replace(
      `  ride.otp_verified = true;
  ride.status = "STARTED";
  await ride.save();`,
      `  ride.otp_verified = true;
  ride.status = "STARTED";
  ride.trip_started_at = new Date();
  await ride.save();`
    );

    out = out.replace(
      `  emitToCustomer(customerId, "ride_status_update", {
    ride_id: ride.id,
    status: statusForClient,
    ride: mapIncomingRide(ride),
  });`,
      `  emitToCustomer(customerId, "pickup_otp_verified", {
    ride_id: ride.id,
    status: statusForClient,
    ride: mapIncomingRide(ride),
  });
  emitToCustomer(customerId, "trip_started", {
    ride_id: ride.id,
    status: statusForClient,
    ride: mapIncomingRide(ride),
  });
  emitToCustomer(customerId, "gps_tracking_started", { ride_id: ride.id });
  emitToCustomer(customerId, "ride_status_update", {
    ride_id: ride.id,
    status: statusForClient,
    ride: mapIncomingRide(ride),
  });`
    );
  }
  return out;
}, "driver-ride.service");

patch(routesPath, (s) => {
  if (s.includes("verify-drop-otp")) return s;
  let out = s.replace(
    "verifyRideOtpController,\n} from \"./driver-ride.controller\";",
    `verifyRideOtpController,
  verifyDropOtpController,
  cashReceivedController,
  completeRideController,
} from "./driver-ride.controller";`
  );
  out = out.replace(
    `driverRideRouter.patch("/api/rides/:rideId/status", validate(updateRideStatusSchema), updateRideStatusController);`,
    `driverRideRouter.post(
  "/api/drivers/rides/:rideId/verify-drop-otp",
  validate(verifyRideOtpSchema),
  verifyDropOtpController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/cash-received",
  validate(driverRideIdParamSchema),
  cashReceivedController
);
driverRideRouter.post(
  "/api/drivers/rides/:rideId/complete",
  validate(driverRideIdParamSchema),
  completeRideController
);
driverRideRouter.patch("/api/rides/:rideId/status", validate(updateRideStatusSchema), updateRideStatusController);`
  );
  return out;
}, "driver-ride.routes");

patch(controllerPath, (s) => {
  if (s.includes("verifyDropOtpController")) return s;
  return `${s}

export const verifyDropOtpController = async (req, res, next) => {
  try {
    const { verifyDropOtpAndProceed } = require("./driver-ride.service");
    const data = await verifyDropOtpAndProceed(req.authUser?.userId, req.params.rideId, req.body.otp);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const cashReceivedController = async (req, res, next) => {
  try {
    const { confirmCashReceived } = require("./driver-ride.service");
    const data = await confirmCashReceived(req.authUser?.userId, req.params.rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};

export const completeRideController = async (req, res, next) => {
  try {
    const { completeRideAfterPayment } = require("./driver-ride.service");
    const data = await completeRideAfterPayment(req.authUser?.userId, req.params.rideId);
    return res.status(200).json(data);
  } catch (error) {
    return next(error);
  }
};
`;
}, "driver-ride.controller");

// dropped controller must pass body
patch(controllerPath, (s) => {
  if (s.includes("markRideDroppedController") && s.includes("req.body")) return s;
  return s.replace(
    "const data = await markRideDropped(req.authUser?.userId, req.params.rideId as string);",
    "const data = await markRideDropped(req.authUser?.userId, req.params.rideId as string, req.body);"
  );
}, "dropped body");

patch(servicePath, (s) => {
  if (s.includes("export const markRideDropped = async") && s.includes("DropBody")) return s;
  return s;
}, "service check");

console.log("Flexible ride patch done. Run: cd /app && npm run build && restart container");
