-- phpMyAdmin SQL Dump
-- version 5.2.3
-- https://www.phpmyadmin.net/
--
-- Host: mysql:3306
-- Generation Time: Mar 22, 2026 at 02:27 PM
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
-- Database: `job7189_hiring_db`
--

-- --------------------------------------------------------

--
-- Table structure for table `hiring_executions`
--

CREATE TABLE `hiring_executions` (
  `ExecutionID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `PipelineID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `ApplicationID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `TriggerNodeID` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Status` enum('running','completed','failed','waiting') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'running',
  `WaitUntil` datetime DEFAULT NULL,
  `CurrentNode` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ExecutionData` json DEFAULT NULL,
  `Logs` json DEFAULT NULL,
  `StartedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `FinishedAt` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `hiring_executions`
--

INSERT INTO `hiring_executions` (`ExecutionID`, `PipelineID`, `ApplicationID`, `TriggerNodeID`, `Status`, `WaitUntil`, `CurrentNode`, `ExecutionData`, `Logs`, `StartedAt`, `FinishedAt`) VALUES
('26ac2d44-f9ed-47aa-8565-6a0ad3e19934', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', '019be5e3-f18e-71fd-8a3a-c81d1efd1ef3', 'trigger-1', 'failed', NULL, 'action-1', '{\"initial\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T13:47:53+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"Ứng viên\", \"candidate_email\": null}}', '[{\"type\": \"trigger.stage_entry\", \"error\": null, \"input\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T13:47:53+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"Ứng viên\", \"candidate_email\": null}, \"output\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T13:47:53+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"Ứng viên\", \"candidate_email\": null}, \"status\": \"success\", \"node_id\": \"trigger-1\", \"timestamp\": \"2026-01-22T13:47:53+00:00\", \"duration_ms\": 2.77, \"resolved_params\": {\"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\"}}, {\"type\": \"action.send_email\", \"error\": \"Missing email address\", \"input\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T13:47:53+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"Ứng viên\", \"candidate_email\": null}, \"output\": [], \"status\": \"failed\", \"node_id\": \"action-1\", \"timestamp\": \"2026-01-22T13:47:53+00:00\", \"duration_ms\": 3.23, \"resolved_params\": {\"to\": \"\", \"template\": \"emails.stage_moved\", \"variables\": {\"job_title\": \"Test Job Microservice\", \"company_name\": \"job718W9\", \"candidate_name\": \"Ứng viên\", \"new_stage_name\": \"Phỏng vấn kỹ thuật\"}}}]', '2026-01-22 13:47:53', NULL),
('272c5625-14ae-4f58-aac2-e93c4c90c5b4', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', '019be5e3-f18e-71fd-8a3a-c81d1efd1ef3', 'trigger-1', 'completed', NULL, 'action-1', '{\"initial\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T14:02:57+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"bảo phùng thái\", \"candidate_email\": \"baophungthai9@gmail.com\"}}', '[{\"type\": \"trigger.stage_entry\", \"error\": null, \"input\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T14:02:57+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"bảo phùng thái\", \"candidate_email\": \"baophungthai9@gmail.com\"}, \"output\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T14:02:57+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"bảo phùng thái\", \"candidate_email\": \"baophungthai9@gmail.com\"}, \"status\": \"success\", \"node_id\": \"trigger-1\", \"timestamp\": \"2026-01-22T14:02:58+00:00\", \"duration_ms\": 3.3, \"resolved_params\": {\"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\"}}, {\"type\": \"action.send_email\", \"error\": null, \"input\": {\"job_id\": \"019be14e-f4af-73c5-ac76-ba8e6c2c1306\", \"actor_id\": \"019bad5c-36f4-728d-a2af-4d8f69c4aec3\", \"stage_id\": \"019bbcd2-bb1e-7235-b0e5-7e63ba5645dd\", \"job_title\": \"Test Job Microservice\", \"timestamp\": \"2026-01-22T14:02:57+00:00\", \"stage_name\": \"Phỏng vấn kỹ thuật\", \"company_name\": \"job718W9\", \"application_id\": \"019be5e3-f18e-71fd-8a3a-c81d1efd1ef3\", \"candidate_name\": \"bảo phùng thái\", \"candidate_email\": \"baophungthai9@gmail.com\"}, \"output\": {\"status\": \"sent\", \"sent_at\": \"2026-01-22T14:02:59+00:00\"}, \"status\": \"success\", \"node_id\": \"action-1\", \"timestamp\": \"2026-01-22T14:02:59+00:00\", \"duration_ms\": 1009.8, \"resolved_params\": {\"to\": \"baophungthai9@gmail.com\", \"template\": \"emails.stage_moved\", \"variables\": {\"job_title\": \"Test Job Microservice\", \"company_name\": \"job718W9\", \"candidate_name\": \"bảo phùng thái\", \"new_stage_name\": \"Phỏng vấn kỹ thuật\"}}}]', '2026-01-22 14:02:58', '2026-01-22 14:02:59');

-- --------------------------------------------------------

--
-- Table structure for table `hiring_scorecards`
--

CREATE TABLE `hiring_scorecards` (
  `ScorecardID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `ApplicationID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `InterviewerID` char(36) COLLATE utf8mb4_unicode_ci NOT NULL,
  `InterviewerName` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `ScoreJson` json NOT NULL COMMENT 'Lưu cấu trúc điểm',
  `Comment` text COLLATE utf8mb4_unicode_ci,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `hiring_scorecards`
--

INSERT INTO `hiring_scorecards` (`ScorecardID`, `ApplicationID`, `InterviewerID`, `InterviewerName`, `ScoreJson`, `Comment`, `CreatedAt`, `UpdatedAt`) VALUES
('62481962-cc5c-4c83-95b3-6cc7c8d91035', '019bf58f-e0e8-7077-ba9e-7019f3023eb9', '019bb2ee-da77-70d9-abfa-d027c98c5341', 'Bao Phung Thai', '{\"culture_fit\": 5, \"communication\": 4.5, \"problem_solving\": 3, \"technical_skills\": 4}', 'good', '2026-01-25 15:10:17', '2026-01-25 15:10:17');

-- --------------------------------------------------------

--
-- Table structure for table `interviews`
--

CREATE TABLE `interviews` (
  `InterviewID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `ApplicationID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `StartTime` datetime NOT NULL,
  `EndTime` datetime NOT NULL,
  `Status` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT 'Scheduled',
  `Location` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `Note` text COLLATE utf8mb4_unicode_ci,
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `Feedback` text COLLATE utf8mb4_unicode_ci NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `interviews`
--

INSERT INTO `interviews` (`InterviewID`, `ApplicationID`, `StartTime`, `EndTime`, `Status`, `Location`, `Note`, `CreatedAt`, `Feedback`) VALUES
('7c5c15ff-8bc6-407b-a11d-edfaecd606d7', '019bf58f-e0e8-7077-ba9e-7019f3023eb9', '2026-02-01 14:00:00', '2026-02-01 15:30:00', 'Scheduled', 'https://meet.google.com/abc-xyz-def', NULL, '2026-01-25 15:17:36', 'Tốt');

-- --------------------------------------------------------

--
-- Table structure for table `job_applications`
--

CREATE TABLE `job_applications` (
  `ApplicationID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `JobID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'External ID (Job Service)',
  `CVID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'External ID (Candidate Service)',
  `WorkspaceID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'External ID (Workspace Service)',
  `ApplicantID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'External ID (Identity Service)',
  `StageID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Internal FK',
  `StatusID` tinyint UNSIGNED NOT NULL DEFAULT '1',
  `AppliedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `Name` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Snapshot tên ứng viên',
  `Email` varchar(255) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Snapshot email',
  `Phone` varchar(20) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `CvUrl` varchar(500) COLLATE utf8mb4_unicode_ci DEFAULT NULL COMMENT 'Link file CV'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `job_applications`
--

INSERT INTO `job_applications` (`ApplicationID`, `JobID`, `CVID`, `WorkspaceID`, `ApplicantID`, `StageID`, `StatusID`, `AppliedAt`, `UpdatedAt`, `Name`, `Email`, `Phone`, `CvUrl`) VALUES
('019be103-d7ca-721f-ac35-4b2344d8c36c', '019bb807-b229-719d-96a9-18bfe6d0a393', '019be103-99bb-70d8-80b4-36175c4ea020', '019b2178-5b78-7048-9978-f3ee7e15acc1', '019be0cb-5942-7133-8493-fa92ba42093c', '019bbcd2-bb1e-7235-b0e5-7e63ba5645dd', 1, '2026-01-21 14:44:44', '2026-01-21 15:56:03', NULL, NULL, NULL, NULL),
('019be5e3-f18e-71fd-8a3a-c81d1efd1ef3', '019be14e-f4af-73c5-ac76-ba8e6c2c1306', '019be103-99bb-70d8-80b4-36175c4ea020', '019badb5-5306-7273-b257-524fa49a4a1f', '019be0cb-5942-7133-8493-fa92ba42093c', '019bbcd2-bb1e-7235-b0e5-7e63ba5645dd', 1, '2026-01-22 13:33:37', '2026-01-22 13:41:39', NULL, NULL, NULL, NULL),
('019bf4ac-e7f8-734c-9af3-ae49ff913cb7', '019bf43c-27cb-719b-adf4-33bc9778b09b', '019be103-99bb-70d8-80b4-36175c4ea020', '019bf438-21d0-728f-ad3b-0e8bce2709e4', '019be0cb-5942-7133-8493-fa92ba42093c', '019bbcd2-bb1e-7235-b0e5-7e63ba5645dd', 1, '2026-01-25 10:22:10', '2026-01-25 10:36:35', NULL, NULL, NULL, NULL),
('019bf58f-e0e8-7077-ba9e-7019f3023eb9', '019bf0b4-d942-73cb-a297-01e119abad64', '019be103-99bb-70d8-80b4-36175c4ea020', '019bf438-21d0-728f-ad3b-0e8bce2709e4', '019be0cb-5942-7133-8493-fa92ba42093c', '019bf4d8-5c2e-73bf-9883-1a293181c512', 1, '2026-01-25 14:30:05', '2026-01-25 14:45:20', 'bảo phùng thái', 'baophungthai9@gmail.com', NULL, 'cvs/c5b51a20-f6cf-4fbc-ae21-74c9bff3f8cb.pdf'),
('019bf91f-a829-73bf-8c09-ca4675c1d2a5', '019bf51d-3f8d-706f-ab48-59c01680a743', '019bf8f8-f5a3-70a3-9251-81e3bbccc09e', '019bf438-21d0-728f-ad3b-0e8bce2709e4', '019be0cb-5942-7133-8493-fa92ba42093c', '019bf4d8-5c2e-73bf-9883-1a293181c512', 1, '2026-01-26 07:06:00', '2026-01-26 07:10:32', 'bảo phùng thái', 'baophungthai9@gmail.com', NULL, 'cvs/93ee82e5-8671-4a75-85b1-90808c48dc4e.pdf');

-- --------------------------------------------------------

--
-- Table structure for table `rct_hiring_pipelines`
--

CREATE TABLE `rct_hiring_pipelines` (
  `PipelineID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `WorkspaceID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'Chỉ lưu ID, KHÔNG FOREIGN KEY',
  `Name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `IsDefault` tinyint(1) DEFAULT '0',
  `WorkflowConfig` json DEFAULT NULL COMMENT 'Cấu trúc Graph: Nodes & Connections',
  `Settings` json DEFAULT NULL COMMENT 'Cấu hình phụ',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `rct_hiring_pipelines`
--

INSERT INTO `rct_hiring_pipelines` (`PipelineID`, `WorkspaceID`, `Name`, `IsDefault`, `WorkflowConfig`, `Settings`, `CreatedAt`, `UpdatedAt`) VALUES
('019bbcd2-bb19-72ab-ab78-b3459b6d9f90', '019badb5-5306-7273-b257-524fa49a4a1f', 'Quy trình IT Developer', 1, '{\"nodes\": [{\"id\": \"trigger-1\", \"type\": \"trigger.stage_entry\", \"position\": {\"x\": 100, \"y\": 100}, \"parameters\": {\"stage_id\": \"019bbcd2-bb1d-72e8-a9a2-d3623d70a24e\"}}, {\"id\": \"wait-1\", \"type\": \"action.wait\", \"position\": {\"x\": 300, \"y\": 100}, \"parameters\": {\"duration\": 24}}, {\"id\": \"action-1\", \"type\": \"action.send_email\", \"position\": {\"x\": 500, \"y\": 100}, \"parameters\": {\"to\": \"{{ candidate_email }}\", \"template\": \"emails.stage_moved\"}}], \"connections\": {\"wait-1\": {\"main\": [[{\"node\": \"action-1\", \"type\": \"main\", \"index\": 0}]]}, \"trigger-1\": {\"main\": [[{\"node\": \"wait-1\", \"type\": \"main\", \"index\": 0}]]}}}', NULL, '2026-01-14 14:04:45', '2026-01-22 16:28:28'),
('019bbcde-46c9-7161-b743-c95b21cdc458', '019badb5-5306-7273-b257-524fa49a4a1f', 'Quy trình IT Developer', 0, NULL, NULL, '2026-01-14 14:17:22', '2026-01-14 14:17:22'),
('019bbce7-66ab-71f2-afb5-dab78dc2a235', '019badb5-5306-7273-b257-524fa49a4a1f', 'Quy trình IT Developer (Updated)', 0, NULL, NULL, '2026-01-14 14:27:20', '2026-01-14 14:28:29'),
('019bf4d8-5c2b-71a3-b510-24c1951d187a', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Quy trình IT Developer', 0, NULL, NULL, '2026-01-25 11:09:38', '2026-01-25 11:09:38'),
('019bf4fd-c8bc-724b-9580-5f070064acc3', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Quy trình IT Developer', 0, NULL, NULL, '2026-01-25 11:50:31', '2026-01-25 11:50:31'),
('019bf559-550c-73e7-88a1-bdfe3d2dd31b', '019bf438-21d0-728f-ad3b-0e8bce2709e4', 'Quy trình IT Developer', 0, NULL, NULL, '2026-01-25 13:30:31', '2026-01-25 13:30:31');

-- --------------------------------------------------------

--
-- Table structure for table `rct_pipeline_stages`
--

CREATE TABLE `rct_pipeline_stages` (
  `StageID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL COMMENT 'UUIDv7',
  `PipelineID` char(36) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `Name` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL,
  `StageOrder` tinyint UNSIGNED DEFAULT '0',
  `Color` varchar(7) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci DEFAULT '#FFFFFF',
  `IsSystemStage` tinyint(1) DEFAULT '0',
  `CreatedAt` datetime DEFAULT CURRENT_TIMESTAMP,
  `UpdatedAt` datetime DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `rct_pipeline_stages`
--

INSERT INTO `rct_pipeline_stages` (`StageID`, `PipelineID`, `Name`, `StageOrder`, `Color`, `IsSystemStage`, `CreatedAt`, `UpdatedAt`) VALUES
('019bbcd2-bb1d-72e8-a9a2-d3623d70a24e', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', 'Sàng lọc hồ sơ', 1, '#FFC107', 0, '2026-01-14 14:04:45', '2026-01-14 14:04:45'),
('019bbcd2-bb1e-7235-b0e5-7e63ba5645dd', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', 'Phỏng vấn kỹ thuật', 2, '#2196F3', 0, '2026-01-14 14:04:45', '2026-01-14 14:04:45'),
('019bbcd2-bb1e-7235-b0e5-7e63bad206a7', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', 'Phỏng vấn văn hóa', 3, '#9C27B0', 0, '2026-01-14 14:04:45', '2026-01-14 14:04:45'),
('019bbcd2-bb1f-706f-b6f3-e68fbea613b3', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', 'Gửi Offer', 4, '#4CAF50', 0, '2026-01-14 14:04:45', '2026-01-14 14:04:45'),
('019bbcd2-bb1f-706f-b6f3-e68fbebcb7ae', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', 'Hired', 5, '#DFF0D8', 1, '2026-01-14 14:04:45', '2026-01-14 14:04:45'),
('019bbcd2-bb1f-706f-b6f3-e68fbf10c46c', '019bbcd2-bb19-72ab-ab78-b3459b6d9f90', 'Rejected', 6, '#F2DEDE', 1, '2026-01-14 14:04:45', '2026-01-14 14:04:45'),
('019bbcde-46cc-70db-8e36-4575a6b6cff8', '019bbcde-46c9-7161-b743-c95b21cdc458', 'Sàng lọc hồ sơ', 1, '#FFC107', 0, '2026-01-14 14:17:22', '2026-01-14 14:17:22'),
('019bbcde-46cc-70db-8e36-4575a76a7669', '019bbcde-46c9-7161-b743-c95b21cdc458', 'Phỏng vấn kỹ thuật', 2, '#2196F3', 0, '2026-01-14 14:17:22', '2026-01-14 14:17:22'),
('019bbcde-46cd-71d2-9687-83fc1998a984', '019bbcde-46c9-7161-b743-c95b21cdc458', 'Phỏng vấn văn hóa', 3, '#9C27B0', 0, '2026-01-14 14:17:22', '2026-01-14 14:17:22'),
('019bbcde-46cd-71d2-9687-83fc1a2ff942', '019bbcde-46c9-7161-b743-c95b21cdc458', 'Gửi Offer', 4, '#4CAF50', 0, '2026-01-14 14:17:22', '2026-01-14 14:17:22'),
('019bbcde-46cd-71d2-9687-83fc1b1bb225', '019bbcde-46c9-7161-b743-c95b21cdc458', 'Hired', 5, '#DFF0D8', 1, '2026-01-14 14:17:22', '2026-01-14 14:17:22'),
('019bbcde-46cd-71d2-9687-83fc1b4152ec', '019bbcde-46c9-7161-b743-c95b21cdc458', 'Rejected', 6, '#F2DEDE', 1, '2026-01-14 14:17:22', '2026-01-14 14:17:22'),
('019bbce7-66ae-70a1-a10a-b455518df925', '019bbce7-66ab-71f2-afb5-dab78dc2a235', 'Hired', 3, '#DFF0D8', 1, '2026-01-14 14:27:20', '2026-01-21 15:26:10'),
('019bbce7-66ae-70a1-a10a-b45551b8c30e', '019bbce7-66ab-71f2-afb5-dab78dc2a235', 'Rejected', 4, '#F2DEDE', 1, '2026-01-14 14:27:20', '2026-01-21 15:26:10'),
('019be129-ca31-72d0-86ec-a60d2ca81548', '019bbce7-66ab-71f2-afb5-dab78dc2a235', 'Sơ loại', 1, '#FFC107', 0, '2026-01-21 15:26:10', '2026-01-21 15:26:10'),
('019be129-ca35-7225-a70f-7dde60d4287f', '019bbce7-66ab-71f2-afb5-dab78dc2a235', 'Phỏng vấn', 2, '#2196F3', 0, '2026-01-21 15:26:10', '2026-01-21 15:26:10'),
('019bf4d8-5c2d-71ed-becc-bdab73f841fa', '019bf4d8-5c2b-71a3-b510-24c1951d187a', 'Sàng lọc hồ sơ', 1, '#FFC107', 0, '2026-01-25 11:09:38', '2026-01-25 11:09:38'),
('019bf4d8-5c2e-73bf-9883-1a293181c512', '019bf4d8-5c2b-71a3-b510-24c1951d187a', 'Phỏng vấn kỹ thuật', 2, '#2196F3', 0, '2026-01-25 11:09:38', '2026-01-25 11:09:38'),
('019bf4d8-5c2f-70f9-963e-5a5452f73cdd', '019bf4d8-5c2b-71a3-b510-24c1951d187a', 'Phỏng vấn văn hóa', 3, '#9C27B0', 0, '2026-01-25 11:09:38', '2026-01-25 11:09:38'),
('019bf4d8-5c2f-70f9-963e-5a54530b70b8', '019bf4d8-5c2b-71a3-b510-24c1951d187a', 'Gửi Offer', 4, '#4CAF50', 0, '2026-01-25 11:09:38', '2026-01-25 11:09:38'),
('019bf4d8-5c2f-70f9-963e-5a5453a9e8f6', '019bf4d8-5c2b-71a3-b510-24c1951d187a', 'Hired', 5, '#DFF0D8', 1, '2026-01-25 11:09:38', '2026-01-25 11:09:38'),
('019bf4d8-5c2f-70f9-963e-5a54544fa0ee', '019bf4d8-5c2b-71a3-b510-24c1951d187a', 'Rejected', 6, '#F2DEDE', 1, '2026-01-25 11:09:38', '2026-01-25 11:09:38'),
('019bf4fd-c8be-73de-aafd-0d310567cdae', '019bf4fd-c8bc-724b-9580-5f070064acc3', 'Sàng lọc hồ sơ', 1, '#FFC107', 0, '2026-01-25 11:50:31', '2026-01-25 11:50:31'),
('019bf4fd-c8bf-72fe-b3e5-f7f0a7040d92', '019bf4fd-c8bc-724b-9580-5f070064acc3', 'Phỏng vấn kỹ thuật', 2, '#2196F3', 0, '2026-01-25 11:50:31', '2026-01-25 11:50:31'),
('019bf4fd-c8bf-72fe-b3e5-f7f0a7575309', '019bf4fd-c8bc-724b-9580-5f070064acc3', 'Phỏng vấn văn hóa', 3, '#9C27B0', 0, '2026-01-25 11:50:31', '2026-01-25 11:50:31'),
('019bf4fd-c8bf-72fe-b3e5-f7f0a79e78fe', '019bf4fd-c8bc-724b-9580-5f070064acc3', 'Gửi Offer', 4, '#4CAF50', 0, '2026-01-25 11:50:31', '2026-01-25 11:50:31'),
('019bf4fd-c8c0-7352-b82a-8db446bd49c4', '019bf4fd-c8bc-724b-9580-5f070064acc3', 'Hired', 5, '#DFF0D8', 1, '2026-01-25 11:50:31', '2026-01-25 11:50:31'),
('019bf4fd-c8c0-7352-b82a-8db44764379f', '019bf4fd-c8bc-724b-9580-5f070064acc3', 'Rejected', 6, '#F2DEDE', 1, '2026-01-25 11:50:31', '2026-01-25 11:50:31'),
('019bf559-550f-7230-8ea1-ea65f8b883ba', '019bf559-550c-73e7-88a1-bdfe3d2dd31b', 'Sàng lọc hồ sơ', 1, '#FFC107', 0, '2026-01-25 13:30:31', '2026-01-25 13:30:31'),
('019bf559-550f-7230-8ea1-ea65f9a00fb8', '019bf559-550c-73e7-88a1-bdfe3d2dd31b', 'Phỏng vấn kỹ thuật', 2, '#2196F3', 0, '2026-01-25 13:30:31', '2026-01-25 13:30:31'),
('019bf559-550f-7230-8ea1-ea65fa5a74dc', '019bf559-550c-73e7-88a1-bdfe3d2dd31b', 'Phỏng vấn văn hóa', 3, '#9C27B0', 0, '2026-01-25 13:30:31', '2026-01-25 13:30:31'),
('019bf559-5510-7359-b016-39efecf6c0e4', '019bf559-550c-73e7-88a1-bdfe3d2dd31b', 'Gửi Offer', 4, '#4CAF50', 0, '2026-01-25 13:30:31', '2026-01-25 13:30:31'),
('019bf559-5510-7359-b016-39efed473d98', '019bf559-550c-73e7-88a1-bdfe3d2dd31b', 'Hired', 5, '#DFF0D8', 1, '2026-01-25 13:30:31', '2026-01-25 13:30:31'),
('019bf559-5510-7359-b016-39efedd984cb', '019bf559-550c-73e7-88a1-bdfe3d2dd31b', 'Rejected', 6, '#F2DEDE', 1, '2026-01-25 13:30:31', '2026-01-25 13:30:31');

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
('019bee32-1551-70db-868d-8bbe530c43ee', '99e70aa7-823a-4791-971c-42c27500e47b', 'baophungthai3@gmail.com', 'Bao Phung Thai', 'recruiter', '2026-01-24 08:35:04', '2026-01-24 08:39:14'),
('019bf0cf-e398-72fd-9741-4f03d0ccfa34', 'b4db192b-5ecb-4c7c-a2e6-790976e1d383', 'baophungthai6@gmail.com', 'Bao', 'candidate', '2026-01-24 16:25:39', '2026-01-24 16:25:39'),
('019bf2bc-619c-72b6-a8d2-80c3fbf4c5a7', 'ca6b9e8d-6b48-45bf-a94d-507aa1f7a6de', 'kidmardesu@gmail.com', 'sssssssssssssss', 'recruiter', '2026-01-25 01:41:31', '2026-01-25 09:10:44'),
('019bf453-e9a5-70f0-8d37-24664fad38e9', '0acabd04-636a-4830-bccb-bfac2b050b9b', 'baophungthai7@gmail.com', 'Job seeker', 'candidate', '2026-01-25 08:45:29', '2026-01-25 08:45:29'),
('019bf581-f343-73be-b77a-3296ab6138e4', 'c9dfafd3-570a-4d30-aa21-3ad98d7e8dc5', 'nguyenzdiz@gmail.com', 'adminssssss', 'recruiter', '2026-01-25 14:15:49', '2026-01-25 14:15:49');

--
-- Indexes for dumped tables
--

--
-- Indexes for table `hiring_executions`
--
ALTER TABLE `hiring_executions`
  ADD PRIMARY KEY (`ExecutionID`),
  ADD KEY `idx_exec_pipeline` (`PipelineID`),
  ADD KEY `idx_exec_application` (`ApplicationID`);

--
-- Indexes for table `hiring_scorecards`
--
ALTER TABLE `hiring_scorecards`
  ADD PRIMARY KEY (`ScorecardID`),
  ADD KEY `idx_app_score` (`ApplicationID`);

--
-- Indexes for table `interviews`
--
ALTER TABLE `interviews`
  ADD PRIMARY KEY (`InterviewID`),
  ADD KEY `fk_interview_app` (`ApplicationID`);

--
-- Indexes for table `job_applications`
--
ALTER TABLE `job_applications`
  ADD PRIMARY KEY (`ApplicationID`),
  ADD UNIQUE KEY `uq_job_cv` (`JobID`,`CVID`),
  ADD KEY `idx_app_workspace` (`WorkspaceID`),
  ADD KEY `idx_app_job` (`JobID`),
  ADD KEY `fk_application_stage` (`StageID`);

--
-- Indexes for table `rct_hiring_pipelines`
--
ALTER TABLE `rct_hiring_pipelines`
  ADD PRIMARY KEY (`PipelineID`),
  ADD KEY `idx_pipeline_workspace` (`WorkspaceID`);

--
-- Indexes for table `rct_pipeline_stages`
--
ALTER TABLE `rct_pipeline_stages`
  ADD PRIMARY KEY (`StageID`),
  ADD KEY `fk_stage_pipeline` (`PipelineID`);

--
-- Indexes for table `service_users`
--
ALTER TABLE `service_users`
  ADD PRIMARY KEY (`internal_id`),
  ADD KEY `idx_service_users_keycloak_id` (`keycloak_id`);

--
-- Constraints for dumped tables
--

--
-- Constraints for table `hiring_executions`
--
ALTER TABLE `hiring_executions`
  ADD CONSTRAINT `fk_exec_application` FOREIGN KEY (`ApplicationID`) REFERENCES `job_applications` (`ApplicationID`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_exec_pipeline` FOREIGN KEY (`PipelineID`) REFERENCES `rct_hiring_pipelines` (`PipelineID`) ON DELETE CASCADE;

--
-- Constraints for table `interviews`
--
ALTER TABLE `interviews`
  ADD CONSTRAINT `fk_interview_app` FOREIGN KEY (`ApplicationID`) REFERENCES `job_applications` (`ApplicationID`) ON DELETE CASCADE;

--
-- Constraints for table `job_applications`
--
ALTER TABLE `job_applications`
  ADD CONSTRAINT `fk_application_stage` FOREIGN KEY (`StageID`) REFERENCES `rct_pipeline_stages` (`StageID`) ON DELETE SET NULL;

--
-- Constraints for table `rct_pipeline_stages`
--
ALTER TABLE `rct_pipeline_stages`
  ADD CONSTRAINT `fk_stage_pipeline` FOREIGN KEY (`PipelineID`) REFERENCES `rct_hiring_pipelines` (`PipelineID`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
