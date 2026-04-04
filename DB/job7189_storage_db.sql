-- =================================================
-- Job7189 Storage Service Database Schema
-- =================================================
-- ZTA Compliant: This file contains ONLY schema + default data.
-- NO passwords, NO user creations, NO GRANT statements.
-- All credentials are managed by Vault dynamic database engine.
-- =================================================

-- Create the database if it doesn't exist
CREATE DATABASE IF NOT EXISTS `job7189_storage_db`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE `job7189_storage_db`;

-- =================================================
-- Tables
-- =================================================

-- Storage files table
CREATE TABLE IF NOT EXISTS `storage_files` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `file_name` VARCHAR(255) NOT NULL,
  `file_path` VARCHAR(255) NOT NULL UNIQUE,
  `file_size` BIGINT UNSIGNED NOT NULL,
  `mime_type` VARCHAR(100),
  `storage_type` ENUM('minio', 'local', 's3') DEFAULT 'minio',
  `bucket` VARCHAR(100),
  `owner_id` BIGINT UNSIGNED,
  `owner_type` VARCHAR(50),
  `is_public` TINYINT(1) DEFAULT 0,
  `uploaded_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `deleted_at` TIMESTAMP NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX `idx_owner` (`owner_id`, `owner_type`),
  INDEX `idx_storage_type` (`storage_type`),
  INDEX `idx_uploaded_at` (`uploaded_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Storage access logs
CREATE TABLE IF NOT EXISTS `storage_access_logs` (
  `id` BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `file_id` BIGINT UNSIGNED NOT NULL,
  `user_id` BIGINT UNSIGNED,
  `access_type` ENUM('download', 'view', 'upload') DEFAULT 'download',
  `ip_address` VARCHAR(45),
  `user_agent` TEXT,
  `accessed_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`file_id`) REFERENCES `storage_files` (`id`) ON DELETE CASCADE,
  INDEX `idx_file_id` (`file_id`),
  INDEX `idx_user_id` (`user_id`),
  INDEX `idx_accessed_at` (`accessed_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =================================================
-- Default Data (if needed)
-- =================================================

-- Placeholder for default data insertion
-- INSERT INTO storage_files VALUES (...);
