const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    userType: { type: String, enum: ["customer", "driver"], required: true },
    userId: { type: String, required: true, index: true },
    title: { type: String, required: true },
    message: { type: String, required: true },
    read: { type: Boolean, default: false }
  },
  { timestamps: true }
);

module.exports = mongoose.model("Notification", notificationSchema);
