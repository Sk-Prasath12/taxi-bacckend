require("dotenv").config();
const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const { connectDatabase } = require("./config/db");
const { setSocketServer, setDriverModel } = require("./utils/socket");
const Driver = require("./models/Driver");
const { registerSocketServer } = require("./sockets");

const PORT = Number(process.env.PORT || 3000);

const bootstrap = async () => {
  const mongoUri = process.env.MONGODB_URI || process.env.MONGO_URI;
  if (mongoUri || process.env.RIDE_STORE === "mongo") {
    await connectDatabase();
  } else {
    // eslint-disable-next-line no-console
    console.warn("MongoDB not configured — auth and rides will fail. Set MONGO_URI in .env");
  }

  const server = http.createServer(app);
  const io = new Server(server, {
    cors: { origin: "*" }
  });

  setSocketServer(io);
  setDriverModel(Driver);
  registerSocketServer(io);

  server.listen(PORT, () => {
    // eslint-disable-next-line no-console
    console.log(`Taxi backend running on port ${PORT}`);
  });
};

bootstrap().catch((error) => {
  // eslint-disable-next-line no-console
  console.error("Failed to start backend:", error);
  process.exit(1);
});
