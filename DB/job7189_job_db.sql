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
-- Database: `job7189_job_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `job_companies`
--

CREATE TABLE `job_companies` (
  `CompanyID` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUID giống WorkspaceID',
  `IsActive` tinyint(1) DEFAULT '1',
  `CompanyName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `LocationID` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `PicturePath` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Description` text COLLATE utf8mb4_unicode_ci,
  `SizeID` tinyint UNSIGNED DEFAULT NULL,
  `IndustryID` tinyint UNSIGNED DEFAULT NULL,
  `Website` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_companies`
--

INSERT INTO `job_companies` (`CompanyID`, `IsActive`, `CompanyName`, `LocationID`, `PicturePath`, `Description`, `SizeID`, `IndustryID`, `Website`, `CreatedAt`, `UpdatedAt`) VALUES
('019bf3ae-dc52-736b-80d5-06ec49972a1d', 1, 'Telecom', '019bf3b6-39bb-7062-97cf-c4ca79326fb0', NULL, NULL, 5, 11, 'aaa.com.vn', '2026-01-25 05:52:44', '2026-01-25 05:52:44'),
('019bf3b5-244e-703e-9682-6772a1dad00f', 1, 'Telecom', '019bf3b6-39be-7357-addd-af789eba9567', NULL, NULL, 5, 11, 'aaa.com.vn', '2026-01-25 05:52:44', '2026-01-25 05:52:44'),
('019bf438-21d0-728f-ad3b-0e8bce2709e4', 1, 'Telecom', '019bf438-21e8-701f-9b24-aec9379ac75d', NULL, NULL, 5, 11, 'aaa.com.vn', '2026-01-25 08:14:38', '2026-01-25 08:14:38'),
('019bf46b-81fd-707a-96bc-0d1b6ba1abf5', 1, 'Nguyen', '019bf46b-8201-71bd-a202-466f1feff8bc', NULL, NULL, 1, 2, 'sssssssssssss', '2026-01-25 09:10:44', '2026-01-25 09:10:44'),
('019bf582-ceb6-7186-acbd-c35cc281bf1c', 1, 'Nguyen', '019bf582-cec7-7088-84e2-a5d1bedc6cd2', NULL, NULL, 2, 3, NULL, '2026-01-25 14:15:49', '2026-01-25 14:15:49'),
('019bf8d1-0b54-7178-bbe2-03177b0a842f', 1, 'Bao Bao Bao', '019bf8d1-0b67-708a-9505-63c74d463582', NULL, NULL, 2, 16, NULL, '2026-01-26 05:40:08', '2026-01-26 05:40:08'),
('019bf8db-5938-70c3-b262-85183a4be372', 1, 'baocompany', '019bf8db-593d-717e-81c2-04fa74262943', NULL, NULL, 5, 11, 'baocompany.com.vn', '2026-01-26 05:51:23', '2026-01-26 05:51:23');

-- --------------------------------------------------------

--
-- Table structure for table `job_company_sizes`
--

