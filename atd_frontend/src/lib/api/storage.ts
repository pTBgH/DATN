import { config } from "@/lib/config";
import { mockPresignedUrl } from "@/mocks/storage";
import type { PresignedUrlInput, PresignedUrlResponse } from "@/types/storage";
import { apiFetch } from "./client";

export async function getPresignedUrl(
  input: PresignedUrlInput,
): Promise<PresignedUrlResponse> {
  if (config.useMock) return Promise.resolve(mockPresignedUrl(input.filename));
  const response = await apiFetch<unknown>("/api/presigned-url", {
    query: {
      filename: input.filename,
      type: input.type,
    },
  });
  return normalizePresignedUrlResponse(response);
}

/** Upload a file to MinIO/S3 using a presigned PUT URL. */
export async function uploadFile(
  presignedUrl: string,
  file: File | Blob,
  contentType?: string,
): Promise<void> {
  const headers: HeadersInit = {};
  if (contentType ?? (file as File).type) {
    headers["Content-Type"] = contentType ?? (file as File).type;
  }
  const res = await fetch(presignedUrl, {
    method: "PUT",
    body: file,
    headers,
  });
  if (!res.ok) throw new Error(`Upload failed: HTTP ${res.status}`);
}

function normalizePresignedUrlResponse(response: unknown): PresignedUrlResponse {
  const payload = pickPayload(response);
  const url = readString(payload, "url") ?? readString(payload, "upload_url");
  const path =
    readString(payload, "path") ??
    readString(payload, "file_path") ??
    readString(payload, "key") ??
    "";

  if (!url) {
    throw new Error("Storage service did not return a presigned upload URL");
  }

  return {
    url,
    path,
    expires_in: readNumber(payload, "expires_in") ?? 600,
    file_url: readString(payload, "file_url") ?? readString(payload, "public_url"),
    success: readBoolean(payload, "success"),
  };
}

function pickPayload(response: unknown): Record<string, unknown> {
  if (!isRecord(response)) return {};
  const data = response.data;
  return isRecord(data) ? data : response;
}

function readString(payload: Record<string, unknown>, key: string) {
  const value = payload[key];
  return typeof value === "string" ? value : undefined;
}

function readNumber(payload: Record<string, unknown>, key: string) {
  const value = payload[key];
  return typeof value === "number" ? value : undefined;
}

function readBoolean(payload: Record<string, unknown>, key: string) {
  const value = payload[key];
  return typeof value === "boolean" ? value : undefined;
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null;
}
