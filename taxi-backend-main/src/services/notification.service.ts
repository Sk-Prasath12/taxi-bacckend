import admin from "../config/firebase";

export const sendPushNotification = async ({
  token,
  title,
  body,
  data = {},
}: {
  token: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}) => {
  try {
    const message = {
      token,
      notification: {
        title,
        body,
      },
      data,
    };

    await admin.messaging().send(message);

    console.log("✅ Push sent:", title);
  } catch (error) {
    console.error("❌ Push failed:", error);
  }
};
