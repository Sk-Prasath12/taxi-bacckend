import admin from "../../config/firebase";
import { logger } from "../../config/logger";

type PushData = {
  ride_id?: string;
  type?: string;
  status?: string;
};

const toStringMap = (data?: PushData): Record<string, string> => {
  const entries = Object.entries(data ?? {}).filter(
    ([, value]) => value !== undefined && value !== null && String(value).trim() !== ""
  );
  return Object.fromEntries(entries.map(([key, value]) => [key, String(value)]));
};

export const sendPushNotification = async (
  token: string | undefined,
  title: string,
  body: string,
  data?: PushData
): Promise<void> => {
  if (!token || token.trim() === "") {
    return;
  }

  try {
    await admin.messaging().send({
      token,
      notification: { title, body },
      data: toStringMap(data),
    });
  } catch (error) {
    logger.error({ error }, "Failed to send push notification");
  }
};
