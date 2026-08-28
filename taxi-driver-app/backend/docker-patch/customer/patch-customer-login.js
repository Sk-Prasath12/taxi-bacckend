const fs = require('fs');
const p = '/app/src/modules/customer/customer.service.ts';
let s = fs.readFileSync(p, 'utf8');

function patchBlock(label, marker, insertAfter) {
  const idx = s.indexOf(marker);
  if (idx === -1) {
    console.error(`${label}: marker not found`);
    return false;
  }
  if (s.includes(insertAfter.trim())) {
    console.log(`${label}: already patched`);
    return true;
  }
  s = s.slice(0, idx) + insertAfter + s.slice(idx);
  console.log(`${label}: patched`);
  return true;
}

patchBlock(
  'login',
  '  const token = generateAccessToken(customer.id, "CUSTOMER");\n  logger.info(\n    { customer_id: customer.id, email: customer.email },\n    "Customer login successful"',
  '  const refreshToken = generateRefreshToken(customer.id, "CUSTOMER");\n',
);

patchBlock(
  'register set-password',
  '  const token = generateAccessToken(customer.id, "CUSTOMER");\n  logger.info(\n    { customer_id: customer.id, email: customer.email },\n    "Customer registered successfully"',
  '  const refreshToken = generateRefreshToken(customer.id, "CUSTOMER");\n',
);

s = s.replace(
  /return \{\n    token,\n    user: \{\n      id: customer\.id,\n      name: customer\.name,\n      email: customer\.email,\n      phone: customer\.phone \?\? null,\n      role: "customer",\n      is_blocked: customer\.is_blocked,/g,
  'return {\n    token,\n    refreshToken,\n    user: {\n      id: customer.id,\n      name: customer.name,\n      email: customer.email,\n      phone: customer.phone ?? null,\n      role: "customer",\n      is_blocked: customer.is_blocked,',
);

s = s.replace(
  /return \{\n    token,\n    user: \{\n      id: customer\.id,\n      name: customer\.name,\n      email: customer\.email,\n      phone: customer\.phone \?\? null,\n      role: "customer",\n    \},\n  \};\n\};\n\nexport const loginCustomer/g,
  'return {\n    token,\n    refreshToken,\n    user: {\n      id: customer.id,\n      name: customer.name,\n      email: customer.email,\n      phone: customer.phone ?? null,\n      role: "customer",\n    },\n  };\n};\n\nexport const loginCustomer',
);

fs.writeFileSync(p, s);
