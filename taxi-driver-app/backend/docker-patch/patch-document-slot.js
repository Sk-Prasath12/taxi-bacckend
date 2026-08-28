/**
 * Adds document_slot to driver documents for per-slot upsert (no duplicates).
 */
const fs = require('fs');

const modelPath = '/app/src/modules/driver-documents/driver-document.model.ts';
const validationPath = '/app/src/modules/driver-documents/driver-document.validation.ts';
const servicePath = '/app/src/modules/driver-documents/driver-document.service.ts';
const controllerPath = '/app/src/modules/driver-documents/driver-document.controller.ts';

function read(p) {
  return fs.existsSync(p) ? fs.readFileSync(p, 'utf8') : null;
}
function write(p, s) {
  fs.writeFileSync(p, s);
  console.log('patched', p);
}

let model = read(modelPath);
if (model && !model.includes('document_slot')) {
  model = model.replace(
    'document_type: DriverDocumentType;',
    'document_type: DriverDocumentType;\n  document_slot?: string;'
  ).replace(
    'document_type: {\n      type: String,\n      enum: DRIVER_DOCUMENT_TYPES,\n      required: true,\n    },',
    `document_type: {
      type: String,
      enum: DRIVER_DOCUMENT_TYPES,
      required: true,
    },
    document_slot: { type: String, trim: true, default: undefined },`
  ).replace(
    'driverDocumentSchema.index({ user_id: 1, document_type: 1 });',
    `driverDocumentSchema.index({ user_id: 1, document_type: 1 });
driverDocumentSchema.index({ user_id: 1, document_slot: 1 }, { unique: true, sparse: true });`
  );
  write(modelPath, model);
}

let validation = read(validationPath);
if (validation && !validation.includes('document_slot')) {
  validation = validation.replace(
    `document_type: z.enum(["IDENTITY", "VEHICLE", "BANK", "PERSONAL"], {
      errorMap: () => ({ message: "Invalid or missing document_type query param" }),
    }),`,
    `document_type: z.enum(["IDENTITY", "VEHICLE", "BANK", "PERSONAL"], {
      errorMap: () => ({ message: "Invalid or missing document_type query param" }),
    }),
    document_slot: z.string().trim().optional(),`
  );
  write(validationPath, validation);
}

let service = read(servicePath);
if (service && !service.includes('document_slot')) {
  service = service.replace(
    'export async function uploadDocument(\n  userId: string,\n  documentType: DriverDocumentType,\n  file: UploadableFile\n): Promise<DriverDocumentView> {',
    'export async function uploadDocument(\n  userId: string,\n  documentType: DriverDocumentType,\n  file: UploadableFile,\n  documentSlot?: string\n): Promise<DriverDocumentView> {'
  ).replace(
    `const created = await DriverDocumentModel.create({
    user_id: new Types.ObjectId(userId),
    document_type: documentType,
    file_url: uploaded.file_url,
    file_key: uploaded.file_key,
    status: "PENDING",
  });

  return mapDocument(created.toObject());`,
    `const slot = documentSlot?.trim() || documentType;
  const existing = await DriverDocumentModel.findOne({
    user_id: new Types.ObjectId(userId),
    document_slot: slot,
  });
  if (existing?.file_key) {
    await deleteFile(existing.file_key).catch(() => {});
  }
  const saved = await DriverDocumentModel.findOneAndUpdate(
    { user_id: new Types.ObjectId(userId), document_slot: slot },
    {
      user_id: new Types.ObjectId(userId),
      document_type: documentType,
      document_slot: slot,
      file_url: uploaded.file_url,
      file_key: uploaded.file_key,
      status: "PENDING",
      rejection_reason: undefined,
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );
  return mapDocument(saved.toObject());`
  ).replace(
    'document_type: doc.document_type,',
    'document_type: doc.document_type,\n    document_slot: (doc as { document_slot?: string }).document_slot,'
  ).replace(
    'rejection_reason: string | null;\n};',
    `rejection_reason: string | null;
  document_slot?: string | null;
};`
  );
  write(servicePath, service);
}

let controller = read(controllerPath);
if (controller && !controller.includes('document_slot')) {
  controller = controller.replace(
    'const document = await uploadDocument(userId, documentType, req.file);',
    'const documentSlot = typeof req.query.document_slot === "string" ? req.query.document_slot : undefined;\n    const document = await uploadDocument(userId, documentType, req.file, documentSlot);'
  );
  write(controllerPath, controller);
}

console.log('document_slot patch done');
