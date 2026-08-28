let ioInstance;
let DriverModel;

const setSocketServer = (io) => {
  ioInstance = io;
};

const setDriverModel = (Driver) => {
  DriverModel = Driver;
};

const getSocketServer = () => {
  if (!ioInstance) {
    throw new Error("Socket.IO has not been initialized.");
  }
  return ioInstance;
};

const emitToDriver = (driverId, event, payload) => ioInstance?.to(`driver:${driverId}`).emit(event, payload);
const emitToCustomer = (customerId, event, payload) => ioInstance?.to(`customer:${customerId}`).emit(event, payload);
const emitToRide = (rideId, event, payload) => ioInstance?.to(`ride:${rideId}`).emit(event, payload);

/** Emit only to online/busy drivers (driver:{id} rooms), never all sockets. */
const emitToAllDrivers = async (event, payload) => {
  if (!ioInstance) return;
  if (!DriverModel) {
    return;
  }
  const drivers = await DriverModel.find({ status: { $in: ["online", "busy"] } })
    .select("_id")
    .lean();
  for (const d of drivers) {
    ioInstance.to(`driver:${d._id}`).emit(event, payload);
  }
};

module.exports = {
  setSocketServer,
  setDriverModel,
  getSocketServer,
  emitToAllDrivers,
  emitToDriver,
  emitToCustomer,
  emitToRide
};
