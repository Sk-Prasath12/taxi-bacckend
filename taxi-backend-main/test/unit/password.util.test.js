require("ts-node/register/transpile-only");
const { expect } = require("chai");
const { hashPassword, comparePassword } = require("../../src/utils/password.util");

describe("password.util", () => {
  it("hashes and compares valid password", async () => {
    const hashed = await hashPassword("Secur3Pass!");

    expect(hashed).to.be.a("string");
    expect(hashed).to.not.equal("Secur3Pass!");
    expect(await comparePassword("Secur3Pass!", hashed)).to.equal(true);
  });

  it("returns false for invalid password compare", async () => {
    const hashed = await hashPassword("RightPassword");
    const valid = await comparePassword("WrongPassword", hashed);
    expect(valid).to.equal(false);
  });

  it("handles boundary empty string password", async () => {
    const hashed = await hashPassword("");
    expect(await comparePassword("", hashed)).to.equal(true);
    expect(await comparePassword("x", hashed)).to.equal(false);
  });
});
