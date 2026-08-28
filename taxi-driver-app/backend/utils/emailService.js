const nodemailer = require("nodemailer");

let transporter;

const getTransporter = () => {
  if (transporter) {
    return transporter;
  }

  const host = process.env.EMAIL_HOST;
  const port = Number(process.env.EMAIL_PORT || 587);
  const user = process.env.EMAIL_USER;
  const pass = process.env.EMAIL_PASS;

  if (!host || !user || !pass) {
    return null;
  }

  transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass }
  });

  return transporter;
};

const sendOtpEmail = async ({ to, otp, purpose }) => {
  const client = getTransporter();
  if (!client) {
    // Fallback to console logging for local setup without SMTP.
    // This keeps API behavior intact while avoiding crashes.
    // eslint-disable-next-line no-console
    console.log(`OTP(${purpose}) for ${to}: ${otp}`);
    return { mocked: true };
  }

  return client.sendMail({
    from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
    to,
    subject: `Your Taxi Driver OTP for ${purpose}`,
    text: `Your OTP is ${otp}. It will expire in ${process.env.OTP_EXPIRY_MINUTES || 10} minutes.`,
    html: `<p>Your OTP is <strong>${otp}</strong>.</p><p>It will expire in ${process.env.OTP_EXPIRY_MINUTES || 10} minutes.</p>`
  });
};

module.exports = { sendOtpEmail };
