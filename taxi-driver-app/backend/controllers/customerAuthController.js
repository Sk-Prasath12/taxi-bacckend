const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");
const Customer = require("../models/Customer");
const Otp = require("../models/Otp");
const { generateOtp } = require("../utils/otp");
const { sendOtpEmail } = require("../utils/emailService");

const otpExpiryDate = () => new Date(Date.now() + Number(process.env.OTP_EXPIRY_MINUTES || 10) * 60 * 1000);

const signCustomerToken = (customerId) => {
  const secret =
    process.env.JWT_SECRET ||
    process.env.JWT_ACCESS_SECRET ||
    process.env.JWT_REFRESH_SECRET;
  const expiresIn =
    process.env.JWT_EXPIRES_IN ||
    process.env.JWT_ACCESS_EXPIRES_IN ||
    "7d";
  return jwt.sign({ customerId }, secret, { expiresIn });
};

const registerEmail = async (req, res) => {
  const { name, phone, email } = req.body;
  if (!name || !phone || !email) {
    return res.status(400).json({ success: false, message: "name, phone, email are required." });
  }
  await Otp.deleteMany({ email, purpose: "CUSTOMER_REGISTER" });
  const otp = generateOtp();
  await Otp.create({ email, purpose: "CUSTOMER_REGISTER", otp, expiresAt: otpExpiryDate() });
  await sendOtpEmail({ to: email, otp, purpose: "CUSTOMER_REGISTER" });
  return res.json({ success: true, message: "OTP sent.", data: { name, phone, email } });
};

const verifyRegisterOtp = async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) {
    return res.status(400).json({ success: false, message: "email and otp are required." });
  }
  const otpDoc = await Otp.findOne({ email, purpose: "CUSTOMER_REGISTER", otp }).sort({ createdAt: -1 });
  if (!otpDoc || otpDoc.expiresAt < new Date()) {
    return res.status(400).json({ success: false, message: "Invalid or expired OTP." });
  }
  otpDoc.verified = true;
  await otpDoc.save();
  return res.json({ success: true, message: "OTP verified." });
};

const setRegisterPassword = async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password || password.length < 6) {
    return res.status(400).json({ success: false, message: "email and strong password are required." });
  }

  const verifiedOtp = await Otp.findOne({ email, purpose: "CUSTOMER_REGISTER", verified: true }).sort({ createdAt: -1 });
  if (!verifiedOtp) {
    return res.status(400).json({ success: false, message: "Verify OTP first." });
  }

  const existing = await Customer.findOne({ email: email.toLowerCase() });
  if (existing) {
    existing.password = await bcrypt.hash(password, 10);
    existing.isEmailVerified = true;
    existing.name = existing.name || email.split("@")[0];
    existing.phone = existing.phone || `pending-${Date.now()}`;
    await existing.save();

    const token = signCustomerToken(existing._id.toString());
    return res.status(200).json({ success: true, token, user: { id: existing._id, email: existing.email, name: existing.name, phone: existing.phone } });
  }

  const passwordHash = await bcrypt.hash(password, 10);
  const customer = await Customer.create({
    name: email.split("@")[0],
    phone: `pending-${Date.now()}`,
    email: email.toLowerCase(),
    password: passwordHash,
    isEmailVerified: true
  });
  const token = signCustomerToken(customer._id.toString());
  return res.status(201).json({ success: true, token, user: { id: customer._id, email: customer.email, name: customer.name, phone: customer.phone } });
};

const login = async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ success: false, message: "Email and password required." });
  }
  const customer = await Customer.findOne({ email: email.toLowerCase().trim() });
  if (!customer || !(await bcrypt.compare(password, customer.password))) {
    return res.status(401).json({ success: false, message: "Invalid credentials." });
  }
  const token = signCustomerToken(customer._id.toString());
  return res.json({
    success: true,
    token,
    user: { id: customer._id, name: customer.name, email: customer.email, phone: customer.phone }
  });
};

const profile = async (req, res) => {
  return res.json({ success: true, user: req.customer });
};

module.exports = {
  registerEmail,
  verifyRegisterOtp,
  setRegisterPassword,
  login,
  profile
};
