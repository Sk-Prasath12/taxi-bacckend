const bcrypt = require("bcryptjs");
const Driver = require("../models/Driver");
const Otp = require("../models/Otp");
const { Ride, RIDE_STATUS } = require("../models/Ride");
const { generateToken } = require("../utils/jwt");
const { generateOtp } = require("../utils/otp");
const { sendOtpEmail } = require("../utils/emailService");

const otpExpiryDate = () => {
  const minutes = Number(process.env.OTP_EXPIRY_MINUTES || 10);
  return new Date(Date.now() + minutes * 60 * 1000);
};

const validEmail = (email) => /\S+@\S+\.\S+/.test(email);

const { applyNewDriverVerificationDefaults } = require("../services/driverVerification");

const driverVerificationFields = (driver) => ({
  is_driver_verified: driver.is_driver_verified === true,
  driver_verification_status: driver.driver_verification_status || "PENDING"
});

const sendRegisterOtp = async (req, res) => {
  const { email } = req.body;
  if (!email || !validEmail(email)) {
    return res.status(400).json({ success: false, message: "Valid email is required." });
  }

  const normalizedEmail = normalizeEmail(email);
  await Otp.deleteMany({ email: normalizedEmail, purpose: "REGISTER" });
  const otp = generateOtp();
  await Otp.create({ email: normalizedEmail, purpose: "REGISTER", otp, expiresAt: otpExpiryDate() });
  await sendOtpEmail({ to: normalizedEmail, otp, purpose: "REGISTER" });

  return res.json({ success: true, message: "Registration OTP sent successfully." });
};

const verifyRegisterOtp = async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) {
    return res.status(400).json({ success: false, message: "Email and OTP are required." });
  }

  const normalizedEmail = normalizeEmail(email);
  const otpDoc = await Otp.findOne({ email: normalizedEmail, purpose: "REGISTER", otp }).sort({ createdAt: -1 });
  if (!otpDoc || otpDoc.expiresAt < new Date()) {
    return res.status(400).json({ success: false, message: "Invalid or expired OTP." });
  }

  otpDoc.verified = true;
  await otpDoc.save();

  return res.json({ success: true, message: "OTP verified successfully." });
};

const setRegisterPassword = async (req, res) => {
  const { email, password, name, phone } = req.body;
  if (!email || !password || password.length < 6) {
    return res.status(400).json({ success: false, message: "Email and strong password are required." });
  }

  const normalizedEmail = normalizeEmail(email);
  const verifiedOtp = await Otp.findOne({ email: normalizedEmail, purpose: "REGISTER", verified: true }).sort({ createdAt: -1 });
  if (!verifiedOtp) {
    return res.status(400).json({ success: false, message: "Verify OTP before setting password." });
  }

  const existing = await Driver.findOne({ email: normalizedEmail });
  if (existing) {
    existing.password = await bcrypt.hash(password, 10);
    existing.isEmailVerified = true;
    existing.name = name || existing.name || normalizedEmail.split("@")[0];
    existing.phone = phone || existing.phone || `pending-${Date.now()}`;
    await applyNewDriverVerificationDefaults(existing);
    const refreshed = await Driver.findById(existing._id);

    const token = generateToken(existing._id);
    return res.status(200).json({
      success: true,
      message: "Password set. Waiting for admin to approve your account.",
      token,
      driver: {
        id: refreshed._id,
        name: refreshed.name,
        email: refreshed.email,
        phone: refreshed.phone,
        ...driverVerificationFields(refreshed)
      }
    });
  }

  const hashedPassword = await bcrypt.hash(password, 10);
  const fallbackName = name || normalizedEmail.split("@")[0];
  let driver = await Driver.create({
    name: fallbackName,
    email: normalizedEmail,
    phone: phone || `pending-${Date.now()}`,
    password: hashedPassword,
    isEmailVerified: true,
    driver_verification_status: "PENDING",
    is_driver_verified: false
  });
  driver = (await applyNewDriverVerificationDefaults(driver)) || driver;

  const token = generateToken(driver._id);
  return res.status(201).json({
    success: true,
    message: "Account created. Admin will approve your email/password before you can go online.",
    token,
    driver: {
      id: driver._id,
      name: driver.name,
      email: driver.email,
      phone: driver.phone,
      ...driverVerificationFields(driver)
    }
  });
};

