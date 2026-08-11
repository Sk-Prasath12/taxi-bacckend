import fs from "fs";
import path from "path";
import admin from "firebase-admin";

const serviceAccountPath = [
    path.resolve(process.cwd(), "src/config/firebase-service.json"),
    path.resolve(process.cwd(), "taxi-backend-main/src/config/firebase-service.json"),
  ].find((candidate) => fs.existsSync(candidate));

if (!serviceAccountPath) {
  throw new Error(
    "firebase-service.json not found under src/config or taxi-backend-main/src/config",
  );
}

const serviceAccount = JSON.parse(
  fs.readFileSync(serviceAccountPath, "utf-8")
) as admin.ServiceAccount;

try {
  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
    });

    console.log("🔥 Firebase initialized successfully");
  }
} catch (error) {
  console.error("❌ Firebase init failed:", error);
}

export default admin;
