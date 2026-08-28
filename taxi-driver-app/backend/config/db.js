const mongoose = require("mongoose");

const connectDatabase = async () => {
  const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI || "mongodb://taxiadmin:taxi123@localhost:27018/taxi_app?authSource=admin";
  if (!mongoUri) {
    throw new Error("MONGODB_URI is required in environment variables.");
  }

  await mongoose.connect(mongoUri, {
    autoIndex: true,
    serverSelectionTimeoutMS: 10000,
  });
  return mongoose.connection;
};

module.exports = { connectDatabase };
