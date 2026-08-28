// Seed minimal driver_profile + verification so a driver can go ONLINE (Docker TS backend).
// Usage (from project root):
//   Get-Content backend/scripts/seed-driver-profile.mongodb.js | docker exec -i taxi_app_mongo mongosh -u taxiadmin -p taxi123 --authenticationDatabase admin --quiet
//
// Replace DRIVER_EMAIL below if needed.

const DRIVER_EMAIL = "sridharshini@yopmail.com";

db = db.getSiblingDB("taxi_app");

const driver = db.users.findOne({ email: DRIVER_EMAIL, role: "DRIVER" });
if (!driver) {
  print("Driver not found for email: " + DRIVER_EMAIL);
  quit(1);
}

const userId = driver._id;

db.users.updateOne(
  { _id: userId },
  {
    $set: {
      is_driver_verified: true,
      driver_verification_status: "APPROVED",
      phone: driver.phone || "9876543210",
    },
  }
);

db.driver_profiles.updateOne(
  { user_id: userId },
  {
    $set: {
      user_id: userId,
      profile_completed: true,
      license_number: "DL1234567890",
      vehicle_model: "Swift",
      vehicle_reg_number: "TN01AB1234",
      phone: "9876543210",
      updatedAt: new Date(),
    },
    $setOnInsert: { createdAt: new Date() },
  },
  { upsert: true }
);

print("Driver ready for ONLINE: " + DRIVER_EMAIL + " (" + userId + ")");
