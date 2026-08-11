import fs from "fs";
import path from "path";
import admin from "firebase-admin";

function resolveServiceAccountPath(): string | undefined {
  const candidates = [
    path.resolve(__dirname, "firebase-service.json"),
    path.resolve(process.cwd(), "src/config/firebase-service.json"),
    path.resolve(process.cwd(), "taxi-backend-main/src/config/firebase-service.json"),
  ];
  return candidates.find((candidate) => fs.existsSync(candidate));
}

function loadServiceAccount(): admin.ServiceAccount | undefined {
  const fromEnv = process.env.FIREBASE_SERVICE_ACCOUNT?.trim();
  if (fromEnv) {
    try {
      return JSON.parse(fromEnv) as admin.ServiceAccount;
    } catch {
      console.error("❌ FIREBASE_SERVICE_ACCOUNT is not valid JSON");
    }
  }

  const serviceAccountPath = resolveServiceAccountPath();
  if (!serviceAccountPath) {
    return undefined;
  }

  return JSON.parse(fs.readFileSync(serviceAccountPath, "utf-8")) as admin.ServiceAccount;
}

try {
  if (!admin.apps.length) {
    const serviceAccount = loadServiceAccount();
    if (!serviceAccount) {
      console.warn(
        "⚠️ Firebase skipped: no firebase-service.json and no FIREBASE_SERVICE_ACCOUNT. REST API still works.",
      );
    } else {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      console.log("🔥 Firebase initialized successfully");
    }
  }
} catch (error) {
  console.error("❌ Firebase init failed:", error);
}

export default admin;
