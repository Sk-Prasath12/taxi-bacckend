import { findUserByEmail } from "../src/modules/users/users.repository";
import { OperationalZoneModel } from "../src/modules/operational-zone/operational-zone.model";
import { Seed } from "./seed.types";

const ADMIN_EMAIL = "admin@taxigo.com";
const CHENNAI_ZONE_NAME = "Chennai Metro";

/** Greater Chennai + suburbs (Tambaram, OMR, Sriperumbudur, Red Hills). Format: [lng, lat]. */
const CHENNAI_POLYGON: [number, number][] = [
  [79.85, 12.70],
  [80.45, 12.70],
  [80.45, 13.25],
  [79.85, 13.25],
  [79.85, 12.70],
];

const run = async (): Promise<void> => {
  const polygon = {
    type: "Polygon" as const,
    coordinates: [CHENNAI_POLYGON],
  };

  const existing = await OperationalZoneModel.findOne({ zone_name: CHENNAI_ZONE_NAME });
  if (existing) {
    existing.polygon = polygon;
    existing.is_active = true;
    await existing.save();
    console.log("Chennai operational zone updated (expanded polygon, active)");
    return;
  }

  const admin = await findUserByEmail(ADMIN_EMAIL);
  if (!admin) {
    console.warn("Admin user not found — run seed-admin first. Skipping operational zone seed.");
    return;
  }

  await OperationalZoneModel.create({
    zone_name: CHENNAI_ZONE_NAME,
    polygon,
    is_active: true,
    created_by: admin._id,
  });

  console.log("Chennai operational zone seeded successfully");
};

const seed: Seed = {
  name: "seed-operational-zone",
  run,
};

export default seed;
