require("dotenv").config({ path: require("path").join(__dirname, "..", ".env") });
const mongoose = require("mongoose");
const Driver = require("../models/Driver");

const q = process.argv[2] || "";
mongoose.connect(process.env.MONGODB_URI || process.env.MONGO_URI).then(async () => {
  const filter = q
    ? {
        $or: [
          { email: new RegExp(q, "i") },
          { name: new RegExp(q, "i") },
          { phone: new RegExp(q, "i") }
        ]
      }
    : {};
  const drivers = await Driver.find(filter)
    .select("name email phone is_driver_verified driver_verification_status")
    .limit(20);
  console.log(JSON.stringify(drivers, null, 2));
  process.exit(0);
});