const register = async (req, res) => {
  const { name, email, phone, password, vehicleDetails } = req.body;
  if (!name || !email || !phone || !password) {
    return res.status(400).json({ success: false, message: "name, email, phone and password are required." });
  }
  if (!validEmail(email)) {
    return res.status(400).json({ success: false, message: "Invalid email format." });
  }
  if (password.length < 6) {
    return res.status(400).json({ success: false, message: "Password must be at least 6 characters." });
  }

  const existingDriver = await Driver.findOne({ $or: [{ email: email.toLowerCase() }, { phone }] });
  if (existingDriver) {
    existingDriver.name = name || existingDriver.name;
    existingDriver.email = email.toLowerCase();
    existingDriver.phone = phone || existingDriver.phone;
    existingDriver.password = await bcrypt.hash(password, 10);
    existingDriver.vehicleDetails = vehicleDetails || existingDriver.vehicleDetails || {};
    existingDriver.isEmailVerified = true;
    await existingDriver.save();

    const token = generateToken(existingDriver._id);
    return res.status(200).json({
      success: true,
      message: "Driver account updated successfully.",
      token,
      user: {
        id: existingDriver._id,
        name: existingDriver.name,
        email: existingDriver.email,
        phone: existingDriver.phone,
        vehicleDetails: existingDriver.vehicleDetails
      }
    });
  }

  const hashedPassword = await bcrypt.hash(password, 10);
  let driver = await Driver.create({
    name,
    email: email.toLowerCase(),
    phone,
    password: hashedPassword,
    vehicleDetails: vehicleDetails || {},
    isEmailVerified: true,
    driver_verification_status: "PENDING",
    is_driver_verified: false
  });
  driver = (await applyNewDriverVerificationDefaults(driver)) || driver;

  const token = generateToken(driver._id);
  return res.status(201).json({
    success: true,
    message: "Driver registered. Admin approval required before going online.",
    token,
    user: {
      id: driver._id,
      name: driver.name,
      email: driver.email,
      phone: driver.phone,
      vehicleDetails: driver.vehicleDetails,
      ...driverVerificationFields(driver)
    }
  });
};

const login = async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password) {
    return res.status(400).json({ success: false, message: "Email and password are required." });
  }

  const driver = await Driver.findOne({ email: normalizeEmail(email) });
  if (!driver) {
    return res.status(401).json({ success: false, message: "Invalid credentials." });
  }

  const isMatched = await bcrypt.compare(password, driver.password);
  if (!isMatched) {
    return res.status(401).json({ success: false, message: "Invalid credentials." });
  }

  const token = generateToken(driver._id);
  return res.json({
    success: true,
    token,
    driverId: driver._id.toString(),
    name: driver.name,
    user: {
      id: driver._id,
      name: driver.name,
      email: driver.email,
      phone: driver.phone,
      is_driver_verified: driver.is_driver_verified === true,
      driver_verification_status: driver.driver_verification_status
    },
    driver: {
      id: driver._id,
      name: driver.name,
      email: driver.email,
      phone: driver.phone,
      is_driver_verified: driver.is_driver_verified === true,
      driver_verification_status: driver.driver_verification_status
    }
  });
};

const vehicleSetupComplete = (driver) => {
  const v = driver.vehicleDetails || {};
  const model = String(v.model || "").trim();
  const plate = String(v.plateNumber || "").trim();
  return model.length >= 2 && plate.length >= 4;
};

