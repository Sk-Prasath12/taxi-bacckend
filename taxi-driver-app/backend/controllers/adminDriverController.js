const Driver = require("../models/Driver");
const { DriverDocument } = require("../models/DriverDocument");
const { notifyDriverApproved } = require("../services/driverVerification");

const formatDriverRow = (d, extra = {}) => ({
  driver_id: d._id.toString(),
  id: d._id.toString(),
  name: d.name,
  email: d.email,
  phone: d.phone,
  driver_verification_status: d.driver_verification_status,
  is_driver_verified: d.is_driver_verified === true,
  createdAt: d.createdAt,
  updatedAt: d.updatedAt,
  verification_note: d.verification_note || "",
  ...extra
});

const listPendingDrivers = async (req, res) => {
  const q = (req.query.q || "").toString().trim();
  const base = { is_driver_verified: { $ne: true } };
  const filter = q
    ? {
        $and: [
          base,
          {
            $or: [
              { name: new RegExp(q, "i") },
              { email: new RegExp(q, "i") },
              { phone: new RegExp(q, "i") }
            ]
          }
        ]
      }
    : base;

  const drivers = await Driver.find(filter)
    .select("name email phone driver_verification_status is_driver_verified createdAt updatedAt verification_note")
    .sort({ createdAt: -1 })
    .limit(100);

  const withDocs = await Promise.all(
    drivers.map(async (d) => {
      const docCount = await DriverDocument.countDocuments({ driver_id: d._id });
      return formatDriverRow(d, { documents_uploaded: docCount });
    })
  );

  return res.json({ success: true, data: withDocs, count: withDocs.length });
};

const listApprovedDrivers = async (req, res) => {
  const q = (req.query.q || "").toString().trim();
  const base = { is_driver_verified: true };
  const filter = q
    ? {
        $and: [
          base,
          {
            $or: [
              { name: new RegExp(q, "i") },
              { email: new RegExp(q, "i") },
              { phone: new RegExp(q, "i") }
            ]
          }
        ]
      }
    : base;

  const drivers = await Driver.find(filter)
    .select("name email phone driver_verification_status is_driver_verified createdAt updatedAt verification_note")
    .sort({ updatedAt: -1 })
    .limit(100);

  return res.json({
    success: true,
    data: drivers.map((d) => formatDriverRow(d)),
    count: drivers.length
  });
};

const approveDriver = async (req, res) => {
  const driver = await Driver.findById(req.params.driverId);
  if (!driver) {
    return res.status(404).json({ success: false, message: "Driver not found." });
  }

  driver.is_driver_verified = true;
  driver.driver_verification_status = "APPROVED";
  driver.verification_note = req.body.note || "Approved by admin";
  await driver.save();

  await DriverDocument.updateMany(
    { driver_id: driver._id, status: "PENDING" },
    { $set: { status: "APPROVED" } }
  );

  notifyDriverApproved(driver);

  return res.json({
    success: true,
    message: "Driver account approved. Documents are optional.",
    driver: formatDriverRow(driver)
  });
};

const rejectDriver = async (req, res) => {
  const driver = await Driver.findById(req.params.driverId);
  if (!driver) {
    return res.status(404).json({ success: false, message: "Driver not found." });
  }

  const reason = req.body.reason || "Documents rejected. Please re-upload.";
  driver.is_driver_verified = false;
  driver.driver_verification_status = "REJECTED";
  driver.verification_note = reason;
  await driver.save();

  await DriverDocument.updateMany(
    { driver_id: driver._id },
    { $set: { status: "REJECTED", rejection_reason: reason } }
  );

  return res.json({ success: true, message: "Driver rejected.", reason });
};

const findDriverByLoginId = async (loginId) => {
  const raw = String(loginId || "").trim();
  if (!raw) return null;
  const escaped = raw.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  return Driver.findOne({
    $or: [
      { email: raw.toLowerCase() },
      { email: new RegExp(escaped, "i") },
      { name: new RegExp(`^${escaped}$`, "i") },
      { phone: new RegExp(escaped, "i") }
    ]
  });
};

const approveDriverByLogin = async (req, res) => {
  const loginId = req.body.login_id || req.body.email || req.body.login || req.query.q;
  const driver = await findDriverByLoginId(loginId);
  if (!driver) {
    return res.status(404).json({ success: false, message: `No driver found for: ${loginId}` });
  }
  req.params.driverId = driver._id.toString();
  return approveDriver(req, res);
};

module.exports = {
  listPendingDrivers,
  listApprovedDrivers,
  approveDriver,
  approveDriverByLogin,
  rejectDriver
};
