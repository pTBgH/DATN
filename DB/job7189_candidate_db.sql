-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: mysql:3306
-- Generation Time: Mar 22, 2026 at 02:25 PM
-- Server version: 8.0.44
-- PHP Version: 8.3.26

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `job7189_candidate_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `service_users`
--

CREATE TABLE `service_users` (
  `internal_id` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7 (Giống bên Identity)',
  `keycloak_id` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Để tìm kiếm nhanh',
  `email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `type` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'recruiter/candidate',
  `created_at` timestamp NULL DEFAULT NULL,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `service_users`
--

INSERT INTO `service_users` (`internal_id`, `keycloak_id`, `email`, `name`, `type`, `created_at`, `updated_at`) VALUES
('019bb2ee-da77-70d9-abfa-d027c98c5341', 'bc30bc63-e21c-4917-a1d7-94a253ecbfa4', 'baophungthai2@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-25 08:14:21', '2026-01-25 08:14:21'),
('019be0c2-4f95-7126-ba59-e57bf88f566c', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Thai Bao', 'recruiter', '2026-01-26 05:40:07', '2026-01-26 05:40:07'),
('019be0cb-5942-7133-8493-fa92ba42093c', '1ca9861b-2d3b-45b2-8dad-04badcffaabc', 'baophungthai9@gmail.com', 'bảo phùng thái', 'candidate', '2026-01-25 10:21:08', '2026-01-25 10:21:08'),
('019bee32-1551-70db-868d-8bbe530c43ee', '99e70aa7-823a-4791-971c-42c27500e47b', 'baophungthai3@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-24 08:02:10', '2026-01-24 08:39:14'),
('019bf0cf-e398-72fd-9741-4f03d0ccfa34', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Bao', 'candidate', '2026-01-24 16:25:39', '2026-01-24 16:25:39'),
('019bf2bc-619c-72b6-a8d2-80c3fbf4c5a7', 'ca6b9e8d-6b48-45bf-a94d-507aa1f7a6de', 'kidmardesu@gmail.com', 'sssssssssssssss', 'recruiter', '2026-01-25 01:55:27', '2026-01-25 09:10:44'),
('019bf453-e9a5-70f0-8d37-24664fad38e9', '0acabd04-636a-4830-bccb-bfac2b050b9b', 'baophungthai7@gmail.com', 'Job seeker', 'candidate', '2026-01-25 08:45:29', '2026-01-25 08:45:29'),
('019bf581-f343-73be-b77a-3296ab6138e4', 'c9dfafd3-570a-4d30-aa21-3ad98d7e8dc5', 'nguyenzdiz@gmail.com', 'adminssssss', 'recruiter', '2026-01-25 14:15:49', '2026-01-25 14:15:49');

-- --------------------------------------------------------

--
-- Table structure for table `usr_cvs`
--

CREATE TABLE `usr_cvs` (
  `CVID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `UserID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'ID ứng viên (từ Identity)',
  `Title` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên hiển thị CV (VD: CV Java Dev)',
  `CVPath` varchar(2048) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Đường dẫn file trên MinIO (VD: cvs/uuid.pdf)',
  `IsDefault` tinyint(1) DEFAULT '0',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `DeletedAt` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `usr_cvs`
--

INSERT INTO `usr_cvs` (`CVID`, `UserID`, `Title`, `CVPath`, `IsDefault`, `CreatedAt`, `UpdatedAt`, `DeletedAt`) VALUES
('019bcb34-47bc-708b-b23f-8c9e3b8db0d6', 'b47ba303-b1a3-45ee-8ee2-d2c57751583e', 'CV Fullstack 2026', 'cvs/253af56c-e1bd-461d-8f48-7c0a7798ffbd.pdf', 0, '2026-01-17 09:05:59', '2026-01-17 09:05:59', NULL),
('019bcb44-3cb0-7374-9197-cb6b5589897b', 'b47ba303-b1a3-45ee-8ee2-d2c57751583e', 'CV Fullstack 2026', 'cvs/253af56c-e1bd-461d-8f48-7c0a7798ffbd.pdf', 1, '2026-01-17 09:23:25', '2026-01-17 09:23:25', NULL),
('019bcb47-54d6-70d1-be0d-845dd5fe108d', 'b47ba303-b1a3-45ee-8ee2-d2c57751583e', 'CV Fullstack 2026', 'cvs/253af56c-e1bd-461d-8f48-7c0a7798ffbd.pdf', 1, '2026-01-17 09:26:48', '2026-01-17 09:26:48', NULL),
('019be0f6-9abb-7178-9c64-c93c8145d567', '019be0cb-5942-7133-8493-fa92ba42093c', 'CV Fullstack Developer 2026', 'cvs/UUID.pdf', 1, '2026-01-21 14:30:16', '2026-01-21 14:30:16', NULL),
('019be103-99bb-70d8-80b4-36175c4ea020', '019be0cb-5942-7133-8493-fa92ba42093c', 'CV Fullstack 2026', 'cvs/c5b51a20-f6cf-4fbc-ae21-74c9bff3f8cb.pdf', 1, '2026-01-21 14:44:28', '2026-01-21 14:44:28', NULL),
('019bf4c2-b7bf-7344-90fc-351ccc0a8c18', '019be0cb-5942-7133-8493-fa92ba42093c', 'CV quan ly', 'cvs/93ee82e5-8671-4a75-85b1-90808c48dc4e.pdf', 1, '2026-01-25 10:46:00', '2026-01-25 10:46:00', NULL),
('019bf8f8-f5a3-70a3-9251-81e3bbccc09e', '019be0cb-5942-7133-8493-fa92ba42093c', 'CV Laravel', 'cvs/93ee82e5-8671-4a75-85b1-90808c48dc4e.pdf', 1, '2026-01-26 06:23:44', '2026-01-26 06:23:44', NULL);

-- --------------------------------------------------------

--
-- Table structure for table `usr_job_interacts`
--

CREATE TABLE `usr_job_interacts` (
  `UserID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `JobID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `IsSaved` tinyint(1) DEFAULT '0',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Indexes for dumped tables
--

--
-- Indexes for table `service_users`
--
ALTER TABLE `service_users`
  ADD PRIMARY KEY (`internal_id`),
  ADD KEY `idx_service_users_keycloak_id` (`keycloak_id`);

--
-- Indexes for table `usr_cvs`
--
ALTER TABLE `usr_cvs`
  ADD PRIMARY KEY (`CVID`),
  ADD KEY `idx_userid` (`UserID`);

--
-- Indexes for table `usr_job_interacts`
--
ALTER TABLE `usr_job_interacts`
  ADD PRIMARY KEY (`UserID`,`JobID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
