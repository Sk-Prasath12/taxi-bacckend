const express = require("express");
const { requireCustomerAuth } = require("../middleware/customerAuthMiddleware");
const { getCustomerNotifications } = require("../controllers/notificationController");

const router = express.Router();

router.get("/customers", requireCustomerAuth, getCustomerNotifications);

module.exports = router;
