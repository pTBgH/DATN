import { config } from "@/lib/config";
import { mockPresignedUrl } from "@/mocks/storage";
import type { PresignedUrlInput, PresignedUrlResponse } from "@/types/storage";
import { apiFetch } from "./client";

export async function getPresignedUrl(
  input: PresignedUrlInput,
): Promise<PresignedUrlResponse> {
  if (config.useMock) return Promise.resolve(mockPresignedUrl(input.filename));
  return apiFetch<PresignedUrlResponse>("/api/presigned-url", {
    method: "POST",
    body: input,
  });
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
