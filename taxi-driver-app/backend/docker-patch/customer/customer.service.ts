// Patch: customer login returns refreshToken (apply to Docker /app/src/modules/customer/customer.service.ts)

import { generateRefreshToken } from "../../utils/jwt"; // adjust import path to match project

// In loginCustomer, replace return block with:
  const token = generateAccessToken(customer.id, "CUSTOMER");
  const refreshToken = generateRefreshToken(customer.id, "CUSTOMER");
  logger.info(
    { customer_id: customer.id, email: customer.email },
    "Customer login successful"
  );

  return {
    token,
    refreshToken,
    user: {
      id: customer.id,
      name: customer.name,
      email: customer.email,
      phone: customer.phone ?? null,
      role: "customer",
      is_blocked: customer.is_blocked,
      blocked_reason: customer.blocked_reason ?? null,
    },
  };
