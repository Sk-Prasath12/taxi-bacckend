const express = require("express");
const { listVehicleTypes, listActiveVehicleTypes } = require("../controllers/vehicleTypeController");

const router = express.Router();

router.get("/", listVehicleTypes);
router.get("/active", listActiveVehicleTypes);

module.exports = router;
