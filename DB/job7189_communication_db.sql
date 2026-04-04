-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: mysql:3306
-- Generation Time: Mar 22, 2026 at 02:26 PM
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
-- Database: `job7189_communication_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `con_conversations`
--

CREATE TABLE `con_conversations` (
  `ConversationID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `WorkspaceID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `Type` enum('direct','group') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'direct',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `con_conversation_participants`
--

CREATE TABLE `con_conversation_participants` (
  `ConversationID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `UserID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `JoinedAt` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `con_messages`
--

CREATE TABLE `con_messages` (
  `MessageID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `ConversationID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `SenderID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `Content` text COLLATE utf8mb4_unicode_ci NOT NULL,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `email_logs`
--

CREATE TABLE `email_logs` (
  `LogID` bigint UNSIGNED NOT NULL,
  `Recipient` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `Subject` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `Content` text COLLATE utf8mb4_unicode_ci,
  `Status` enum('sent','failed','queued') COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'queued',
  `ErrorMessage` text COLLATE utf8mb4_unicode_ci,
  `TriggeredBy` varchar(50) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Service nào gọi (Hiring/Auth)',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `email_logs`
--

INSERT INTO `email_logs` (`LogID`, `Recipient`, `Subject`, `Content`, `Status`, `ErrorMessage`, `TriggeredBy`, `CreatedAt`) VALUES
(1, 'baophungthai9@gmail.com', 'Test Microservices Email', '<h1>Xin chào!</h1><p>Đây là email test từ Hiring Service.</p>...', 'sent', NULL, 'HiringService', '2026-01-20 02:57:53'),
(2, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019bb807-b229-719d-96a9-18bfe6d0a393....', 'sent', NULL, 'System', '2026-01-22 03:37:34'),
(3, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 03:37:36'),
(4, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 03:37:37'),
(5, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 03:37:38'),
(6, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 03:37:39'),
(7, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 03:37:40'),
(8, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 03:37:42'),
(9, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 03:58:41'),
(10, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 04:02:04'),
(11, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 04:03:31'),
(12, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 04:11:34'),
(13, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 04:28:07'),
(14, 'baophungthai9@gmail.com', 'Ứng tuyển thành công!', 'Chào bảo phùng thái, chúng tôi đã nhận được hồ sơ của bạn cho Job ID: 019be14e-f4af-73c5-ac76-ba8e6c2c1306....', 'sent', NULL, 'System', '2026-01-22 05:12:13');

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
('019bee32-1551-70db-868d-8bbe530c43ee', '99e70aa7-823a-4791-971c-42c27500e47b', 'baophungthai3@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-24 08:13:04', '2026-01-24 08:39:14'),
('019bf0cf-e398-72fd-9741-4f03d0ccfa34', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Bao', 'candidate', '2026-01-24 16:25:39', '2026-01-24 16:25:39'),
('019bf2bc-619c-72b6-a8d2-80c3fbf4c5a7', 'ca6b9e8d-6b48-45bf-a94d-507aa1f7a6de', 'kidmardesu@gmail.com', 'sssssssssssssss', 'recruiter', '2026-01-25 01:55:27', '2026-01-25 09:10:44'),
('019bf453-e9a5-70f0-8d37-24664fad38e9', '0acabd04-636a-4830-bccb-bfac2b050b9b', 'baophungthai7@gmail.com', 'Job seeker', 'candidate', '2026-01-25 08:45:29', '2026-01-25 08:45:29'),
('019bf581-f343-73be-b77a-3296ab6138e4', 'c9dfafd3-570a-4d30-aa21-3ad98d7e8dc5', 'nguyenzdiz@gmail.com', 'adminssssss', 'recruiter', '2026-01-25 14:15:49', '2026-01-25 14:15:49');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `con_conversations`
--
ALTER TABLE `con_conversations`
  ADD PRIMARY KEY (`ConversationID`),
  ADD KEY `idx_ws` (`WorkspaceID`);

--
-- Indexes for table `con_conversation_participants`
--
ALTER TABLE `con_conversation_participants`
  ADD PRIMARY KEY (`ConversationID`,`UserID`);

--
-- Indexes for table `con_messages`
--
ALTER TABLE `con_messages`
  ADD PRIMARY KEY (`MessageID`),
  ADD KEY `idx_conv_time` (`ConversationID`,`CreatedAt`);

--
-- Indexes for table `email_logs`
--
ALTER TABLE `email_logs`
  ADD PRIMARY KEY (`LogID`);

--
-- Indexes for table `service_users`
--
ALTER TABLE `service_users`
  ADD PRIMARY KEY (`internal_id`),
  ADD KEY `idx_service_users_keycloak_id` (`keycloak_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `email_logs`
--
ALTER TABLE `email_logs`
  MODIFY `LogID` bigint UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
