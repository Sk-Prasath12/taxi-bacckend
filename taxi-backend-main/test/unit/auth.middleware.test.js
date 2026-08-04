require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const jwt = require("jsonwebtoken");
const jwtUtil = require("../../src/utils/jwt.util");
const { HttpError } = require("../../src/utils/http-error");
const { requireAuth } = require("../../src/middlewares/auth.middleware");

describe("auth.middleware requireAuth", () => {
  let next;
  let req;

  beforeEach(() => {
    next = sinon.spy();
    req = { headers: {} };
  });

  afterEach(() => {
    sinon.restore();
  });

  it("fails when header is missing", () => {
    requireAuth(req, {}, next);
    expect(next.calledOnce).to.equal(true);
    expect(next.firstCall.args[0]).to.be.instanceOf(HttpError);
    expect(next.firstCall.args[0].statusCode).to.equal(401);
  });

  it("fails when bearer token value is undefined text", () => {
    req.headers.authorization = "Bearer undefined";
    requireAuth(req, {}, next);
    expect(next.firstCall.args[0].message).to.include("Missing access token");
  });

  it("fails when token type is not access", () => {
    sinon.stub(jwtUtil, "verifyAccessToken").returns({ sub: "u1", role: "CUSTOMER", type: "refresh" });
    req.headers.authorization = "Bearer token";
    requireAuth(req, {}, next);
    expect(next.firstCall.args[0].message).to.equal("Invalid access token");
  });

  it("sets authUser and calls next without error on success", () => {
    sinon.stub(jwtUtil, "verifyAccessToken").returns({ sub: "u1", role: "DRIVER", type: "access" });
    req.headers.authorization = "Bearer good-token";

    requireAuth(req, {}, next);

    expect(req.authUser).to.deep.equal({ userId: "u1", role: "DRIVER" });
    expect(next.calledWithExactly()).to.equal(true);
  });

  it("maps jwt errors to expected messages", () => {
    req.headers.authorization = "Bearer expired";
    sinon.stub(jwtUtil, "verifyAccessToken").throws(new jwt.TokenExpiredError("expired", new Date()));
    requireAuth(req, {}, next);
    expect(next.firstCall.args[0].message).to.include("expired");

    sinon.restore();
    next = sinon.spy();
    req.headers.authorization = "Bearer invalid";
    sinon.stub(jwtUtil, "verifyAccessToken").throws(new jwt.JsonWebTokenError("bad"));
    requireAuth(req, {}, next);
    expect(next.firstCall.args[0].message).to.include("Invalid access token");
  });
});
