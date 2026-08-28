/**
 * Approve driver by full email OR login id (e.g. kiruba12 matches kiruba12@yopmail.com).
 * Usage: node scripts/approve-driver-by-email.js kiruba12
 */
require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const mongoose = require("mongoose");
const Driver = require("../models/Driver");
const { notifyDriverApproved } = require("../services/driverVerification");

const loginOrEmail = process.argv[2];
if (!loginOrEmail) {
  console.error("Usage: node scripts/approve-driver-by-email.js <email-or-login-id>");
  process.exit(1);
}

const uri = process.env.MONGODB_URI || process.env.MONGO_URI;
if (!uri) {
  console.error("Set MONGODB_URI in .env");
  process.exit(1);
}

const escaped = loginOrEmail.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");

mongoose
  .connect(uri)
  .then(async () => {
    const driver = await Driver.findOne({
      $or: [
        { email: loginOrEmail.toLowerCase().trim() },
        { email: new RegExp(escaped, "i") },
        { name: new RegExp(`^${escaped}$`, "i") },
        { phone: new RegExp(escaped, "i") }
      ]
    });

    if (!driver) {
      console.error("Driver not found for:", loginOrEmail);
      process.exit(1);
    }

    driver.is_driver_verified = true;
    driver.driver_verification_status = "APPROVED";
    driver.verification_note = "Approved via approve-driver-by-email script";
    await driver.save();
    notifyDriverApproved(driver);

    console.log("Approved driver:");
    console.log("  driver_id:", driver._id.toString());
    console.log("  name:", driver.name);
    console.log("  email:", driver.email);
    console.log("  status:", driver.driver_verification_status);
    process.exit(0);
  })
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
