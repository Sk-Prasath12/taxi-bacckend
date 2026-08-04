import { DeleteObjectCommand, GetObjectCommand, PutObjectCommand, S3Client } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomBytes } from "crypto";
import type { Readable } from "stream";
import { env } from "../config/env";
import { HttpError } from "./http-error";

let s3Client: S3Client | null = null;

function requireAwsConfig(): { client: S3Client; bucket: string; region: string } {
  const accessKeyId = env.AWS_ACCESS_KEY_ID;
  const secretAccessKey = env.AWS_SECRET_ACCESS_KEY;
  const region = env.AWS_REGION;
  const documentsBucket = env.AWS_S3_BUCKET_DOCUMENTS?.trim();
  const bucket = documentsBucket || env.AWS_S3_BUCKET;

  if (!accessKeyId || !secretAccessKey || !region || !bucket) {
    throw new HttpError(503, "File storage is not configured");
  }

  if (!s3Client) {
    s3Client = new S3Client({
      region,
      credentials: {
        accessKeyId,
        secretAccessKey,
      },
    });
  }

  return { client: s3Client, bucket, region };
}

function buildPublicObjectUrl(bucket: string, region: string, key: string): string {
  const safeKey = key.split("/").map((segment) => encodeURIComponent(segment)).join("/");
  return `https://${bucket}.s3.${region}.amazonaws.com/${safeKey}`;
}

export type UploadableFile = {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
};

export async function uploadFile(
  file: UploadableFile,
  folder: string
): Promise<{ file_url: string; file_key: string }> {
  const { client, bucket, region } = requireAwsConfig();
  const safeFolder = folder.replace(/^\/+|\/+$/g, "");
  const ext = file.originalname.includes(".") ? file.originalname.slice(file.originalname.lastIndexOf(".")) : "";
  const key = `${safeFolder}/${Date.now()}-${randomBytes(8).toString("hex")}${ext}`;

  // Omit ACL — "Bucket owner enforced" buckets reject ACL: public-read (AccessControlListNotSupported).
  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: file.buffer,
      ContentType: file.mimetype || "application/octet-stream",
    })
  );

  return {
    file_key: key,
    file_url: buildPublicObjectUrl(bucket, region, key),
  };
}

/** Presigned GET URL (optional: mobile / CDN). Downloads should prefer {@link getObjectForDownload}. */
export async function getSignedReadUrl(fileKey: string, expiresInSeconds = 900): Promise<string> {
  const { client, bucket } = requireAwsConfig();
  const command = new GetObjectCommand({ Bucket: bucket, Key: fileKey });
  return getSignedUrl(client, command, { expiresIn: expiresInSeconds });
}

export type S3ObjectDownload = {
  body: Readable;
  contentType: string;
  contentLength?: number;
};

/**
 * Stream object bytes from the configured documents bucket (server-side; works with private objects).
 * Requires IAM s3:GetObject on the bucket.
 */
export async function getObjectForDownload(fileKey: string): Promise<S3ObjectDownload> {
  const key = fileKey.trim();
  if (!key) {
    throw new HttpError(400, "Invalid file key");
  }

  const { client, bucket } = requireAwsConfig();
  try {
    const out = await client.send(
      new GetObjectCommand({
        Bucket: bucket,
        Key: key,
      })
    );
    if (!out.Body) {
      throw new HttpError(404, "File not found");
    }
    return {
      body: out.Body as Readable,
      contentType: (out.ContentType && out.ContentType.trim()) || "application/octet-stream",
      contentLength: out.ContentLength,
    };
  } catch (e: unknown) {
    const name = e && typeof e === "object" && "name" in e ? String((e as { name: string }).name) : "";
    if (name === "NoSuchKey") {
      throw new HttpError(404, "File not found");
    }
    throw e;
  }
}

export async function deleteFile(fileKey: string): Promise<void> {
  if (!fileKey) {
    return;
  }

  const { client, bucket } = requireAwsConfig();
  await client.send(
    new DeleteObjectCommand({
      Bucket: bucket,
      Key: fileKey,
    })
  );
}
