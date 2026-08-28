const express = require("express");
const { requireAdminKey } = require("../middleware/adminAuth");
const {
  listPendingDrivers,
  listApprovedDrivers,
  approveDriver,
  approveDriverByLogin,
  rejectDriver
} = require("../controllers/adminDriverController");

const router = express.Router();

router.use(requireAdminKey);

router.get("/drivers/pending", listPendingDrivers);
router.get("/drivers/approved", listApprovedDrivers);
router.post("/drivers/approve-by-login", approveDriverByLogin);
router.post("/drivers/:driverId/approve", approveDriver);
router.post("/drivers/:driverId/reject", rejectDriver);

module.exports = router;
