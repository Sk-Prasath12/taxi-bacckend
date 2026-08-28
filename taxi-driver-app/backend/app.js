const path = require("path");
const express = require("express");
const cors = require("cors");
const driverRoutes = require("./routes/driverRoutes");
const rideRoutes = require("./routes/rideRoutes");
const customerRoutes = require("./routes/customerRoutes");
const paymentRoutes = require("./routes/paymentRoutes");
const vehicleTypeRoutes = require("./routes/vehicleTypeRoutes");
const notificationRoutes = require("./routes/notificationRoutes");
const adminRoutes = require("./routes/adminRoutes");
const { errorHandler, notFoundHandler } = require("./middleware/errorHandler");

const app = express();

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

app.get("/health", (req, res) => {
  res.json({ success: true, status: "ok" });
});
app.get("/admin/driver-approval", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "admin-driver-approval.html"));
});
app.get("/api/v1/health", (req, res) => {
  res.json({ success: true, status: "ok" });
});

app.use("/api/drivers", driverRoutes);
app.use("/api/driver", driverRoutes);
app.use("/api/v1/driver", driverRoutes);
app.use("/api/rides", rideRoutes);
app.use("/api/customers", customerRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/vehicle-types", vehicleTypeRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/admin", adminRoutes);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
