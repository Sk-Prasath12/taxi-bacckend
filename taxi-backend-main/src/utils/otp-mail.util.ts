import nodemailer from "nodemailer";
import { env } from "../config/env";
import { logger } from "../config/logger";

const transporter = nodemailer.createTransport({
  host: env.SMTP_HOST,
  port: env.SMTP_PORT,
  secure: env.SMTP_PORT === 465,
  auth: {
    user: env.SMTP_USER,
    pass: env.SMTP_PASSWORD,
  },
  tls: {
    rejectUnauthorized: env.SMTP_TLS_REJECT_UNAUTHORIZED,
  },
  connectionTimeout: 8_000,
  greetingTimeout: 8_000,
  socketTimeout: 8_000,
});

/** Send OTP email without blocking the HTTP response (avoids Vercel/app timeouts). */
export const queueOtpEmail = (params: {
  to: string;
  subject: string;
  html: string;
  logLabel: string;
}): void => {
  void transporter
    .sendMail({
      from: env.SMTP_FROM_EMAIL,
      to: params.to,
      subject: params.subject,
      html: params.html,
    })
    .then(() => {
      logger.info({ email: params.to }, `${params.logLabel} OTP email sent`);
    })
    .catch((err) => {
      logger.warn(
        { email: params.to, err },
        `${params.logLabel} OTP email failed; OTP remains valid in the database`
      );
    });
};
