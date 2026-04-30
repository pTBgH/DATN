import type { PresignedUrlResponse } from "@/types/storage";

export function mockPresignedUrl(filename: string): PresignedUrlResponse {
  const ext = filename.includes(".") ? filename.split(".").pop() : "bin";
  return {
    url: `https://minio.job7189.com/uploads/${crypto.randomUUID()}.${ext}?signature=mock`,
    path: `uploads/${crypto.randomUUID()}.${ext}`,
    expires_in: 600,
  };
}
