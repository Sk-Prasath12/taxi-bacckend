const admin = db.users.findOne({ email: "suadmintaxi@gmail.com", role: "ADMIN" });
if (!admin) {
  print("ERROR: admin not found");
  quit(1);
}

/** Greater Chennai + suburbs. Format: [lng, lat]. */
const ring = [
  [79.85, 12.70],
  [80.45, 12.70],
  [80.45, 13.25],
  [79.85, 13.25],
  [79.85, 12.70],
];

const existing = db.operational_zones.findOne({ zone_name: "Chennai Metro" });
if (existing) {
  db.operational_zones.updateOne(
    { _id: existing._id },
    { $set: { is_active: true, polygon: { type: "Polygon", coordinates: [ring] } } }
  );
  print("ZONE_UPDATED");
} else {
  db.operational_zones.insertOne({
    zone_name: "Chennai Metro",
    polygon: { type: "Polygon", coordinates: [ring] },
    is_active: true,
    created_by: admin._id,
    createdAt: new Date(),
    updatedAt: new Date(),
  });
  print("ZONE_CREATED");
}

printjson(db.operational_zones.findOne({ zone_name: "Chennai Metro" }));