const getProfile = async (req, res) => {
  const d = req.driver;
  if (d.is_driver_verified !== true) {
    if (!d.driver_verification_status || d.driver_verification_status === "NOT_SUBMITTED") {
      d.driver_verification_status = "PENDING";
      d.is_driver_verified = false;
      await d.save();
    }
  }
  const verified = d.is_driver_verified === true;
  const status = verified ? "APPROVED" : d.driver_verification_status || "PENDING";
  const vehicleReady = vehicleSetupComplete(d);
  return res.json({
    success: true,
    driver: {
      id: d._id.toString(),
      _id: d._id.toString(),
      driver_id: d._id.toString(),
      name: d.name,
      email: d.email,
      phone: d.phone,
      status: d.status,
      vehicleDetails: d.vehicleDetails,
      vehicle_model: d.vehicleDetails?.model || "",
      vehicle_number: d.vehicleDetails?.plateNumber || "",
      vehicle_setup_complete: vehicleReady,
      is_driver_verified: verified,
      driver_verification_status: status,
      verification_note: d.verification_note || ""
    }
  });
};

/** Mandatory first-step after login: vehicle model + plate/number. */
const updateVehicleDetails = async (req, res) => {
  const body = req.body || {};
  const model = String(body.model || body.vehicle_model || "").trim();
  const plateNumber = String(
    body.plateNumber || body.vehicle_number || body.vehicle_reg_number || body.number || ""
  ).trim();
  const type = String(body.type || body.vehicle_type || "sedan").trim();
  const color = String(body.color || "").trim();

  if (model.length < 2) {
    return res.status(400).json({ success: false, message: "Vehicle model is required." });
  }
  if (plateNumber.length < 4) {
    return res.status(400).json({ success: false, message: "Vehicle number / plate is required." });
  }

  req.driver.vehicleDetails = {
    ...(req.driver.vehicleDetails?.toObject?.() || req.driver.vehicleDetails || {}),
    model,
    plateNumber,
    type: type || "sedan",
    color: color || req.driver.vehicleDetails?.color || ""
  };
  await req.driver.save();

  return res.json({
    success: true,
    message: "Vehicle details saved.",
    vehicle_setup_complete: true,
    driver: {
      id: req.driver._id.toString(),
      vehicleDetails: req.driver.vehicleDetails,
      vehicle_model: model,
      vehicle_number: plateNumber,
      vehicle_setup_complete: true
    }
  });
};

const sendForgotOtp = async (req, res) => {
  const { email } = req.body;
  if (!email || !validEmail(email)) {
    return res.status(400).json({ success: false, message: "Valid email is required." });
  }

  const driver = await Driver.findOne({ email });
  if (!driver) {
    return res.status(404).json({ success: false, message: "Driver not found." });
  }

  await Otp.deleteMany({ email, purpose: "FORGOT_PASSWORD" });
  const otp = generateOtp();
  await Otp.create({ email, purpose: "FORGOT_PASSWORD", otp, expiresAt: otpExpiryDate() });
  await sendOtpEmail({ to: email, otp, purpose: "FORGOT_PASSWORD" });

  return res.json({ success: true, message: "Forgot password OTP sent." });
};

const verifyForgotOtp = async (req, res) => {
  const { email, otp } = req.body;
  if (!email || !otp) {
    return res.status(400).json({ success: false, message: "Email and OTP are required." });
  }

  const otpDoc = await Otp.findOne({ email, purpose: "FORGOT_PASSWORD", otp }).sort({ createdAt: -1 });
  if (!otpDoc || otpDoc.expiresAt < new Date()) {
    return res.status(400).json({ success: false, message: "Invalid or expired OTP." });
  }

  otpDoc.verified = true;
  await otpDoc.save();
  return res.json({ success: true, message: "OTP verified." });
};

const setForgotPassword = async (req, res) => {
  const { email, password } = req.body;
  if (!email || !password || password.length < 6) {
    return res.status(400).json({ success: false, message: "Email and strong password are required." });
  }

  const verifiedOtp = await Otp.findOne({ email, purpose: "FORGOT_PASSWORD", verified: true }).sort({ createdAt: -1 });
  if (!verifiedOtp) {
    return res.status(400).json({ success: false, message: "Verify OTP first." });
  }

  const driver = await Driver.findOne({ email });
  if (!driver) {
    return res.status(404).json({ success: false, message: "Driver not found." });
  }

  driver.password = await bcrypt.hash(password, 10);
  await driver.save();

  return res.json({ success: true, message: "Password reset successful." });
};

