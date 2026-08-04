require("ts-node/register/transpile-only");
const { expect } = require("chai");

const {
  registerEmailSchema,
  verifyOtpSchema,
  updateCustomerProfileSchema,
} = require("../../src/modules/customer/customer.validator");

describe("customer.validator schemas", () => {
  it("registerEmailSchema parses valid payload and rejects invalid email/phone/name", () => {
    const ok = registerEmailSchema.safeParse({
      body: { name: "An", email: "a@example.com", phone: "1234567" },
      params: {},
      query: {},
    });
    expect(ok.success).to.equal(true);

    const bad = registerEmailSchema.safeParse({
      body: { name: "A", email: "not-email", phone: "12" },
      params: {},
      query: {},
    });
    expect(bad.success).to.equal(false);
    expect(bad.error.issues[0].message).to.be.a("string");
  });

  it("verifyOtpSchema rejects non 6-digit OTP and parses valid OTP", () => {
    const ok = verifyOtpSchema.safeParse({
      body: { email: "a@example.com", otp: "123456" },
      params: {},
      query: {},
    });
    expect(ok.success).to.equal(true);

    const bad = verifyOtpSchema.safeParse({
      body: { email: "a@example.com", otp: "12ab" },
      params: {},
      query: {},
    });
    expect(bad.success).to.equal(false);
    expect(bad.error.issues[0].message).to.include("OTP");
  });

  it("updateCustomerProfileSchema refine requires at least one field", () => {
    const bad = updateCustomerProfileSchema.safeParse({
      body: {},
      params: {},
      query: {},
    });
    expect(bad.success).to.equal(false);
    const messages = bad.error.issues.map((i) => i.message).join(" | ");
    expect(messages).to.include("At least one field");

    const ok = updateCustomerProfileSchema.safeParse({
      body: { name: "Alice" },
      params: {},
      query: {},
    });
    expect(ok.success).to.equal(true);
  });
});

