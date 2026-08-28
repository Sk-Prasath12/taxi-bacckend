/**
 * Patches Docker backend for driver GPS → MongoDB GeoJSON + location:update socket.
 */
const fs = require('fs');

const handlersPath = '/app/src/socket/ride-booking/ride-booking.handlers.ts';
const usersTypesPath = '/app/src/modules/users/users.types.ts';
const usersModelPath = '/app/src/modules/users/users.model.ts';
const socketPath = '/app/src/socket/socket.ts';

function patchFile(path, transform, label) {
  if (!fs.existsSync(path)) {
    console.error(`${label}: missing ${path}`);
    return;
  }
  const before = fs.readFileSync(path, 'utf8');
  const after = transform(before);
  if (after === before) {
    console.log(`${label}: unchanged`);
    return;
  }
  fs.writeFileSync(path, after);
  console.log(`${label}: patched`);
}

patchFile(usersTypesPath, (s) => {
  if (s.includes('current_location')) return s;
  return s
    .replace(
      'export type UserEntity = {',
      `export type GeoPoint = {
  type: "Point";
  coordinates: [number, number];
};

export type UserEntity = {`
    )
    .replace(
      'driver_profile?: DriverProfileSnapshot;',
      `driver_profile?: DriverProfileSnapshot;
  current_location?: GeoPoint;`
    );
}, 'users.types');

patchFile(usersModelPath, (s) => {
  if (s.includes('current_location')) return s;
  return s
    .replace(
      'driver_profile: { type: Schema.Types.Mixed, default: undefined },',
      `driver_profile: { type: Schema.Types.Mixed, default: undefined },
    current_location: {
      type: {
        type: String,
        enum: ["Point"],
        default: "Point",
      },
      coordinates: { type: [Number], default: undefined },
    },`
    )
    .replace(
      'userSchema.index({ role: 1 });',
      `userSchema.index({ role: 1 });
userSchema.index({ current_location: "2dsphere" });`
    );
}, 'users.model');

patchFile(handlersPath, (s) => {
  let out = s;
  if (!out.includes('location:update')) {
    const block = `
  socket.on("location:update", async (payload: DriverOnlinePayload = {}) => {
    try {
      const identity = ensureDriverIdentity(extractIdentity(socket));
      const driverId = payload.driverId ?? identity.userId;
      if (driverId !== identity.userId) {
        throw new HttpError(403, "driverId does not match authenticated driver");
      }
      if (!isCoordinate(payload.location)) {
        throw new HttpError(400, "Invalid location");
      }

      const existing = getOnlineDriver(driverId);
      if (existing) {
        upsertOnlineDriver({
          driverId,
          socketId: socket.id,
          location: payload.location,
          updatedAt: Date.now(),
        });
      }

      const { UserModel } = await import("../../modules/users/users.model");
      await UserModel.updateOne(
        { _id: driverId, role: "DRIVER" },
        {
          $set: {
            current_location: {
              type: "Point",
              coordinates: [payload.location.lng, payload.location.lat],
            },
            driver_status: "ONLINE",
          },
        }
      );
      socket.emit("location:update:ack", { driverId, ok: true });
    } catch (error) {
      logger.error({ error, socketId: socket.id }, "location:update failed");
      emitSocketError(socket, error);
    }
  });
`;
    out = out.replace(
      'socket.on("ride:request", async (payload: RideRequestPayload) => {',
      `${block}\n\n  socket.on("ride:request", async (payload: RideRequestPayload) => {`
    );
  }
  if (!out.includes('current_location')) {
    out = out.replace(
      'logger.info({ driverId, socketId: socket.id, location: payload.location }, "Driver is online");',
      `logger.info({ driverId, socketId: socket.id, location: payload.location }, "Driver is online");
      const { UserModel } = await import("../../modules/users/users.model");
      await UserModel.updateOne(
        { _id: driverId, role: "DRIVER" },
        {
          $set: {
            current_location: {
              type: "Point",
              coordinates: [payload.location.lng, payload.location.lat],
            },
            driver_status: "ONLINE",
          },
        }
      );`
    );
  }
  return out;
}, 'ride-booking.handlers');

patchFile(socketPath, (s) => {
  if (s.includes('handleCustomerLocationEvent')) return s;
  const block = `
const handleCustomerLocationEvent = (socket: Socket) => {
  socket.on("customer:location", (payload: Record<string, unknown> = {}) => {
    const role = socketRoleMap.get(socket.id);
    if (role !== "customer") return;
    const lat = toFiniteNumber(payload.lat);
    const lng = toFiniteNumber(payload.lng);
    if (!isValidCoordinate(lat, -90, 90) || !isValidCoordinate(lng, -180, 180)) return;
    const customerId = socketUserMap.get(socket.id);
    if (!customerId) return;
    const rideId = payload.rideId ?? payload.ride_id;
    if (typeof rideId === "string" && rideId.length > 0) {
      const rooms = getRideRooms(rideId);
      for (const room of rooms) {
        ioInstance?.to(room).emit("customer_location_update", {
          ride_id: rideId,
          customer_id: customerId,
          lat,
          lng,
          timestamp: Date.now(),
        });
      }
      ioInstance?.to(\`customer_\${customerId}\`).emit("customer_location_update", {
        ride_id: rideId,
        lat,
        lng,
        timestamp: Date.now(),
      });
    }
  });
};
`;
  return s
    .replace(
      'const handleDriverLocationEvent = (socket: Socket) => {',
      `${block}\n\nconst handleDriverLocationEvent = (socket: Socket) => {`
    )
    .replace(
      'handleDriverLocationEvent(socket);',
      'handleCustomerLocationEvent(socket);\n    handleDriverLocationEvent(socket);'
    );
}, 'socket.ts');

console.log('GPS patch complete');
