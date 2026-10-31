-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/server/mdt.lua
--  The Mobile Data Terminal, minus the UI. Everything is served
--  as structured tables the client prints to chat.
-- ─────────────────────────────────────────────────────────────

MDT = MDT or {}
local M = MDT

-- ─── Guards ──────────────────────────────────────────────────
function M.Allowed(src)
    if not PoliceUtil.IsPolice(src) then
        return false, 'MDT access is restricted to law enforcement'
    end
    if Config.Mdt.requireDuty and not PoliceUtil.OnDuty(src) then
        return false, Config.Text.noDuty
    end
    if not PoliceUtil.Cooldown('mdt:' .. tostring(src), 1) then
        return false, Config.Text.rateLimited
    end
    return true
end

local function officer(src)
    local citizenid = PoliceUtil.GetCitizenId(src)
    local name = GetPlayerName(src) or citizenid or tostring(src)
    return citizenid, name
end

--- Resolves a server id, citizenid or (partial) name to a citizen.
function M.Resolve(query)
    query = tostring(query or '')
    if query == '' then return nil end

    local asNumber = tonumber(query)
    if asNumber and GetPlayerName(asNumber) then
        local cid = PoliceUtil.GetCitizenId(asNumber)
        return cid, asNumber, GetPlayerName(asNumber)
    end

    local cid = query
    if #query > 12 then
        local row = Database.Character(query)
        if row then
            return query, nil, Database.CharacterName(query)
        end
    end

    local rows = Database.SearchRecords(query, 1)
    if rows and rows[1] then
        return rows[1].citizenid, nil, rows[1].name
    end

    local row = Database.Character(cid)
    if row then
        return cid, nil, Database.CharacterName(cid)
    end

    return nil
end

local function ensureRecord(citizenid, name)
    local record = Database.Record(citizenid)
    if record then return record end
    return Database.UpsertRecord(citizenid, name, nil, nil)
end

-- ─── Profile ─────────────────────────────────────────────────
function M.Profile(src, query)
    local ok, reason = M.Allowed(src)
    if not ok then return false, reason end

    local citizenid, onlineSrc, name = M.Resolve(query)
    if not citizenid then return false, 'No citizen or record matched that query' end

    local character = Database.Character(citizenid)
    local record = ensureRecord(citizenid, name)
    local warrants = Database.WarrantsFor(citizenid)
    local fines = Database.FineHistory(citizenid, 10)
    local sentences = Database.SentenceHistory(citizenid, 5)
    local licences = Database.Licences(citizenid)
    local evidence = Database.EvidenceFor(citizenid, Config.Mdt.pageSize)
    local wanted = Wanted.Get(citizenid)

    local profile = {
        citizenid = citizenid,
        name = name or Database.CharacterName(citizenid),
        online = onlineSrc ~= nil,
        serverId = onlineSrc,
        job = character and character.job or 'unknown',
        jobGrade = character and character.job_grade or 0,
        wanted = wanted,
        record = record,
        warrants = warrants or {},
        fines = fines or {},
        unpaid = 0,
        sentences = sentences or {},
        licences = licences or {},
        evidence = evidence or {},
    }

    for _, fine in ipairs(profile.fines) do
        if not fine.paid or tonumber(fine.paid) == 0 then
            profile.unpaid = profile.unpaid + (tonumber(fine.amount) or 0)
        end
    end

    TriggerClientEvent('grand_police:client:MdtProfile', src, profile)
    return true, profile
end

-- ─── Search ──────────────────────────────────────────────────
function M.Search(src, query)
    local ok, reason = M.Allowed(src)
    if not ok then return false, reason end

    query = PoliceUtil.SanitizeText(query or '', 64)
    if query == '' then return false, 'Provide a name or citizenid' end

    local rows = Database.SearchRecords(query, Config.Mdt.searchLimit or 20)
    local results = {}
    for _, row in ipairs(rows) do
        results[#results + 1] = {
            citizenid = row.citizenid,
            name = row.name,
            wanted = tonumber(row.wanted_level) or 0,
            updated = row.updated_at,
            charges = row.charges,
        }
    end

    TriggerClientEvent('grand_police:client:MdtSearch', src, query, results)
    return true, results
end

-- ─── Record editing ──────────────────────────────────────────
function M.Record(src, query, charges, notes)
    local ok, reason = M.Allowed(src)
    if not ok then return false, reason end

    local citizenid, _, name = M.Resolve(query)
    if not citizenid then return false, 'No citizen matched that query' end

    local officerCid, officerName = officer(src)
    local record = ensureRecord(citizenid, name)

    if charges and charges ~= '' then
        local previous = record and record.charges or ''
        local stamp = os.date('%Y-%m-%d %H:%M')
        local entry = ('[%s] %s: %s'):format(stamp, officerName, PoliceUtil.SanitizeText(charges, 300))
        local combined = previous ~= '' and (previous .. '\n' .. entry) or entry
        Database.UpsertRecord(citizenid, name, officerCid, officerName, { charges = combined })
    end

    if notes and notes ~= '' then
        local previous = record and record.notes or ''
        local stamp = os.date('%Y-%m-%d %H:%M')
        local entry = ('[%s] %s: %s'):format(stamp, officerName, PoliceUtil.SanitizeText(notes, 300))
        local combined = previous ~= '' and (previous .. '\n' .. entry) or entry
        Database.UpsertRecord(citizenid, name, officerCid, officerName, { notes = combined })
    end

    TriggerClientEvent('grand_police:client:MdtNotice', src,
        ('Record updated for %s (%s)'):format(name or citizenid, citizenid), 'success')
    return true
end

