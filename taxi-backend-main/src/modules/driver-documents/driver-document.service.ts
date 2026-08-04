import { Types } from "mongoose";
import { UserModel } from "../users/users.model";
import { HttpError } from "../../utils/http-error";
import type { Readable } from "stream";
import { deleteFile, getObjectForDownload, uploadFile, type UploadableFile } from "../../utils/s3";
import { DriverDocumentModel, type DriverDocumentType } from "./driver-document.model";
import { getIo } from "../../socket/socket";
import { sendPushNotification } from "../../services/notification.service";
import { ensureDriverReadyForOnline } from "../driver-profile/driver-profile.service";

function assertDriver(user: { role: string } | null): asserts user is NonNullable<typeof user> {
  if (!user) {
    throw new HttpError(404, "User not found");
  }
  if (user.role !== "DRIVER") {
    throw new HttpError(403, "Only drivers can perform this action");
  }
}

export type DriverDocumentView = {
  id: string;
  user_id: string;
  document_type: DriverDocumentType;
  file_url: string;
  file_key: string;
  status: string;
  rejection_reason: string | null;
};

function mapDocument(doc: {
  _id: Types.ObjectId;
  user_id: Types.ObjectId;
  document_type: DriverDocumentType;
  file_url: string;
  file_key: string;
  status: string;
  rejection_reason?: string | null;
}): DriverDocumentView {
  return {
    id: String(doc._id),
    user_id: String(doc.user_id),
    document_type: doc.document_type,
    file_url: doc.file_url,
    file_key: doc.file_key,
    status: doc.status,
    rejection_reason: doc.rejection_reason ?? null,
  };
}

export async function uploadDocument(
  userId: string,
  documentType: DriverDocumentType,
  file: UploadableFile
): Promise<DriverDocumentView> {
  const user = await UserModel.findById(userId);
  assertDriver(user);

  const existing = await DriverDocumentModel.findOne({
    user_id: new Types.ObjectId(userId),
    document_type: documentType,
    status: { $in: ["PENDING", "APPROVED"] },
  })
    .sort({ createdAt: -1 })
    .exec();

  if (existing?.status === "APPROVED") {
    return mapDocument(existing.toObject());
  }

  const folder = `driver-documents/${userId}`;
  const uploaded = await uploadFile(file, folder);

  if (existing?.status === "PENDING") {
    if (existing.file_key) {
      await deleteFile(existing.file_key).catch(() => undefined);
    }
    existing.file_url = uploaded.file_url;
    existing.file_key = uploaded.file_key;
    existing.rejection_reason = undefined;
    await existing.save();
    return mapDocument(existing.toObject());
  }

  const created = await DriverDocumentModel.create({
    user_id: new Types.ObjectId(userId),
    document_type: documentType,
    file_url: uploaded.file_url,
    file_key: uploaded.file_key,
    status: "PENDING",
  });

  await UserModel.updateOne(
    { _id: userId, role: "DRIVER" },
    { $set: { is_driver_verified: false, driver_verification_status: "PENDING" } }
  );

  return mapDocument(created.toObject());
}

export async function getDriverDocuments(userId: string): Promise<DriverDocumentView[]> {
  const user = await UserModel.findById(userId);
  assertDriver(user);

  const docs = await DriverDocumentModel.find({ user_id: new Types.ObjectId(userId) })
    .sort({ createdAt: -1 })
    .lean();

  return docs.map((doc) =>
    mapDocument({
      _id: doc._id as Types.ObjectId,
      user_id: doc.user_id as Types.ObjectId,
      document_type: doc.document_type,
      file_url: doc.file_url,
      file_key: doc.file_key,
      status: doc.status,
      rejection_reason: doc.rejection_reason,
    })
  );
}

export async function getDocumentById(docId: string, userId: string): Promise<DriverDocumentView> {
  const user = await UserModel.findById(userId);
  assertDriver(user);

  const doc = await DriverDocumentModel.findById(docId).lean();
  if (!doc) {
    throw new HttpError(404, "Document not found");
  }
  if (String(doc.user_id) !== userId) {
    throw new HttpError(403, "You cannot access this document");
  }

  return mapDocument({
    _id: doc._id as Types.ObjectId,
    user_id: doc.user_id as Types.ObjectId,
    document_type: doc.document_type,
    file_url: doc.file_url,
    file_key: doc.file_key,
    status: doc.status,
    rejection_reason: doc.rejection_reason,
  });
}

export type DocumentDownloadStream = {
  stream: Readable;
  contentType: string;
  contentLength?: number;
  filename: string;
};

function attachmentFilenameFromFileKey(fileKey: string): string {
  const base = fileKey.split("/").pop() || "document";
  const safe = base.replace(/[^\w.\-]+/g, "_");
  return safe.length > 0 ? safe : "document";
}