const updateDriverStatus = async (req, res) => {
  const raw = String(req.body.status || "offline").toLowerCase();
  const status = raw === "online" || raw === "busy" || raw === "offline" ? raw : null;
  if (!status) {
    return res.status(400).json({ success: false, message: "Invalid status. Use online, offline, or busy." });
  }

  if (status === "online" || status === "busy") {
    if (!vehicleSetupComplete(req.driver)) {
      return res.status(403).json({
        success: false,
        message: "Complete vehicle model and vehicle number before going online.",
        vehicle_setup_complete: false
      });
    }
    const { driverCanAcceptRides, isVerificationRequired } = require("../services/driverVerification");
    if (isVerificationRequired() && !driverCanAcceptRides(req.driver)) {
      return res.status(403).json({
        success: false,
        message:
          req.driver.driver_verification_status === "PENDING"
            ? "Waiting for admin to approve your driver account."
            : "Your driver account is not approved yet. Contact admin.",
        driver_verification_status: req.driver.driver_verification_status,
        is_driver_verified: req.driver.is_driver_verified
      });
    }
  }

  req.driver.status = status;
  await req.driver.save();
  return res.json({
    success: true,
    message: "Status updated.",
    status: req.driver.status,
    driver: {
      id: req.driver._id.toString(),
      status: req.driver.status,
      is_driver_verified: req.driver.is_driver_verified,
      driver_verification_status: req.driver.driver_verification_status
    }
  });
};

const getWallet = async (req, res) => {
  const { getDriverWalletSummary } = require("../services/walletService");
  const summary = await getDriverWalletSummary(req.driver._id);
  return res.json({
    success: true,
    data: {
      balance: summary.balance,
      pending: summary.pending,
      currency: "INR",
      transactions: summary.transactions.map((t) => ({
        id: t._id.toString(),
        rideId: t.rideId?.toString(),
        amount: t.driverEarnings,
        fare: t.amount,
        commission: t.commission,
        paymentId: t.paymentId,
        orderId: t.razorpayOrderId,
        method: t.paymentMethod,
        status: t.status,
        date: t.transactionTime
      }))
    }
  });
};

const getInvoice = async (req, res) => {
  const { rideId } = req.params;
  const ride = await Ride.findOne({ _id: rideId, driverId: req.driver._id });
  if (!ride) {
    return res.status(404).json({ success: false, message: "Ride not found." });
  }
  const tax = Number((ride.fare * 0.05).toFixed(2));
  return res.json({
    success: true,
    data: {
      rideId: ride._id.toString(),
      amount: ride.fare,
      tax,
      total: Number((ride.fare + tax).toFixed(2))
    }
  });
};

const getCashEarnings = async (req, res) => {
  const cashCompleted = await Ride.aggregate([
    {
      $match: {
        driverId: req.driver._id,
        status: RIDE_STATUS.COMPLETED,
        paymentMode: "CASH"
      }
    },
    { $group: { _id: null, total: { $sum: "$fare" } } }
  ]);
  return res.json({
    success: true,
    data: { totalCashEarnings: Number((cashCompleted[0]?.total || 0).toFixed(2)) }
  });
};

const getTotalEarnings = async (req, res) => {
  const totals = await Ride.aggregate([
    {
      $match: {
        driverId: req.driver._id,
        status: RIDE_STATUS.COMPLETED
      }
    },
    { $group: { _id: null, total: { $sum: "$fare" } } }
  ]);
  return res.json({
    success: true,
    data: { totalEarnings: Number((totals[0]?.total || 0).toFixed(2)) }
  });
};

const withdraw = async (req, res) => {
  const amount = Number(req.body.amount || 0);
  if (!amount || amount <= 0) {
    return res.status(400).json({ success: false, message: "Valid withdrawal amount is required." });
  }
  return res.json({
    success: true,
    message: "Withdrawal request submitted.",
    data: { amount }
  });
};

module.exports = {
  sendRegisterOtp,
  verifyRegisterOtp,
  setRegisterPassword,
  register,
  login,
  getProfile,
  updateVehicleDetails,
  sendForgotOtp,
  verifyForgotOtp,
  setForgotPassword,
  updateDriverStatus,
  getWallet,
  getInvoice,
  getCashEarnings,
  getTotalEarnings,
  withdraw
};
