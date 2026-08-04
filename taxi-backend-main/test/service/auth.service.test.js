require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const repo = require("../../src/modules/users/users.repository");
const passwordUtil = require("../../src/utils/password.util");
const jwtUtil = require("../../src/utils/jwt.util");
const { HttpError } = require("../../src/utils/http-error");
const { loginUser, refreshAccessToken } = require("../../src/modules/auth/auth.service");

describe("auth.service", () => {
  const expectHttpError = async (promise, statusCode, text) => {
    try {
      await promise;
      throw new Error("Expected promise to fail");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(statusCode);
      expect(error.message).to.include(text);
    }
  };

  afterEach(() => {
    sinon.restore();
  });

  it("loginUser returns tokens for valid credentials", async () => {
    sinon.stub(repo, "findUserByEmail").resolves({
      id: "u1",
      name: "Alice",
      email: "a@a.com",
      role: "CUSTOMER",
      is_active: true,
      is_blocked: false,
      password_hash: "hash",
      blocked_reason: null,
    });
    sinon.stub(passwordUtil, "comparePassword").resolves(true);
    sinon.stub(jwtUtil, "generateAccessToken").returns("access-token");
    sinon.stub(jwtUtil, "generateRefreshToken").returns("refresh-token");

    const out = await loginUser("a@a.com", "secret");
    expect(out.accessToken).to.equal("access-token");
    expect(out.refreshToken).to.equal("refresh-token");
    expect(out.user.email).to.equal("a@a.com");
  });

  it("loginUser rejects unknown user", async () => {
    sinon.stub(repo, "findUserByEmail").resolves(null);
    await expectHttpError(loginUser("x@y.com", "bad"), 401, "Invalid credentials");
  });

  it("loginUser rejects invalid password", async () => {
    sinon.stub(repo, "findUserByEmail").resolves({
      id: "u1",
      role: "CUSTOMER",
      is_active: true,
      password_hash: "hash",
    });
    sinon.stub(passwordUtil, "comparePassword").resolves(false);
    await expectHttpError(loginUser("x@y.com", "bad"), 401, "Invalid credentials");
  });

  it("refreshAccessToken returns new access token for valid refresh token", async () => {
    sinon.stub(jwtUtil, "verifyRefreshToken").returns({ sub: "u2", role: "DRIVER", type: "refresh" });
    sinon.stub(repo, "findUserById").resolves({ id: "u2", role: "DRIVER", is_active: true });
    sinon.stub(jwtUtil, "generateAccessToken").returns("new-access");

    const out = await refreshAccessToken("refresh");
    expect(out).to.deep.equal({ accessToken: "new-access" });
  });

  it("refreshAccessToken rejects token type mismatch", async () => {
    sinon.stub(jwtUtil, "verifyRefreshToken").returns({ sub: "u2", role: "DRIVER", type: "access" });
    await expectHttpError(refreshAccessToken("refresh"), 401, "Invalid refresh token");
  });
});