CREATE TABLE `job_company_sizes` (
  `SizeID` tinyint UNSIGNED NOT NULL,
  `SizeName` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_company_sizes`
--

INSERT INTO `job_company_sizes` (`SizeID`, `SizeName`) VALUES
(1, '1-9 employees'),
(2, '10-24 employees'),
(3, '25-99 employees'),
(4, '100-499 employees'),
(5, '500-1000 employees'),
(6, '1000+ employees');

-- --------------------------------------------------------

--
-- Table structure for table `job_contracttypes`
--

CREATE TABLE `job_contracttypes` (
  `ContractTypeID` tinyint NOT NULL COMMENT 'ID loại hợp đồng',
  `ContractTypeName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên loại hợp đồng',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các loại hợp đồng lao động';

--
-- Dumping data for table `job_contracttypes`
--

INSERT INTO `job_contracttypes` (`ContractTypeID`, `ContractTypeName`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Indefinite-term', '2026-01-24 14:54:39', '2026-01-24 14:54:39'),
(2, 'Fixed-term', '2026-01-24 14:54:39', '2026-01-24 14:54:39'),
(3, 'Probation', '2026-01-24 14:54:39', '2026-01-24 14:54:39'),
(4, 'Internship', '2026-01-24 14:54:39', '2026-01-24 14:54:39'),
(5, 'Freelance', '2026-01-24 14:54:39', '2026-01-24 14:54:39'),
(6, 'Seasonal', '2026-01-24 14:54:39', '2026-01-24 14:54:39');

-- --------------------------------------------------------

--
-- Table structure for table `job_degreelevels`
--

CREATE TABLE `job_degreelevels` (
  `DegreeLevelID` tinyint NOT NULL COMMENT 'ID trình độ học vấn',
  `DegreeLevelName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên trình độ học vấn',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các trình độ học vấn';

--
-- Dumping data for table `job_degreelevels`
--

INSERT INTO `job_degreelevels` (`DegreeLevelID`, `DegreeLevelName`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Intern', '2026-01-24 14:54:50', '2026-01-24 14:54:50'),
(2, 'Fresher', '2026-01-24 14:54:50', '2026-01-24 14:54:50'),
(3, 'Junior', '2026-01-24 14:54:50', '2026-01-24 14:54:50'),
(4, 'Middle', '2026-01-24 14:54:50', '2026-01-24 14:54:50'),
(5, 'Senior', '2026-01-24 14:54:50', '2026-01-24 14:54:50'),
(6, 'Lead / Supervisor', '2026-01-24 14:54:50', '2026-01-24 14:54:50'),
(7, 'Manager', '2026-01-24 14:54:50', '2026-01-24 14:54:50'),
(8, 'Director / C-Level', '2026-01-24 14:54:50', '2026-01-24 14:54:50');

-- --------------------------------------------------------

--
-- Table structure for table `job_industries`
--

CREATE TABLE `job_industries` (
  `IndustryID` tinyint UNSIGNED NOT NULL,
  `IndustryName` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_industries`
--

INSERT INTO `job_industries` (`IndustryID`, `IndustryName`) VALUES
(1, 'Agriculture, Forestry and Fishing'),
(2, 'Mining and Quarrying'),
(3, 'Manufacturing'),
(4, 'Electricity, Gas, Steam and Air Conditioning Supply'),
(5, 'Water Supply; Sewerage, Waste Management and Remediation Activities'),
(6, 'Construction'),
(7, 'Wholesale and Retail Trade; Repair of Motor Vehicles and Motorcycles'),
(8, 'Transportation and Storage'),
(9, 'Accommodation and Food Service Activities'),
(10, 'Information and Communication'),
(11, 'Financial and Insurance Activities'),
(12, 'Real Estate Activities'),
(13, 'Professional, Scientific and Technical Activities'),
(14, 'Administrative and Support Service Activities'),
(15, 'Public Administration and Defence; Compulsory Social Security'),
(16, 'Education'),
(17, 'Human Health and Social Work Activities'),
(18, 'Arts, Entertainment and Recreation'),
(19, 'Other Service Activities'),
(20, 'Activities of Households as Employers; Undifferentiated Goods- and Services-Producing Activities of Households for Own Use'),
(21, 'Activities of Extraterritorial Organisations and Bodies');

-- --------------------------------------------------------

--
-- Table structure for table `job_jds`
--

CREATE TABLE `job_jds` (
  `JobID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `CompanyID` varchar(64) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `IsActive` tinyint(1) DEFAULT '1',
  `FlagID` tinyint DEFAULT NULL,
  `SourceID` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Title` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `JobSectorID` tinyint DEFAULT NULL,
  `JobTypeID` tinyint DEFAULT NULL,
  `WorkingTypeID` tinyint DEFAULT NULL,
  `DegreeLevelID` tinyint DEFAULT NULL,
  `ExperienceYear` tinyint DEFAULT NULL,
  `MinSalary` bigint DEFAULT NULL,
  `MaxSalary` bigint DEFAULT NULL,
  `CurrencyID` smallint NOT NULL DEFAULT '1',
  `OpenDate` date DEFAULT NULL,
  `EndDate` date DEFAULT NULL,
  `Description` longtext COLLATE utf8mb4_unicode_ci,
  `Requirements` longtext COLLATE utf8mb4_unicode_ci,
  `Benefits` longtext COLLATE utf8mb4_unicode_ci,
  `Keywords` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ContractTypeID` tinyint DEFAULT NULL,
  `SexID` tinyint DEFAULT NULL,
  `MinAge` tinyint DEFAULT NULL,
  `MaxAge` tinyint DEFAULT NULL,
  `JobLink` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `PictureUrl` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT '',
  `detail_address` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `LocationID` bigint DEFAULT NULL,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_jds`
--

INSERT INTO `job_jds` (`JobID`, `CompanyID`, `slug`, `IsActive`, `FlagID`, `SourceID`, `Title`, `JobSectorID`, `JobTypeID`, `WorkingTypeID`, `DegreeLevelID`, `ExperienceYear`, `MinSalary`, `MaxSalary`, `CurrencyID`, `OpenDate`, `EndDate`, `Description`, `Requirements`, `Benefits`, `Keywords`, `ContractTypeID`, `SexID`, `MinAge`, `MaxAge`, `JobLink`, `PictureUrl`, `detail_address`, `LocationID`, `CreatedAt`, `UpdatedAt`) VALUES
('019bf0b4-d942-73cb-a297-01e119abad64', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'senior-laravel-developer-microservices-vgwgb7', 1, NULL, NULL, 'Senior Laravel Developer (Microservices)', 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', NULL, '2026-01-24 15:56:48', '2026-01-25 11:18:03'),
('019bf43c-27cb-719b-adf4-33bc9778b09b', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'senior-flutter-developer-fintech-payment-etfpv8', 1, NULL, NULL, 'Senior Flutter Developer (Fintech & Payment)', 3, 1, 2, 1, 3, 35000000, 65000000, 1, '2026-01-25', '2026-03-10', '<p>Mô tả công việc:</p>\n\n<p>- Chịu trách nhiệm chính phát triển các tính năng mới trên ứng dụng Job7189 trên nền tảng Mobile (iOS &amp; Android).</p>\n\n<p>- Tối ưu hóa hiệu năng ứng dụng, đảm bảo trải nghiệm người dùng mượt mà ở mức 60fps.</p>\n\n<p>- Phối hợp với team Backend để tích hợp hệ thống thanh toán và bảo mật vân tay/FaceID.</p>\n\n<p>- Mentor và hỗ trợ review code cho các thành viên Junior trong team.</p>', '<ul><li>Ít nhất 3 năm kinh nghiệm thực chiến với Flutter &amp; Dart.</li><li>Nắm vững quản lý State bằng BLoC hoặc Riverpod.</li><li>Có kinh nghiệm đưa App lên Store (AppStore/CH Play) và xử lý quy trình review nghiêm ngặt.</li><li>Hiểu sâu về CI/CD cho Mobile (Codemagic, Fastlane hoặc Jenkins).</li><li>Ưu tiên ứng viên có kiến thức về Native (Kotlin/Swift) là một điểm cộng cực lớn.</li></ul>', '<ul><li>Lương cứng: 35.000.000 - 65.000.000 VNĐ (Net).</li><li>Tháng lương thứ 13 + Thưởng hiệu suất (1-3 tháng lương).</li><li>Làm việc 5 ngày/tuần (Nghỉ T7, CN).</li><li>Gói bảo hiểm sức khỏe PVI dành riêng cho nhân viên Senior.</li><li>Company trip hàng năm tại các resort 5 sao.</li></ul>', 'Flutter, Dart, Mobile Developer, Fintech, BLoC, iOS, Android', 5, 1, 25, 35, 'https://tuyendung.job7189.com/senior-flutter-fintech', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', NULL, '2026-01-25 09:38:06', '2026-01-25 09:38:06'),
('019bf51d-3f8d-706f-ab48-59c01680a743', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'senior-laravel-developer-microservices-s9oiid', 1, NULL, NULL, 'Senior Laravel Developer (Microservices)', 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', NULL, '2026-01-25 12:25:28', '2026-01-25 12:25:28'),
('019bf8e4-cdf5-70a8-b5d5-21d647737b47', '019bf8db-5938-70c3-b262-85183a4be372', 'senior-laravel-developer-microservices-wff6xy', 1, NULL, NULL, 'Senior Laravel Developer (Microservices)', 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-26', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', NULL, '2026-01-26 06:05:19', '2026-01-26 06:05:19');

-- --------------------------------------------------------

--
-- Table structure for table `job_jd_changes`
--

CREATE TABLE `job_jd_changes` (
  `ChangeID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Primary key, UUIDv7',
  `JobID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Version` bigint UNSIGNED NOT NULL COMMENT 'Thay đổi này thuộc về lần cập nhật tạo ra version này',
  `Field` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên của trường dữ liệu đã thay đổi (vd: Title, Job_Description)',
  `OldValue` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Giá trị của trường trước khi thay đổi',
  `NewValue` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Giá trị của trường sau khi thay đổi',
  `ChangedBy` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'UUID of the user who made the change',
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian thay đổi được ghi lại'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Ghi lại nhật ký chi tiết từng thay đổi (delta) của mỗi version job';

-- --------------------------------------------------------

--
-- Table structure for table `job_jd_snapshot`
--

CREATE TABLE `job_jd_snapshot` (
  `SnapshotID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Primary key, UUIDv7',
  `JobID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Version` bigint UNSIGNED NOT NULL COMMENT 'Phiên bản của job được snapshot',
  `Data` json NOT NULL COMMENT 'Bản sao lưu đầy đủ dữ liệu của job tại thời điểm snapshot',
  `SnapshotType` enum('auto','manual') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'auto' COMMENT 'Loại snapshot: tự động theo version hoặc thủ công',
  `CreatedBy` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'UUID of the user who created the snapshot',
  `CreatedAt` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo snapshot'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Lưu các bản sao lưu (snapshot) đầy đủ của job tại các version quan trọng';

--
-- Dumping data for table `job_jd_snapshot`
--

INSERT INTO `job_jd_snapshot` (`SnapshotID`, `JobID`, `Version`, `Data`, `SnapshotType`, `CreatedBy`, `CreatedAt`) VALUES
('019bf085-3100-7222-ad47-cc98de16c6b4', '019bf085-30fa-7033-9885-36e6f8d5c5c0', 1, '{\"JobID\": \"019bf085-30fa-7033-9885-36e6f8d5c5c0\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:00:19'),
('019bf085-768f-715d-9808-e1fbce8eb15e', '019bf085-7689-70cf-8a26-7c14d38dce58', 1, '{\"JobID\": \"019bf085-7689-70cf-8a26-7c14d38dce58\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:00:37'),
('019bf091-3216-721b-a4af-dcbb236b1e1e', '019bf091-3211-7080-9c7a-4413b27fe8d2', 1, '{\"JobID\": \"019bf091-3211-7080-9c7a-4413b27fe8d2\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:13:26'),
('019bf09c-45f2-7365-9392-a9f57867420a', '019bf09c-45ed-72dc-badb-6ceecacf1c4a', 1, '{\"JobID\": \"019bf09c-45ed-72dc-badb-6ceecacf1c4a\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:25:32'),
('019bf09e-72fc-7140-b114-f20f7b882e90', '019bf09e-72f5-72f3-9d24-c2ef219ad1d6', 1, '{\"JobID\": \"019bf09e-72f5-72f3-9d24-c2ef219ad1d6\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:27:54'),
('019bf09e-7c7f-7177-a427-b34cbfabfe05', '019bf09e-7c77-7105-b477-c6b2872db327', 1, '{\"JobID\": \"019bf09e-7c77-7105-b477-c6b2872db327\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:27:57'),
('019bf0a0-7a34-7182-bb42-7b95718f8e5f', '019bf0a0-7a2e-7119-acd3-0141ee125d9e', 1, '{\"JobID\": \"019bf0a0-7a2e-7119-acd3-0141ee125d9e\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:30:07'),
('019bf0a2-802c-70f3-a7b3-7ea60db2f2dd', '019bf0a2-8025-7157-bfe8-8c195467c70f', 1, '{\"JobID\": \"019bf0a2-8025-7157-bfe8-8c195467c70f\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:32:20'),
('019bf0a2-8a89-7043-b7dc-b056ae7bc49a', '019bf0a2-8a83-708b-ae22-3fc6fc990a16', 1, '{\"JobID\": \"019bf0a2-8a83-708b-ae22-3fc6fc990a16\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:32:22'),
('019bf0a9-de37-7121-b072-b6f33d77d567', '019bf0a9-de32-7365-a025-ab96c4c44ea6', 1, '{\"JobID\": \"019bf0a9-de32-7365-a025-ab96c4c44ea6\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:40:22'),
('019bf0ad-5d5b-71ce-8046-760cd7face91', '019bf0ad-5d55-72be-940b-3b2f5ea8968a', 1, '{\"JobID\": \"019bf0ad-5d55-72be-940b-3b2f5ea8968a\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:44:12'),
('019bf0ae-596d-72bf-945c-321e2830c8a2', '019bf0ae-5968-724e-9773-ea5000384744', 1, '{\"JobID\": \"019bf0ae-5968-724e-9773-ea5000384744\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:45:16'),
('019bf0b0-36e6-70a2-9433-2f4e35ac8c17', '019bf0b0-36e0-70fb-b3a1-68ceb403db8a', 1, '{\"JobID\": \"019bf0b0-36e0-70fb-b3a1-68ceb403db8a\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"LocationID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:47:18'),
('019bf0b2-9c94-71d6-b5b2-1b033a055f5a', '019bf0b2-9c8d-72f7-b295-0d44434d3968', 1, '{\"JobID\": \"019bf0b2-9c8d-72f7-b295-0d44434d3968\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:49:55'),
('019bf0b4-ce0a-7397-9a99-79c22540bff9', '019bf0b4-ce05-734e-a512-0d0466fe5700', 1, '{\"JobID\": \"019bf0b4-ce05-734e-a512-0d0466fe5700\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:52:19'),
('019bf0b4-d948-7143-91a7-097281d4a189', '019bf0b4-d942-73cb-a297-01e119abad64', 1, '{\"JobID\": \"019bf0b4-d942-73cb-a297-01e119abad64\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-24 15:52:22'),
('019bf30b-2c97-7010-8a44-41a00aa0fee7', '019bf30b-2c92-7348-8f5f-3243b154dfcf', 1, '{\"JobID\": \"019bf30b-2c92-7348-8f5f-3243b154dfcf\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 02:45:54'),
('019bf30b-88af-71d5-acde-e942fe273f1b', '019bf30b-88a9-71f7-b3fa-8d9ba9b75f3d', 1, '{\"JobID\": \"019bf30b-88a9-71f7-b3fa-8d9ba9b75f3d\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 02:46:18'),
('019bf343-c568-7289-933a-24366d889597', '019bf343-c55f-73bf-9172-8c4da37e9f0d', 1, '{\"JobID\": \"019bf343-c55f-73bf-9172-8c4da37e9f0d\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e20\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 03:47:43'),
('019bf439-38a8-703c-ac6d-0c16be17c88e', '019bf439-38a3-70e9-be41-644950e759ac', 1, '{\"JobID\": \"019bf439-38a3-70e9-be41-644950e759ac\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 08:15:49'),
('019bf43c-27d1-7073-888e-2deb201997b0', '019bf43c-27cb-719b-adf4-33bc9778b09b', 1, '{\"JobID\": \"019bf43c-27cb-719b-adf4-33bc9778b09b\", \"SexID\": 1, \"Title\": \"Senior Flutter Developer (Fintech & Payment)\", \"MaxAge\": 35, \"MinAge\": 25, \"EndDate\": \"2026-03-10\", \"JobLink\": \"https://tuyendung.job7189.com/senior-flutter-fintech\", \"Benefits\": \"<ul><li>Lương cứng: 35.000.000 - 65.000.000 VNĐ (Net).</li><li>Tháng lương thứ 13 + Thưởng hiệu suất (1-3 tháng lương).</li><li>Làm việc 5 ngày/tuần (Nghỉ T7, CN).</li><li>Gói bảo hiểm sức khỏe PVI dành riêng cho nhân viên Senior.</li><li>Company trip hàng năm tại các resort 5 sao.</li></ul>\", \"Keywords\": \"Flutter, Dart, Mobile Developer, Fintech, BLoC, iOS, Android\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 65000000, \"MinSalary\": 35000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>- Chịu trách nhiệm chính phát triển các tính năng mới trên ứng dụng Job7189 trên nền tảng Mobile (iOS &amp; Android).</p>\\n\\n<p>- Tối ưu hóa hiệu năng ứng dụng, đảm bảo trải nghiệm người dùng mượt mà ở mức 60fps.</p>\\n\\n<p>- Phối hợp với team Backend để tích hợp hệ thống thanh toán và bảo mật vân tay/FaceID.</p>\\n\\n<p>- Mentor và hỗ trợ review code cho các thành viên Junior trong team.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Ít nhất 3 năm kinh nghiệm thực chiến với Flutter &amp; Dart.</li><li>Nắm vững quản lý State bằng BLoC hoặc Riverpod.</li><li>Có kinh nghiệm đưa App lên Store (AppStore/CH Play) và xử lý quy trình review nghiêm ngặt.</li><li>Hiểu sâu về CI/CD cho Mobile (Codemagic, Fastlane hoặc Jenkins).</li><li>Ưu tiên ứng viên có kiến thức về Native (Kotlin/Swift) là một điểm cộng cực lớn.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 08:19:01'),
('019bf51d-3f92-7257-9a41-9225cafdde0d', '019bf51d-3f8d-706f-ab48-59c01680a743', 1, '{\"JobID\": \"019bf51d-3f8d-706f-ab48-59c01680a743\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 12:24:53'),
('019bf54c-ac1a-732b-ab31-d9a679d21258', '019bf54c-ac15-72ec-93b2-e5ecceb1d7a0', 1, '{\"JobID\": \"019bf54c-ac15-72ec-93b2-e5ecceb1d7a0\", \"SexID\": 1, \"Title\": \"Senior Flutter Developer (Fintech & Payment)\", \"MaxAge\": 35, \"MinAge\": 25, \"EndDate\": \"2026-03-10\", \"JobLink\": \"https://tuyendung.job7189.com/senior-flutter-fintech\", \"Benefits\": \"<ul><li>Lương cứng: 35.000.000 - 65.000.000 VNĐ (Net).</li><li>Tháng lương thứ 13 + Thưởng hiệu suất (1-3 tháng lương).</li><li>Làm việc 5 ngày/tuần (Nghỉ T7, CN).</li><li>Gói bảo hiểm sức khỏe PVI dành riêng cho nhân viên Senior.</li><li>Company trip hàng năm tại các resort 5 sao.</li></ul>\", \"Keywords\": \"Flutter, Dart, Mobile Developer, Fintech, BLoC, iOS, Android\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bb544-6383-719b-87f9-e7fe568e0e2\", \"JobTypeID\": 1, \"MaxSalary\": 65000000, \"MinSalary\": 35000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>- Chịu trách nhiệm chính phát triển các tính năng mới trên ứng dụng Job7189 trên nền tảng Mobile (iOS &amp; Android).</p>\\n\\n<p>- Tối ưu hóa hiệu năng ứng dụng, đảm bảo trải nghiệm người dùng mượt mà ở mức 60fps.</p>\\n\\n<p>- Phối hợp với team Backend để tích hợp hệ thống thanh toán và bảo mật vân tay/FaceID.</p>\\n\\n<p>- Mentor và hỗ trợ review code cho các thành viên Junior trong team.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Ít nhất 3 năm kinh nghiệm thực chiến với Flutter &amp; Dart.</li><li>Nắm vững quản lý State bằng BLoC hoặc Riverpod.</li><li>Có kinh nghiệm đưa App lên Store (AppStore/CH Play) và xử lý quy trình review nghiêm ngặt.</li><li>Hiểu sâu về CI/CD cho Mobile (Codemagic, Fastlane hoặc Jenkins).</li><li>Ưu tiên ứng viên có kiến thức về Native (Kotlin/Swift) là một điểm cộng cực lớn.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 13:16:41'),
('019bf54d-bee0-735a-89ac-7d1ac74bebcc', '019bf54d-bedb-72b4-b609-4b41d05fd722', 1, '{\"JobID\": \"019bf54d-bedb-72b4-b609-4b41d05fd722\", \"SexID\": 1, \"Title\": \"Senior Flutter Developer (Fintech & Payment)\", \"MaxAge\": 35, \"MinAge\": 25, \"EndDate\": \"2026-03-10\", \"JobLink\": \"https://tuyendung.job7189.com/senior-flutter-fintech\", \"Benefits\": \"<ul><li>Lương cứng: 35.000.000 - 65.000.000 VNĐ (Net).</li><li>Tháng lương thứ 13 + Thưởng hiệu suất (1-3 tháng lương).</li><li>Làm việc 5 ngày/tuần (Nghỉ T7, CN).</li><li>Gói bảo hiểm sức khỏe PVI dành riêng cho nhân viên Senior.</li><li>Company trip hàng năm tại các resort 5 sao.</li></ul>\", \"Keywords\": \"Flutter, Dart, Mobile Developer, Fintech, BLoC, iOS, Android\", \"OpenDate\": \"2026-01-25\", \"CompanyID\": \"019bf46b-81fd-707a-96bc-0d1b6ba1abf5\", \"JobTypeID\": 1, \"MaxSalary\": 65000000, \"MinSalary\": 35000000, \"CurrencyID\": 1, \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>- Chịu trách nhiệm chính phát triển các tính năng mới trên ứng dụng Job7189 trên nền tảng Mobile (iOS &amp; Android).</p>\\n\\n<p>- Tối ưu hóa hiệu năng ứng dụng, đảm bảo trải nghiệm người dùng mượt mà ở mức 60fps.</p>\\n\\n<p>- Phối hợp với team Backend để tích hợp hệ thống thanh toán và bảo mật vân tay/FaceID.</p>\\n\\n<p>- Mentor và hỗ trợ review code cho các thành viên Junior trong team.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Ít nhất 3 năm kinh nghiệm thực chiến với Flutter &amp; Dart.</li><li>Nắm vững quản lý State bằng BLoC hoặc Riverpod.</li><li>Có kinh nghiệm đưa App lên Store (AppStore/CH Play) và xử lý quy trình review nghiêm ngặt.</li><li>Hiểu sâu về CI/CD cho Mobile (Codemagic, Fastlane hoặc Jenkins).</li><li>Ưu tiên ứng viên có kiến thức về Native (Kotlin/Swift) là một điểm cộng cực lớn.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-25 13:17:51'),
('019bf81a-ce08-72fc-927e-fe44692c8a29', '019bf81a-ce02-7038-982b-4c0bea89ad4a', 1, '{\"JobID\": \"019bf81a-ce02-7038-982b-4c0bea89ad4a\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-26 02:21:04'),
('019bf81b-3d3e-717d-8986-190733a1dd8d', '019bf81b-3d36-7084-85a0-cfaabb9b8007', 1, '{\"JobID\": \"019bf81b-3d36-7084-85a0-cfaabb9b8007\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-26 02:21:33'),
('019bf81b-8a7f-70ab-9841-f2a12babecdb', '019bf81b-8a79-700c-8d85-35599b473bd1', 1, '{\"JobID\": \"019bf81b-8a79-700c-8d85-35599b473bd1\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-26 02:21:53'),
('019bf81b-c9a7-7362-ab6d-966fbb397fc0', '019bf81b-c9a1-7330-b2d8-c6d144cb5c6f', 1, '{\"JobID\": \"019bf81b-c9a1-7330-b2d8-c6d144cb5c6f\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-26 02:22:09'),
('019bf81c-00af-718d-8bbb-fa7a52093101', '019bf81c-00aa-714e-991c-1cd5d6f8e12f', 1, '{\"JobID\": \"019bf81c-00aa-714e-991c-1cd5d6f8e12f\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-26 02:22:23'),
('019bf81c-6f67-70e7-a9b2-4557d304a763', '019bf81c-6f61-725d-9802-1eb9a811620c', 1, '{\"JobID\": \"019bf81c-6f61-725d-9802-1eb9a811620c\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf438-21d0-728f-ad3b-0e8bce2709e4\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019bb2ee-da77-70d9-abfa-d027c98c5341', '2026-01-26 02:22:51'),
('019bf8e4-2812-70ad-b839-a4dd2b426e85', '019bf8e4-280c-71cc-8c4a-9b9eb1be6cc9', 1, '{\"JobID\": \"019bf8e4-280c-71cc-8c4a-9b9eb1be6cc9\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf8db-5938-70c3-b262-85183a4be372\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019be0c2-4f95-7126-ba59-e57bf88f566c', '2026-01-26 06:01:00'),
('019bf8e4-cdfa-70d9-b7cf-868dad0c23eb', '019bf8e4-cdf5-70a8-b5d5-21d647737b47', 1, '{\"JobID\": \"019bf8e4-cdf5-70a8-b5d5-21d647737b47\", \"SexID\": 1, \"Title\": \"Senior Laravel Developer (Microservices)\", \"MaxAge\": 35, \"MinAge\": 24, \"EndDate\": \"2026-02-28\", \"JobLink\": \"https://tuyendung.job7189.com/senior-php\", \"Benefits\": \"<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>\", \"Keywords\": \"PHP, Laravel, Microservices, Kafka, Redis\", \"OpenDate\": \"2026-01-26\", \"CompanyID\": \"019bf8db-5938-70c3-b262-85183a4be372\", \"JobTypeID\": 1, \"MaxSalary\": 55000000, \"MinSalary\": 25000000, \"CurrencyID\": 1, \"PipelineID\": \"019bf4fd-c8bc-724b-9580-5f070064acc3\", \"Description\": \"<p>Mô tả công việc:</p>\\n\\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\\n\\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>\", \"JobSectorID\": 3, \"Requirements\": \"<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>\", \"DegreeLevelID\": 1, \"WorkingTypeID\": 2, \"ContractTypeID\": 5, \"ExperienceYear\": 3, \"detail_address\": \"Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội\"}', 'auto', '019be0c2-4f95-7126-ba59-e57bf88f566c', '2026-01-26 06:01:43');

-- --------------------------------------------------------

--
-- Table structure for table `job_pipelines`
--

CREATE TABLE `job_pipelines` (
  `PipelineID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `Name` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `IsDefault` tinyint(1) DEFAULT '0',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_pipelines`
--

INSERT INTO `job_pipelines` (`PipelineID`, `Name`, `IsDefault`, `CreatedAt`, `UpdatedAt`) VALUES
('019bf4fd-c8bc-724b-9580-5f070064acc3', 'Quy trình IT Developer', 0, '2026-01-25 11:50:32', '2026-01-25 11:50:32'),
('019bf559-550c-73e7-88a1-bdfe3d2dd31b', 'Quy trình IT Developer', 0, '2026-01-25 13:30:31', '2026-01-25 13:30:31');

-- --------------------------------------------------------

--
-- Table structure for table `job_sectors`
--

CREATE TABLE `job_sectors` (
  `JobSectorID` tinyint NOT NULL COMMENT 'ID ngành nghề',
  `JobSectorName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên ngành nghề',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các ngành nghề công việc';

--
-- Dumping data for table `job_sectors`
--

INSERT INTO `job_sectors` (`JobSectorID`, `JobSectorName`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Agriculture and Environment', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(2, 'Construction and Real Estate', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(3, 'Technology and IT', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(4, 'Manufacturing and Production', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(5, 'Healthcare and Life Sciences', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(6, 'Education and Training', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(7, 'Finance and Insurance', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(8, 'Marketing and Advertising', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(9, 'Retail, Sales, and Customer Service', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(10, 'Transportation and Logistics', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(11, 'Sports, Fitness, and Recreation', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(12, 'Media and Entertainment', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(13, 'Hospitality and Tourism', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(14, 'Legal and Professional Services', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(15, 'Administrative', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(16, 'Nonprofit and Charitable Work', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(17, 'Science and Research', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(18, 'Arts and Design', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(19, 'Human Resources (HR)', '2025-06-02 04:43:42', '2025-06-02 04:43:42'),
(20, 'Others', '2025-06-02 04:43:42', '2025-06-02 04:43:42');

-- --------------------------------------------------------

--
-- Table structure for table `job_stats`
--

CREATE TABLE `job_stats` (
  `job_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'FK to job_sub_jds.JobID',
  `view_count` int UNSIGNED NOT NULL DEFAULT '0',
  `apply_count` int UNSIGNED NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_stats`
--

INSERT INTO `job_stats` (`job_id`, `view_count`, `apply_count`, `created_at`, `updated_at`) VALUES
('019bf0b4-d942-73cb-a297-01e119abad64', 0, 0, '2026-01-24 15:56:48', '2026-01-24 15:56:48'),
('019bf43c-27cb-719b-adf4-33bc9778b09b', 0, 0, '2026-01-25 09:38:06', '2026-01-25 09:38:06'),
('019bf51d-3f8d-706f-ab48-59c01680a743', 0, 0, '2026-01-25 12:25:28', '2026-01-25 12:25:28'),
('019bf8e4-cdf5-70a8-b5d5-21d647737b47', 0, 0, '2026-01-26 06:05:19', '2026-01-26 06:05:19');

-- --------------------------------------------------------

--
-- Table structure for table `job_sub_jds`
--

CREATE TABLE `job_sub_jds` (
  `JobID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `status` tinyint UNSIGNED NOT NULL DEFAULT '0',
  `Version` bigint UNSIGNED NOT NULL DEFAULT '1',
  `pending_data` json DEFAULT NULL,
  `PipelineID` char(36) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `CompanyID` varchar(64) COLLATE utf8mb4_unicode_ci NOT NULL,
  `Title` varchar(1000) COLLATE utf8mb4_unicode_ci NOT NULL,
  `slug` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `JobSectorID` tinyint DEFAULT NULL,
  `JobTypeID` tinyint DEFAULT NULL,
  `WorkingTypeID` tinyint DEFAULT NULL,
  `DegreeLevelID` tinyint DEFAULT NULL,
  `ExperienceYear` tinyint DEFAULT NULL,
  `MinSalary` bigint DEFAULT NULL,
  `MaxSalary` bigint DEFAULT NULL,
  `CurrencyID` smallint DEFAULT NULL,
  `OpenDate` date DEFAULT NULL,
  `EndDate` date DEFAULT NULL,
  `Description` longtext COLLATE utf8mb4_unicode_ci,
  `Requirements` longtext COLLATE utf8mb4_unicode_ci,
  `Benefits` longtext COLLATE utf8mb4_unicode_ci,
  `Keywords` varchar(1000) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ContractTypeID` tinyint DEFAULT NULL,
  `SexID` tinyint DEFAULT NULL,
  `MinAge` tinyint DEFAULT NULL,
  `MaxAge` tinyint DEFAULT NULL,
  `FlagID` tinyint DEFAULT NULL,
  `JobLink` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `PictureUrl` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT '',
  `detail_address` varchar(2048) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_sub_jds`
--

INSERT INTO `job_sub_jds` (`JobID`, `status`, `Version`, `pending_data`, `PipelineID`, `CompanyID`, `Title`, `slug`, `JobSectorID`, `JobTypeID`, `WorkingTypeID`, `DegreeLevelID`, `ExperienceYear`, `MinSalary`, `MaxSalary`, `CurrencyID`, `OpenDate`, `EndDate`, `Description`, `Requirements`, `Benefits`, `Keywords`, `ContractTypeID`, `SexID`, `MinAge`, `MaxAge`, `FlagID`, `JobLink`, `PictureUrl`, `detail_address`, `CreatedAt`, `UpdatedAt`) VALUES
('019bf085-30fa-7033-9885-36e6f8d5c5c0', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:00:19', '2026-01-24 15:00:19'),
('019bf085-7689-70cf-8a26-7c14d38dce58', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:00:37', '2026-01-24 15:00:37'),
('019bf091-3211-7080-9c7a-4413b27fe8d2', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:13:26', '2026-01-24 15:13:26'),
('019bf09c-45ed-72dc-badb-6ceecacf1c4a', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:25:32', '2026-01-24 15:25:32'),
('019bf09e-72f5-72f3-9d24-c2ef219ad1d6', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:27:54', '2026-01-24 15:27:54'),
('019bf09e-7c77-7105-b477-c6b2872db327', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:27:57', '2026-01-24 15:27:57'),
('019bf0a0-7a2e-7119-acd3-0141ee125d9e', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:30:07', '2026-01-24 15:30:07'),
('019bf0a2-8025-7157-bfe8-8c195467c70f', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:32:20', '2026-01-24 15:32:20'),
('019bf0a2-8a83-708b-ae22-3fc6fc990a16', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:32:22', '2026-01-24 15:32:22'),
('019bf0a9-de32-7365-a025-ab96c4c44ea6', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:40:22', '2026-01-24 15:40:22'),
('019bf0ad-5d55-72be-940b-3b2f5ea8968a', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:44:12', '2026-01-24 15:44:12'),
('019bf0ae-5968-724e-9773-ea5000384744', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:45:16', '2026-01-24 15:45:16'),
('019bf0b0-36e0-70fb-b3a1-68ceb403db8a', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:47:18', '2026-01-24 15:47:18'),
('019bf0b2-9c8d-72f7-b295-0d44434d3968', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:49:55', '2026-01-24 15:49:55'),
('019bf0b4-ce05-734e-a512-0d0466fe5700', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:52:19', '2026-01-24 15:52:19'),
('019bf0b4-d942-73cb-a297-01e119abad64', 20, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', 'senior-laravel-developer-microservices-vgwgb7', 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-24 15:52:22', '2026-01-24 15:56:48'),
('019bf30b-2c92-7348-8f5f-3243b154dfcf', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 02:45:54', '2026-01-25 02:45:54'),
('019bf30b-88a9-71f7-b3fa-8d9ba9b75f3d', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 02:46:18', '2026-01-25 02:46:18'),
('019bf343-c55f-73bf-9172-8c4da37e9f0d', 10, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e20', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 03:47:43', '2026-01-25 03:47:43'),
('019bf439-38a3-70e9-be41-644950e759ac', 10, 1, NULL, NULL, '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 08:15:49', '2026-01-25 08:16:45'),
('019bf43c-27cb-719b-adf4-33bc9778b09b', 20, 1, NULL, NULL, '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Flutter Developer (Fintech & Payment)', 'senior-flutter-developer-fintech-payment-etfpv8', 3, 1, 2, 1, 3, 35000000, 65000000, 1, '2026-01-25', '2026-03-10', '<p>Mô tả công việc:</p>\n\n<p>- Chịu trách nhiệm chính phát triển các tính năng mới trên ứng dụng Job7189 trên nền tảng Mobile (iOS &amp; Android).</p>\n\n<p>- Tối ưu hóa hiệu năng ứng dụng, đảm bảo trải nghiệm người dùng mượt mà ở mức 60fps.</p>\n\n<p>- Phối hợp với team Backend để tích hợp hệ thống thanh toán và bảo mật vân tay/FaceID.</p>\n\n<p>- Mentor và hỗ trợ review code cho các thành viên Junior trong team.</p>', '<ul><li>Ít nhất 3 năm kinh nghiệm thực chiến với Flutter &amp; Dart.</li><li>Nắm vững quản lý State bằng BLoC hoặc Riverpod.</li><li>Có kinh nghiệm đưa App lên Store (AppStore/CH Play) và xử lý quy trình review nghiêm ngặt.</li><li>Hiểu sâu về CI/CD cho Mobile (Codemagic, Fastlane hoặc Jenkins).</li><li>Ưu tiên ứng viên có kiến thức về Native (Kotlin/Swift) là một điểm cộng cực lớn.</li></ul>', '<ul><li>Lương cứng: 35.000.000 - 65.000.000 VNĐ (Net).</li><li>Tháng lương thứ 13 + Thưởng hiệu suất (1-3 tháng lương).</li><li>Làm việc 5 ngày/tuần (Nghỉ T7, CN).</li><li>Gói bảo hiểm sức khỏe PVI dành riêng cho nhân viên Senior.</li><li>Company trip hàng năm tại các resort 5 sao.</li></ul>', 'Flutter, Dart, Mobile Developer, Fintech, BLoC, iOS, Android', 5, 1, 25, 35, NULL, 'https://tuyendung.job7189.com/senior-flutter-fintech', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 08:19:01', '2026-01-25 09:38:06'),
('019bf51d-3f8d-706f-ab48-59c01680a743', 20, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', 'senior-laravel-developer-microservices-s9oiid', 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-25', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 12:24:53', '2026-01-25 12:25:28'),
('019bf54c-ac15-72ec-93b2-e5ecceb1d7a0', 0, 1, NULL, NULL, '019bb544-6383-719b-87f9-e7fe568e0e2', 'Senior Flutter Developer (Fintech & Payment)', NULL, 3, 1, 2, 1, 3, 35000000, 65000000, 1, NULL, '2026-03-10', '<p>Mô tả công việc:</p>\n\n<p>- Chịu trách nhiệm chính phát triển các tính năng mới trên ứng dụng Job7189 trên nền tảng Mobile (iOS &amp; Android).</p>\n\n<p>- Tối ưu hóa hiệu năng ứng dụng, đảm bảo trải nghiệm người dùng mượt mà ở mức 60fps.</p>\n\n<p>- Phối hợp với team Backend để tích hợp hệ thống thanh toán và bảo mật vân tay/FaceID.</p>\n\n<p>- Mentor và hỗ trợ review code cho các thành viên Junior trong team.</p>', '<ul><li>Ít nhất 3 năm kinh nghiệm thực chiến với Flutter &amp; Dart.</li><li>Nắm vững quản lý State bằng BLoC hoặc Riverpod.</li><li>Có kinh nghiệm đưa App lên Store (AppStore/CH Play) và xử lý quy trình review nghiêm ngặt.</li><li>Hiểu sâu về CI/CD cho Mobile (Codemagic, Fastlane hoặc Jenkins).</li><li>Ưu tiên ứng viên có kiến thức về Native (Kotlin/Swift) là một điểm cộng cực lớn.</li></ul>', '<ul><li>Lương cứng: 35.000.000 - 65.000.000 VNĐ (Net).</li><li>Tháng lương thứ 13 + Thưởng hiệu suất (1-3 tháng lương).</li><li>Làm việc 5 ngày/tuần (Nghỉ T7, CN).</li><li>Gói bảo hiểm sức khỏe PVI dành riêng cho nhân viên Senior.</li><li>Company trip hàng năm tại các resort 5 sao.</li></ul>', 'Flutter, Dart, Mobile Developer, Fintech, BLoC, iOS, Android', 5, 1, 25, 35, NULL, 'https://tuyendung.job7189.com/senior-flutter-fintech', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 13:16:41', '2026-01-25 13:16:41'),
('019bf54d-bedb-72b4-b609-4b41d05fd722', 0, 1, NULL, NULL, '019bf46b-81fd-707a-96bc-0d1b6ba1abf5', 'Senior Flutter Developer (Fintech & Payment)', NULL, 3, 1, 2, 1, 3, 35000000, 65000000, 1, NULL, '2026-03-10', '<p>Mô tả công việc:</p>\n\n<p>- Chịu trách nhiệm chính phát triển các tính năng mới trên ứng dụng Job7189 trên nền tảng Mobile (iOS &amp; Android).</p>\n\n<p>- Tối ưu hóa hiệu năng ứng dụng, đảm bảo trải nghiệm người dùng mượt mà ở mức 60fps.</p>\n\n<p>- Phối hợp với team Backend để tích hợp hệ thống thanh toán và bảo mật vân tay/FaceID.</p>\n\n<p>- Mentor và hỗ trợ review code cho các thành viên Junior trong team.</p>', '<ul><li>Ít nhất 3 năm kinh nghiệm thực chiến với Flutter &amp; Dart.</li><li>Nắm vững quản lý State bằng BLoC hoặc Riverpod.</li><li>Có kinh nghiệm đưa App lên Store (AppStore/CH Play) và xử lý quy trình review nghiêm ngặt.</li><li>Hiểu sâu về CI/CD cho Mobile (Codemagic, Fastlane hoặc Jenkins).</li><li>Ưu tiên ứng viên có kiến thức về Native (Kotlin/Swift) là một điểm cộng cực lớn.</li></ul>', '<ul><li>Lương cứng: 35.000.000 - 65.000.000 VNĐ (Net).</li><li>Tháng lương thứ 13 + Thưởng hiệu suất (1-3 tháng lương).</li><li>Làm việc 5 ngày/tuần (Nghỉ T7, CN).</li><li>Gói bảo hiểm sức khỏe PVI dành riêng cho nhân viên Senior.</li><li>Company trip hàng năm tại các resort 5 sao.</li></ul>', 'Flutter, Dart, Mobile Developer, Fintech, BLoC, iOS, Android', 5, 1, 25, 35, NULL, 'https://tuyendung.job7189.com/senior-flutter-fintech', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-25 13:17:51', '2026-01-25 13:17:51'),
('019bf81a-ce02-7038-982b-4c0bea89ad4a', 10, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 02:21:04', '2026-01-26 02:21:04'),
('019bf81b-3d36-7084-85a0-cfaabb9b8007', 10, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 02:21:33', '2026-01-26 02:21:33'),
('019bf81b-8a79-700c-8d85-35599b473bd1', 10, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 02:21:53', '2026-01-26 02:21:53'),
('019bf81b-c9a1-7330-b2d8-c6d144cb5c6f', 10, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 02:22:09', '2026-01-26 02:22:09'),
('019bf81c-00aa-714e-991c-1cd5d6f8e12f', 10, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 02:22:23', '2026-01-26 02:22:23'),
('019bf81c-6f61-725d-9802-1eb9a811620c', 10, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 02:22:51', '2026-01-26 02:22:51'),
('019bf8e4-280c-71cc-8c4a-9b9eb1be6cc9', 10, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf8db-5938-70c3-b262-85183a4be372', 'Senior Laravel Developer (Microservices)', NULL, 3, 1, 2, 1, 3, 25000000, 55000000, 1, NULL, '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 06:01:00', '2026-01-26 06:01:00'),
('019bf8e4-cdf5-70a8-b5d5-21d647737b47', 20, 1, NULL, '019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf8db-5938-70c3-b262-85183a4be372', 'Senior Laravel Developer (Microservices)', 'senior-laravel-developer-microservices-wff6xy', 3, 1, 2, 1, 3, 25000000, 55000000, 1, '2026-01-26', '2026-02-28', '<p>Mô tả công việc:</p>\n\n<p>Tham gia phát triển hệ thống Job7189 từ Monolith sang Microservices.</p>\n\n<p>Làm việc với Kubernetes, Kafka, Kong Gateway.</p>', '<ul><li>Thành thạo PHP 8.2+, Laravel 10/11.</li><li>Có kinh nghiệm với Docker, K8s.</li><li>Hiểu sâu về Design Patterns, SOLID.</li></ul>', '<ul><li>Lương cạnh tranh: $1000 - $3000.</li><li>Thưởng dự án, thưởng tết.</li><li>Review lương 2 lần/năm.</li></ul>', 'PHP, Laravel, Microservices, Kafka, Redis', 5, 1, 24, 35, NULL, 'https://tuyendung.job7189.com/senior-php', '', 'Tầng 72, Tòa nhà Keangnam, Phạm Hùng, Hà Nội', '2026-01-26 06:01:43', '2026-01-26 06:05:19');

-- --------------------------------------------------------

--
-- Table structure for table `job_types`
--

CREATE TABLE `job_types` (
  `JobTypeID` tinyint NOT NULL COMMENT 'ID loại công việc',
  `JobTypeName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên loại công việc. VD fulltime, partime,',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các loại hình công việc';

--
-- Dumping data for table `job_types`
--

INSERT INTO `job_types` (`JobTypeID`, `JobTypeName`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Full-Time', '2025-06-02 03:12:09', '2025-06-02 03:12:09'),
(2, 'Part-Time', '2025-06-02 03:12:09', '2025-06-02 03:12:09'),
(3, 'Remote', '2025-06-02 03:12:09', '2025-06-02 03:12:09'),
(4, 'Internship', '2025-06-02 03:12:09', '2025-06-02 03:12:09'),
(5, 'Freelance', '2025-06-02 03:12:09', '2025-06-02 03:12:09'),
(6, 'Other', '2025-06-26 18:06:12', '2025-06-26 18:06:12');

-- --------------------------------------------------------

--
-- Table structure for table `job_workingtypes`
--

CREATE TABLE `job_workingtypes` (
  `WorkingTypeID` tinyint NOT NULL COMMENT 'ID hình thức làm việc',
  `WorkingTypeName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên hình thức làm việc. VD remote, hybrid,...',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các hình thức làm việc';

--
-- Dumping data for table `job_workingtypes`
--

INSERT INTO `job_workingtypes` (`WorkingTypeID`, `WorkingTypeName`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'On-site', '2025-06-08 03:12:52', '2025-06-08 03:12:52'),
(2, 'Remote', '2025-06-08 03:12:52', '2025-06-08 03:12:52'),
(3, 'Hybrid', '2025-06-08 03:12:52', '2025-06-08 03:12:52');

-- --------------------------------------------------------

--
-- Table structure for table `per_jobs`
--

CREATE TABLE `per_jobs` (
  `job_id` char(24) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `recruiter_id` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `job_permissions` bigint UNSIGNED NOT NULL DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

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
('019bad5c-36f4-728d-a2af-4d8f69c4aec3', '1ca9861b-2d3b-45b2-8dad-04badcffaabc', 'baophungthai9@gmail.com', 'bảo phùng thái', 'recruiter', '2026-01-24 09:06:49', '2026-01-24 09:06:49'),
('019bb2ee-da77-70d9-abfa-d027c98c5341', 'bc30bc63-e21c-4917-a1d7-94a253ecbfa4', 'baophungthai2@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-24 03:40:38', '2026-01-25 08:14:21'),
('019be0c2-4f95-7126-ba59-e57bf88f566c', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Thai Bao', 'recruiter', '2026-01-26 05:40:07', '2026-01-26 05:40:07'),
('019bee32-1551-70db-868d-8bbe530c43ee', '99e70aa7-823a-4791-971c-42c27500e47b', 'baophungthai3@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-24 04:31:54', '2026-01-24 08:39:14'),
('019bf0cf-e398-72fd-9741-4f03d0ccfa34', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Bao', 'candidate', '2026-01-24 16:25:39', '2026-01-24 16:25:39'),
('019bf2bc-619c-72b6-a8d2-80c3fbf4c5a7', 'ca6b9e8d-6b48-45bf-a94d-507aa1f7a6de', 'kidmardesu@gmail.com', 'sssssssssssssss', 'recruiter', '2026-01-25 01:55:27', '2026-01-25 09:10:44'),
('019bf453-e9a5-70f0-8d37-24664fad38e9', '0acabd04-636a-4830-bccb-bfac2b050b9b', 'baophungthai7@gmail.com', 'Job seeker', 'candidate', '2026-01-25 08:45:29', '2026-01-25 08:45:29'),
('019bf581-f343-73be-b77a-3296ab6138e4', 'c9dfafd3-570a-4d30-aa21-3ad98d7e8dc5', 'nguyenzdiz@gmail.com', 'adminssssss', 'recruiter', '2026-01-25 14:15:49', '2026-01-25 14:15:49');

-- --------------------------------------------------------

--
-- Table structure for table `sys_cities`
--

CREATE TABLE `sys_cities` (
  `CityID` int NOT NULL COMMENT 'ID thành phố',
  `CountryID` int NOT NULL COMMENT 'ID quốc gia',
  `CityName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên thành phố',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật',
  `Order` tinyint NOT NULL DEFAULT '0'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu danh sách thành phố';

--
-- Dumping data for table `sys_cities`
--

INSERT INTO `sys_cities` (`CityID`, `CountryID`, `CityName`, `CreatedAt`, `UpdatedAt`, `Order`) VALUES
(1, 84, 'Hà Nội', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(2, 84, 'Hà Giang', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(4, 84, 'Cao Bằng', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(6, 84, 'Bắc Kạn', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(8, 84, 'Tuyên Quang', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(10, 84, 'Lào Cai', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(11, 84, 'Điện Biên', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(12, 84, 'Lai Châu', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(14, 84, 'Sơn La', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(15, 84, 'Yên Bái', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(17, 84, 'Hoà Bình', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(19, 84, 'Thái Nguyên', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(20, 84, 'Lạng Sơn', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(22, 84, 'Quảng Ninh', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(24, 84, 'Bắc Giang', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(25, 84, 'Phú Thọ', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(26, 84, 'Vĩnh Phúc', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(27, 84, 'Bắc Ninh', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(30, 84, 'Hải Dương', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(31, 84, 'Hải Phòng', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(33, 84, 'Hưng Yên', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(34, 84, 'Thái Bình', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(35, 84, 'Hà Nam', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(36, 84, 'Nam Định', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(37, 84, 'Ninh Bình', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(38, 84, 'Thanh Hóa', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(40, 84, 'Nghệ An', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(42, 84, 'Hà Tĩnh', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(44, 84, 'Quảng Bình', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(45, 84, 'Quảng Trị', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(46, 84, 'Huế', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(48, 84, 'Đà Nẵng', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(49, 84, 'Quảng Nam', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(51, 84, 'Quảng Ngãi', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(52, 84, 'Bình Định', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(54, 84, 'Phú Yên', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(56, 84, 'Khánh Hòa', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(58, 84, 'Ninh Thuận', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(60, 84, 'Bình Thuận', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(62, 84, 'Kon Tum', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(64, 84, 'Gia Lai', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(66, 84, 'Đắk Lắk', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(67, 84, 'Đắk Nông', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(68, 84, 'Lâm Đồng', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(70, 84, 'Bình Phước', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(72, 84, 'Tây Ninh', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(74, 84, 'Bình Dương', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(75, 84, 'Đồng Nai', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(77, 84, 'Bà Rịa - Vũng Tàu', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(79, 84, 'Hồ Chí Minh', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(80, 84, 'Long An', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(82, 84, 'Tiền Giang', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(83, 84, 'Bến Tre', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(84, 84, 'Trà Vinh', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(86, 84, 'Vĩnh Long', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(87, 84, 'Đồng Tháp', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(89, 84, 'An Giang', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(91, 84, 'Kiên Giang', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(92, 84, 'Cần Thơ', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(93, 84, 'Hậu Giang', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(94, 84, 'Sóc Trăng', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(95, 84, 'Bạc Liêu', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0),
(96, 84, 'Cà Mau', '2025-06-02 02:59:22', '2025-06-02 02:59:22', 0);

-- --------------------------------------------------------

--
-- Table structure for table `sys_countries`
--

CREATE TABLE `sys_countries` (
  `CountryID` int NOT NULL COMMENT 'ID quốc gia',
  `CountryName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên quốc gia',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu danh sách quốc gia';

--
-- Dumping data for table `sys_countries`
--

INSERT INTO `sys_countries` (`CountryID`, `CountryName`, `CreatedAt`, `UpdatedAt`) VALUES
(84, 'Vietnam', '2025-06-02 02:58:57', '2025-06-02 02:58:57');

-- --------------------------------------------------------

--
-- Table structure for table `sys_currencies`
--

CREATE TABLE `sys_currencies` (
  `CurrencyID` smallint NOT NULL COMMENT 'ID đơn vị tiền tệ',
  `CurrencyCode` char(3) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Mã tiền tệ theo chuẩn ISO 4217',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các đơn vị tiền tệ';

--
-- Dumping data for table `sys_currencies`
--

INSERT INTO `sys_currencies` (`CurrencyID`, `CurrencyCode`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'VND', '2025-06-02 06:05:35', '2025-06-02 06:05:35');

-- --------------------------------------------------------

--
-- Table structure for table `sys_districts`
--

CREATE TABLE `sys_districts` (
  `DistrictID` int NOT NULL COMMENT 'ID quận/huyện',
  `CityID` int NOT NULL COMMENT 'ID thành phố',
  `DistrictName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên quận/huyện',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu danh sách quận/huyện';

--
-- Dumping data for table `sys_districts`
--

INSERT INTO `sys_districts` (`DistrictID`, `CityID`, `DistrictName`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 1, 'Quận Ba Đình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(2, 1, 'Quận Hoàn Kiếm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(3, 1, 'Quận Tây Hồ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(4, 1, 'Quận Long Biên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(5, 1, 'Quận Cầu Giấy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(6, 1, 'Quận Đống Đa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(7, 1, 'Quận Hai Bà Trưng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(8, 1, 'Quận Hoàng Mai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(9, 1, 'Quận Thanh Xuân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(16, 1, 'Huyện Sóc Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(17, 1, 'Huyện Đông Anh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(18, 1, 'Huyện Gia Lâm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(19, 1, 'Quận Nam Từ Liêm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(20, 1, 'Huyện Thanh Trì', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(21, 1, 'Quận Bắc Từ Liêm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(24, 2, 'Thành phố Hà Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(26, 2, 'Huyện Đồng Văn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(27, 2, 'Huyện Mèo Vạc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(28, 2, 'Huyện Yên Minh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(29, 2, 'Huyện Quản Bạ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(30, 2, 'Huyện Vị Xuyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(31, 2, 'Huyện Bắc Mê', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(32, 2, 'Huyện Hoàng Su Phì', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(33, 2, 'Huyện Xín Mần', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(34, 2, 'Huyện Bắc Quang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(35, 2, 'Huyện Quang Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(40, 4, 'Thành phố Cao Bằng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(42, 4, 'Huyện Bảo Lâm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(43, 4, 'Huyện Bảo Lạc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(45, 4, 'Huyện Hà Quảng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(47, 4, 'Huyện Trùng Khánh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(48, 4, 'Huyện Hạ Lang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(49, 4, 'Huyện Quảng Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(51, 4, 'Huyện Hoà An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(52, 4, 'Huyện Nguyên Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(53, 4, 'Huyện Thạch An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(58, 6, 'Thành Phố Bắc Kạn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(60, 6, 'Huyện Pác Nặm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(61, 6, 'Huyện Ba Bể', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(62, 6, 'Huyện Ngân Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(63, 6, 'Huyện Bạch Thông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(64, 6, 'Huyện Chợ Đồn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(65, 6, 'Huyện Chợ Mới', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(66, 6, 'Huyện Na Rì', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(70, 8, 'Thành phố Tuyên Quang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(71, 8, 'Huyện Lâm Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(72, 8, 'Huyện Na Hang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(73, 8, 'Huyện Chiêm Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(74, 8, 'Huyện Hàm Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(75, 8, 'Huyện Yên Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(76, 8, 'Huyện Sơn Dương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(80, 10, 'Thành phố Lào Cai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(82, 10, 'Huyện Bát Xát', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(83, 10, 'Huyện Mường Khương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(84, 10, 'Huyện Si Ma Cai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(85, 10, 'Huyện Bắc Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(86, 10, 'Huyện Bảo Thắng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(87, 10, 'Huyện Bảo Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(88, 10, 'Thị xã Sa Pa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(89, 10, 'Huyện Văn Bàn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(94, 11, 'Thành phố Điện Biên Phủ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(95, 11, 'Thị Xã Mường Lay', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(96, 11, 'Huyện Mường Nhé', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(97, 11, 'Huyện Mường Chà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(98, 11, 'Huyện Tủa Chùa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(99, 11, 'Huyện Tuần Giáo', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(100, 11, 'Huyện Điện Biên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(101, 11, 'Huyện Điện Biên Đông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(102, 11, 'Huyện Mường Ảng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(103, 11, 'Huyện Nậm Pồ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(105, 12, 'Thành phố Lai Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(106, 12, 'Huyện Tam Đường', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(107, 12, 'Huyện Mường Tè', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(108, 12, 'Huyện Sìn Hồ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(109, 12, 'Huyện Phong Thổ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(110, 12, 'Huyện Than Uyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(111, 12, 'Huyện Tân Uyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(112, 12, 'Huyện Nậm Nhùn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(116, 14, 'Thành phố Sơn La', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(118, 14, 'Huyện Quỳnh Nhai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(119, 14, 'Huyện Thuận Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(120, 14, 'Huyện Mường La', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(121, 14, 'Huyện Bắc Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(122, 14, 'Huyện Phù Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(123, 14, 'Thị xã Mộc Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(124, 14, 'Huyện Yên Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(125, 14, 'Huyện Mai Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(126, 14, 'Huyện Sông Mã', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(127, 14, 'Huyện Sốp Cộp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(128, 14, 'Huyện Vân Hồ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(132, 15, 'Thành phố Yên Bái', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(133, 15, 'Thị xã Nghĩa Lộ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(135, 15, 'Huyện Lục Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(136, 15, 'Huyện Văn Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(137, 15, 'Huyện Mù Căng Chải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(138, 15, 'Huyện Trấn Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(139, 15, 'Huyện Trạm Tấu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(140, 15, 'Huyện Văn Chấn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(141, 15, 'Huyện Yên Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(148, 17, 'Thành phố Hòa Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(150, 17, 'Huyện Đà Bắc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(152, 17, 'Huyện Lương Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(153, 17, 'Huyện Kim Bôi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(154, 17, 'Huyện Cao Phong', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(155, 17, 'Huyện Tân Lạc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(156, 17, 'Huyện Mai Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(157, 17, 'Huyện Lạc Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(158, 17, 'Huyện Yên Thủy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(159, 17, 'Huyện Lạc Thủy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(164, 19, 'Thành phố Thái Nguyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(165, 19, 'Thành phố Sông Công', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(167, 19, 'Huyện Định Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(168, 19, 'Huyện Phú Lương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(169, 19, 'Huyện Đồng Hỷ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(170, 19, 'Huyện Võ Nhai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(171, 19, 'Huyện Đại Từ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(172, 19, 'Thành phố Phổ Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(173, 19, 'Huyện Phú Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(178, 20, 'Thành phố Lạng Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(180, 20, 'Huyện Tràng Định', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(181, 20, 'Huyện Bình Gia', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(182, 20, 'Huyện Văn Lãng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(183, 20, 'Huyện Cao Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(184, 20, 'Huyện Văn Quan', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(185, 20, 'Huyện Bắc Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(186, 20, 'Huyện Hữu Lũng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(187, 20, 'Huyện Chi Lăng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(188, 20, 'Huyện Lộc Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(189, 20, 'Huyện Đình Lập', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(193, 22, 'Thành phố Hạ Long', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(194, 22, 'Thành phố Móng Cái', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(195, 22, 'Thành phố Cẩm Phả', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(196, 22, 'Thành phố Uông Bí', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(198, 22, 'Huyện Bình Liêu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(199, 22, 'Huyện Tiên Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(200, 22, 'Huyện Đầm Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(201, 22, 'Huyện Hải Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(202, 22, 'Huyện Ba Chẽ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(203, 22, 'Huyện Vân Đồn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(205, 22, 'Thành phố Đông Triều', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(206, 22, 'Thị xã Quảng Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(207, 22, 'Huyện Cô Tô', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(213, 24, 'Thành phố Bắc Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(215, 24, 'Huyện Yên Thế', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(216, 24, 'Huyện Tân Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(217, 24, 'Huyện Lạng Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(218, 24, 'Huyện Lục Nam', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(219, 24, 'Huyện Lục Ngạn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(220, 24, 'Huyện Sơn Động', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(222, 24, 'Thị Xã Việt Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(223, 24, 'Huyện Hiệp Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(224, 24, 'Thị xã Chũ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(227, 25, 'Thành phố Việt Trì', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(228, 25, 'Thị xã Phú Thọ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(230, 25, 'Huyện Đoan Hùng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(231, 25, 'Huyện Hạ Hoà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(232, 25, 'Huyện Thanh Ba', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(233, 25, 'Huyện Phù Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(234, 25, 'Huyện Yên Lập', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(235, 25, 'Huyện Cẩm Khê', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(236, 25, 'Huyện Tam Nông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(237, 25, 'Huyện Lâm Thao', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(238, 25, 'Huyện Thanh Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(239, 25, 'Huyện Thanh Thuỷ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(240, 25, 'Huyện Tân Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(243, 26, 'Thành phố Vĩnh Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(244, 26, 'Thành phố Phúc Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(246, 26, 'Huyện Lập Thạch', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(247, 26, 'Huyện Tam Dương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(248, 26, 'Huyện Tam Đảo', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(249, 26, 'Huyện Bình Xuyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(250, 1, 'Huyện Mê Linh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(251, 26, 'Huyện Yên Lạc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(252, 26, 'Huyện Vĩnh Tường', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(253, 26, 'Huyện Sông Lô', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(256, 27, 'Thành phố Bắc Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(258, 27, 'Huyện Yên Phong', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(259, 27, 'Thị xã Quế Võ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(260, 27, 'Huyện Tiên Du', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(261, 27, 'Thành phố Từ Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(262, 27, 'Thị xã Thuận Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(263, 27, 'Huyện Gia Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(264, 27, 'Huyện Lương Tài', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(268, 1, 'Quận Hà Đông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(269, 1, 'Thị xã Sơn Tây', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(271, 1, 'Huyện Ba Vì', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(272, 1, 'Huyện Phúc Thọ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(273, 1, 'Huyện Đan Phượng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(274, 1, 'Huyện Hoài Đức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(275, 1, 'Huyện Quốc Oai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(276, 1, 'Huyện Thạch Thất', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(277, 1, 'Huyện Chương Mỹ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(278, 1, 'Huyện Thanh Oai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(279, 1, 'Huyện Thường Tín', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(280, 1, 'Huyện Phú Xuyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(281, 1, 'Huyện Ứng Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(282, 1, 'Huyện Mỹ Đức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(288, 30, 'Thành phố Hải Dương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(290, 30, 'Thành phố Chí Linh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(291, 30, 'Huyện Nam Sách', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(292, 30, 'Thị xã Kinh Môn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(293, 30, 'Huyện Kim Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(294, 30, 'Huyện Thanh Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(295, 30, 'Huyện Cẩm Giàng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(296, 30, 'Huyện Bình Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(297, 30, 'Huyện Gia Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(298, 30, 'Huyện Tứ Kỳ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(299, 30, 'Huyện Ninh Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(300, 30, 'Huyện Thanh Miện', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(303, 31, 'Quận Hồng Bàng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(304, 31, 'Quận Ngô Quyền', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(305, 31, 'Quận Lê Chân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(306, 31, 'Quận Hải An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(307, 31, 'Quận Kiến An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(308, 31, 'Quận Đồ Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(309, 31, 'Quận Dương Kinh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(311, 31, 'Thành phố Thuỷ Nguyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(312, 31, 'Quận An Dương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(313, 31, 'Huyện An Lão', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(314, 31, 'Huyện Kiến Thuỵ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(315, 31, 'Huyện Tiên Lãng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(316, 31, 'Huyện Vĩnh Bảo', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(317, 31, 'Huyện Cát Hải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(318, 31, 'Huyện Bạch Long Vĩ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(323, 33, 'Thành phố Hưng Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(325, 33, 'Huyện Văn Lâm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(326, 33, 'Huyện Văn Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(327, 33, 'Huyện Yên Mỹ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(328, 33, 'Thị xã Mỹ Hào', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(329, 33, 'Huyện Ân Thi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(330, 33, 'Huyện Khoái Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(331, 33, 'Huyện Kim Động', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(332, 33, 'Huyện Tiên Lữ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(333, 33, 'Huyện Phù Cừ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(336, 34, 'Thành phố Thái Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(338, 34, 'Huyện Quỳnh Phụ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(339, 34, 'Huyện Hưng Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(340, 34, 'Huyện Đông Hưng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(341, 34, 'Huyện Thái Thụy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(342, 34, 'Huyện Tiền Hải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(343, 34, 'Huyện Kiến Xương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(344, 34, 'Huyện Vũ Thư', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(347, 35, 'Thành phố Phủ Lý', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(349, 35, 'Thị xã Duy Tiên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(350, 35, 'Thị xã Kim Bảng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(351, 35, 'Huyện Thanh Liêm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(352, 35, 'Huyện Bình Lục', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(353, 35, 'Huyện Lý Nhân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(356, 36, 'Thành phố Nam Định', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(359, 36, 'Huyện Vụ Bản', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(360, 36, 'Huyện Ý Yên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(361, 36, 'Huyện Nghĩa Hưng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(362, 36, 'Huyện Nam Trực', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(363, 36, 'Huyện Trực Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(364, 36, 'Huyện Xuân Trường', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(365, 36, 'Huyện Giao Thủy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(366, 36, 'Huyện Hải Hậu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(370, 37, 'Thành phố Tam Điệp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(372, 37, 'Huyện Nho Quan', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(373, 37, 'Huyện Gia Viễn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(374, 37, 'Thành phố Hoa Lư', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(375, 37, 'Huyện Yên Khánh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(376, 37, 'Huyện Kim Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(377, 37, 'Huyện Yên Mô', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(380, 38, 'Thành phố Thanh Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(381, 38, 'Thị xã Bỉm Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(382, 38, 'Thành phố Sầm Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(384, 38, 'Huyện Mường Lát', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(385, 38, 'Huyện Quan Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(386, 38, 'Huyện Bá Thước', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(387, 38, 'Huyện Quan Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(388, 38, 'Huyện Lang Chánh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(389, 38, 'Huyện Ngọc Lặc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(390, 38, 'Huyện Cẩm Thủy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(391, 38, 'Huyện Thạch Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(392, 38, 'Huyện Hà Trung', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(393, 38, 'Huyện Vĩnh Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(394, 38, 'Huyện Yên Định', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(395, 38, 'Huyện Thọ Xuân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(396, 38, 'Huyện Thường Xuân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(397, 38, 'Huyện Triệu Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(398, 38, 'Huyện Thiệu Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(399, 38, 'Huyện Hoằng Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(400, 38, 'Huyện Hậu Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(401, 38, 'Huyện Nga Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(402, 38, 'Huyện Như Xuân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(403, 38, 'Huyện Như Thanh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(404, 38, 'Huyện Nông Cống', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(406, 38, 'Huyện Quảng Xương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(407, 38, 'Thị xã Nghi Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(412, 40, 'Thành phố Vinh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(414, 40, 'Thị xã Thái Hoà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(415, 40, 'Huyện Quế Phong', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(416, 40, 'Huyện Quỳ Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(417, 40, 'Huyện Kỳ Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(418, 40, 'Huyện Tương Dương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(419, 40, 'Huyện Nghĩa Đàn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(420, 40, 'Huyện Quỳ Hợp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(421, 40, 'Huyện Quỳnh Lưu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(422, 40, 'Huyện Con Cuông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(423, 40, 'Huyện Tân Kỳ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(424, 40, 'Huyện Anh Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(425, 40, 'Huyện Diễn Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(426, 40, 'Huyện Yên Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(427, 40, 'Huyện Đô Lương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(428, 40, 'Huyện Thanh Chương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(429, 40, 'Huyện Nghi Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(430, 40, 'Huyện Nam Đàn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(431, 40, 'Huyện Hưng Nguyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(432, 40, 'Thị xã Hoàng Mai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(436, 42, 'Thành phố Hà Tĩnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(437, 42, 'Thị xã Hồng Lĩnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(439, 42, 'Huyện Hương Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(440, 42, 'Huyện Đức Thọ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(441, 42, 'Huyện Vũ Quang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(442, 42, 'Huyện Nghi Xuân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(443, 42, 'Huyện Can Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(444, 42, 'Huyện Hương Khê', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(445, 42, 'Huyện Thạch Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(446, 42, 'Huyện Cẩm Xuyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(447, 42, 'Huyện Kỳ Anh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(449, 42, 'Thị xã Kỳ Anh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(450, 44, 'Thành Phố Đồng Hới', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(452, 44, 'Huyện Minh Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(453, 44, 'Huyện Tuyên Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(454, 44, 'Huyện Quảng Trạch', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(455, 44, 'Huyện Bố Trạch', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(456, 44, 'Huyện Quảng Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(457, 44, 'Huyện Lệ Thủy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(458, 44, 'Thị xã Ba Đồn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(461, 45, 'Thành phố Đông Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(462, 45, 'Thị xã Quảng Trị', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(464, 45, 'Huyện Vĩnh Linh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(465, 45, 'Huyện Hướng Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(466, 45, 'Huyện Gio Linh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(467, 45, 'Huyện Đa Krông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(468, 45, 'Huyện Cam Lộ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(469, 45, 'Huyện Triệu Phong', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(470, 45, 'Huyện Hải Lăng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(471, 45, 'Huyện Cồn Cỏ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(474, 46, 'Quận Thuận Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(475, 46, 'Quận Phú Xuân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(476, 46, 'Thị xã Phong Điền', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(477, 46, 'Huyện Quảng Điền', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(478, 46, 'Huyện Phú Vang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(479, 46, 'Thị xã Hương Thủy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(480, 46, 'Thị xã Hương Trà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(481, 46, 'Huyện A Lưới', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(482, 46, 'Huyện Phú Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(490, 48, 'Quận Liên Chiểu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(491, 48, 'Quận Thanh Khê', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(492, 48, 'Quận Hải Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(493, 48, 'Quận Sơn Trà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(494, 48, 'Quận Ngũ Hành Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(495, 48, 'Quận Cẩm Lệ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(497, 48, 'Huyện Hòa Vang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(498, 48, 'Huyện Hoàng Sa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(502, 49, 'Thành phố Tam Kỳ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(503, 49, 'Thành phố Hội An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(504, 49, 'Huyện Tây Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(505, 49, 'Huyện Đông Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(506, 49, 'Huyện Đại Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(507, 49, 'Thị xã Điện Bàn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(508, 49, 'Huyện Duy Xuyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(509, 49, 'Huyện Quế Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(510, 49, 'Huyện Nam Giang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(511, 49, 'Huyện Phước Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(512, 49, 'Huyện Hiệp Đức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(513, 49, 'Huyện Thăng Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(514, 49, 'Huyện Tiên Phước', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(515, 49, 'Huyện Bắc Trà My', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(516, 49, 'Huyện Nam Trà My', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(517, 49, 'Huyện Núi Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(518, 49, 'Huyện Phú Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(522, 51, 'Thành phố Quảng Ngãi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(524, 51, 'Huyện Bình Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(525, 51, 'Huyện Trà Bồng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(527, 51, 'Huyện Sơn Tịnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(528, 51, 'Huyện Tư Nghĩa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(529, 51, 'Huyện Sơn Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(530, 51, 'Huyện Sơn Tây', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(531, 51, 'Huyện Minh Long', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(532, 51, 'Huyện Nghĩa Hành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(533, 51, 'Huyện Mộ Đức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(534, 51, 'Thị xã Đức Phổ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(535, 51, 'Huyện Ba Tơ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(536, 51, 'Huyện Lý Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(540, 52, 'Thành phố Quy Nhơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(542, 52, 'Huyện An Lão', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(543, 52, 'Thị xã Hoài Nhơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(544, 52, 'Huyện Hoài Ân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(545, 52, 'Huyện Phù Mỹ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(546, 52, 'Huyện Vĩnh Thạnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(547, 52, 'Huyện Tây Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(548, 52, 'Huyện Phù Cát', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(549, 52, 'Thị xã An Nhơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(550, 52, 'Huyện Tuy Phước', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(551, 52, 'Huyện Vân Canh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(555, 54, 'Thành phố Tuy Hoà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(557, 54, 'Thị xã Sông Cầu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(558, 54, 'Huyện Đồng Xuân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(559, 54, 'Huyện Tuy An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(560, 54, 'Huyện Sơn Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(561, 54, 'Huyện Sông Hinh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(562, 54, 'Huyện Tây Hoà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(563, 54, 'Huyện Phú Hoà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(564, 54, 'Thị xã Đông Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(568, 56, 'Thành phố Nha Trang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(569, 56, 'Thành phố Cam Ranh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(570, 56, 'Huyện Cam Lâm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(571, 56, 'Huyện Vạn Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(572, 56, 'Thị xã Ninh Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(573, 56, 'Huyện Khánh Vĩnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(574, 56, 'Huyện Diên Khánh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(575, 56, 'Huyện Khánh Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(576, 56, 'Huyện Trường Sa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(582, 58, 'Thành phố Phan Rang-Tháp Chàm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(584, 58, 'Huyện Bác Ái', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(585, 58, 'Huyện Ninh Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(586, 58, 'Huyện Ninh Hải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(587, 58, 'Huyện Ninh Phước', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(588, 58, 'Huyện Thuận Bắc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(589, 58, 'Huyện Thuận Nam', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(593, 60, 'Thành phố Phan Thiết', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(594, 60, 'Thị xã La Gi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(595, 60, 'Huyện Tuy Phong', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(596, 60, 'Huyện Bắc Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(597, 60, 'Huyện Hàm Thuận Bắc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(598, 60, 'Huyện Hàm Thuận Nam', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(599, 60, 'Huyện Tánh Linh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(600, 60, 'Huyện Đức Linh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(601, 60, 'Huyện Hàm Tân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(602, 60, 'Huyện Phú Quí', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(608, 62, 'Thành phố Kon Tum', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(610, 62, 'Huyện Đắk Glei', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(611, 62, 'Huyện Ngọc Hồi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(612, 62, 'Huyện Đắk Tô', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(613, 62, 'Huyện Kon Plông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(614, 62, 'Huyện Kon Rẫy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(615, 62, 'Huyện Đắk Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(616, 62, 'Huyện Sa Thầy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(617, 62, 'Huyện Tu Mơ Rông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(618, 62, 'Huyện Ia H\' Drai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(622, 64, 'Thành phố Pleiku', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(623, 64, 'Thị xã An Khê', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(624, 64, 'Thị xã Ayun Pa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(625, 64, 'Huyện KBang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(626, 64, 'Huyện Đăk Đoa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(627, 64, 'Huyện Chư Păh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(628, 64, 'Huyện Ia Grai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(629, 64, 'Huyện Mang Yang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(630, 64, 'Huyện Kông Chro', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(631, 64, 'Huyện Đức Cơ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(632, 64, 'Huyện Chư Prông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(633, 64, 'Huyện Chư Sê', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(634, 64, 'Huyện Đăk Pơ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(635, 64, 'Huyện Ia Pa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(637, 64, 'Huyện Krông Pa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(638, 64, 'Huyện Phú Thiện', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(639, 64, 'Huyện Chư Pưh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(643, 66, 'Thành phố Buôn Ma Thuột', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(644, 66, 'Thị Xã Buôn Hồ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(645, 66, 'Huyện Ea H\'leo', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(646, 66, 'Huyện Ea Súp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(647, 66, 'Huyện Buôn Đôn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(648, 66, 'Huyện Cư M\'gar', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(649, 66, 'Huyện Krông Búk', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(650, 66, 'Huyện Krông Năng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(651, 66, 'Huyện Ea Kar', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(652, 66, 'Huyện M\'Đrắk', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(653, 66, 'Huyện Krông Bông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(654, 66, 'Huyện Krông Pắc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(655, 66, 'Huyện Krông A Na', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(656, 66, 'Huyện Lắk', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(657, 66, 'Huyện Cư Kuin', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(660, 67, 'Thành phố Gia Nghĩa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(661, 67, 'Huyện Đăk Glong', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(662, 67, 'Huyện Cư Jút', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(663, 67, 'Huyện Đắk Mil', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(664, 67, 'Huyện Krông Nô', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(665, 67, 'Huyện Đắk Song', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(666, 67, 'Huyện Đắk R\'Lấp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(667, 67, 'Huyện Tuy Đức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(672, 68, 'Thành phố Đà Lạt', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(673, 68, 'Thành phố Bảo Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(674, 68, 'Huyện Đam Rông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(675, 68, 'Huyện Lạc Dương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(676, 68, 'Huyện Lâm Hà', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(677, 68, 'Huyện Đơn Dương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(678, 68, 'Huyện Đức Trọng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(679, 68, 'Huyện Di Linh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(680, 68, 'Huyện Bảo Lâm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(682, 68, 'Huyện Đạ Huoai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(688, 70, 'Thị xã Phước Long', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(689, 70, 'Thành phố Đồng Xoài', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(690, 70, 'Thị xã Bình Long', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(691, 70, 'Huyện Bù Gia Mập', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(692, 70, 'Huyện Lộc Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(693, 70, 'Huyện Bù Đốp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(694, 70, 'Huyện Hớn Quản', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(695, 70, 'Huyện Đồng Phú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(696, 70, 'Huyện Bù Đăng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(697, 70, 'Thị xã Chơn Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(698, 70, 'Huyện Phú Riềng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(703, 72, 'Thành phố Tây Ninh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(705, 72, 'Huyện Tân Biên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(706, 72, 'Huyện Tân Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(707, 72, 'Huyện Dương Minh Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(708, 72, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(709, 72, 'Thị xã Hòa Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(710, 72, 'Huyện Gò Dầu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(711, 72, 'Huyện Bến Cầu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(712, 72, 'Thị xã Trảng Bàng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(718, 74, 'Thành phố Thủ Dầu Một', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(719, 74, 'Huyện Bàu Bàng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(720, 74, 'Huyện Dầu Tiếng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(721, 74, 'Thành phố Bến Cát', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(722, 74, 'Huyện Phú Giáo', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(723, 74, 'Thành phố Tân Uyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(724, 74, 'Thành phố Dĩ An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(725, 74, 'Thành phố Thuận An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(726, 74, 'Huyện Bắc Tân Uyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(731, 75, 'Thành phố Biên Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(732, 75, 'Thành phố Long Khánh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(734, 75, 'Huyện Tân Phú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(735, 75, 'Huyện Vĩnh Cửu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(736, 75, 'Huyện Định Quán', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(737, 75, 'Huyện Trảng Bom', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(738, 75, 'Huyện Thống Nhất', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(739, 75, 'Huyện Cẩm Mỹ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(740, 75, 'Huyện Long Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(741, 75, 'Huyện Xuân Lộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(742, 75, 'Huyện Nhơn Trạch', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(747, 77, 'Thành phố Vũng Tàu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(748, 77, 'Thành phố Bà Rịa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(750, 77, 'Huyện Châu Đức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(751, 77, 'Huyện Xuyên Mộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(753, 77, 'Huyện Long Đất', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(754, 77, 'Thành phố Phú Mỹ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(755, 77, 'Huyện Côn Đảo', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(760, 79, 'Quận 1', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(761, 79, 'Quận 12', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(764, 79, 'Quận Gò Vấp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(765, 79, 'Quận Bình Thạnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(766, 79, 'Quận Tân Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(767, 79, 'Quận Tân Phú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(768, 79, 'Quận Phú Nhuận', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(769, 79, 'Thành phố Thủ Đức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(770, 79, 'Quận 3', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(771, 79, 'Quận 10', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(772, 79, 'Quận 11', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(773, 79, 'Quận 4', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(774, 79, 'Quận 5', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(775, 79, 'Quận 6', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(776, 79, 'Quận 8', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(777, 79, 'Quận Bình Tân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(778, 79, 'Quận 7', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(783, 79, 'Huyện Củ Chi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(784, 79, 'Huyện Hóc Môn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(785, 79, 'Huyện Bình Chánh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(786, 79, 'Huyện Nhà Bè', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(787, 79, 'Huyện Cần Giờ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(794, 80, 'Thành phố Tân An', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(795, 80, 'Thị xã Kiến Tường', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(796, 80, 'Huyện Tân Hưng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(797, 80, 'Huyện Vĩnh Hưng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(798, 80, 'Huyện Mộc Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(799, 80, 'Huyện Tân Thạnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(800, 80, 'Huyện Thạnh Hóa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(801, 80, 'Huyện Đức Huệ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(802, 80, 'Huyện Đức Hòa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(803, 80, 'Huyện Bến Lức', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(804, 80, 'Huyện Thủ Thừa', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(805, 80, 'Huyện Tân Trụ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(806, 80, 'Huyện Cần Đước', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(807, 80, 'Huyện Cần Giuộc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(808, 80, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(815, 82, 'Thành phố Mỹ Tho', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(816, 82, 'Thành phố Gò Công', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(817, 82, 'Thị xã Cai Lậy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(818, 82, 'Huyện Tân Phước', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(819, 82, 'Huyện Cái Bè', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(820, 82, 'Huyện Cai Lậy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(821, 82, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(822, 82, 'Huyện Chợ Gạo', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(823, 82, 'Huyện Gò Công Tây', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(824, 82, 'Huyện Gò Công Đông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(825, 82, 'Huyện Tân Phú Đông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(829, 83, 'Thành phố Bến Tre', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(831, 83, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(832, 83, 'Huyện Chợ Lách', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(833, 83, 'Huyện Mỏ Cày Nam', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(834, 83, 'Huyện Giồng Trôm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(835, 83, 'Huyện Bình Đại', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(836, 83, 'Huyện Ba Tri', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(837, 83, 'Huyện Thạnh Phú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(838, 83, 'Huyện Mỏ Cày Bắc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(842, 84, 'Thành phố Trà Vinh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(844, 84, 'Huyện Càng Long', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(845, 84, 'Huyện Cầu Kè', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(846, 84, 'Huyện Tiểu Cần', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(847, 84, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(848, 84, 'Huyện Cầu Ngang', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(849, 84, 'Huyện Trà Cú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(850, 84, 'Huyện Duyên Hải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(851, 84, 'Thị xã Duyên Hải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(855, 86, 'Thành phố Vĩnh Long', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(857, 86, 'Huyện Long Hồ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(858, 86, 'Huyện Mang Thít', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(859, 86, 'Huyện  Vũng Liêm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(860, 86, 'Huyện Tam Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(861, 86, 'Thị xã Bình Minh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(862, 86, 'Huyện Trà Ôn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(863, 86, 'Huyện Bình Tân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(866, 87, 'Thành phố Cao Lãnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(867, 87, 'Thành phố Sa Đéc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(868, 87, 'Thành phố Hồng Ngự', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(869, 87, 'Huyện Tân Hồng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(870, 87, 'Huyện Hồng Ngự', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(871, 87, 'Huyện Tam Nông', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(872, 87, 'Huyện Tháp Mười', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(873, 87, 'Huyện Cao Lãnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(874, 87, 'Huyện Thanh Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(875, 87, 'Huyện Lấp Vò', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(876, 87, 'Huyện Lai Vung', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(877, 87, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(883, 89, 'Thành phố Long Xuyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(884, 89, 'Thành phố Châu Đốc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(886, 89, 'Huyện An Phú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(887, 89, 'Thị xã Tân Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(888, 89, 'Huyện Phú Tân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(889, 89, 'Huyện Châu Phú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(890, 89, 'Thị xã Tịnh Biên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(891, 89, 'Huyện Tri Tôn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(892, 89, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(893, 89, 'Huyện Chợ Mới', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(894, 89, 'Huyện Thoại Sơn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(899, 91, 'Thành phố Rạch Giá', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(900, 91, 'Thành phố Hà Tiên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(902, 91, 'Huyện Kiên Lương', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(903, 91, 'Huyện Hòn Đất', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(904, 91, 'Huyện Tân Hiệp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(905, 91, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(906, 91, 'Huyện Giồng Riềng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(907, 91, 'Huyện Gò Quao', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(908, 91, 'Huyện An Biên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(909, 91, 'Huyện An Minh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(910, 91, 'Huyện Vĩnh Thuận', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(911, 91, 'Thành phố Phú Quốc', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(912, 91, 'Huyện Kiên Hải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(913, 91, 'Huyện U Minh Thượng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(914, 91, 'Huyện Giang Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(916, 92, 'Quận Ninh Kiều', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(917, 92, 'Quận Ô Môn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(918, 92, 'Quận Bình Thuỷ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(919, 92, 'Quận Cái Răng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(923, 92, 'Quận Thốt Nốt', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(924, 92, 'Huyện Vĩnh Thạnh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(925, 92, 'Huyện Cờ Đỏ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(926, 92, 'Huyện Phong Điền', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(927, 92, 'Huyện Thới Lai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(930, 93, 'Thành phố Vị Thanh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(931, 93, 'Thành phố Ngã Bảy', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(932, 93, 'Huyện Châu Thành A', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(933, 93, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(934, 93, 'Huyện Phụng Hiệp', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(935, 93, 'Huyện Vị Thuỷ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(936, 93, 'Huyện Long Mỹ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(937, 93, 'Thị xã Long Mỹ', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(941, 94, 'Thành phố Sóc Trăng', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(942, 94, 'Huyện Châu Thành', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(943, 94, 'Huyện Kế Sách', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(944, 94, 'Huyện Mỹ Tú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(945, 94, 'Huyện Cù Lao Dung', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(946, 94, 'Huyện Long Phú', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(947, 94, 'Huyện Mỹ Xuyên', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(948, 94, 'Thị xã Ngã Năm', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(949, 94, 'Huyện Thạnh Trị', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(950, 94, 'Thị xã Vĩnh Châu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(951, 94, 'Huyện Trần Đề', '2025-06-01 21:05:01', '2025-06-01 21:05:01');
INSERT INTO `sys_districts` (`DistrictID`, `CityID`, `DistrictName`, `CreatedAt`, `UpdatedAt`) VALUES
(954, 95, 'Thành phố Bạc Liêu', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(956, 95, 'Huyện Hồng Dân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(957, 95, 'Huyện Phước Long', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(958, 95, 'Huyện Vĩnh Lợi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(959, 95, 'Thị xã Giá Rai', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(960, 95, 'Huyện Đông Hải', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(961, 95, 'Huyện Hoà Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(964, 96, 'Thành phố Cà Mau', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(966, 96, 'Huyện U Minh', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(967, 96, 'Huyện Thới Bình', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(968, 96, 'Huyện Trần Văn Thời', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(969, 96, 'Huyện Cái Nước', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(970, 96, 'Huyện Đầm Dơi', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(971, 96, 'Huyện Năm Căn', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(972, 96, 'Huyện Phú Tân', '2025-06-01 21:05:01', '2025-06-01 21:05:01'),
(973, 96, 'Huyện Ngọc Hiển', '2025-06-01 21:05:01', '2025-06-01 21:05:01');

-- --------------------------------------------------------

--
-- Table structure for table `sys_flags`
--

CREATE TABLE `sys_flags` (
  `FlagID` tinyint NOT NULL COMMENT 'ID cờ',
  `FlagName` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên cờ (trạng thái dữ liệu)',
  `StageOrder` tinyint DEFAULT NULL COMMENT 'Thứ tự của stage',
  `Description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci COMMENT 'Mô tả thêm',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các cờ trạng thái dữ liệu';

--
-- Dumping data for table `sys_flags`
--

INSERT INTO `sys_flags` (`FlagID`, `FlagName`, `StageOrder`, `Description`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'embedded', 1, 'Đã embedded', '2025-06-08 23:05:29', '2025-06-08 23:05:29'),
(2, 'to_es', 2, 'Đã add ES', '2025-06-08 23:05:29', '2025-06-08 23:05:29'),
(3, 'reformat ', 3, 'đã reformat ', '2025-06-08 23:05:29', '2025-08-15 14:03:08'),
(4, 'error', -1, 'Lỗi khi xử lý hoặc sync', '2025-06-08 23:05:29', '2025-06-08 23:05:29'),
(5, 'raw', 0, 'Mới insert từ Mongo, chưa xử lý gì tiếp theo', '2025-06-08 23:12:53', '2025-06-08 23:12:53');

-- --------------------------------------------------------

--
-- Table structure for table `sys_languages`
--

CREATE TABLE `sys_languages` (
  `LanguageID` tinyint NOT NULL COMMENT 'ID ngôn ngữ',
  `LanguageName` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên ngôn ngữ',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu danh sách ngôn ngữ';

--
-- Dumping data for table `sys_languages`
--

INSERT INTO `sys_languages` (`LanguageID`, `LanguageName`, `CreatedAt`, `UpdatedAt`) VALUES
(1, 'Vietnamese', '2025-06-08 22:58:15', '2025-06-08 22:58:15'),
(2, 'English', '2025-06-08 22:58:15', '2025-06-08 22:58:15'),
(3, 'Japanese', '2025-06-08 22:58:15', '2025-06-08 22:58:15');

-- --------------------------------------------------------

--
-- Table structure for table `sys_locations`
--

CREATE TABLE `sys_locations` (
  `LocationID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `CityID` int DEFAULT NULL,
  `DistrictID` int DEFAULT NULL,
  `DetailLocation` varchar(255) COLLATE utf8mb4_unicode_ci NOT NULL,
  `Latitude` decimal(10,7) DEFAULT NULL,
  `Longitude` decimal(10,7) DEFAULT NULL,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `sys_locations`
--

INSERT INTO `sys_locations` (`LocationID`, `CityID`, `DistrictID`, `DetailLocation`, `Latitude`, `Longitude`, `CreatedAt`, `UpdatedAt`) VALUES
('019bf3b6-39bb-7062-97cf-c4ca79326fb0', 1, 3, 'Số 9 đường Bưởi, quận Tây Hồ, thành phố Hà Nội', NULL, NULL, '2026-01-25 05:52:44', '2026-01-25 05:52:44'),
('019bf3b6-39be-7357-addd-af789eba9567', 1, 3, 'Số 9 đường Bưởi, quận Tây Hồ, thành phố Hà Nội', NULL, NULL, '2026-01-25 05:52:44', '2026-01-25 05:52:44'),
('019bf438-21e8-701f-9b24-aec9379ac75d', 1, 3, 'Số 9 đường Bưởi, quận Tây Hồ, thành phố Hà Nội', NULL, NULL, '2026-01-25 08:14:38', '2026-01-25 08:14:38'),
('019bf46b-8201-71bd-a202-466f1feff8bc', 22, 195, 'dong hop', NULL, NULL, '2026-01-25 09:10:44', '2026-01-25 09:10:44'),
('019bf582-cec7-7088-84e2-a5d1bedc6cd2', 24, 223, 'dong hop', NULL, NULL, '2026-01-25 14:15:49', '2026-01-25 14:15:49'),
('019bf8d1-0b67-708a-9505-63c74d463582', 1, 3, 'Số 9 đường Bưởi, quận Tây Hồ, Hà Nội', NULL, NULL, '2026-01-26 05:40:08', '2026-01-26 05:40:08'),
('019bf8db-593d-717e-81c2-04fa74262943', 1, 3, 'Số 9 đường Bưởi, quận Tây Hồ, thành phố Hà Nội', NULL, NULL, '2026-01-26 05:51:23', '2026-01-26 05:51:23');

-- --------------------------------------------------------

--
-- Table structure for table `sys_sexes`
--

CREATE TABLE `sys_sexes` (
  `SexID` tinyint NOT NULL COMMENT 'ID giới tính',
  `SexName` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Tên giới tính',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP COMMENT 'Thời gian tạo',
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'Thời gian cập nhật'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Bảng lưu các giới tính';

--
-- Dumping data for table `sys_sexes`
--

INSERT INTO `sys_sexes` (`SexID`, `SexName`, `CreatedAt`, `UpdatedAt`) VALUES
(0, 'No Preference', '2026-01-24 14:55:43', '2026-01-24 14:56:34'),
(1, 'Male', '2026-01-24 14:55:43', '2026-01-24 14:55:43'),
(2, 'Female', '2026-01-24 14:55:43', '2026-01-24 14:55:43'),
(3, 'Other', '2026-01-24 14:55:43', '2026-01-24 14:55:43');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `job_companies`
--
ALTER TABLE `job_companies`
  ADD PRIMARY KEY (`CompanyID`),
  ADD KEY `fk_job_companies_location` (`LocationID`),
  ADD KEY `fk_job_companies_size` (`SizeID`),
  ADD KEY `fk_job_companies_industry` (`IndustryID`);

--
-- Indexes for table `job_company_sizes`
--
ALTER TABLE `job_company_sizes`
  ADD PRIMARY KEY (`SizeID`);

--
-- Indexes for table `job_contracttypes`
--
ALTER TABLE `job_contracttypes`
  ADD PRIMARY KEY (`ContractTypeID`),
  ADD UNIQUE KEY `ContractName` (`ContractTypeName`);

--
-- Indexes for table `job_degreelevels`
--
ALTER TABLE `job_degreelevels`
  ADD PRIMARY KEY (`DegreeLevelID`),
  ADD UNIQUE KEY `DegreeName` (`DegreeLevelName`);

--
-- Indexes for table `job_industries`
--
ALTER TABLE `job_industries`
  ADD PRIMARY KEY (`IndustryID`);

--
-- Indexes for table `job_jds`
--
ALTER TABLE `job_jds`
  ADD PRIMARY KEY (`JobID`),
  ADD UNIQUE KEY `slug` (`slug`),
  ADD KEY `idx_CompanyID` (`CompanyID`),
  ADD KEY `idx_JobSector` (`JobSectorID`),
  ADD KEY `idx_OpenDate` (`OpenDate`);

--
-- Indexes for table `job_jd_changes`
--
ALTER TABLE `job_jd_changes`
  ADD PRIMARY KEY (`ChangeID`),
  ADD KEY `idx_job_version_field` (`JobID`,`Version`,`Field`);

--
-- Indexes for table `job_jd_snapshot`
--
ALTER TABLE `job_jd_snapshot`
  ADD PRIMARY KEY (`SnapshotID`),
  ADD KEY `idx_job_version` (`JobID`,`Version`);

--
-- Indexes for table `job_pipelines`
--
ALTER TABLE `job_pipelines`
  ADD PRIMARY KEY (`PipelineID`);

--
-- Indexes for table `job_sectors`
--
ALTER TABLE `job_sectors`
  ADD PRIMARY KEY (`JobSectorID`),
  ADD UNIQUE KEY `SectorName` (`JobSectorName`);

--
-- Indexes for table `job_stats`
--
ALTER TABLE `job_stats`
  ADD PRIMARY KEY (`job_id`);

--
-- Indexes for table `job_sub_jds`
--
ALTER TABLE `job_sub_jds`
  ADD PRIMARY KEY (`JobID`),
  ADD KEY `idx_company_status` (`CompanyID`,`status`);

--
-- Indexes for table `job_types`
--
ALTER TABLE `job_types`
  ADD PRIMARY KEY (`JobTypeID`),
  ADD UNIQUE KEY `JobTypeName` (`JobTypeName`);

--
-- Indexes for table `job_workingtypes`
--
ALTER TABLE `job_workingtypes`
  ADD PRIMARY KEY (`WorkingTypeID`),
  ADD UNIQUE KEY `WorkingTypeName` (`WorkingTypeName`);

--
-- Indexes for table `per_jobs`
--
ALTER TABLE `per_jobs`
  ADD PRIMARY KEY (`job_id`,`recruiter_id`),
  ADD KEY `fk_per_jobs_recruiter` (`recruiter_id`);

--
-- Indexes for table `service_users`
--
ALTER TABLE `service_users`
  ADD PRIMARY KEY (`internal_id`),
  ADD KEY `idx_service_users_keycloak_id` (`keycloak_id`);

--
-- Indexes for table `sys_cities`
--
ALTER TABLE `sys_cities`
  ADD PRIMARY KEY (`CityID`),
  ADD UNIQUE KEY `UQ_Country_City` (`CountryID`,`CityName`);

--
-- Indexes for table `sys_countries`
--
ALTER TABLE `sys_countries`
  ADD PRIMARY KEY (`CountryID`),
  ADD UNIQUE KEY `CountryName` (`CountryName`);

--
-- Indexes for table `sys_currencies`
--
ALTER TABLE `sys_currencies`
  ADD PRIMARY KEY (`CurrencyID`);

--
-- Indexes for table `sys_districts`
--
ALTER TABLE `sys_districts`
  ADD PRIMARY KEY (`DistrictID`),
  ADD UNIQUE KEY `UQ_City_District` (`CityID`,`DistrictName`);

--
-- Indexes for table `sys_flags`
--
ALTER TABLE `sys_flags`
  ADD PRIMARY KEY (`FlagID`);

--
-- Indexes for table `sys_languages`
--
ALTER TABLE `sys_languages`
  ADD PRIMARY KEY (`LanguageID`),
  ADD UNIQUE KEY `LanguageName` (`LanguageName`);

--
-- Indexes for table `sys_locations`
--
ALTER TABLE `sys_locations`
  ADD PRIMARY KEY (`LocationID`);

--
-- Indexes for table `sys_sexes`
--
ALTER TABLE `sys_sexes`
  ADD PRIMARY KEY (`SexID`),
  ADD UNIQUE KEY `SexName` (`SexName`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `job_company_sizes`
--
ALTER TABLE `job_company_sizes`
  MODIFY `SizeID` tinyint UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `job_contracttypes`
--
ALTER TABLE `job_contracttypes`
  MODIFY `ContractTypeID` tinyint NOT NULL AUTO_INCREMENT COMMENT 'ID loại hợp đồng', AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `job_degreelevels`
--
ALTER TABLE `job_degreelevels`
  MODIFY `DegreeLevelID` tinyint NOT NULL AUTO_INCREMENT COMMENT 'ID trình độ học vấn', AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `job_industries`
--
ALTER TABLE `job_industries`
  MODIFY `IndustryID` tinyint UNSIGNED NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `job_sectors`
--
ALTER TABLE `job_sectors`
  MODIFY `JobSectorID` tinyint NOT NULL AUTO_INCREMENT COMMENT 'ID ngành nghề', AUTO_INCREMENT=21;

--
-- AUTO_INCREMENT for table `job_types`
--
ALTER TABLE `job_types`
  MODIFY `JobTypeID` tinyint NOT NULL AUTO_INCREMENT COMMENT 'ID loại công việc', AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `job_workingtypes`
--
ALTER TABLE `job_workingtypes`
  MODIFY `WorkingTypeID` tinyint NOT NULL AUTO_INCREMENT COMMENT 'ID hình thức làm việc', AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `sys_cities`
--
ALTER TABLE `sys_cities`
  MODIFY `CityID` int NOT NULL AUTO_INCREMENT COMMENT 'ID thành phố', AUTO_INCREMENT=97;

--
-- AUTO_INCREMENT for table `sys_countries`
--
ALTER TABLE `sys_countries`
  MODIFY `CountryID` int NOT NULL AUTO_INCREMENT COMMENT 'ID quốc gia', AUTO_INCREMENT=85;

--
-- AUTO_INCREMENT for table `sys_currencies`
--
ALTER TABLE `sys_currencies`
  MODIFY `CurrencyID` smallint NOT NULL AUTO_INCREMENT COMMENT 'ID đơn vị tiền tệ', AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `sys_districts`
--
ALTER TABLE `sys_districts`
  MODIFY `DistrictID` int NOT NULL AUTO_INCREMENT COMMENT 'ID quận/huyện', AUTO_INCREMENT=974;

--
-- AUTO_INCREMENT for table `sys_flags`
--
ALTER TABLE `sys_flags`
  MODIFY `FlagID` tinyint NOT NULL AUTO_INCREMENT COMMENT 'ID cờ', AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `sys_languages`
--
ALTER TABLE `sys_languages`
  MODIFY `LanguageID` tinyint NOT NULL AUTO_INCREMENT COMMENT 'ID ngôn ngữ', AUTO_INCREMENT=4;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `job_companies`
--
ALTER TABLE `job_companies`
  ADD CONSTRAINT `fk_job_companies_industry` FOREIGN KEY (`IndustryID`) REFERENCES `job_industries` (`IndustryID`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_job_companies_location` FOREIGN KEY (`LocationID`) REFERENCES `sys_locations` (`LocationID`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_job_companies_size` FOREIGN KEY (`SizeID`) REFERENCES `job_company_sizes` (`SizeID`) ON DELETE SET NULL;

--
-- Constraints for table `job_jd_changes`
--
ALTER TABLE `job_jd_changes`
  ADD CONSTRAINT `fk_change_job_id` FOREIGN KEY (`JobID`) REFERENCES `job_sub_jds` (`JobID`) ON DELETE CASCADE;

--
-- Constraints for table `job_jd_snapshot`
--
ALTER TABLE `job_jd_snapshot`
  ADD CONSTRAINT `fk_snapshot_job_id` FOREIGN KEY (`JobID`) REFERENCES `job_sub_jds` (`JobID`) ON DELETE CASCADE;

--
-- Constraints for table `job_stats`
--
ALTER TABLE `job_stats`
  ADD CONSTRAINT `fk_job_stats_job_sub_jds` FOREIGN KEY (`job_id`) REFERENCES `job_sub_jds` (`JobID`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
