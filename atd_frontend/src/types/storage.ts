/**
 * Storage Service — DTOs.
 * Source: src/storage_service/laravel_back/app/Http/Controllers/PresignedUrlController.php
 */

export type UploadKind = "cv" | "avatar" | "logo";

export interface PresignedUrlInput {
  filename: string;
  type: UploadKind;
}

export interface PresignedUrlResponse {
  url: string;
  path: string;
  expires_in: number;
}
