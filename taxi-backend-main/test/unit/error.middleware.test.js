require("ts-node/register/transpile-only");
const { expect } = require("chai");
const multer = require("multer");
const { notFoundHandler, globalErrorHandler } = require("../../src/middlewares/error.middleware");

const mockRes = () => {
  const res = {};
  res.status = (code) => {
    res.statusCode = code;
    return res;
  };
  res.json = (body) => {
    res.body = body;
    return res;
  };
  return res;
};

describe("error middleware", () => {
  it("returns structured 404 for unknown route", () => {
    const req = { method: "GET", originalUrl: "/missing" };
    const res = mockRes();
    notFoundHandler(req, res);

    expect(res.statusCode).to.equal(404);
    expect(res.body.success).to.equal(false);
    expect(res.body.message).to.equal("Route not found");
    expect(res.body.error.path).to.equal("/missing");
  });

  it("handles multer LIMIT_UNEXPECTED_FILE", () => {
    const req = { method: "POST", originalUrl: "/upload" };
    const res = mockRes();
    const err = new multer.MulterError("LIMIT_UNEXPECTED_FILE", "avatar");
    globalErrorHandler(err, req, res, () => {});

    expect(res.statusCode).to.equal(400);
    expect(res.body.message).to.include("Unexpected form field");
  });

  it("handles multer LIMIT_FILE_SIZE", () => {
    const req = { method: "POST", originalUrl: "/upload" };
    const res = mockRes();
    const err = new multer.MulterError("LIMIT_FILE_SIZE", "file");
    globalErrorHandler(err, req, res, () => {});

    expect(res.statusCode).to.equal(400);
    expect(res.body.message).to.include("File too large");
  });

  it("handles multer default upload failed message", () => {
    const req = { method: "POST", originalUrl: "/upload" };
    const res = mockRes();
    const err = new multer.MulterError("LIMIT_PART_COUNT", "file");
    err.message = "Upload failed";
    globalErrorHandler(err, req, res, () => {});

    expect(res.statusCode).to.equal(400);
    expect(res.body.message).to.include("Upload failed");
  });

  it("handles custom 4xx errors", () => {
    const req = { method: "POST", originalUrl: "/api" };
    const res = mockRes();
    const err = new Error("Bad request");
    err.statusCode = 422;
    globalErrorHandler(err, req, res, () => {});

    expect(res.statusCode).to.equal(422);
    expect(res.body.message).to.equal("Bad request");
  });

  it("handles 5xx with generic message", () => {
    const req = { method: "GET", originalUrl: "/api" };
    const res = mockRes();
    const err = new Error("Hidden detail");
    err.statusCode = 500;
    globalErrorHandler(err, req, res, () => {});

    expect(res.statusCode).to.equal(500);
    expect(res.body.message).to.equal("Internal server error");
  });
});