-- ─── Warrants ────────────────────────────────────────────────
function M.Warrant(src, query, offenceId, reason)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end

    if not PoliceUtil.IsSupervisor(src) then
        return false, 'supervisor clearance required for warrants'
    end

    local citizenid, _, name = M.Resolve(query)
    if not citizenid then return false, 'No citizen matched that query' end

    reason = PoliceUtil.SanitizeText(reason or '', 190)
    if reason == '' then return false, Config.Text.noReason end

    local offence = PoliceUtil.Offence(offenceId)
    local officerCid, officerName = officer(src)

    local id = Database.AddWarrant({
        citizenid = citizenid,
        name = name or Database.CharacterName(citizenid),
        offence = offence and offence.id or nil,
        reason = reason,
        officer_citizenid = officerCid,
        officer_name = officerName,
        hours = Config.Mdt.warrantHours or 72,
    })

    if not id then return false, 'warrant could not be filed' end

    if offence and offence.stars and offence.stars > 0 then
        Wanted.Set(citizenid, math.max(Wanted.Get(citizenid), offence.stars),
            ('Warrant: %s'):format(reason))
    end

    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'warrant',
        priority = 3,
        message = ('WARRANT #%d for %s: %s'):format(id, name or citizenid, reason),
        citizenid = citizenid,
    })

    TriggerClientEvent('grand_police:client:MdtNotice', src,
        ('Warrant #%d filed for %s'):format(id, name or citizenid), 'success')
    return true, id
end

function M.ClearWarrant(src, id)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end
    if not PoliceUtil.IsSupervisor(src) then return false, 'supervisor clearance required' end

    id = PoliceUtil.Int(id)
    if not id then return false, 'usage: /warrant clear <id>' end

    local _, officerName = officer(src)
    if not Database.ClearWarrant(id, officerName) then
        return false, 'warrant not found or already cleared'
    end

    TriggerClientEvent('grand_police:client:MdtNotice', src, ('Warrant #%d cleared'):format(id), 'success')
    return true
end

function M.Warrants(src)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end

    local rows = Database.ActiveWarrants(Config.Mdt.searchLimit or 20)
    TriggerClientEvent('grand_police:client:MdtWarrants', src, rows)
    return true, rows
end

-- ─── BOLO ────────────────────────────────────────────────────
function M.Bolo(src, query, reason)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end

    reason = PoliceUtil.SanitizeText(reason or '', 190)
    if reason == '' then return false, Config.Text.noReason end

    local officerCid, officerName = officer(src)
    local citizenid, _, name = M.Resolve(query)
    local plate, model

    if not citizenid then
        -- Treat it as a plate when it looks like one.
        plate = PoliceUtil.SanitizePlate(query)
        if #plate < 3 then
            return false, 'No citizen or plate matched that query'
        end
    end

    local id = Database.AddBolo({
        citizenid = citizenid,
        name = name,
        plate = plate,
        model = model,
        reason = reason,
        officer_citizenid = officerCid,
        officer_name = officerName,
        hours = Config.Mdt.boloHours or 48,
    })
    if not id then return false, 'BOLO could not be filed' end

    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'bolo',
        priority = 2,
        message = ('BOLO #%d: %s %s - %s'):format(
            id, name or plate or citizenid or '?', citizenid and ('(' .. citizenid .. ')') or '', reason),
        citizenid = citizenid,
        plate = plate,
    })

    TriggerClientEvent('grand_police:client:MdtNotice', src, ('BOLO #%d filed'):format(id), 'success')
    return true, id
end

function M.Bolos(src)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end
    local rows = Database.ActiveBolos(Config.Mdt.searchLimit or 20)
    TriggerClientEvent('grand_police:client:MdtBolos', src, rows)
    return true, rows
end

function M.ClearBolo(src, id)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end
    id = PoliceUtil.Int(id)
    if not id then return false, 'usage: /bolo clear <id>' end
    if not Database.ClearBolo(id) then return false, 'BOLO not found' end
    TriggerClientEvent('grand_police:client:MdtNotice', src, ('BOLO #%d cleared'):format(id), 'success')
    return true
end

-- ─── Evidence ────────────────────────────────────────────────
function M.Evidence(src, query, label, detail)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end

    local citizenid, _, name = M.Resolve(query)
    if not citizenid then return false, 'No citizen matched that query' end

    label = PoliceUtil.SanitizeText(label or '', 96)
    if label == '' then return false, 'Provide an evidence label' end

    local officerCid, officerName = officer(src)
    local id = Database.AddEvidence({
        citizenid = citizenid,
        case_ref = ('CASE-%d'):format(os.time()),
        label = label,
        detail = detail,
        officer_citizenid = officerCid,
        officer_name = officerName,
    })
    if not id then return false, 'evidence could not be logged' end

    TriggerClientEvent('grand_police:client:MdtNotice', src,
        ('Evidence #%d logged for %s'):format(id, name or citizenid), 'success')
    return true, id
end

-- ─── Lists / stats ───────────────────────────────────────────
function M.Recent(src)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end
    local rows = Database.RecentRecords(Config.Mdt.pageSize or 8)
    TriggerClientEvent('grand_police:client:MdtRecent', src, rows or {})
    return true
end

function M.Stats(src)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end
    local stats = Database.Stats()
    stats.onDuty = Duty.Count('police')
    stats.emsOnDuty = Duty.Count('ems')
    stats.roster = Duty.Roster()
    TriggerClientEvent('grand_police:client:MdtStats', src, stats)
    return true, stats
end

function M.WantedBoard(src)
    local ok, err = M.Allowed(src)
    if not ok then return false, err end
    TriggerClientEvent('grand_police:client:MdtWanted', src, Wanted.Board())
    return true
end

return M
