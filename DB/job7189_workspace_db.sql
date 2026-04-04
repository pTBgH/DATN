-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: mysql:3306
-- Generation Time: Mar 22, 2026 at 02:28 PM
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
-- Database: `job7189_workspace_db`
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
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '1ca9861b-2d3b-45b2-8dad-04badcffaabc', 'baophungthai9@gmail.com', 'bảo phùng thái', 'recruiter', '2026-01-26 04:02:53', '2026-01-26 04:02:53'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', 'bc30bc63-e21c-4917-a1d7-94a253ecbfa4', 'baophungthai2@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-25 03:55:21', '2026-01-25 08:14:21'),
('019be0c2-4f95-7126-ba59-e57bf88f566c', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Thai Bao', 'recruiter', '2026-01-26 05:40:07', '2026-01-26 05:40:07'),
('019bee32-1551-70db-868d-8bbe530c43ee', '99e70aa7-823a-4791-971c-42c27500e47b', 'baophungthai3@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-24 04:31:27', '2026-01-24 08:39:14'),
('019bf0cf-e398-72fd-9741-4f03d0ccfa34', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Bao', 'candidate', '2026-01-24 16:25:39', '2026-01-24 16:25:39'),
('019bf2bc-619c-72b6-a8d2-80c3fbf4c5a7', 'ca6b9e8d-6b48-45bf-a94d-507aa1f7a6de', 'kidmardesu@gmail.com', 'sssssssssssssss', 'recruiter', '2026-01-25 01:55:27', '2026-01-25 09:10:44'),
('019bf453-e9a5-70f0-8d37-24664fad38e9', '0acabd04-636a-4830-bccb-bfac2b050b9b', 'baophungthai7@gmail.com', 'Job seeker', 'candidate', '2026-01-25 08:45:29', '2026-01-25 08:45:29'),
('019bf581-f343-73be-b77a-3296ab6138e4', 'c9dfafd3-570a-4d30-aa21-3ad98d7e8dc5', 'nguyenzdiz@gmail.com', 'adminssssss', 'recruiter', '2026-01-25 14:15:49', '2026-01-25 14:15:49');

-- --------------------------------------------------------

--
-- Table structure for table `workspaces`
--

CREATE TABLE `workspaces` (
  `WorkspaceID` char(36) NOT NULL,
  `Name` varchar(255) NOT NULL DEFAULT 'Untitled Workspace',
  `Logo` varchar(500) DEFAULT NULL,
  `Email` varchar(255) DEFAULT NULL,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `workspaces`
--

INSERT INTO `workspaces` (`WorkspaceID`, `Name`, `Logo`, `Email`, `CreatedAt`, `UpdatedAt`) VALUES
('019badb1-08bf-71f4-8a02-1bb2e70a6749', 'Untitled Workspace', NULL, 'job7189@gmail.com', '2026-01-11 15:33:39', '2026-01-11 15:33:39'),
('019badb5-5306-7273-b257-524fa49a4a1f', 'Untitled Workspace', NULL, 'job718EE9@gmail.com', '2026-01-11 15:38:20', '2026-01-11 15:38:20'),
('019bafac-9d53-703a-8f1a-ec8c034a30f2', 'Untitled Workspace', NULL, 'job718EE9@gmail.com', '2026-01-12 00:48:03', '2026-01-12 00:48:03'),
('019bb308-692b-7019-af41-d5040f568964', 'Untitled Workspace', NULL, 'job718EE9@gmail.com', '2026-01-12 16:27:11', '2026-01-12 16:27:11'),
('019bb53a-d60a-70ae-bfc5-41c569787a45', 'Untitled Workspace', NULL, 'job718EE9@gmail.com', '2026-01-13 02:41:30', '2026-01-13 02:41:30'),
('019bb544-6383-719b-87f9-e7fe568e0e20', 'Untitled Workspace', NULL, 'job718EE9@gmail.com', '2026-01-13 02:51:56', '2026-01-13 02:51:56'),
('019bb56a-58cf-7241-b150-4e6c39f8ce4c', 'Untitled Workspace', NULL, 'job7189_admin@gmail.com', '2026-01-13 03:33:24', '2026-01-13 03:33:24'),
('019bb56f-bb8a-70ef-824f-500b2b2dddb5', 'Untitled Workspace', NULL, 'job718EE9@gmail.com', '2026-01-13 03:39:17', '2026-01-13 03:39:17'),
('019bb764-3f3b-7169-a013-7abde49209b7', 'Untitled Workspace', NULL, 'job7189_admin@gmail.com', '2026-01-13 12:45:58', '2026-01-13 12:45:58'),
('019bee45-749b-7033-827b-b4f3f133959d', 'Untitled Workspace', NULL, 'job7189_admin@gmail.com', '2026-01-24 04:31:27', '2026-01-24 04:31:27'),
('019bf368-9bed-7120-b6b5-8ee4b294dd53', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 04:27:57', '2026-01-25 04:27:57'),
('019bf368-dd93-7025-b2df-0cc861e03d50', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 04:28:14', '2026-01-25 04:28:14'),
('019bf376-8165-720a-9ef2-af6631f23c4d', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 04:43:08', '2026-01-25 04:43:08'),
('019bf394-4c1e-710e-b865-5a74db222917', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:15:40', '2026-01-25 05:15:40'),
('019bf396-f556-7132-9c7d-799ffb8309d1', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:18:35', '2026-01-25 05:18:35'),
('019bf39d-2ceb-7152-9cfa-e29283acbf15', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:25:22', '2026-01-25 05:25:22'),
('019bf39e-8d6e-7044-a087-9234ab6f405a', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:26:53', '2026-01-25 05:26:53'),
('019bf3aa-5cc3-70bc-a72d-b7427b830b35', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:39:47', '2026-01-25 05:39:47'),
('019bf3ac-2336-70c2-858d-e662af9343ae', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:41:43', '2026-01-25 05:41:43'),
('019bf3ac-a9e5-725a-962a-5599ee20f495', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:42:17', '2026-01-25 05:42:17'),
('019bf3ae-dc52-736b-80d5-06ec49972a1d', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:44:41', '2026-01-25 05:44:41'),
('019bf3b5-244e-703e-9682-6772a1dad00f', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 05:51:33', '2026-01-25 05:51:33'),
('019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Telecom', NULL, 'Telecom@gmail.com', '2026-01-25 08:14:38', '2026-01-25 08:14:38'),
('019bf46b-81fd-707a-96bc-0d1b6ba1abf5', 'Nguyen', NULL, 'kidmardesu@gmail.com', '2026-01-25 09:10:44', '2026-01-25 09:10:44'),
('019bf582-ceb6-7186-acbd-c35cc281bf1c', 'Nguyen', NULL, 'kidmardesu@gmail.com', '2026-01-25 14:15:49', '2026-01-25 14:15:49'),
('019bf8d1-0b54-7178-bbe2-03177b0a842f', 'Bao Bao Bao', NULL, 'phungthaibaocpn@gmail.com', '2026-01-26 05:40:08', '2026-01-26 05:40:08'),
('019bf8db-5938-70c3-b262-85183a4be372', 'baocompany', NULL, 'baocompany@gmail.com', '2026-01-26 05:51:23', '2026-01-26 05:51:23');

-- --------------------------------------------------------

--
-- Table structure for table `workspace_invitations`
--

CREATE TABLE `workspace_invitations` (
  `InvitationID` char(36) NOT NULL,
  `WorkspaceID` char(36) NOT NULL,
  `InvitedBy` char(36) NOT NULL COMMENT 'Logic FK to Identity Service',
  `email` varchar(255) NOT NULL,
  `permissions` json DEFAULT NULL,
  `token` varchar(64) DEFAULT NULL,
  `code` varchar(10) DEFAULT NULL,
  `expires_at` datetime NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- --------------------------------------------------------

--
-- Table structure for table `workspace_members`
--

CREATE TABLE `workspace_members` (
  `RecruiterID` char(36) NOT NULL COMMENT 'Logic FK to Identity Service',
  `WorkspaceID` char(36) NOT NULL,
  `workspace_permissions` bigint UNSIGNED NOT NULL DEFAULT '0',
  `job_permissions` bigint UNSIGNED NOT NULL DEFAULT '0',
  `candidate_permissions` bigint UNSIGNED NOT NULL DEFAULT '0',
  `pipeline_permissions` bigint UNSIGNED NOT NULL DEFAULT '0',
  `status_id` tinyint NOT NULL DEFAULT '1' COMMENT '1=Active, 2=Pending',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

--
-- Dumping data for table `workspace_members`
--

INSERT INTO `workspace_members` (`RecruiterID`, `WorkspaceID`, `workspace_permissions`, `job_permissions`, `candidate_permissions`, `pipeline_permissions`, `status_id`, `created_at`, `updated_at`) VALUES
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '019badb1-08bf-71f4-8a02-1bb2e70a6749', 127, 2047, 255, 127, 1, '2026-01-11 15:33:39', '2026-01-11 15:33:39'),
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '019badb5-5306-7273-b257-524fa49a4a1f', 127, 2047, 255, 127, 1, '2026-01-11 15:38:20', '2026-01-11 15:38:20'),
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '019bafac-9d53-703a-8f1a-ec8c034a30f2', 127, 2047, 255, 127, 1, '2026-01-12 00:48:03', '2026-01-12 00:48:03'),
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '019bb308-692b-7019-af41-d5040f568964', 127, 2047, 255, 127, 1, '2026-01-12 16:27:11', '2026-01-12 16:27:11'),
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '019bb53a-d60a-70ae-bfc5-41c569787a45', 127, 2047, 255, 127, 1, '2026-01-13 02:41:30', '2026-01-13 02:41:30'),
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '019bb56a-58cf-7241-b150-4e6c39f8ce4c', 127, 2047, 255, 127, 1, '2026-01-13 03:33:24', '2026-01-13 03:33:24'),
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '019bb764-3f3b-7169-a013-7abde49209b7', 127, 2047, 255, 127, 1, '2026-01-13 12:45:58', '2026-01-13 12:45:58'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bb544-6383-719b-87f9-e7fe568e0e20', 127, 2047, 255, 127, 1, '2026-01-13 02:51:56', '2026-01-13 02:51:56'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bb56f-bb8a-70ef-824f-500b2b2dddb5', 127, 2047, 255, 127, 1, '2026-01-13 03:39:17', '2026-01-13 03:39:17'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf368-9bed-7120-b6b5-8ee4b294dd53', 127, 2047, 255, 127, 1, '2026-01-25 04:27:57', '2026-01-25 04:27:57'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf368-dd93-7025-b2df-0cc861e03d50', 127, 2047, 255, 127, 1, '2026-01-25 04:28:14', '2026-01-25 04:28:14'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf376-8165-720a-9ef2-af6631f23c4d', 127, 2047, 255, 127, 1, '2026-01-25 04:43:08', '2026-01-25 04:43:08'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf394-4c1e-710e-b865-5a74db222917', 127, 2047, 255, 127, 1, '2026-01-25 05:15:40', '2026-01-25 05:15:40'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf396-f556-7132-9c7d-799ffb8309d1', 127, 2047, 255, 127, 1, '2026-01-25 05:18:35', '2026-01-25 05:18:35'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf39d-2ceb-7152-9cfa-e29283acbf15', 127, 2047, 255, 127, 1, '2026-01-25 05:25:22', '2026-01-25 05:25:22'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf39e-8d6e-7044-a087-9234ab6f405a', 127, 2047, 255, 127, 1, '2026-01-25 05:26:53', '2026-01-25 05:26:53'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf3aa-5cc3-70bc-a72d-b7427b830b35', 127, 2047, 255, 127, 1, '2026-01-25 05:39:47', '2026-01-25 05:39:47'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf3ac-2336-70c2-858d-e662af9343ae', 127, 2047, 255, 127, 1, '2026-01-25 05:41:43', '2026-01-25 05:41:43'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf3ac-a9e5-725a-962a-5599ee20f495', 127, 2047, 255, 127, 1, '2026-01-25 05:42:17', '2026-01-25 05:42:17'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf3ae-dc52-736b-80d5-06ec49972a1d', 127, 2047, 255, 127, 1, '2026-01-25 05:44:41', '2026-01-25 05:44:41'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf3b5-244e-703e-9682-6772a1dad00f', 127, 2047, 255, 127, 1, '2026-01-25 05:51:33', '2026-01-25 05:51:33'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 127, 2047, 255, 127, 1, '2026-01-25 08:14:38', '2026-01-25 08:14:38'),
('019be0c2-4f95-7126-ba59-e57bf88f566c', '019bf8d1-0b54-7178-bbe2-03177b0a842f', 127, 2047, 255, 127, 1, '2026-01-26 05:40:08', '2026-01-26 05:40:08'),
('019bee32-1551-70db-868d-8bbe530c43ee', '019bee45-749b-7033-827b-b4f3f133959d', 127, 2047, 255, 127, 1, '2026-01-24 04:31:27', '2026-01-24 04:31:27'),
('019bf2bc-619c-72b6-a8d2-80c3fbf4c5a7', '019bf46b-81fd-707a-96bc-0d1b6ba1abf5', 127, 2047, 255, 127, 1, '2026-01-25 09:10:44', '2026-01-25 09:10:44'),
('019bf453-e9a5-70f0-8d37-24664fad38e9', '019bf8db-5938-70c3-b262-85183a4be372', 127, 2047, 255, 127, 1, '2026-01-26 05:51:23', '2026-01-26 05:51:23'),
('019bf581-f343-73be-b77a-3296ab6138e4', '019bf582-ceb6-7186-acbd-c35cc281bf1c', 127, 2047, 255, 127, 1, '2026-01-25 14:15:49', '2026-01-25 14:15:49');

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
-- Indexes for table `workspaces`
--
ALTER TABLE `workspaces`
  ADD PRIMARY KEY (`WorkspaceID`);

--
-- Indexes for table `workspace_invitations`
--
ALTER TABLE `workspace_invitations`
  ADD PRIMARY KEY (`InvitationID`),
  ADD UNIQUE KEY `uq_token` (`token`),
  ADD KEY `idx_invitation_email` (`email`),
  ADD KEY `fk_invitation_workspace` (`WorkspaceID`);

--
-- Indexes for table `workspace_members`
--
ALTER TABLE `workspace_members`
  ADD PRIMARY KEY (`RecruiterID`,`WorkspaceID`),
  ADD KEY `fk_member_workspace` (`WorkspaceID`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `workspace_invitations`
--
ALTER TABLE `workspace_invitations`
  ADD CONSTRAINT `fk_invitation_workspace` FOREIGN KEY (`WorkspaceID`) REFERENCES `workspaces` (`WorkspaceID`) ON DELETE CASCADE;

--
-- Constraints for table `workspace_members`
--
ALTER TABLE `workspace_members`
  ADD CONSTRAINT `fk_member_workspace` FOREIGN KEY (`WorkspaceID`) REFERENCES `workspaces` (`WorkspaceID`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
