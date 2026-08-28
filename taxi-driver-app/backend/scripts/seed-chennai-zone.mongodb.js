// Seeds an active operational zone for Chennai test coordinates used in customer-flow.http.
// Run:
//   docker exec -i taxi_app_mongo mongosh -u taxiadmin -p taxi123 --authenticationDatabase admin taxi_app < scripts/seed-chennai-zone.mongodb.js

const admin = db.users.findOne({ role: "ADMIN" });
if (!admin) {
  print("ERROR: No ADMIN user found. Create an admin user first.");
  quit(1);
}

const existing = db.operational_zones.findOne({ zone_name: "Chennai Test Area", is_active: true });
if (existing) {
  print("Chennai Test Area zone already active:", existing._id.str);
  quit(0);
}

const result = db.operational_zones.insertOne({
  zone_name: "Chennai Test Area",
  polygon: {
    type: "Polygon",
    coordinates: [
      [
        [80.05, 12.85],
        [80.3, 12.85],
        [80.3, 13.05],
        [80.05, 13.05],
        [80.05, 12.85]
      ]
    ]
  },
  is_active: true,
  created_by: admin._id,
  createdAt: new Date(),
  updatedAt: new Date()
});

print("Created operational zone:", result.insertedId.str);
