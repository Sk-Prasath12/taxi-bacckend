const toRad = (deg) => (deg * Math.PI) / 180;

const haversineKm = (a, b) => {
  if (!a || !b) return Number.POSITIVE_INFINITY;
  const R = 6371;
  const dLat = toRad((b.lat || 0) - (a.lat || 0));
  const dLng = toRad((b.lng || 0) - (a.lng || 0));
  const lat1 = toRad(a.lat || 0);
  const lat2 = toRad(b.lat || 0);

  const h =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.sin(dLng / 2) * Math.sin(dLng / 2) * Math.cos(lat1) * Math.cos(lat2);
  return 2 * R * Math.asin(Math.sqrt(h));
};

const nearestDriver = (activeDrivers, pickup) => {
  let selected = null;
  let bestDistance = Number.POSITIVE_INFINITY;

  for (const [driverId, driver] of activeDrivers.entries()) {
    if (driver.status !== "available") continue;
    const distance = haversineKm(driver.location, pickup);
    if (distance < bestDistance) {
      bestDistance = distance;
      selected = { driverId, ...driver, distanceKm: distance };
    }
  }

  return selected;
};

module.exports = {
  haversineKm,
  nearestDriver
};
