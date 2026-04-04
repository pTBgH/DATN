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
-- Database: `job7189_identity_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `rct_profiles`
--

CREATE TABLE `rct_profiles` (
  `RecruiterID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'ID người dùng (là nhà tuyển dụng)',
  `UserName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `KeycloakUserID` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `StatusID` tinyint NOT NULL DEFAULT '1' COMMENT 'Trạng thái của hồ sơ nhà tuyển dụng',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật hồ sơ',
  `PhoneNumber` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Số điện thoại nhà tuyển dụng',
  `FirstName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `LastName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu hồ sơ của nhà tuyển dụng';

--
-- Dumping data for table `rct_profiles`
--

INSERT INTO `rct_profiles` (`RecruiterID`, `UserName`, `Email`, `KeycloakUserID`, `StatusID`, `CreatedAt`, `UpdatedAt`, `PhoneNumber`, `FirstName`, `LastName`) VALUES
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', 'bảo phùng thái', 'baophungthai9@gmail.com', '1ca9861b-2d3b-45b2-8dad-04badcffaabc', 1, '2026-01-11 14:01:00', '2026-01-11 14:01:00', NULL, 'bảo', 'phùng thái'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', 'Bao Phung Thai', 'baophungthai2@gmail.com', 'bc30bc63-e21c-4917-a1d7-94a253ecbfa4', 1, '2026-01-12 15:59:16', '2026-01-25 08:14:21', '0293195669', 'Bao', 'Phung'),
('019bb766-1cc5-7383-927d-f540fb4e932b', 'baophungthai7@gmail.com', 'baophungthai7@gmail.com', '0acabd04-636a-4830-bccb-bfac2b050b9b', 1, '2026-01-13 12:48:01', '2026-01-13 12:48:01', NULL, 'bảo', 'phùng thái'),
('019be0c2-4f95-7126-ba59-e57bf88f566c', 'Thai Bao', 'baophungthai6@gmail.com', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 1, '2026-01-21 13:33:09', '2026-01-26 05:40:07', '0392195669', 'Phùng', 'Thái Bảo'),
('019bee32-1551-70db-868d-8bbe530c43ee', 'Bao Phung Thai', 'baophungthai3@gmail.com', '99e70aa7-823a-4791-971c-42c27500e47b', 1, '2026-01-24 04:10:18', '2026-01-24 08:05:42', NULL, 'Bao', 'Béo'),
('019bf2bc-619c-72b6-a8d2-80c3fbf4c5a7', 'sssssssssssssss', 'kidmardesu@gmail.com', 'ca6b9e8d-6b48-45bf-a94d-507aa1f7a6de', 1, '2026-01-25 01:19:50', '2026-01-25 09:10:44', '0365368771', 'Nguyen', 'Nguyen'),
('019bf581-f343-73be-b77a-3296ab6138e4', 'adminssssss', 'nguyenzdiz@gmail.com', 'c9dfafd3-570a-4d30-aa21-3ad98d7e8dc5', 1, '2026-01-25 14:14:52', '2026-01-25 14:15:49', '0365368771', 'Nguyen', 'Nguyen');

-- --------------------------------------------------------

--
-- Table structure for table `usr_users`
--

CREATE TABLE `usr_users` (
  `UserID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'ID người dùng hệ thống',
  `KeycloakUserID` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'ID người dùng từ Keycloak',
  `SexID` tinyint DEFAULT NULL COMMENT 'Giới tính người dùng',
  `Avatar` varchar(2048) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'URL ảnh đại diện/logo của người dùng',
  `UserName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên người dùng',
  `FirstName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `LastName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Email` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci,
  `ExperienceYears` int DEFAULT NULL,
  `PhoneNumber` varchar(20) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `SocialLinks` json DEFAULT NULL,
  `Alias` json DEFAULT NULL,
  `Birth` date DEFAULT NULL COMMENT 'Ngày sinh người dùng',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo người dùng',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật thông tin người dùng'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu thông tin người dùng';

--
-- Dumping data for table `usr_users`
--

INSERT INTO `usr_users` (`UserID`, `KeycloakUserID`, `SexID`, `Avatar`, `UserName`, `FirstName`, `LastName`, `Email`, `Description`, `ExperienceYears`, `PhoneNumber`, `SocialLinks`, `Alias`, `Birth`, `CreatedAt`, `UpdatedAt`) VALUES
('019be0cb-5942-7133-8493-fa92ba42093c', '1ca9861b-2d3b-45b2-8dad-04badcffaabc', NULL, NULL, 'bảo phùng thái', 'bảo', 'phùng thái', 'baophungthai9@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, '2026-01-21 13:43:01', '2026-01-21 13:43:01'),
('019bf0cf-e398-72fd-9741-4f03d0ccfa34', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', NULL, NULL, 'Bao', 'Bao', 'Bao', 'baophungthai6@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, '2026-01-24 16:21:54', '2026-01-24 16:25:39'),
('019bf453-e9a5-70f0-8d37-24664fad38e9', '0acabd04-636a-4830-bccb-bfac2b050b9b', NULL, NULL, 'Job seeker', 'bảo', 'phùng thái', 'baophungthai7@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, '2026-01-25 08:44:58', '2026-01-25 08:45:29'),
('019bfe46-3ffd-72e9-ab2e-2000f93d0232', 'bc30bc63-e21c-4917-a1d7-94a253ecbfa4', NULL, NULL, 'Benjamin Ovich', 'Benjamin', 'Ovich', 'baophungthai2@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, '2026-01-27 07:06:15', '2026-01-27 07:06:15');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `rct_profiles`
--
ALTER TABLE `rct_profiles`
  ADD PRIMARY KEY (`RecruiterID`);

--
-- Indexes for table `usr_users`
--
ALTER TABLE `usr_users`
  ADD PRIMARY KEY (`UserID`);
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
