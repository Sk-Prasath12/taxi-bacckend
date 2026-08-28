const mongoose = require("mongoose");

const vehicleTypeSchema = new mongoose.Schema(
  {
    code: { type: String, trim: true, uppercase: true, sparse: true, unique: true },
    name: { type: String, required: true, unique: true, trim: true },
    baseFare: { type: Number, default: 0 },
    perKmFare: { type: Number, required: true, min: 0 },
    maxPassengers: { type: Number, default: 4, min: 1 },
    active: { type: Boolean, default: true },
  },
  { timestamps: true, collection: "vehicle_types" }
);

module.exports = mongoose.model("VehicleType", vehicleTypeSchema);
