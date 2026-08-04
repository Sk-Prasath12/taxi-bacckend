import { findUserByEmail } from "../src/modules/users/users.repository";
import { OperationalZoneModel } from "../src/modules/operational-zone/operational-zone.model";
import { Seed } from "./seed.types";

const ADMIN_EMAIL = "admin@taxigo.com";
const CHENNAI_ZONE_NAME = "Chennai Metro";

/** Covers Sholinganallur, Tambaram, Velachery, and surrounding areas. Format: [lng, lat]. */
const CHENNAI_POLYGON: [number, number][] = [
  [80.0, 12.85],
  [80.35, 12.85],
  [80.35, 13.05],
  [80.0, 13.05],
  [80.0, 12.85],
];

const run = async (): Promise<void> => {
  const existing = await OperationalZoneModel.findOne({ zone_name: CHENNAI_ZONE_NAME });
  if (existing) {
    if (!existing.is_active) {
      existing.is_active = true;
      await existing.save();
      console.log("Chennai operational zone re-activated");
    } else {
      console.log("Chennai operational zone already exists");
    }
    return;
  }

  const admin = await findUserByEmail(ADMIN_EMAIL);
  if (!admin) {
    console.warn("Admin user not found — run seed-admin first. Skipping operational zone seed.");
    return;
  }

  await OperationalZoneModel.create({
    zone_name: CHENNAI_ZONE_NAME,
    polygon: {
      type: "Polygon",
      coordinates: [CHENNAI_POLYGON],
    },
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
