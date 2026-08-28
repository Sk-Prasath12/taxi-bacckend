const jwt = require("jsonwebtoken");
const Customer = require("../models/Customer");

const requireCustomerAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization || "";
    const token = authHeader.startsWith("Bearer ") ? authHeader.slice(7) : null;
    if (!token) {
      return res.status(401).json({ success: false, message: "Unauthorized. Missing token." });
    }

    const payload = jwt.verify(token, process.env.JWT_SECRET);
    if (!payload.customerId) {
      return res.status(403).json({ success: false, message: "Customer access only." });
    }

    const customer = await Customer.findById(payload.customerId).select("-password");
    if (!customer) {
      return res.status(401).json({ success: false, message: "Invalid token." });
    }

    req.customer = customer;
    return next();
  } catch (error) {
    return res.status(401).json({ success: false, message: "Unauthorized token." });
  }
};

module.exports = { requireCustomerAuth };
