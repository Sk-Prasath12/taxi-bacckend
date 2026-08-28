const jwt = require("jsonwebtoken");

const getJwtSecret = () =>
  process.env.JWT_SECRET ||
  process.env.JWT_ACCESS_SECRET ||
  process.env.JWT_REFRESH_SECRET;

const generateToken = (driverId) => {
  const secret = getJwtSecret();
  if (!secret) {
    throw new Error("JWT_SECRET is missing in environment variables.");
  }

  const expiresIn =
    process.env.JWT_EXPIRES_IN ||
    process.env.JWT_ACCESS_EXPIRES_IN ||
    "7d";

  return jwt.sign({ driverId }, secret, { expiresIn });
};

module.exports = { generateToken, getJwtSecret };
