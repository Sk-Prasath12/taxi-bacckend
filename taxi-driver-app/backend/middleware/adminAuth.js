const requireAdminKey = (req, res, next) => {
  const expected = process.env.ADMIN_API_KEY || "dev-admin-key";
  const provided = req.headers["x-admin-key"] || req.headers["x-admin-api-key"];
  if (!provided || provided !== expected) {
    return res.status(401).json({ success: false, message: "Admin access denied." });
  }
  return next();
};

module.exports = { requireAdminKey };
