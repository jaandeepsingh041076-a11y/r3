-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/sql/schema.sql
--  Additive tables only, no foreign keys (characters can be
--  deleted independently). MariaDB 10.2+ safe: plain VARCHAR
--  status columns, no CHECK constraints, no JSON defaults.
--
--  The resource also runs these CREATE TABLE IF NOT EXISTS
--  statements at boot via server/database.lua, so importing this
--  file is optional but recommended for a clean install.
-- ─────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS `grand_police_records` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(96) DEFAULT NULL,
    `dob` VARCHAR(20) DEFAULT NULL,
    `charges` TEXT DEFAULT NULL,
    `notes` TEXT DEFAULT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `officer_name` VARCHAR(96) DEFAULT NULL,
    `wanted_level` INT NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `uk_police_record_cid` (`citizenid`),
    KEY `idx_police_record_name` (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_warrants` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(96) DEFAULT NULL,
    `offence` VARCHAR(48) DEFAULT NULL,
    `reason` VARCHAR(190) DEFAULT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `officer_name` VARCHAR(96) DEFAULT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    `cleared_at` TIMESTAMP NULL DEFAULT NULL,
    `cleared_by` VARCHAR(96) DEFAULT NULL,
    KEY `idx_police_warrant_cid` (`citizenid`, `active`),
    KEY `idx_police_warrant_active` (`active`, `issued_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_bolo` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `name` VARCHAR(96) DEFAULT NULL,
    `plate` VARCHAR(12) DEFAULT NULL,
    `model` VARCHAR(50) DEFAULT NULL,
    `reason` VARCHAR(190) DEFAULT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `officer_name` VARCHAR(96) DEFAULT NULL,
    `active` TINYINT(1) NOT NULL DEFAULT 1,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `expires_at` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_police_bolo_active` (`active`, `created_at`),
    KEY `idx_police_bolo_plate` (`plate`),
    KEY `idx_police_bolo_cid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_evidence` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `case_ref` VARCHAR(32) DEFAULT NULL,
    `label` VARCHAR(96) NOT NULL,
    `detail` VARCHAR(500) DEFAULT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `officer_name` VARCHAR(96) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_police_evidence_cid` (`citizenid`, `created_at`),
    KEY `idx_police_evidence_case` (`case_ref`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_stops` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `officer_name` VARCHAR(96) DEFAULT NULL,
    `driver_citizenid` VARCHAR(50) DEFAULT NULL,
    `driver_name` VARCHAR(96) DEFAULT NULL,
    `plate` VARCHAR(12) DEFAULT NULL,
    `reason` VARCHAR(190) DEFAULT NULL,
    `notes` VARCHAR(500) DEFAULT NULL,
    `closed` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_police_stop_officer` (`officer_citizenid`, `closed`),
    KEY `idx_police_stop_driver` (`driver_citizenid`),
    KEY `idx_police_stop_created` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_fines` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(96) DEFAULT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `officer_name` VARCHAR(96) DEFAULT NULL,
    `offence` VARCHAR(48) DEFAULT NULL,
    `reason` VARCHAR(190) DEFAULT NULL,
    `amount` INT NOT NULL DEFAULT 0,
    `paid` TINYINT(1) NOT NULL DEFAULT 0,
    `paid_at` TIMESTAMP NULL DEFAULT NULL,
    `due_at` TIMESTAMP NULL DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_police_fine_cid` (`citizenid`, `paid`),
    KEY `idx_police_fine_officer` (`officer_citizenid`, `created_at`),
    KEY `idx_police_fine_due` (`paid`, `due_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_duty` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(96) DEFAULT NULL,
    `job` VARCHAR(48) DEFAULT NULL,
    `grade` INT NOT NULL DEFAULT 0,
    `station` VARCHAR(32) DEFAULT NULL,
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ended_at` TIMESTAMP NULL DEFAULT NULL,
    `minutes` INT NOT NULL DEFAULT 0,
    KEY `idx_police_duty_cid` (`citizenid`, `ended_at`),
    KEY `idx_police_duty_station` (`station`, `ended_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_calls` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `caller_citizenid` VARCHAR(50) DEFAULT NULL,
    `caller_name` VARCHAR(96) DEFAULT NULL,
    `kind` VARCHAR(24) NOT NULL DEFAULT '911',
    `message` VARCHAR(190) DEFAULT NULL,
    `pos_x` FLOAT NOT NULL DEFAULT 0.0,
    `pos_y` FLOAT NOT NULL DEFAULT 0.0,
    `pos_z` FLOAT NOT NULL DEFAULT 0.0,
    `priority` INT NOT NULL DEFAULT 2,
    `status` VARCHAR(16) NOT NULL DEFAULT 'open',
    `assigned` VARCHAR(96) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `closed_at` TIMESTAMP NULL DEFAULT NULL,
    KEY `idx_police_call_status` (`status`, `created_at`),
    KEY `idx_police_call_kind` (`kind`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_sentences` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `name` VARCHAR(96) DEFAULT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `officer_name` VARCHAR(96) DEFAULT NULL,
    `reason` VARCHAR(190) DEFAULT NULL,
    `minutes` INT NOT NULL DEFAULT 0,
    `started_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `release_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `released_at` TIMESTAMP NULL DEFAULT NULL,
    `release_reason` VARCHAR(48) DEFAULT NULL,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_police_sentence_cid` (`citizenid`, `released_at`),
    KEY `idx_police_sentence_due` (`release_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_licences` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `citizenid` VARCHAR(50) NOT NULL,
    `licence` VARCHAR(24) NOT NULL,
    `status` VARCHAR(16) NOT NULL DEFAULT 'valid',
    `issued_by` VARCHAR(96) DEFAULT NULL,
    `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `revoked_at` TIMESTAMP NULL DEFAULT NULL,
    UNIQUE KEY `uk_police_licence` (`citizenid`, `licence`),
    KEY `idx_police_licence_type` (`licence`, `status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_wanted` (
    `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
    `stars` INT NOT NULL DEFAULT 0,
    `reason` VARCHAR(190) DEFAULT NULL,
    `last_crime_at` TIMESTAMP NULL DEFAULT NULL,
    `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    KEY `idx_police_wanted_stars` (`stars`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `grand_police_impound` (
    `id` BIGINT AUTO_INCREMENT PRIMARY KEY,
    `plate` VARCHAR(12) NOT NULL,
    `citizenid` VARCHAR(50) DEFAULT NULL,
    `model` VARCHAR(50) DEFAULT NULL,
    `officer_citizenid` VARCHAR(50) DEFAULT NULL,
    `fee` INT NOT NULL DEFAULT 0,
    `release_at` TIMESTAMP NULL DEFAULT NULL,
    `released` TINYINT(1) NOT NULL DEFAULT 0,
    `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY `idx_police_impound_plate` (`plate`, `released`),
    KEY `idx_police_impound_cid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
