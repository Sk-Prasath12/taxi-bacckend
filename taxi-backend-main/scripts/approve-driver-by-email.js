/**
 * Approve a driver for incoming rides (dev helper).
 * Usage: node scripts/approve-driver-by-email.js sridharshini@yopmail.com
 */
require("dotenv").config({ path: ".env.local" });
require("dotenv").config();
const mongoose = require("mongoose");

const email = (process.argv[2] || "").toLowerCase().trim();
if (!email) {
  console.error("Usage: node scripts/approve-driver-by-email.js <driver-email>");
  process.exit(1);
}

const userSchema = new mongoose.Schema({}, { strict: false, collection: "users" });
const User = mongoose.model("User", userSchema);

async function main() {
  const uri =
    process.env.MONGO_URI ||
    process.env.MONGODB_URI ||
    process.env.DATABASE_URL;
  if (!uri) {
    console.error("Set MONGO_URI in .env.local");
    process.exit(1);
  }
  await mongoose.connect(uri);
  const driver = await User.findOneAndUpdate(
    { email, role: "DRIVER" },
    {
      $set: {
        is_driver_verified: true,
        driver_verification_status: "APPROVED",
        driver_status: "ONLINE",
        is_active: true,
      },
    },
    { new: true }
  );
  if (!driver) {
    console.error("Driver not found:", email);
    process.exit(1);
  }
  console.log("Approved driver:", driver.email, driver._id.toString());
  await mongoose.disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
