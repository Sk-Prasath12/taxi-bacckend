require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");

const { HttpError } = require("../../src/utils/http-error");
const s3util = require("../../src/utils/s3");
const { env } = require("../../src/config/env");
const { S3Client } = require("@aws-sdk/client-s3");

describe("s3 util", () => {
  afterEach(() => sinon.restore());

  it("getObjectForDownload validates empty key", async () => {
    try {
      await s3util.getObjectForDownload(" ");
      throw new Error("Expected failure");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(400);
    }
  });

  it("deleteFile no-op on empty key", async () => {
    await s3util.deleteFile("");
    expect(true).to.equal(true);
  });

  it("throws when aws config missing", async () => {
    const backup = {
      key: env.AWS_ACCESS_KEY_ID,
      secret: env.AWS_SECRET_ACCESS_KEY,
      region: env.AWS_REGION,
      bucket: env.AWS_S3_BUCKET,
      docs: env.AWS_S3_BUCKET_DOCUMENTS,
    };
    env.AWS_ACCESS_KEY_ID = "";
    env.AWS_SECRET_ACCESS_KEY = "";
    env.AWS_REGION = "";
    env.AWS_S3_BUCKET = "";
    env.AWS_S3_BUCKET_DOCUMENTS = "";
    try {
      await s3util.uploadFile({ buffer: Buffer.from("x"), mimetype: "text/plain", originalname: "a.txt" }, "docs");
      throw new Error("Expected failure");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(503);
    } finally {
      env.AWS_ACCESS_KEY_ID = backup.key;
      env.AWS_SECRET_ACCESS_KEY = backup.secret;
      env.AWS_REGION = backup.region;
      env.AWS_S3_BUCKET = backup.bucket;
      env.AWS_S3_BUCKET_DOCUMENTS = backup.docs;
    }
  });

  it("handles no body and NoSuchKey in getObjectForDownload", async () => {
    const sendStub = sinon.stub(S3Client.prototype, "send");
    sendStub.onFirstCall().resolves({});
    sendStub.onSecondCall().rejects({ name: "NoSuchKey" });
    sendStub.onThirdCall().resolves({ Body: {}, ContentType: "application/pdf", ContentLength: 10 });

    try {
      await s3util.getObjectForDownload("file-a");
      throw new Error("Expected failure");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(404);
    }

    try {
      await s3util.getObjectForDownload("file-b");
      throw new Error("Expected failure");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(404);
    }

    const ok = await s3util.getObjectForDownload("file-c");
    expect(ok.contentType).to.equal("application/pdf");
  });
});
