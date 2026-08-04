require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const { z } = require("zod");

const { validate } = require("../../src/middlewares/validate.middleware");
const { HttpError } = require("../../src/utils/http-error");

describe("validate middleware", () => {
  afterEach(() => sinon.restore());

  it("calls next() when zod validation succeeds", async () => {
    const schema = z.object({
      body: z.object({ name: z.string().min(2) }),
      params: z.object({}),
      query: z.object({}),
    });

    const next = sinon.spy();
    const req = { body: { name: "Al" }, params: {}, query: {} };
    const res = {};

    const mw = validate(schema);
    mw(req, res, next);
    expect(next.calledOnce).to.equal(true);
  });

  it("passes HttpError to next() on zod validation failure", async () => {
    const schema = z.object({
      body: z.object({ name: z.string().min(2) }),
      params: z.object({}),
      query: z.object({}),
    });

    const next = sinon.spy();
    const req = { body: { name: "A" }, params: {}, query: {} };
    const res = {};

    const mw = validate(schema);
    mw(req, res, next);

    expect(next.calledOnce).to.equal(true);
    const err = next.getCall(0).args[0];
    expect(err).to.be.instanceOf(HttpError);
    expect(err.statusCode).to.equal(400);
    expect(err.message).to.be.a("string");
  });

  it("uses generic fallback message when zod issue message is empty", async () => {
    const schema = z.object({
      body: z.object({ name: z.string().min(2, "") }),
      params: z.object({}),
      query: z.object({}),
    });

    const next = sinon.spy();
    const req = { body: { name: "A" }, params: {}, query: {} };
    const res = {};

    const mw = validate(schema);
    mw(req, res, next);

    const err = next.getCall(0).args[0];
    expect(err).to.be.instanceOf(HttpError);
    expect(err.statusCode).to.equal(400);
    expect(err.message).to.equal("Validation failed");
  });
});

