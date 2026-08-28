/**
 * Docker patch: Razorpay verify → wallet credit + payment_success socket.
 * Run inside taxi_app_backend after flexible-ride patch.
 */
const fs = require("fs");
const paymentPath = "/app/src/modules/payment/payment.service.ts";

if (!fs.existsSync(paymentPath)) {
  console.error("payment.service.ts not found — skip payment-wallet patch");
  process.exit(0);
}

let src = fs.readFileSync(paymentPath, "utf8");
if (src.includes("creditDriverWalletForRide")) {
  console.log("payment-wallet: already patched");
  process.exit(0);
}

// Append wallet credit hook after successful verify (adjust import paths to match container)
const hook = `
// --- payment-wallet patch ---
import { creditDriverWalletForRide } from "../driver/driver-wallet.service";
import { emitToRide, emitToDriver, emitToCustomer } from "../../socket/socket.service";

export async function afterRazorpayPaymentVerified(ride: any, paymentId: string, orderId: string) {
  if (ride.wallet_credited) return;
  const result = await creditDriverWalletForRide({ ride, paymentId, orderId });
  ride.wallet_credited = true;
  await ride.save();
  const payload = { ride_id: ride.id, amount: ride.fare, payment_id: paymentId, wallet_balance: result.walletBalance };
  emitToCustomer(String(ride.customer_id), "payment_success", payload);
  emitToRide(ride.id, "payment_success", payload);
  if (ride.driver_id) emitToDriver(String(ride.driver_id), "payment_success", payload);
  emitToDriver(String(ride.driver_id), "wallet_updated", payload);
}
`;

fs.appendFileSync(paymentPath, hook);
console.log("payment-wallet: patched payment.service.ts — rebuild required");
