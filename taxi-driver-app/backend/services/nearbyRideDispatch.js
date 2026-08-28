const Driver = require("../models/Driver");
const { haversineKm } = require("../sockets/geo");

const NEARBY_KM = Number(process.env.DRIVER_NEARBY_KM || 5);

/**
 * Online drivers within maxKm of pickup (Mongo 2dsphere).
 * Returns [] if pickup invalid; null if geo query fails (caller may fallback).
 */
async function findDriverIdsNearPickup(pickup, maxKm = NEARBY_KM) {
  const lat = Number(pickup?.lat);
  const lng = Number(pickup?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return [];
  }

  try {
    const drivers = await Driver.find({
      status: { $in: ["online", "busy"] },
      currentLocation: {
        $near: {
          $geometry: { type: "Point", coordinates: [lng, lat] },
          $maxDistance: maxKm * 1000
        }
      }
    })
      .select("_id")
      .limit(50)
      .lean();

    return drivers.map((d) => d._id.toString());
  } catch (err) {
    console.error("findDriverIdsNearPickup:", err.message);
    return null;
  }
}

function filterRidesByPickupDistance(rides, driverLat, driverLng, maxKm = NEARBY_KM) {
  const lat = Number(driverLat);
  const lng = Number(driverLng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return [];
  }
  return rides.filter((ride) => {
    const p = ride.pickup;
    if (!p || p.lat == null || p.lng == null) return false;
    return haversineKm({ lat, lng }, { lat: p.lat, lng: p.lng }) <= maxKm;
  });
}

async function resolveNearbyDriverIds(pickup, maxKm = NEARBY_KM) {
  const ids = await findDriverIdsNearPickup(pickup, maxKm);
  if (ids === null) return null;
  if (ids.length > 0) return ids;

  const lat = Number(pickup?.lat);
  const lng = Number(pickup?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return [];

  const online = await Driver.find({ status: { $in: ["online", "busy"] } })
    .select("_id currentLocation")
    .lean();

  return online
    .filter((d) => {
      const c = d.currentLocation?.coordinates;
      if (!c || c.length < 2) return false;
      const dLng = Number(c[0]);
      const dLat = Number(c[1]);
      if (!Number.isFinite(dLat) || !Number.isFinite(dLng)) return false;
      if (dLat === 0 && dLng === 0) return false;
      return haversineKm({ lat, lng }, { lat: dLat, lng: dLng }) <= maxKm;
    })
    .map((d) => d._id.toString());
}

module.exports = {
  NEARBY_KM,
  findDriverIdsNearPickup,
  resolveNearbyDriverIds,
  filterRidesByPickupDistance
};
