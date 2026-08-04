require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const { requireRole } = require("../../src/middlewares/role.middleware");
const { HttpError } = require("../../src/utils/http-error");

describe("role.middleware requireRole", () => {
  it("fails when auth user missing", () => {
    const next = sinon.spy();
    requireRole(["ADMIN"])({}, {}, next);

    expect(next.calledOnce).to.equal(true);
    expect(next.firstCall.args[0]).to.be.instanceOf(HttpError);
    expect(next.firstCall.args[0].statusCode).to.equal(401);
  });

  it("fails when role not allowed", () => {
    const next = sinon.spy();
    const req = { authUser: { role: "CUSTOMER" } };
    requireRole(["ADMIN"])(req, {}, next);

    expect(next.firstCall.args[0].statusCode).to.equal(403);
    expect(next.firstCall.args[0].message).to.equal("Forbidden");
  });

  it("passes when role is allowed", () => {
    const next = sinon.spy();
    const req = { authUser: { role: "DRIVER" } };
    requireRole(["CUSTOMER", "DRIVER"])(req, {}, next);
    expect(next.calledWithExactly()).to.equal(true);
  });
});
