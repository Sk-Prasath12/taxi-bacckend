require("ts-node/register/transpile-only");
const { expect } = require("chai");
const sinon = require("sinon");
const { Readable } = require("stream");

const docController = require("../../src/modules/driver-documents/driver-document.controller");
const docService = require("../../src/modules/driver-documents/driver-document.service");
const docUpload = require("../../src/modules/driver-documents/driver-document.upload");
const profileController = require("../../src/modules/driver-profile/driver-profile.controller");
const profileService = require("../../src/modules/driver-profile/driver-profile.service");
const { usersController } = require("../../src/modules/users/users.controller");
const usersService = require("../../src/modules/users/users.service");

const mkRes = () => {
  const res = {
    headersSent: false,
    setHeader: sinon.spy(),
    destroy: sinon.spy(),
  };
  res.status = (c) => {
    res.statusCode = c;
    return res;
  };
  res.json = (p) => {
    res.payload = p;
    return res;
  };
  res.write = () => true;
  res.end = () => {
    res.headersSent = true;
  };
  res.emit = () => true;
  res.on = () => res;
  return res;
};

describe("extra controllers", () => {
  afterEach(() => sinon.restore());

  it("driver-document controllers cover auth and success paths", async () => {
    const next = sinon.spy();
    await docController.driverListDocumentsController({}, mkRes(), next);
    expect(next.called).to.equal(true);

    sinon.stub(docUpload, "getDriverUploadedFile").returns({
      buffer: Buffer.from("x"),
      mimetype: "image/png",
      originalname: "a.png",
    });
    sinon.stub(docService, "uploadDocument").resolves({ id: "d1" });
    const res = mkRes();
    await docController.driverUploadDocumentController(
      { authUser: { userId: "u1" }, query: { document_type: "IDENTITY" } },
      res,
      next
    );
    expect(res.statusCode).to.equal(201);

    sinon.stub(docService, "adminGetDriversForVerification").resolves([]);
    await docController.adminListDriversVerificationController({}, mkRes(), next);
  });

  it("download and admin driver-doc endpoints", async () => {
    const next = sinon.spy();
    await docController.driverDownloadDocumentController({ params: { id: "d1" } }, mkRes(), next);
    expect(next.called).to.equal(true);

    sinon.stub(docService, "adminGetDriverDocuments").resolves([]);
    sinon.stub(docService, "adminUpdateDocumentStatus").resolves({ id: "x" });
    sinon.stub(docService, "adminFinalApproveDriver").resolves({ id: "u1" });
    await docController.adminListDriverDocumentsController({ params: { driverId: "u1" } }, mkRes(), next);
    await docController.adminUpdateDocumentStatusController(
      { params: { id: "d1" }, body: { status: "APPROVED" } },
      mkRes(),
      next
    );
    await docController.adminFinalApproveDriverController({ params: { driverId: "u1" } }, mkRes(), next);
  });

  it("driver-document controller error forwarding branches", async () => {
    const next = sinon.spy();
    sinon.stub(docService, "adminGetDriverDocuments").rejects(new Error("list-fail"));
    await docController.adminListDriverDocumentsController({ params: { driverId: "u1" } }, mkRes(), next);

    sinon.restore();
    const next2 = sinon.spy();
    sinon.stub(docService, "adminUpdateDocumentStatus").rejects(new Error("status-fail"));
    await docController.adminUpdateDocumentStatusController(
      { params: { id: "d1" }, body: { status: "APPROVED" } },
      mkRes(),
      next2
    );

    sinon.restore();
    const next3 = sinon.spy();
    sinon.stub(docService, "adminFinalApproveDriver").rejects(new Error("approve-fail"));
    await docController.adminFinalApproveDriverController({ params: { driverId: "u1" } }, mkRes(), next3);
    expect(next.called || next2.called || next3.called).to.equal(true);
  });

  it("driver-profile and users controllers branches", async () => {
    const next = sinon.spy();
    await profileController.getDriverProfileExtendedController({}, mkRes(), next);
    expect(next.called).to.equal(true);

    sinon.stub(profileService, "createOrUpdateProfile").resolves({ id: "p1" });
    sinon.stub(profileService, "getProfile").resolves({ id: "p1" });
    sinon.stub(profileService, "completeProfile").resolves({ id: "p1" });
    await profileController.upsertDriverProfileController({ authUser: { userId: "u1" }, body: {} }, mkRes(), next);
    await profileController.getDriverProfileExtendedController({ authUser: { userId: "u1" } }, mkRes(), next);
    await profileController.completeDriverProfileController({ authUser: { userId: "u1" } }, mkRes(), next);

    let res = mkRes();
    usersController.base({}, res);
    expect(res.statusCode).to.equal(200);
    sinon.stub(usersService, "saveFcmToken").resolves({ message: "ok" });
    res = mkRes();
    await usersController.saveFcmToken({ authUser: { userId: "u1" }, body: { fcm_token: "t" } }, res);
    expect(res.statusCode).to.equal(200);
  });

  it("driver upload/reupload missing-file and admin download error branches", async () => {
    const next = sinon.spy();
    sinon.stub(docUpload, "getDriverUploadedFile").returns(undefined);
    await docController.driverUploadDocumentController(
      { authUser: { userId: "u1" }, query: { document_type: "IDENTITY" } },
      mkRes(),
      next
    );
    await docController.driverReuploadDocumentController(
      { authUser: { userId: "u1" }, params: { id: "d1" } },
      mkRes(),
      next
    );

    sinon.restore();
    const next2 = sinon.spy();
    sinon.stub(docService, "streamAdminDocumentForDownload").rejects(new Error("download-fail"));
    await docController.adminDownloadDocumentController({ params: { id: "d1" } }, mkRes(), next2);
    expect(next.called || next2.called).to.equal(true);
  });

  it("driver get/download document success branches", async () => {
    const next = sinon.spy();
    sinon.stub(docService, "getDocumentById").resolves({ id: "d1" });
    let res = mkRes();
    await docController.driverGetDocumentController({ authUser: { userId: "u1" }, params: { id: "d1" } }, res, next);
    expect(res.statusCode).to.equal(200);

    sinon.restore();
    const next2 = sinon.spy();
    sinon.stub(docService, "streamDriverDocumentForDownload").resolves({
      stream: Readable.from(["abc"]),
      contentType: "application/pdf",
      contentLength: 3,
      filename: "a.pdf",
    });
    res = mkRes();
    await docController.driverDownloadDocumentController(
      { authUser: { userId: "u1" }, params: { id: "d1" } },
      res,
      next2
    );
    expect(res.setHeader.called).to.equal(true);
  });
});
