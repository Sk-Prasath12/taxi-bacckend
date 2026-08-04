require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const mongoose = require("mongoose");

const { HttpError } = require("../../src/utils/http-error");
const service = require("../../src/modules/driver-documents/driver-document.service");
const { UserModel } = require("../../src/modules/users/users.model");
const { DriverDocumentModel } = require("../../src/modules/driver-documents/driver-document.model");
const s3 = require("../../src/utils/s3");

describe("driver-document.service", () => {
  const expectHttpError = async (promise, statusCode, text) => {
    try {
      await promise;
      throw new Error("Expected failure");
    } catch (error) {
      expect(error).to.be.instanceOf(HttpError);
      expect(error.statusCode).to.equal(statusCode);
      expect(error.message).to.include(text);
    }
  };
  afterEach(() => sinon.restore());

  it("uploadDocument validates driver and uploads", async () => {
    sinon.stub(UserModel, "findById").resolves({ role: "DRIVER" });
    sinon.stub(s3, "uploadFile").resolves({ file_url: "u", file_key: "k" });
    sinon.stub(DriverDocumentModel, "create").resolves({
      toObject: () => ({
        _id: new mongoose.Types.ObjectId(),
        user_id: new mongoose.Types.ObjectId(),
        document_type: "LICENSE",
        file_url: "u",
        file_key: "k",
        status: "PENDING",
      }),
    });
    const out = await service.uploadDocument(new mongoose.Types.ObjectId().toString(), "LICENSE", {
      buffer: Buffer.from("x"),
      mimetype: "image/png",
      originalname: "a.png",
    });
    expect(out.status).to.equal("PENDING");
  });

  it("getDocumentById rejects unauthorized access", async () => {
    sinon.stub(UserModel, "findById").resolves({ role: "DRIVER" });
    sinon.stub(DriverDocumentModel, "findById").returns({ lean: async () => ({ user_id: "other" }) });
    await expectHttpError(
      service.getDocumentById(new mongoose.Types.ObjectId().toString(), new mongoose.Types.ObjectId().toString()),
      403,
      "cannot access"
    );
  });

  it("reuploadDocument enforces rejected status", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findById").resolves({ role: "DRIVER" });
    sinon.stub(DriverDocumentModel, "findById").resolves({ user_id: uid, status: "PENDING" });
    await expectHttpError(
      service.reuploadDocument(new mongoose.Types.ObjectId().toString(), uid, {
        buffer: Buffer.from("x"),
        mimetype: "image/png",
        originalname: "a.png",
      }),
      400,
      "only allowed"
    );
  });

  it("reuploadDocument skips deleteFile when file_key is missing", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    const docId = new mongoose.Types.ObjectId().toString();

    sinon.stub(UserModel, "findById").resolves({ role: "DRIVER" });

    const doc = {
      user_id: uid,
      status: "REJECTED",
      file_url: "old-url",
      file_key: undefined,
      rejection_reason: "bad",
      save: sinon.stub().resolves(),
      toObject: () => ({
        _id: new mongoose.Types.ObjectId(),
        user_id: new mongoose.Types.ObjectId(uid),
        document_type: "LICENSE",
        file_url: doc.file_url,
        file_key: doc.file_key,
        status: doc.status,
        rejection_reason: doc.rejection_reason,
      }),
    };

    sinon.stub(DriverDocumentModel, "findById").resolves(doc);
    sinon.stub(s3, "uploadFile").resolves({ file_url: "new-url", file_key: "new-key" });
    const deleteStub = sinon.stub(s3, "deleteFile").resolves();

    const out = await service.reuploadDocument(docId, uid, {
      buffer: Buffer.from("x"),
      mimetype: "image/png",
      originalname: "a.png",
    });

    expect(out.status).to.equal("PENDING");
    expect(out.file_key).to.equal("new-key");
    expect(deleteStub.called).to.equal(false);
  });

  it("admin update/final approve and validate verified", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(DriverDocumentModel, "findById").resolves({
      status: "PENDING",
      rejection_reason: null,
      save: sinon.stub().resolves(),
      toObject: () => ({
        _id: new mongoose.Types.ObjectId(),
        user_id: new mongoose.Types.ObjectId(uid),
        document_type: "LICENSE",
        file_url: "u",
        file_key: "k",
        status: "APPROVED",
      }),
    });
    const doc = await service.adminUpdateDocumentStatus(new mongoose.Types.ObjectId().toString(), "APPROVED");
    expect(doc.status).to.equal("APPROVED");

    const driver = {
      _id: uid,
      role: "DRIVER",
      is_driver_verified: false,
      driver_verification_status: "PENDING",
      save: sinon.stub().resolves(),
    };
    sinon.stub(UserModel, "findById").onFirstCall().resolves(driver).onSecondCall().returns({ lean: async () => driver });
    sinon.stub(DriverDocumentModel, "find").returns({
      lean: async () => [{ status: "APPROVED", document_type: "LICENSE" }],
    });
    const out = await service.adminFinalApproveDriver(uid);
    expect(out.driver_verification_status).to.equal("APPROVED");

    await service.validateDriverVerified(uid);
  });

  it("stream download and admin list branches", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findById").onFirstCall().resolves({ role: "DRIVER" }).onSecondCall().returns({
      lean: async () => ({ role: "DRIVER" }),
    });
    sinon.stub(DriverDocumentModel, "findById")
      .onFirstCall()
      .returns({
        lean: async () => ({
          _id: new mongoose.Types.ObjectId(),
          user_id: uid,
          document_type: "LICENSE",
          file_url: "u",
          file_key: "folder/doc.pdf",
          status: "APPROVED",
        }),
      })
      .onSecondCall()
      .returns({
        lean: async () => ({
          file_key: "admin/file.pdf",
        }),
      });
    sinon.stub(s3, "getObjectForDownload").resolves({
      body: {},
      contentType: "application/pdf",
      contentLength: 10,
    });
    let out = await service.streamDriverDocumentForDownload(new mongoose.Types.ObjectId().toString(), uid);
    expect(out.filename).to.equal("doc.pdf");
    out = await service.streamAdminDocumentForDownload(new mongoose.Types.ObjectId().toString());
    expect(out.filename).to.equal("file.pdf");

    sinon.stub(UserModel, "find").returns({
      select: () => ({
        sort: () => ({
          lean: async () => [],
        }),
      }),
    });
    const list = await service.adminGetDriversForVerification();
    expect(list).to.deep.equal([]);
  });

  it("adminGetDriversForVerification uses 0 fallback when count is missing", async () => {
    const id1 = new mongoose.Types.ObjectId().toString();
    const id2 = new mongoose.Types.ObjectId().toString();

    sinon.stub(UserModel, "find").returns({
      select: () => ({
        sort: () => ({
          lean: async () => [
            { _id: new mongoose.Types.ObjectId(id1), name: "D1", email: "d1@x.com", phone: null, driver_verification_status: "PENDING" },
            { _id: new mongoose.Types.ObjectId(id2), name: "D2", email: "d2@x.com", phone: "999", driver_verification_status: "PENDING" },
          ],
        }),
      }),
    });

    sinon.stub(DriverDocumentModel, "aggregate").resolves([
      { _id: new mongoose.Types.ObjectId(id1), count: 3 },
    ]);

    const out = await service.adminGetDriversForVerification();
    const d2 = out.find((d) => d.id === id2);
    expect(d2.documents_uploaded_count).to.equal(0);
  });

  it("admin final approve fails for missing or non-approved docs", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    const driver = {
      _id: uid,
      role: "DRIVER",
      is_driver_verified: false,
      driver_verification_status: "PENDING",
      save: sinon.stub().resolves(),
    };
    sinon.stub(UserModel, "findById").resolves(driver);
    sinon.stub(DriverDocumentModel, "find").returns({ lean: async () => [] });
    await expectHttpError(service.adminFinalApproveDriver(uid), 400, "at least one uploaded");

    sinon.restore();
    sinon.stub(UserModel, "findById").resolves(driver);
    sinon.stub(DriverDocumentModel, "find").returns({
      lean: async () => [{ status: "REJECTED", document_type: "LICENSE" }],
    });
    await expectHttpError(service.adminFinalApproveDriver(uid), 400, "must be APPROVED");
  });

  it("validateDriverVerified error branches", async () => {
    sinon.stub(UserModel, "findById").returns({ lean: async () => null });
    await expectHttpError(service.validateDriverVerified(new mongoose.Types.ObjectId().toString()), 404, "User not found");

    sinon.restore();
    sinon.stub(UserModel, "findById").returns({ lean: async () => ({ role: "CUSTOMER" }) });
    await expectHttpError(service.validateDriverVerified(new mongoose.Types.ObjectId().toString()), 403, "Not a driver");

    sinon.restore();
    sinon.stub(UserModel, "findById").returns({
      lean: async () => ({ role: "DRIVER", is_driver_verified: false, driver_verification_status: "PENDING" }),
    });
    await expectHttpError(service.validateDriverVerified(new mongoose.Types.ObjectId().toString()), 403, "not verified");
  });

  it("adminUpdateDocumentStatus validates not-found and rejection reason", async () => {
    sinon.stub(DriverDocumentModel, "findById").onFirstCall().resolves(null).onSecondCall().resolves({
      status: "PENDING",
      toObject: () => ({
        _id: new mongoose.Types.ObjectId(),
        user_id: new mongoose.Types.ObjectId(),
        document_type: "IDENTITY",
        file_url: "x",
        file_key: "k",
        status: "PENDING",
      }),
      save: sinon.stub().resolves(),
    });

    await expectHttpError(service.adminUpdateDocumentStatus(new mongoose.Types.ObjectId().toString(), "APPROVED"), 404, "Document not found");
    await expectHttpError(
      service.adminUpdateDocumentStatus(new mongoose.Types.ObjectId().toString(), "REJECTED", "   "),
      400,
      "Rejection reason is required"
    );
  });

  it("adminFinalApproveDriver rejects non-driver account", async () => {
    sinon.stub(UserModel, "findById").resolves({
      _id: new mongoose.Types.ObjectId(),
      role: "CUSTOMER",
      save: sinon.stub().resolves(),
    });
    await expectHttpError(service.adminFinalApproveDriver(new mongoose.Types.ObjectId().toString()), 400, "not a driver");
  });

  it("adminFinalApproveDriver throws 404 when driver not found", async () => {
    sinon.stub(UserModel, "findById").resolves(null);
    await expectHttpError(
      service.adminFinalApproveDriver(new mongoose.Types.ObjectId().toString()),
      404,
      "Driver not found"
    );
  });

  it("covers getDriverDocuments, not-found and key-missing stream branches", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findById")
      .onFirstCall()
      .resolves({ role: "DRIVER" })
      .onSecondCall()
      .resolves({ role: "DRIVER" })
      .onThirdCall()
      .resolves({ role: "DRIVER" });
    sinon.stub(DriverDocumentModel, "find")
      .onFirstCall()
      .returns({
        sort: () => ({
          lean: async () => [{
            _id: new mongoose.Types.ObjectId(),
            user_id: new mongoose.Types.ObjectId(uid),
            document_type: "IDENTITY",
            file_url: "u",
            file_key: "k",
            status: "PENDING",
          }],
        }),
      })
      .onSecondCall()
      .returns({ lean: async () => [] });
    sinon.stub(DriverDocumentModel, "findById")
      .onFirstCall()
      .returns({ lean: async () => null })
      .onSecondCall()
      .returns({
        lean: async () => ({
          _id: new mongoose.Types.ObjectId(),
          user_id: uid,
          document_type: "IDENTITY",
          file_url: "u",
          file_key: "   ",
          status: "APPROVED",
        }),
      });

    const docs = await service.getDriverDocuments(uid);
    expect(docs).to.have.lengthOf(1);
    await expectHttpError(service.getDocumentById(new mongoose.Types.ObjectId().toString(), uid), 404, "Document not found");
    await expectHttpError(service.streamDriverDocumentForDownload(new mongoose.Types.ObjectId().toString(), uid), 404, "file not found");
  });

  it("covers reupload not-found/ownership and streamAdmin not-found/key-missing", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findById").resolves({ role: "DRIVER" });
    sinon.stub(DriverDocumentModel, "findById")
      .onFirstCall()
      .resolves(null)
      .onSecondCall()
      .resolves({ user_id: "other", status: "REJECTED" })
      .onThirdCall()
      .returns({ lean: async () => null })
      .onCall(3)
      .returns({ lean: async () => ({ file_key: " " }) });

    await expectHttpError(
      service.reuploadDocument(new mongoose.Types.ObjectId().toString(), uid, {
        buffer: Buffer.from("x"),
        mimetype: "image/png",
        originalname: "a.png",
      }),
      404,
      "Document not found"
    );
    await expectHttpError(
      service.reuploadDocument(new mongoose.Types.ObjectId().toString(), uid, {
        buffer: Buffer.from("x"),
        mimetype: "image/png",
        originalname: "a.png",
      }),
      403,
      "cannot modify"
    );
    await expectHttpError(service.streamAdminDocumentForDownload(new mongoose.Types.ObjectId().toString()), 404, "Document not found");
    await expectHttpError(service.streamAdminDocumentForDownload(new mongoose.Types.ObjectId().toString()), 404, "file not found");
  });

  it("covers adminGetDriverDocuments mapping branch", async () => {
    const uid = new mongoose.Types.ObjectId().toString();
    sinon.stub(UserModel, "findById").returns({ lean: async () => ({ role: "DRIVER" }) });
    sinon.stub(DriverDocumentModel, "find").returns({
      sort: () => ({
        lean: async () => [{
          _id: new mongoose.Types.ObjectId(),
          user_id: new mongoose.Types.ObjectId(uid),
          document_type: "BANK",
          file_url: "url",
          file_key: "key",
          status: "APPROVED",
          rejection_reason: null,
        }],
      }),
    });
    const out = await service.adminGetDriverDocuments(uid);
    expect(out[0].document_type).to.equal("BANK");
  });

  it("covers adminGetDriverDocuments driver-not-found/non-driver branches", async () => {
    sinon.stub(UserModel, "findById")
      .onFirstCall()
      .returns({ lean: async () => null })
      .onSecondCall()
      .returns({ lean: async () => ({ role: "CUSTOMER" }) });
    await expectHttpError(service.adminGetDriverDocuments(new mongoose.Types.ObjectId().toString()), 404, "Driver not found");
    await expectHttpError(service.adminGetDriverDocuments(new mongoose.Types.ObjectId().toString()), 400, "not a driver");
  });
});
