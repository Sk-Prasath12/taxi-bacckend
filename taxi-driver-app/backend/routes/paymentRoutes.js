const express = require("express");
const { requireCustomerAuth } = require("../middleware/customerAuthMiddleware");
const { createOrder, verify } = require("../controllers/paymentController");

const router = express.Router();

router.post("/create-order", requireCustomerAuth, createOrder);
router.post("/verify", requireCustomerAuth, verify);

module.exports = router;
