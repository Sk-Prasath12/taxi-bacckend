/**
 * Adds local disk fallback when AWS S3 is not configured (dev/Docker).
 */
const fs = require('fs');
const path = '/app/src/utils/s3.ts';

if (!fs.existsSync(path)) {
  console.error('s3.ts not found');
  process.exit(1);
}

let s = fs.readFileSync(path, 'utf8');
if (s.includes('uploadFileLocal')) {
  console.log('s3 local fallback already patched');
  process.exit(0);
}

const importLine = `import path from "path";\nimport fs from "fs/promises";`;
if (!s.includes('import path from "path"')) {
  s = s.replace(
    'import { env } from "../config/env";',
    `${importLine}\nimport { env } from "../config/env";`
  );
}

const localHelper = `
async function uploadFileLocal(
  file: UploadableFile,
  folder: string
): Promise<{ file_url: string; file_key: string }> {
  const safeFolder = folder.replace(/^\\/+|\\/+$/g, "");
  const ext = file.originalname.includes(".")
    ? file.originalname.slice(file.originalname.lastIndexOf("."))
    : "";
  const key = \`\${safeFolder}/\${Date.now()}-\${randomBytes(8).toString("hex")}\${ext}\`;
  const abs = path.join(process.cwd(), "uploads", key);
  await fs.mkdir(path.dirname(abs), { recursive: true });
  await fs.writeFile(abs, file.buffer);
  return {
    file_key: key,
    file_url: \`/uploads/\${key.split(path.sep).join("/")}\`,
  };
}
`;

s = s.replace(
  'export async function uploadFile(',
  `${localHelper}\n\nexport async function uploadFile(`
);

s = s.replace(
  `export async function uploadFile(
  file: UploadableFile,
  folder: string
): Promise<{ file_url: string; file_key: string }> {
  const { client, bucket, region } = requireAwsConfig();`,
  `export async function uploadFile(
  file: UploadableFile,
  folder: string
): Promise<{ file_url: string; file_key: string }> {
  try {
    const { client, bucket, region } = requireAwsConfig();`
);

s = s.replace(
  `  return {
    file_key: key,
    file_url: buildPublicObjectUrl(bucket, region, key),
  };
}

/** Presigned GET URL`,
  `  return {
    file_key: key,
    file_url: buildPublicObjectUrl(bucket, region, key),
  };
  } catch (err) {
    if (err instanceof HttpError && err.statusCode === 503) {
      return uploadFileLocal(file, folder);
    }
    throw err;
  }
}

/** Presigned GET URL`
);

fs.writeFileSync(path, s);
console.log('s3.ts local fallback patched');