/** Auth + DB check, then S3 GetObject stream (private bucket safe). */
export async function streamDriverDocumentForDownload(
  docId: string,
  userId: string
): Promise<DocumentDownloadStream> {
  const doc = await getDocumentById(docId, userId);
  const key = doc.file_key?.trim();
  if (!key) {
    throw new HttpError(404, "Document file not found");
  }
  const { body, contentType, contentLength } = await getObjectForDownload(key);
  return {
    stream: body,
    contentType,
    contentLength,
    filename: attachmentFilenameFromFileKey(key),
  };
}

export async function streamAdminDocumentForDownload(docId: string): Promise<DocumentDownloadStream> {
  const doc = await DriverDocumentModel.findById(docId).lean();
  if (!doc) {
    throw new HttpError(404, "Document not found");
  }
  const key = doc.file_key?.trim();
  if (!key) {
    throw new HttpError(404, "Document file not found");
  }
  const { body, contentType, contentLength } = await getObjectForDownload(key);
  return {
    stream: body,
    contentType,
    contentLength,
    filename: attachmentFilenameFromFileKey(key),
  };
}

export async function reuploadDocument(
  docId: string,
  userId: string,
  file: UploadableFile
): Promise<DriverDocumentView> {
  const user = await UserModel.findById(userId);
  assertDriver(user);

  const doc = await DriverDocumentModel.findById(docId);
  if (!doc) {
    throw new HttpError(404, "Document not found");
  }
  if (String(doc.user_id) !== userId) {
    throw new HttpError(403, "You cannot modify this document");
  }
  if (doc.status !== "REJECTED") {
    throw new HttpError(400, "Reupload is only allowed for rejected documents");
  }

  const folder = `driver-documents/${userId}`;
  const uploaded = await uploadFile(file, folder);

  if (doc.file_key) {
    await deleteFile(doc.file_key).catch(() => undefined);
  }

  doc.file_url = uploaded.file_url;
  doc.file_key = uploaded.file_key;
  doc.status = "PENDING";
  doc.rejection_reason = undefined;
  await doc.save();

  return mapDocument(doc.toObject());
}

export async function adminGetDriversForVerification() {
  const drivers = await UserModel.find({
    role: "DRIVER",
    driver_verification_status: { $ne: "APPROVED" },
  })
    .select("_id name email phone driver_verification_status created_at")
    .sort({ created_at: -1 })
    .lean();

  const ids = drivers.map((d) => d._id as Types.ObjectId);
  if (ids.length === 0) {
    return [];
  }

  const counts = await DriverDocumentModel.aggregate<{ _id: Types.ObjectId; count: number }>([
    { $match: { user_id: { $in: ids } } },
    { $group: { _id: "$user_id", count: { $sum: 1 } } },
  ]);

  const countMap = new Map<string, number>();
  for (const row of counts) {
    countMap.set(String(row._id), row.count);
  }

  return drivers.map((driver) => ({
    id: String(driver._id),
    name: driver.name,
    email: driver.email,
    phone: driver.phone ?? null,
    driver_verification_status: driver.driver_verification_status ?? "PENDING",
    documents_uploaded_count: countMap.get(String(driver._id)) ?? 0,
    joined_at: (driver as { created_at?: Date }).created_at ?? null,
  }));
}

export async function adminGetDriverDocuments(driverId: string): Promise<DriverDocumentView[]> {
  const driver = await UserModel.findById(driverId).lean();
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }
  if (driver.role !== "DRIVER") {
    throw new HttpError(400, "User is not a driver");
  }

  const docs = await DriverDocumentModel.find({ user_id: new Types.ObjectId(driverId) })
    .sort({ createdAt: -1 })
    .lean();

  return docs.map((doc) =>
    mapDocument({
      _id: doc._id as Types.ObjectId,
      user_id: doc.user_id as Types.ObjectId,
      document_type: doc.document_type,
      file_url: doc.file_url,
      file_key: doc.file_key,
      status: doc.status,
      rejection_reason: doc.rejection_reason,
    })
  );
}

