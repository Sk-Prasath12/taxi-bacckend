const VehicleType = require("../models/VehicleType");

/** Keep in sync with taxi-bacckend-deploy ensure-canonical-vehicles. */
const CANONICAL = [
  { code: "BIKE", name: "Bike", perKmFare: 10, maxPassengers: 1 },
  { code: "AUTO", name: "Auto", perKmFare: 20, maxPassengers: 3 },
  { code: "MINI", name: "Mini", perKmFare: 30, maxPassengers: 4 },
  { code: "SEDAN", name: "Sedan", perKmFare: 40, maxPassengers: 4 },
  { code: "SUV", name: "SUV", perKmFare: 50, maxPassengers: 6 },
  { code: "PREMIUM_SEDAN", name: "Premium Sedan", perKmFare: 60, maxPassengers: 4 },
  { code: "PREMIUM_SUV", name: "Premium SUV", perKmFare: 70, maxPassengers: 7 },
  { code: "XL", name: "XL", perKmFare: 80, maxPassengers: 12 },
  { code: "ELECTRIC", name: "Electric", perKmFare: 90, maxPassengers: 4 },
  { code: "ACCESSIBLE", name: "Accessible", perKmFare: 100, maxPassengers: 4 },
];

const ensureDefaults = async () => {
  for (const item of CANONICAL) {
    await VehicleType.findOneAndUpdate(
      { $or: [{ code: item.code }, { name: item.name }] },
      {
        $set: {
          code: item.code,
          name: item.name,
          baseFare: item.perKmFare,
          perKmFare: item.perKmFare,
          maxPassengers: item.maxPassengers,
          active: true,
        },
      },
      { upsert: true, new: true, setDefaultsOnInsert: true }
    );
  }
  await VehicleType.updateMany(
    { code: { $nin: CANONICAL.map((v) => v.code) } },
    { $set: { active: false } }
  );
};

const mapType = (v) => ({
  id: v._id.toString(),
  code: v.code || null,
  name: v.name,
  base_fare: v.baseFare,
  per_km_fare: v.perKmFare,
  per_km_rate: v.perKmFare,
  max_passengers: v.maxPassengers || 4,
  active: v.active,
  is_active: v.active,
});

const listVehicleTypes = async (req, res) => {
  await ensureDefaults();
  const list = await VehicleType.find({ active: true }).sort({ perKmFare: 1 });
  return res.json(list.map(mapType));
};

const listActiveVehicleTypes = async (req, res) => {
  await ensureDefaults();
  const list = await VehicleType.find({ active: true }).sort({ perKmFare: 1 });
  return res.json({
    success: true,
    data: list.map(mapType),
  });
};

module.exports = {
  listVehicleTypes,
  listActiveVehicleTypes,
};
