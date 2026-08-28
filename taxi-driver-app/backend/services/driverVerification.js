const Driver = require("../models/Driver");
const socketUtils = require("../utils/socket");

const isVerificationRequired = () => process.env.REQUIRE_DRIVER_VERIFICATION !== "false";

/** Account approved by admin (email/password signup). Documents are optional. */
const driverCanAcceptRides = (driver) => {
  if (!isVerificationRequired()) return true;
  if (driver.is_driver_verified === true) return true;
  return String(driver.driver_verification_status || "").toUpperCase() === "APPROVED";
};

async function applyNewDriverVerificationDefaults(driver) {
  if (!driver) return null;
  if (driver.is_driver_verified && driver.driver_verification_status === "APPROVED") {
    return driver;
  }

  if (process.env.AUTO_APPROVE_DRIVERS === "true") {
    driver.is_driver_verified = true;
    driver.driver_verification_status = "APPROVED";
    driver.verification_note = "Auto-approved (AUTO_APPROVE_DRIVERS)";
    await driver.save();
    notifyDriverApproved(driver);
    return driver;
  }

  driver.is_driver_verified = false;
  driver.driver_verification_status = "PENDING";
  driver.verification_note = "Awaiting admin approval of your driver account.";
  await driver.save();
  return driver;
}

/** Document uploads do not change account approval (optional KYC). */
async function syncDriverVerificationState(driverId) {
  return Driver.findById(driverId);
}

function notifyDriverApproved(driver) {
  const payload = {
    type: "driver_verification_approved",
    driver_id: driver._id.toString(),
    is_driver_verified: true,
    driver_verification_status: "APPROVED",
    message: "Your driver account was approved. You can go online and accept rides."
  };
  socketUtils.emitToDriver(driver._id.toString(), "driver:verification", payload);
  socketUtils.emitToDriver(driver._id.toString(), "notification", payload);
}

module.exports = {
  isVerificationRequired,
  driverCanAcceptRides,
  applyNewDriverVerificationDefaults,
  syncDriverVerificationState,
  notifyDriverApproved
};
