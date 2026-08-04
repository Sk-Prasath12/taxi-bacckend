require("ts-node/register/transpile-only");
const { expect } = require("chai");
const jwt = require("jsonwebtoken");

const {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
} = require("../../src/utils/jwt.util");

describe("jwt.util", () => {
  it("generates and verifies access token", () => {
    const token = generateAccessToken("user-1", "ADMIN");
    const payload = verifyAccessToken(token);

    expect(payload.sub).to.equal("user-1");
    expect(payload.role).to.equal("ADMIN");
    expect(payload.type).to.equal("access");
  });

  it("generates and verifies refresh token", () => {
    const token = generateRefreshToken("user-2", "CUSTOMER");
    const payload = verifyRefreshToken(token);

    expect(payload.sub).to.equal("user-2");
    expect(payload.role).to.equal("CUSTOMER");
    expect(payload.type).to.equal("refresh");
  });

  it("throws for malformed token", () => {
    expect(() => verifyAccessToken("bad-token")).to.throw(jwt.JsonWebTokenError);
  });
});
