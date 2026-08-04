/**
 * Removes duplicate user rows for the same email when a CUSTOMER account exists.
 * Run: node scripts/fix-duplicate-customer-emails.js
 */
const mongoose = require("mongoose");

const MONGO_URI =
  process.env.MONGO_URI ||
  "mongodb://taxiadmin:taxi123@127.0.0.1:27018/taxi_app?authSource=admin";

async function main() {
  await mongoose.connect(MONGO_URI);
  const col = mongoose.connection.db.collection("users");

  const dupes = await col
    .aggregate([
      { $group: { _id: "$email", count: { $sum: 1 }, roles: { $push: "$role" } } },
      { $match: { count: { $gt: 1 } } },
    ])
    .toArray();

  console.log(`Found ${dupes.length} duplicate email(s)`);

  for (const d of dupes) {
    const users = await col.find({ email: d._id }).toArray();
    const customer = users.find((u) => u.role === "CUSTOMER");
    if (!customer) {
      console.log(`Skip ${d._id} — no CUSTOMER row (${d.roles.join(", ")})`);
      continue;
    }
    const toDelete = users.filter((u) => u.role !== "CUSTOMER").map((u) => u._id);
    if (toDelete.length === 0) continue;
    const result = await col.deleteMany({ _id: { $in: toDelete } });
    console.log(`Fixed ${d._id}: removed ${result.deletedCount} non-customer duplicate(s)`);
  }

  await mongoose.disconnect();
  console.log("Done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
