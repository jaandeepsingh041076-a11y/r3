-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/server/database.lua
--  Every SQL statement for police, EMS, MDT and the prison.
--  oxmysql MySQL.*.await only. Additive tables, no FKs.
-- ─────────────────────────────────────────────────────────────

Database = Database or {}
local DB = Database

DB.Ready = false

-- ─── Schema ──────────────────────────────────────────────────
DB.Schema = {
    [[CREATE TABLE IF NOT EXISTS `grand_police_records` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_warrants` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_bolo` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_evidence` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_stops` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_fines` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_duty` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_calls` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_sentences` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_licences` (
        `id` INT AUTO_INCREMENT PRIMARY KEY,
        `citizenid` VARCHAR(50) NOT NULL,
        `licence` VARCHAR(24) NOT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'valid',
        `issued_by` VARCHAR(96) DEFAULT NULL,
        `issued_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
        `revoked_at` TIMESTAMP NULL DEFAULT NULL,
        UNIQUE KEY `uk_police_licence` (`citizenid`, `licence`),
        KEY `idx_police_licence_type` (`licence`, `status`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_wanted` (
        `citizenid` VARCHAR(50) NOT NULL PRIMARY KEY,
        `stars` INT NOT NULL DEFAULT 0,
        `reason` VARCHAR(190) DEFAULT NULL,
        `last_crime_at` TIMESTAMP NULL DEFAULT NULL,
        `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        KEY `idx_police_wanted_stars` (`stars`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],

    [[CREATE TABLE IF NOT EXISTS `grand_police_impound` (
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
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci]],
}

-- ─── Wrappers ────────────────────────────────────────────────
local function safe(fn, sql, params)
    local ok, result = pcall(fn, sql, params or {})
    if not ok then
        PoliceUtil.Log('error', ('query failed: %s'):format(tostring(result)))
        return nil
    end
    return result
end

function DB.Single(sql, params) return safe(MySQL.single.await, sql, params) end
function DB.Query(sql, params) return safe(MySQL.query.await, sql, params) or {} end
function DB.Scalar(sql, params) return safe(MySQL.scalar.await, sql, params) end
function DB.Insert(sql, params) return safe(MySQL.insert.await, sql, params) end
function DB.Update(sql, params) return safe(MySQL.update.await, sql, params) or 0 end

function DB.Bootstrap()
    if DB.Ready then return true end
    for _, statement in ipairs(DB.Schema) do
        local ok = pcall(MySQL.query.await, statement)
        if not ok then
            PoliceUtil.Log('error', 'schema statement failed - check DB privileges')
        end
    end
    DB.Ready = true
    PoliceUtil.Log('info', 'police schema ready')
    return true
end

-- ─── Records ─────────────────────────────────────────────────
function DB.Character(citizenid)
    return DB.Single([[
        SELECT citizenid, firstname, lastname, job, job_grade, level, created_at
          FROM `characters` WHERE citizenid = ? LIMIT 1
    ]], { citizenid })
end

function DB.CharacterName(citizenid)
    local row = DB.Character(citizenid)
    if not row then return citizenid end
    local name = ('%s %s'):format(tostring(row.firstname or ''), tostring(row.lastname or ''))
    name = name:gsub('^%s+', ''):gsub('%s+$', '')
    if name ~= '' then return name end
    return citizenid
end

function DB.Record(citizenid)
    return DB.Single('SELECT * FROM `grand_police_records` WHERE citizenid = ? LIMIT 1', { citizenid })
end

function DB.UpsertRecord(citizenid, name, officerCid, officerName, fields)
    fields = fields or {}
    DB.Insert([[
        INSERT INTO `grand_police_records` (citizenid, name, officer_citizenid, officer_name)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE name = COALESCE(VALUES(name), name)
    ]], { citizenid, name, officerCid, officerName })

    if fields.charges then
        DB.Update('UPDATE `grand_police_records` SET charges = ? WHERE citizenid = ?',
            { PoliceUtil.SanitizeText(fields.charges, 2000), citizenid })
    end
    if fields.notes then
        DB.Update('UPDATE `grand_police_records` SET notes = ? WHERE citizenid = ?',
            { PoliceUtil.SanitizeText(fields.notes, 2000), citizenid })
    end
    if fields.wanted ~= nil then
        DB.Update('UPDATE `grand_police_records` SET wanted_level = ? WHERE citizenid = ?',
            { math.max(0, PoliceUtil.Int(fields.wanted) or 0), citizenid })
    end
    return DB.Record(citizenid)
end

function DB.SearchRecords(query, limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 20, 1, 50)
    local like = '%' .. tostring(query or '') .. '%'
    return DB.Query([[
        SELECT citizenid, name, charges, notes, wanted_level, updated_at
          FROM `grand_police_records`
         WHERE citizenid LIKE ? OR name LIKE ?
         ORDER BY updated_at DESC
         LIMIT ?
    ]], { like, like, limit })
end

function DB.RecentRecords(limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 10, 1, 50)
    return DB.Query([[
        SELECT citizenid, name, charges, wanted_level, updated_at
          FROM `grand_police_records`
         ORDER BY updated_at DESC LIMIT ?
    ]], { limit })
end

-- ─── Warrants ────────────────────────────────────────────────
function DB.AddWarrant(row)
    return DB.Insert([[
        INSERT INTO `grand_police_warrants`
            (citizenid, name, offence, reason, officer_citizenid, officer_name, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], {
        row.citizenid, row.name, row.offence, PoliceUtil.SanitizeText(row.reason, 190),
        row.officer_citizenid, row.officer_name, PoliceUtil.Int(row.hours) or 72,
    })
end

function DB.ActiveWarrants(limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 25, 1, 100)
    return DB.Query([[
        SELECT * FROM `grand_police_warrants`
         WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW())
         ORDER BY issued_at DESC LIMIT ?
    ]], { limit })
end

function DB.WarrantsFor(citizenid)
    return DB.Query([[
        SELECT * FROM `grand_police_warrants`
         WHERE citizenid = ? AND active = 1
           AND (expires_at IS NULL OR expires_at > NOW())
         ORDER BY issued_at DESC
    ]], { citizenid })
end

function DB.ClearWarrant(id, clearedBy)
    return DB.Update([[
        UPDATE `grand_police_warrants`
           SET active = 0, cleared_at = NOW(), cleared_by = ?
         WHERE id = ? AND active = 1
    ]], { clearedBy, PoliceUtil.Int(id) or 0 }) == 1
end

function DB.ExpireWarrants()
    return DB.Update([[
        UPDATE `grand_police_warrants` SET active = 0, cleared_at = NOW(), cleared_by = 'expired'
         WHERE active = 1 AND expires_at IS NOT NULL AND expires_at <= NOW()
    ]], {})
end

-- ─── BOLO ────────────────────────────────────────────────────
function DB.AddBolo(row)
    return DB.Insert([[
        INSERT INTO `grand_police_bolo`
            (citizenid, name, plate, model, reason, officer_citizenid, officer_name, expires_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], {
        row.citizenid, row.name, row.plate, row.model,
        PoliceUtil.SanitizeText(row.reason, 190), row.officer_citizenid, row.officer_name,
        PoliceUtil.Int(row.hours) or 48,
    })
end

function DB.ActiveBolos(limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 25, 1, 100)
    return DB.Query([[
        SELECT * FROM `grand_police_bolo`
         WHERE active = 1 AND (expires_at IS NULL OR expires_at > NOW())
         ORDER BY created_at DESC LIMIT ?
    ]], { limit })
end

function DB.ClearBolo(id)
    return DB.Update('UPDATE `grand_police_bolo` SET active = 0 WHERE id = ?',
        { PoliceUtil.Int(id) or 0 }) == 1
end

function DB.BoloForPlate(plate)
    return DB.Single([[
        SELECT * FROM `grand_police_bolo`
         WHERE plate = ? AND active = 1
           AND (expires_at IS NULL OR expires_at > NOW())
         LIMIT 1
    ]], { tostring(plate) })
end

-- ─── Evidence ────────────────────────────────────────────────
function DB.AddEvidence(row)
    return DB.Insert([[
        INSERT INTO `grand_police_evidence`
            (citizenid, case_ref, label, detail, officer_citizenid, officer_name)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        row.citizenid, row.case_ref, PoliceUtil.SanitizeText(row.label, 96),
        PoliceUtil.SanitizeText(row.detail, 500), row.officer_citizenid, row.officer_name,
    })
end

function DB.EvidenceFor(citizenid, limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 10, 1, 50)
    return DB.Query([[
        SELECT * FROM `grand_police_evidence`
         WHERE citizenid = ? ORDER BY created_at DESC LIMIT ?
    ]], { citizenid, limit })
end

-- ─── Traffic stops ───────────────────────────────────────────
function DB.CreateStop(row)
    return DB.Insert([[
        INSERT INTO `grand_police_stops`
            (officer_citizenid, officer_name, driver_citizenid, driver_name, plate, reason, notes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ]], {
        row.officer_citizenid, row.officer_name, row.driver_citizenid, row.driver_name,
        row.plate, PoliceUtil.SanitizeText(row.reason, 190), PoliceUtil.SanitizeText(row.notes, 500),
    })
end

function DB.CloseStop(id, notes)
    return DB.Update([[
        UPDATE `grand_police_stops`
           SET closed = 1, closed_at = NOW(), notes = COALESCE(?, notes)
         WHERE id = ?
    ]], { notes and PoliceUtil.SanitizeText(notes, 500) or nil, PoliceUtil.Int(id) or 0 }) == 1
end

function DB.ActiveStops(officerCid)
    return DB.Query([[
        SELECT * FROM `grand_police_stops`
         WHERE closed = 0 AND officer_citizenid = ?
         ORDER BY created_at DESC LIMIT 10
    ]], { officerCid })
end

-- ─── Fines ───────────────────────────────────────────────────
function DB.CreateFine(row)
    return DB.Insert([[
        INSERT INTO `grand_police_fines`
            (citizenid, name, officer_citizenid, officer_name, offence, reason, amount, due_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? HOUR))
    ]], {
        row.citizenid, row.name, row.officer_citizenid, row.officer_name, row.offence,
        PoliceUtil.SanitizeText(row.reason, 190), PoliceUtil.Int(row.amount) or 0,
        PoliceUtil.Int(row.dueHours) or 72,
    })
end

function DB.Fine(id)
    return DB.Single('SELECT * FROM `grand_police_fines` WHERE id = ? LIMIT 1',
        { PoliceUtil.Int(id) or 0 })
end

function DB.UnpaidFines(citizenid)
    return DB.Query([[
        SELECT * FROM `grand_police_fines`
         WHERE citizenid = ? AND paid = 0
         ORDER BY created_at ASC
    ]], { citizenid })
end

function DB.FineHistory(citizenid, limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 15, 1, 50)
    return DB.Query([[
        SELECT * FROM `grand_police_fines`
         WHERE citizenid = ? ORDER BY created_at DESC LIMIT ?
    ]], { citizenid, limit })
end

function DB.MarkFinePaid(id)
    return DB.Update('UPDATE `grand_police_fines` SET paid = 1, paid_at = NOW() WHERE id = ? AND paid = 0',
        { PoliceUtil.Int(id) or 0 }) == 1
end

function DB.UnpaidTotal(citizenid)
    return tonumber(DB.Scalar([[
        SELECT COALESCE(SUM(amount), 0) FROM `grand_police_fines`
         WHERE citizenid = ? AND paid = 0
    ]], { citizenid })) or 0
end

function DB.OverdueFines()
    return DB.Query([[
        SELECT * FROM `grand_police_fines`
         WHERE paid = 0 AND due_at IS NOT NULL AND due_at <= NOW()
         LIMIT 100
    ]], {})
end

function DB.OfficerFines(citizenid, limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 10, 1, 50)
    return DB.Query([[
        SELECT * FROM `grand_police_fines`
         WHERE officer_citizenid = ? ORDER BY created_at DESC LIMIT ?
    ]], { citizenid, limit })
end

-- ─── Duty ────────────────────────────────────────────────────
function DB.StartDuty(citizenid, name, job, grade, station)
    DB.Update('UPDATE `grand_police_duty` SET ended_at = NOW() WHERE citizenid = ? AND ended_at IS NULL',
        { citizenid })
    return DB.Insert([[
        INSERT INTO `grand_police_duty` (citizenid, name, job, grade, station)
        VALUES (?, ?, ?, ?, ?)
    ]], { citizenid, name, job, grade, station })
end

function DB.EndDuty(citizenid)
    DB.Update([[
        UPDATE `grand_police_duty`
           SET ended_at = NOW(), minutes = TIMESTAMPDIFF(MINUTE, started_at, NOW())
         WHERE citizenid = ? AND ended_at IS NULL
    ]], { citizenid })
end

function DB.Roster()
    return DB.Query([[
        SELECT citizenid, name, job, grade, station, started_at
          FROM `grand_police_duty`
         WHERE ended_at IS NULL
         ORDER BY started_at ASC
    ]], {})
end

function DB.ActiveDutyFor(citizenid)
    return DB.Single([[
        SELECT * FROM `grand_police_duty`
         WHERE citizenid = ? AND ended_at IS NULL
         ORDER BY id DESC LIMIT 1
    ]], { citizenid })
end

function DB.DutyHistory(citizenid, limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 10, 1, 50)
    return DB.Query([[
        SELECT id, job, grade, station, started_at, ended_at, minutes
          FROM `grand_police_duty` WHERE citizenid = ?
         ORDER BY id DESC LIMIT ?
    ]], { citizenid, limit })
end

-- ─── Calls ───────────────────────────────────────────────────
function DB.CreateCall(row)
    return DB.Insert([[
        INSERT INTO `grand_police_calls`
            (caller_citizenid, caller_name, kind, message, pos_x, pos_y, pos_z, priority)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    ]], {
        row.caller_citizenid, row.caller_name, row.kind or '911',
        PoliceUtil.SanitizeText(row.message, 190), row.x or 0.0, row.y or 0.0, row.z or 0.0,
        PoliceUtil.Int(row.priority) or 2,
    })
end

function DB.ActiveCalls(limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 20, 1, 100)
    return DB.Query([[
        SELECT * FROM `grand_police_calls`
         WHERE status <> 'closed'
         ORDER BY priority DESC, created_at DESC LIMIT ?
    ]], { limit })
end

function DB.CloseCall(id, officerName)
    return DB.Update([[
        UPDATE `grand_police_calls`
           SET status = 'closed', assigned = ?, closed_at = NOW()
         WHERE id = ? AND status <> 'closed'
    ]], { officerName, PoliceUtil.Int(id) or 0 }) == 1
end

function DB.CloseStaleCalls(minutes)
    DB.Update([[
        UPDATE `grand_police_calls` SET status = 'closed', closed_at = NOW()
         WHERE status = 'open' AND created_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { PoliceUtil.Int(minutes) or 120 })
end

-- ─── Sentences ───────────────────────────────────────────────
function DB.CreateSentence(row)
    return DB.Insert([[
        INSERT INTO `grand_police_sentences`
            (citizenid, name, officer_citizenid, officer_name, reason, minutes, release_at)
        VALUES (?, ?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? MINUTE))
    ]], {
        row.citizenid, row.name, row.officer_citizenid, row.officer_name,
        PoliceUtil.SanitizeText(row.reason, 190), PoliceUtil.Int(row.minutes) or 0,
        PoliceUtil.Int(row.minutes) or 0,
    })
end

function DB.ActiveSentence(citizenid)
    return DB.Single([[
        SELECT * FROM `grand_police_sentences`
         WHERE citizenid = ? AND released_at IS NULL
         ORDER BY id DESC LIMIT 1
    ]], { citizenid })
end

function DB.DueSentences()
    return DB.Query([[
        SELECT * FROM `grand_police_sentences`
         WHERE released_at IS NULL AND release_at <= NOW()
         LIMIT 50
    ]], {})
end

function DB.ReleaseSentence(citizenid, reason)
    DB.Update([[
        UPDATE `grand_police_sentences`
           SET released_at = NOW(), release_reason = ?
         WHERE citizenid = ? AND released_at IS NULL
    ]], { PoliceUtil.SanitizeText(reason or 'released', 48), citizenid })
end

function DB.SentenceHistory(citizenid, limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 10, 1, 50)
    return DB.Query([[
        SELECT * FROM `grand_police_sentences`
         WHERE citizenid = ? ORDER BY id DESC LIMIT ?
    ]], { citizenid, limit })
end

function DB.SentenceById(id)
    return DB.Single('SELECT * FROM `grand_police_sentences` WHERE id = ? LIMIT 1',
        { PoliceUtil.Int(id) or 0 })
end

function DB.SentenceRemaining(citizenid)
    local seconds = DB.Scalar([[
        SELECT GREATEST(0, TIMESTAMPDIFF(SECOND, NOW(), release_at))
          FROM `grand_police_sentences`
         WHERE citizenid = ? AND released_at IS NULL
         ORDER BY id DESC LIMIT 1
    ]], { citizenid })
    return tonumber(seconds) or 0
end

-- ─── Licences ────────────────────────────────────────────────
function DB.Licences(citizenid)
    return DB.Query('SELECT * FROM `grand_police_licences` WHERE citizenid = ?', { citizenid })
end

function DB.Licence(citizenid, licence)
    return DB.Single([[
        SELECT * FROM `grand_police_licences`
         WHERE citizenid = ? AND licence = ? LIMIT 1
    ]], { citizenid, tostring(licence) })
end

function DB.SetLicence(citizenid, licence, status, issuedBy)
    DB.Insert([[
        INSERT INTO `grand_police_licences` (citizenid, licence, status, issued_by)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE status = VALUES(status), issued_by = VALUES(issued_by),
            issued_at = IF(VALUES(status) = 'valid', NOW(), issued_at),
            revoked_at = IF(VALUES(status) = 'valid', NULL, NOW())
    ]], { citizenid, tostring(licence), status, issuedBy })
    return DB.Licence(citizenid, licence)
end

-- ─── Wanted ──────────────────────────────────────────────────
function DB.SetWanted(citizenid, stars, reason)
    DB.Insert([[
        INSERT INTO `grand_police_wanted` (citizenid, stars, reason, last_crime_at)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE stars = VALUES(stars), reason = VALUES(reason), last_crime_at = NOW()
    ]], { citizenid, math.max(0, PoliceUtil.Int(stars) or 0), PoliceUtil.SanitizeText(reason, 190) })
end

function DB.Wanted(citizenid)
    return DB.Single('SELECT * FROM `grand_police_wanted` WHERE citizenid = ? LIMIT 1', { citizenid })
end

function DB.ClearWanted(citizenid)
    return DB.Update('UPDATE `grand_police_wanted` SET stars = 0 WHERE citizenid = ?',
        { citizenid }) > 0
end

function DB.WantedList(limit)
    limit = PoliceUtil.Clamp(PoliceUtil.Int(limit) or 50, 1, 200)
    return DB.Query([[
        SELECT w.citizenid, w.stars, w.reason, w.last_crime_at, r.name
          FROM `grand_police_wanted` w
          LEFT JOIN `grand_police_records` r ON r.citizenid = w.citizenid
         WHERE w.stars > 0 ORDER BY w.stars DESC, w.last_crime_at ASC
         LIMIT ?
    ]], { limit })
end

function DB.DecayWanted(minutes)
    return DB.Update([[
        UPDATE `grand_police_wanted`
           SET stars = stars - 1, last_crime_at = NOW()
         WHERE stars > 0 AND last_crime_at < DATE_SUB(NOW(), INTERVAL ? MINUTE)
    ]], { PoliceUtil.Int(minutes) or 8 })
end

-- ─── Impound ─────────────────────────────────────────────────
function DB.VehicleByPlate(plate)
    return DB.Single('SELECT * FROM `grand_vehicles` WHERE plate = ? LIMIT 1', { plate })
end

function DB.SetVehicleState(plate, state)
    return DB.Update('UPDATE `grand_vehicles` SET state = ? WHERE plate = ?', { state, plate }) > 0
end

function DB.ImpoundVehicle(plate, citizenid, model, officerCid, fee, days)
    return DB.Insert([[
        INSERT INTO `grand_police_impound`
            (plate, citizenid, model, officer_citizenid, fee, release_at)
        VALUES (?, ?, ?, ?, ?, DATE_ADD(NOW(), INTERVAL ? DAY))
    ]], { plate, citizenid, model, officerCid, fee, PoliceUtil.Int(days) or 7 })
end

function DB.Impounded(plate)
    return DB.Single([[
        SELECT * FROM `grand_police_impound`
         WHERE plate = ? AND released = 0 ORDER BY id DESC LIMIT 1
    ]], { plate })
end

function DB.ReleaseImpound(plate)
    return DB.Update('UPDATE `grand_police_impound` SET released = 1 WHERE plate = ? AND released = 0',
        { plate }) > 0
end

-- ─── Stats ───────────────────────────────────────────────────
function DB.Stats()
    local row = DB.Single([[
        SELECT
          (SELECT COUNT(*) FROM `grand_police_fines` WHERE paid = 0) AS unpaid_fines,
          (SELECT COALESCE(SUM(amount), 0) FROM `grand_police_fines` WHERE paid = 0) AS unpaid_value,
          (SELECT COUNT(*) FROM `grand_police_warrants` WHERE active = 1) AS warrants,
          (SELECT COUNT(*) FROM `grand_police_sentences` WHERE released_at IS NULL) AS inmates,
          (SELECT COUNT(*) FROM `grand_police_calls` WHERE status <> 'closed') AS calls
    ]], {})
    return row or { unpaid_fines = 0, unpaid_value = 0, warrants = 0, inmates = 0, calls = 0 }
end

return DB
