import fs from "fs";
import path from "path";
import admin from "firebase-admin";

const serviceAccountPath = path.resolve(process.cwd(), "src/config/firebase-service.json");

if (!fs.existsSync(serviceAccountPath)) {
  throw new Error("firebase-service.json not found at " + serviceAccountPath);
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