export async function adminUpdateDocumentStatus(
  docId: string,
  status: "APPROVED" | "REJECTED",
  reason?: string
): Promise<DriverDocumentView> {
  const doc = await DriverDocumentModel.findById(docId);
  if (!doc) {
    throw new HttpError(404, "Document not found");
  }

  doc.status = status;
  if (status === "REJECTED") {
    if (!reason?.trim()) {
      throw new HttpError(400, "Rejection reason is required");
    }
    doc.rejection_reason = reason.trim();
  } else {
    doc.rejection_reason = undefined;
  }

  await doc.save();

  const driver = await UserModel.findById(doc.user_id);
  if (driver && driver.role === "DRIVER") {
    if (status === "REJECTED") {
      driver.is_driver_verified = false;
      driver.driver_verification_status = "REJECTED";
      await driver.save();
      emitDriverVerificationEvent(String(driver._id), "admin_driver_rejected", {
        message: reason?.trim() || "A document was rejected. Please re-upload and wait for admin approval.",
        driver_verification_status: "REJECTED",
        is_driver_verified: false,
        document_type: doc.document_type,
      });
    } else {
      driver.is_driver_verified = false;
      driver.driver_verification_status = "PENDING";
      await driver.save();
    }
  }

  return mapDocument(doc.toObject());
}

function emitDriverVerificationEvent(
  driverId: string,
  event: string,
  payload: Record<string, unknown>
): void {
  try {
    const io = getIo();
    io.to(`driver_${driverId}`).emit(event, payload);
    io.to(`driver_${driverId}`).emit("driver:verification:update", payload);
  } catch {
    // Socket may be unavailable during tests or startup
  }
}

async function notifyDriverVerificationApproved(driver: {
  _id: Types.ObjectId;
  fcm_token?: string;
}): Promise<void> {
  const driverId = String(driver._id);
  const message =
    "Your account has been verified successfully. You can now go online and accept rides.";
  emitDriverVerificationEvent(driverId, "admin_driver_approved", {
    type: "driver_verification_approved",
    message,
    driver_verification_status: "APPROVED",
    is_driver_verified: true,
  });

  if (driver.fcm_token?.trim()) {
    await sendPushNotification({
      token: driver.fcm_token.trim(),
      title: "Driver verified",
      body: message,
      data: {
        type: "driver_verification_approved",
        driver_id: driverId,
      },
    });
  }
}

/** Admin approves driver account (email/password signup). Documents are optional. */
export async function adminFinalApproveDriver(driverId: string) {
  const driver = await UserModel.findById(driverId);
  if (!driver) {
    throw new HttpError(404, "Driver not found");
  }
  if (driver.role !== "DRIVER") {
    throw new HttpError(400, "User is not a driver");
  }

  // Optional uploads: auto-approve any pending/rejected rows so admin one-click works.
  await DriverDocumentModel.updateMany(
    { user_id: new Types.ObjectId(driverId), status: { $ne: "APPROVED" } },
    { $set: { status: "APPROVED" }, $unset: { rejection_reason: "" } }
  );

  driver.is_driver_verified = true;
  driver.driver_verification_status = "APPROVED";
  driver.is_active = true;
  driver.is_blocked = false;
  driver.blocked_reason = undefined;
  await driver.save();

  await ensureDriverReadyForOnline(driverId);
  await notifyDriverVerificationApproved(driver);

  const docsCount = await DriverDocumentModel.countDocuments({
    user_id: new Types.ObjectId(driverId),
  });

  return {
    driver_id: String(driver._id),
    email: driver.email,
    is_driver_verified: driver.is_driver_verified,
    driver_verification_status: driver.driver_verification_status,
    documents_optional: true,
    documents_on_file: docsCount,
    message:
      "Driver approved. They can go online in the driver app and receive ride requests.",
  };
}

/** Driver finished uploading — keep account in PENDING until admin approves each doc + final approve. */
export async function submitDocumentsForAdminReview(userId: string): Promise<{
  driver_verification_status: string;
  documents_count: number;
  documents_required: boolean;
}> {
  const user = await UserModel.findById(userId);
  assertDriver(user);

  const docs = await DriverDocumentModel.find({ user_id: new Types.ObjectId(userId) }).lean();

  user.is_driver_verified = false;
  user.driver_verification_status = "PENDING";
  await user.save();

  const message =
    docs.length === 0
      ? "Account submitted for admin approval (documents optional)"
      : "Documents submitted for admin review";

  emitDriverVerificationEvent(String(user._id), "driver_documents_submitted", {
    message,
    driver_verification_status: "PENDING",
    is_driver_verified: false,
    documents_count: docs.length,
  });

  return {
    driver_verification_status: user.driver_verification_status ?? "PENDING",
    documents_count: docs.length,
    documents_required: false,
  };
}

export async function validateDriverVerified(userId: string): Promise<void> {
  const user = await UserModel.findById(userId).lean();
  if (!user) {
    throw new HttpError(404, "User not found");
  }
  if (user.role !== "DRIVER") {
    throw new HttpError(403, "Not a driver account");
  }
  if (!user.is_driver_verified || user.driver_verification_status !== "APPROVED") {
    throw new HttpError(403, "Driver is not verified");
  }
}
