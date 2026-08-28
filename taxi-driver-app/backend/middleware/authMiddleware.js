const jwt = require("jsonwebtoken");
const Driver = require("../models/Driver");

const requireAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;

    if (!token) {
      return res.status(401).json({ success: false, message: "Unauthorized. Missing token." });
    }

    const secret =
      process.env.JWT_SECRET ||
      process.env.JWT_ACCESS_SECRET ||
      process.env.JWT_REFRESH_SECRET;
    if (!secret) {
      return res.status(500).json({ success: false, message: "JWT secret not configured." });
    }

    const payload = jwt.verify(token, secret);
    const driver = await Driver.findById(payload.driverId).select("-password");
    if (!driver) {
      return res.status(401).json({ success: false, message: "Invalid token." });
    }

    req.driver = driver;
    return next();
  } catch (error) {
    return res.status(401).json({ success: false, message: "Unauthorized token." });
  }
};

module.exports = { requireAuth };
