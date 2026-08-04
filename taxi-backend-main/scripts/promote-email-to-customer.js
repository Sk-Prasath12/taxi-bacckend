/**
 * Set a user's role to CUSTOMER (for testing the customer app with an existing email).
 * Usage: node scripts/promote-email-to-customer.js user@example.com
 */
const mongoose = require("mongoose");

const email = (process.argv[2] || "").trim().toLowerCase();
if (!email) {
  console.error("Usage: node scripts/promote-email-to-customer.js <email>");
  process.exit(1);
}

const MONGO_URI =
  process.env.MONGO_URI ||
  "mongodb://taxiadmin:taxi123@127.0.0.1:27018/taxi_app?authSource=admin";

async function main() {
  await mongoose.connect(MONGO_URI);
  const col = mongoose.connection.db.collection("users");
  const result = await col.updateOne(
    { email },
    { $set: { role: "CUSTOMER", is_active: true } }
  );
  if (result.matchedCount === 0) {
    console.error(`No user found for ${email}`);
    process.exit(1);
  }
  console.log(`Updated ${email} -> role CUSTOMER (${result.modifiedCount} modified)`);
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
