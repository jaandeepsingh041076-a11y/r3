-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/server/main.lua
--  Commands, net events, exports and lifecycle.
--  Loads last: Database, Duty, Wanted, Prison, MDT and Traffic
--  are already global.
-- ─────────────────────────────────────────────────────────────

Police = Police or {}
local PL = Police

local RESOURCE = GetCurrentResourceName()

local LicenceTypes = {
    driver = 'Driver Licence',
    weapon = 'Firearm Licence',
    hunting = 'Hunting Licence',
    boating = 'Boating Licence',
    pilot = 'Pilot Licence',
}

-- ─── Small helpers ───────────────────────────────────────────
local function notify(src, message, kind)
    PoliceUtil.Notify(src, message, kind)
end

local function online(src)
    src = tonumber(src)
    return src ~= nil and src > 0 and GetPlayerName(src) ~= nil
end

local function officerGuard(src)
    if not PoliceUtil.IsPolice(src) then return false, Config.Text.noFaction end
    if not PoliceUtil.OnDuty(src) then return false, Config.Text.noDuty end
    return true
end

local function emsGuard(src)
    if not PoliceUtil.IsEMS(src) then return false, Config.Text.noFaction end
    if not PoliceUtil.OnDuty(src) then return false, Config.Text.noDuty end
    return true
end

local function targetName(target)
    local src = tonumber(target)
    if src and online(src) then return GetPlayerName(src) end
    return Database.CharacterName(tostring(target))
end

local function resolveCitizen(target)
    local src = tonumber(target)
    if src and online(src) then
        return PoliceUtil.GetCitizenId(src), src, GetPlayerName(src)
    end
    local citizenid = tostring(target or '')
    if citizenid == '' then return nil end
    local row = Database.Character(citizenid)
    return citizenid, nil, row and Database.CharacterName(citizenid) or citizenid
end

local function distanceCheck(src, targetSrc, maxDistance)
    local a = PoliceUtil.CoordsOf(src)
    local b = PoliceUtil.CoordsOf(targetSrc)
    if not a or not b then return false end
    return PoliceUtil.Distance(a, b) <= (maxDistance or 8.0)
end

-- ─── Calls / dispatch ────────────────────────────────────────
function PL.CreateCall(src, kind, message, priority, coords)
    kind = tostring(kind or '911'):lower()
    message = PoliceUtil.SanitizeText(message or '', Config.Calls.messageMax or 190)
    if message == '' then return nil, 'a message is required' end

    local citizenid, name
    if src and tonumber(src) and tonumber(src) > 0 then
        src = tonumber(src)
        citizenid = PoliceUtil.GetCitizenId(src)
        name = GetPlayerName(src)
        coords = coords or PoliceUtil.CoordsOf(src)
    else
        name = 'Anonymous'
    end

    priority = PoliceUtil.Clamp(PoliceUtil.Int(priority) or Config.Calls.defaultPriority or 2, 1, 4)
    coords = coords or vector3(0.0, 0.0, 0.0)

    local id = Database.CreateCall({
        caller_citizenid = citizenid,
        caller_name = name,
        kind = kind,
        message = message,
        x = coords.x, y = coords.y, z = coords.z,
        priority = priority,
    })
    if not id then return nil, 'call could not be logged' end

    local payload = {
        id = id,
        kind = kind,
        message = message,
        caller = name,
        citizenid = citizenid,
        priority = priority,
        coords = coords,
        at = os.time(),
    }

    if kind == 'ems' then
        PoliceUtil.Broadcast('ems', 'grand_police:client:Dispatch', payload)
    else
        PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', payload)
        if priority >= 4 then
            PoliceUtil.Broadcast('ems', 'grand_police:client:Dispatch', payload)
        end
    end

    PoliceUtil.Log('info', ('call #%d [%s/%d] %s'):format(id, kind, priority, message))
    return id, payload
end

function PL.ActiveCalls(limit)
    return Database.ActiveCalls(limit or 20)
end

function PL.CloseCall(officerSrc, id)
    local ok, err = officerGuard(officerSrc)
    if not ok then return false, err end
    id = PoliceUtil.Int(id)
    if not id then return false, 'usage: /calls close <id>' end
    local name = GetPlayerName(officerSrc) or tostring(officerSrc)
    if not Database.CloseCall(id, name) then return false, 'call not found or already closed' end
    TriggerClientEvent('grand_police:client:MdtNotice', officerSrc, ('Call #%d closed'):format(id), 'success')
    return true
end

-- ─── /duty ───────────────────────────────────────────────────
RegisterCommand(Config.Commands.duty, function(src, args)
    if not online(src) then return end
    local ok, value = Duty.Toggle(src, args[1])
    if not ok then notify(src, value, 'error') end
end, false)

-- ─── /mdt ────────────────────────────────────────────────────
RegisterCommand(Config.Commands.mdt, function(src, args)
    if not online(src) then return end
    local sub = tostring(args[1] or 'help'):lower()

    if sub == 'search' then
        local query = table.concat(args, ' ', 2)
        local ok, value = MDT.Search(src, query)
        if not ok then notify(src, value, 'error') end

    elseif sub == 'profile' or sub == 'record' and #args < 3 then
        local query = args[2] or tostring(src)
        local ok, value = MDT.Profile(src, query)
        if not ok then notify(src, value, 'error') end

    elseif sub == 'recent' then
        MDT.Recent(src)

    elseif sub == 'stats' then
        MDT.Stats(src)

    elseif sub == 'warrants' then
        MDT.Warrants(src)

    elseif sub == 'bolos' then
        MDT.Bolos(src)

    elseif sub == 'wanted' then
        MDT.WantedBoard(src)

    elseif sub == 'stops' then
        Traffic.List(src)

    else
        notify(src, table.concat({
            '/mdt search <name|cid>',
            '/mdt profile <id|cid>',
            '/mdt recent',
            '/mdt stats',
            '/mdt warrants',
            '/mdt bolos',
            '/mdt wanted',
            '/mdt stops',
            '/warrant <id> <offence> <reason>',
            '/bolo <id|plate> <reason>',
            '/record <id> <charges>',
            '/evidence <id> <label> | <detail>',
        }, '\n'), 'info')
    end
end, false)

-- ─── Wanted / arrest ─────────────────────────────────────────
RegisterCommand(Config.Commands.wanted, function(src, args)
    if not online(src) then return end
    local ok, err = officerGuard(src)
    if not ok then return notify(src, err, 'error') end

    local target = tonumber(args[1])
    local stars = tonumber(args[2])
    if not target or not stars then
        return notify(src, 'usage: /wanted <player_id> <1-5> [reason]', 'info')
    end
    if not online(target) then return notify(src, Config.Text.noTarget, 'error') end

    local reason = table.concat(args, ' ', 3)
    local citizenid = PoliceUtil.GetCitizenId(target)
    if not citizenid then return notify(src, 'target has no loaded character', 'error') end

    local setOk, value = Wanted.Set(citizenid, stars, reason ~= '' and reason or ('Flagged by ' .. (GetPlayerName(src) or 'officer')))
    if not setOk then return notify(src, value, 'error') end

    notify(src, Config.Text.wantedSet:format(GetPlayerName(target), value), 'success')
    notify(target, ('You are now %d star wanted'):format(value), 'error')
end, false)

RegisterCommand(Config.Commands.clearwanted, function(src, args)
    if not online(src) then return end
    if not (PoliceUtil.IsAdmin(src) or PoliceUtil.IsSupervisor(src)) then
        return notify(src, 'supervisor clearance required', 'error')
    end

    local citizenid, _, name = resolveCitizen(args[1])
    if not citizenid then return notify(src, 'usage: /clearwanted <id|cid>', 'info') end

    Wanted.Clear(citizenid)
    notify(src, Config.Text.wantedCleared:format(name or citizenid), 'success')
end, false)

RegisterCommand(Config.Commands.arrest, function(src, args)
    if not online(src) then return end
    local ok, err = officerGuard(src)
    if not ok then return notify(src, err, 'error') end

    local target = tonumber(args[1])
    if not target or not online(target) then
        return notify(src, 'usage: /arrest <player_id> [minutes] [reason]', 'info')
    end
    if target == src then return notify(src, 'you cannot arrest yourself', 'error') end
    if not distanceCheck(src, target, 6.0) then return notify(src, Config.Text.tooFar, 'error') end

    local citizenid = PoliceUtil.GetCitizenId(target)
    if not citizenid then return notify(src, 'target has no loaded character', 'error') end

    local stars = Wanted.Get(citizenid)
    if stars <= 0 and not PoliceUtil.IsSupervisor(src) then
        return notify(src, Config.Text.notWanted, 'error')
    end

    local explicitMinutes = tonumber(args[2])
    local minutes = explicitMinutes
    if not minutes then
        minutes = math.max(5, stars * (Config.Wanted.starsPerMinute or 8))
    end

    local reason = table.concat(args, ' ', explicitMinutes and 3 or 2)
    if reason == '' then reason = ('Arrested at %d stars'):format(stars) end

    local jailed, value = Prison.Jail(citizenid, minutes, reason, src)
    if not jailed then return notify(src, value, 'error') end

    notify(src, ('%s arrested for %d minutes'):format(GetPlayerName(target), math.min(minutes, Config.Prison.maxMinutes)), 'success')
end, false)

-- ─── Jail / bail ─────────────────────────────────────────────
RegisterCommand(Config.Commands.jail, function(src, args)
    if not online(src) then return end
    local ok, err = officerGuard(src)
    if not ok then return notify(src, err, 'error') end
    if not PoliceUtil.IsSupervisor(src) then return notify(src, 'supervisor clearance required', 'error') end

    local target = tonumber(args[1])
    local minutes = tonumber(args[2])
    if not target or not minutes then
        return notify(src, 'usage: /jail <player_id> <minutes> [reason]', 'info')
    end
    if not online(target) then return notify(src, Config.Text.noTarget, 'error') end

    local reason = table.concat(args, ' ', 3)
    local jailed, value = Prison.Jail(target, minutes, reason ~= '' and reason or 'Court order', src)
    if not jailed then return notify(src, value, 'error') end
    notify(src, ('Jailed %s (#%s)'):format(GetPlayerName(target), tostring(value)), 'success')
end, false)

RegisterCommand(Config.Commands.unjail, function(src, args)
    if not online(src) then return end
    if not (PoliceUtil.IsAdmin(src) or PoliceUtil.IsSupervisor(src)) then
        return notify(src, 'supervisor clearance required', 'error')
    end

    local citizenid, _, name = resolveCitizen(args[1])
    if not citizenid then return notify(src, 'usage: /unjail <id|cid>', 'info') end

    local released, reason = Prison.Release(citizenid, 'released by ' .. (GetPlayerName(src) or 'staff'))
    if not released then return notify(src, reason, 'error') end
    notify(src, Config.Text.released:format(name or citizenid), 'success')
end, false)

RegisterCommand(Config.Commands.bail, function(src)
    if not online(src) then return end
    local price = Prison.BailPrice(src)
    local ok, value = Prison.Bail(src)
    if not ok then
        notify(src, value, 'error')
    else
        notify(src, ('Bail posted: %s'):format(PoliceUtil.Money(value or price)), 'success')
    end
end, false)

-- ─── Fines ───────────────────────────────────────────────────
RegisterCommand(Config.Commands.fine, function(src, args)
    if not online(src) then return end
    local ok, err = officerGuard(src)
    if not ok then return notify(src, err, 'error') end

    local target = tonumber(args[1])
    if not target or not online(target) then
        return notify(src, 'usage: /fine <player_id> <offence|amount> [reason]', 'info')
    end
    if not distanceCheck(src, target, 20.0) then return notify(src, Config.Text.tooFar, 'error') end

    local citizenid = PoliceUtil.GetCitizenId(target)
    if not citizenid then return notify(src, 'target has no loaded character', 'error') end

    local key = PoliceUtil.SanitizeKey(args[2] or '')
    local offence = Config.OffenceIndex[key]
    local amount = offence and offence.fine or tonumber(args[2])
    if not amount then
        return notify(src, 'usage: /fine <id> <offence|amount> [reason]', 'info')
    end

    amount = PoliceUtil.Clamp(PoliceUtil.Int(amount) or 0, Config.Fines.min, Config.Fines.max)

    local reason
    if offence then
        reason = offence.label
        if offence.stars and offence.stars > 0 then
            Wanted.Set(citizenid, math.max(Wanted.Get(citizenid), offence.stars), offence.label)
        end
    else
        reason = table.concat(args, ' ', 3)
        if reason == '' then return notify(src, Config.Text.noReason, 'error') end
    end

    local officerCid = PoliceUtil.GetCitizenId(src)
    local officerName = GetPlayerName(src) or citizenid
    local fineId = Database.CreateFine({
        citizenid = citizenid,
        name = GetPlayerName(target),
        officer_citizenid = officerCid,
        officer_name = officerName,
        offence = offence and offence.id or nil,
        reason = reason,
        amount = amount,
        dueHours = Config.Fines.defaultDueHours,
    })
    if not fineId then return notify(src, 'fine could not be issued', 'error') end

    notify(src, Config.Text.fineIssued:format(PoliceUtil.Money(amount), GetPlayerName(target)), 'success')
    notify(target, ('Fine #%d issued: %s - %s'):format(fineId, PoliceUtil.Money(amount), reason), 'warning')
end, false)

RegisterCommand(Config.Commands.fines, function(src, args)
    if not online(src) then return end

    local target = tonumber(args[1]) or src
    local own = target == src
    if not own then
        local ok, err = officerGuard(src)
        if not ok then return notify(src, err, 'error') end
    end

    local citizenid = PoliceUtil.GetCitizenId(target)
    if not citizenid then return notify(src, Config.Text.noTarget, 'error') end

    local rows = Database.UnpaidFines(citizenid)
    if #rows == 0 then return notify(src, Config.Text.noFines, 'info') end

    local total = 0
    for _, row in ipairs(rows) do
        total = total + (tonumber(row.amount) or 0)
        notify(src, ('#%d %s - %s (%s)'):format(
            tonumber(row.id) or 0, PoliceUtil.Money(row.amount),
            tostring(row.reason or row.offence), tostring(row.due_at or 'due')), 'info')
    end
    notify(src, ('Total unpaid: %s'):format(PoliceUtil.Money(total)), 'warning')
end, false)

RegisterCommand(Config.Commands.payfine, function(src, args)
    if not online(src) then return end

    local id = PoliceUtil.Int(args[1])
    if not id then return notify(src, 'usage: /payfine <fine_id>', 'info') end

    local citizenid = PoliceUtil.GetCitizenId(src)
    local fine = Database.Fine(id)
    if not fine or fine.citizenid ~= citizenid then
        return notify(src, 'that fine is not yours', 'error')
    end
    if tonumber(fine.paid) == 1 then return notify(src, 'that fine is already paid', 'info') end

    local amount = tonumber(fine.amount) or 0
    local money = PoliceUtil.GetMoney(src)
    local paid = false

    if (tonumber(money.bank) or 0) >= amount then
        paid = PoliceUtil.RemoveMoney(src, 'bank', amount, ('Fine #%d'):format(id))
    elseif Config.Fines.acceptCash and (tonumber(money.cash) or 0) >= amount then
        paid = PoliceUtil.RemoveMoney(src, 'cash', amount, ('Fine #%d'):format(id))
    end

    if not paid then return notify(src, 'you cannot afford that fine', 'error') end
    if not Database.MarkFinePaid(id) then
        PoliceUtil.AddMoney(src, 'bank', amount, 'Fine refund')
        return notify(src, 'fine payment failed, refunded', 'error')
    end

    notify(src, Config.Text.finePaid:format(PoliceUtil.Money(amount)), 'success')
    local officer = PoliceUtil.TryExport('grand_core', 'GetSourceByCitizenId', fine.officer_citizenid)
    if officer and tonumber(officer) then
        notify(tonumber(officer), ('Fine #%d paid by %s'):format(id, GetPlayerName(src)), 'info')
    end
end, false)

-- ─── Warrants / BOLO / records ──────────────────────────────
RegisterCommand(Config.Commands.warrant, function(src, args)
    if not online(src) then return end
    local sub = tostring(args[1] or ''):lower()

    if sub == 'list' then
        MDT.Warrants(src)
        return
    end
    if sub == 'clear' then
        local ok, value = MDT.ClearWarrant(src, args[2])
        if not ok then notify(src, value, 'error') else notify(src, value, 'success') end
        return
    end

    local query = args[1]
    local offence = args[2]
    local reason = table.concat(args, ' ', 3)
    if not query then return notify(src, 'usage: /warrant <id|cid> <offence> <reason>', 'info') end

    local ok, value = MDT.Warrant(src, query, offence, reason)
    if not ok then
        notify(src, value, 'error')
    else
        notify(src, ('Warrant #%s filed'):format(tostring(value)), 'success')
    end
end, false)

RegisterCommand(Config.Commands.bolo, function(src, args)
    if not online(src) then return end

    local sub = tostring(args[1] or ''):lower()
    if sub == 'list' then
        MDT.Bolos(src)
        return
    end
    if sub == 'clear' then
        local ok, value = MDT.ClearBolo(src, args[2])
        if not ok then notify(src, value, 'error') else notify(src, value, 'success') end
        return
    end

    local query = args[1]
    local reason = table.concat(args, ' ', 2)
    if not query then return notify(src, 'usage: /bolo <id|plate> <reason>', 'info') end

    local ok, value = MDT.Bolo(src, query, reason)
    if not ok then notify(src, value, 'error') else notify(src, ('BOLO #%s filed'):format(tostring(value)), 'success') end
end, false)

RegisterCommand(Config.Commands.record, function(src, args)
    if not online(src) then return end
    local query = args[1]
    local text = table.concat(args, ' ', 2)
    if not query or text == '' then
        return notify(src, 'usage: /record <id|cid> <charges>', 'info')
    end
    local ok, value = MDT.Record(src, query, text, nil)
    if not ok then notify(src, value, 'error') end
end, false)

RegisterCommand(Config.Commands.evidence, function(src, args)
    if not online(src) then return end
    local query = args[1]
    local rest = table.concat(args, ' ', 2)
    if not query or rest == '' then
        return notify(src, 'usage: /evidence <id|cid> <label> | <detail>', 'info')
    end

    local label, detail = rest:match('^(.-)%s*|%s*(.+)$')
    if not label then label, detail = rest, nil end

    local ok, value = MDT.Evidence(src, query, label, detail)
    if not ok then notify(src, value, 'error') else notify(src, ('Evidence #%s logged'):format(tostring(value)), 'success') end
end, false)

-- ─── Traffic ─────────────────────────────────────────────────
RegisterCommand(Config.Commands.trafficstop, function(src, args)
    if not online(src) then return end
    local target = tonumber(args[1])
    if not target then return notify(src, 'usage: /trafficstop <player_id> [plate] [reason]', 'info') end

    local plate = args[2]
    local reason = table.concat(args, ' ', 3)

    local ok, value = Traffic.Stop(src, target, plate, reason ~= '' and reason or 'Traffic stop')
    if not ok then notify(src, value, 'error') else notify(src, ('Stop #%s logged'):format(tostring(value)), 'success') end
end, false)

RegisterCommand(Config.Commands.breathalyzer, function(src, args)
    if not online(src) then return end
    local target = tonumber(args[1]) or src
    local ok, value = Traffic.Breathalyzer(src, target)
    if not ok then notify(src, value, 'error') end
end, false)

RegisterCommand(Config.Commands.impound, function(src, args)
    if not online(src) then return end

    if tostring(args[1] or ''):lower() == 'release' then
        local ok, value = Traffic.ReleaseImpound(src, args[2])
        if not ok then notify(src, value, 'error') else notify(src, 'Vehicle released', 'success') end
        return
    end

    local ok, value = Traffic.Impound(src, args[1], args[2])
    if not ok then notify(src, value, 'error') else notify(src, ('Vehicle impounded (record #%s)'):format(tostring(value)), 'success') end
end, false)

-- ─── Calls / panic / radio ──────────────────────────────────
RegisterCommand('911', function(src, args)
    if not online(src) then return end
    if not PoliceUtil.Cooldown('911:' .. src, Config.Calls.cooldownSeconds or 20) then
        return notify(src, 'You just called emergency services', 'warning')
    end

    local message = table.concat(args, ' ')
    local id, value = PL.CreateCall(src, '911', message, 2)
    if not id then return notify(src, value, 'error') end

    notify(src, ('Emergency call #%d dispatched'):format(id), 'success')
end, false)

RegisterCommand('ems', function(src, args)
    if not online(src) then return end
    if not PoliceUtil.Cooldown('ems:' .. src, Config.Calls.cooldownSeconds or 20) then
        return notify(src, 'You just called emergency services', 'warning')
    end

    local message = table.concat(args, ' ')
    local id, value = PL.CreateCall(src, 'ems', message, 2)
    if not id then return notify(src, value, 'error') end
    notify(src, ('Medical call #%d dispatched'):format(id), 'success')
end, false)

RegisterCommand(Config.Commands.panic, function(src)
    if not online(src) then return end
    if not PoliceUtil.IsEmergency(src) then return notify(src, Config.Text.noFaction, 'error') end
    if not PoliceUtil.OnDuty(src) then return notify(src, Config.Text.noDuty, 'error') end
    if not PoliceUtil.Cooldown('panic:' .. src, Config.Calls.panicCooldownSeconds or 60) then
        return notify(src, 'Panic button cooling down', 'warning')
    end

    local id = PL.CreateCall(src, 'panic', ('OFFICER PANIC: %s'):format(GetPlayerName(src) or 'unknown'), 4)
    if not id then return notify(src, 'panic could not be sent', 'error') end
end, false)

RegisterCommand(Config.Commands.calls, function(src, args)
    if not online(src) then return end
    local ok, err = officerGuard(src)
    if not ok then return notify(src, err, 'error') end

    if tostring(args[1] or ''):lower() == 'close' then
        local closed, value = PL.CloseCall(src, args[2])
        if not closed then notify(src, value, 'error') end
        return
    end

    local rows = PL.ActiveCalls(20)
    if #rows == 0 then return notify(src, 'No active calls', 'info') end
    for _, row in ipairs(rows) do
        notify(src, ('#%d [%s] %s - %s'):format(
            tonumber(row.id) or 0, tostring(row.kind), tostring(row.message),
            tostring(row.caller_name or 'unknown')), 'info')
    end
end, false)

RegisterCommand(Config.Commands.radio, function(src, args)
    if not online(src) then return end
    local ok, err = officerGuard(src)
    if not ok then return notify(src, err, 'error') end

    local message = PoliceUtil.SanitizeText(table.concat(args, ' '), 190)
    if message == '' then return notify(src, 'usage: /radio <message>', 'info') end
    if not PoliceUtil.Cooldown('radio:' .. src, 3) then return notify(src, Config.Text.rateLimited, 'error') end

    PoliceUtil.Broadcast('police', 'grand_police:client:Radio', {
        name = GetPlayerName(src),
        message = message,
    })
end, false)

-- ─── EMS ─────────────────────────────────────────────────────
RegisterCommand(Config.Commands.revive, function(src, args)
    if not online(src) then return end
    local ok, err = emsGuard(src)
    if not ok then return notify(src, err, 'error') end

    local target = tonumber(args[1])
    if not target or not online(target) then return notify(src, 'usage: /revive <player_id>', 'info') end
    if not distanceCheck(src, target, 4.0) then return notify(src, Config.Text.tooFar, 'error') end
    if not PoliceUtil.Cooldown('revive:' .. src, 5) then return notify(src, Config.Text.rateLimited, 'error') end

    local ped = GetPlayerPed(target)
    if ped and ped ~= 0 then
        SetEntityHealth(ped, 200)
    end
    TriggerClientEvent('grand_police:client:Revive', target)

    notify(src, Config.Text.revived:format(GetPlayerName(target)), 'success')
    notify(target, ('You were revived by %s'):format(GetPlayerName(src)), 'success')

    local cid = PoliceUtil.GetCitizenId(src)
    if cid then
        Database.AddEvidence({
            citizenid = PoliceUtil.GetCitizenId(target),
            case_ref = ('EMS-%d'):format(os.time()),
            label = 'Revived by EMS',
            detail = ('Officer %s'):format(GetPlayerName(src) or cid),
            officer_citizenid = cid,
            officer_name = GetPlayerName(src),
        })
    end
end, false)

RegisterCommand(Config.Commands.heal, function(src, args)
    if not online(src) then return end
    local ok, err = emsGuard(src)
    if not ok then return notify(src, err, 'error') end

    local target = tonumber(args[1]) or src
    if not online(target) then return notify(src, Config.Text.noTarget, 'error') end
    if target ~= src and not distanceCheck(src, target, 4.0) then
        return notify(src, Config.Text.tooFar, 'error')
    end

    local ped = GetPlayerPed(target)
    if ped and ped ~= 0 then SetEntityHealth(ped, 200) end
    notify(src, ('Treated %s'):format(GetPlayerName(target)), 'success')
    notify(target, 'You were treated by EMS', 'success')
end, false)

-- ─── Licences ────────────────────────────────────────────────
RegisterCommand(Config.Commands.license, function(src, args)
    if not online(src) then return end

    local sub = tostring(args[1] or 'check'):lower()

    if sub == 'check' or sub == 'show' then
        local target = tonumber(args[2]) or src
        if target ~= src then
            local ok, err = officerGuard(src)
            if not ok then return notify(src, err, 'error') end
        end

        local citizenid = PoliceUtil.GetCitizenId(target)
        if not citizenid then return notify(src, Config.Text.noTarget, 'error') end

        local rows = Database.Licences(citizenid)
        if #rows == 0 then return notify(src, 'No licences on file', 'info') end
        for _, row in ipairs(rows) do
            notify(src, ('%s: %s'):format(
                LicenceTypes[row.licence] or row.licence, tostring(row.status)), 'info')
        end
        return
    end

    if sub == 'grant' or sub == 'revoke' then
        local ok, err = officerGuard(src)
        if not ok then return notify(src, err, 'error') end
        if not PoliceUtil.IsSupervisor(src) then
            return notify(src, 'supervisor clearance required', 'error')
        end

        local target = tonumber(args[2])
        local licence = tostring(args[3] or 'driver'):lower()
        if not target or not online(target) then
            return notify(src, 'usage: /license grant|revoke <id> <type>', 'info')
        end
        if not LicenceTypes[licence] then
            return notify(src, ('types: %s'):format(table.concat(
                (function()
                    local list = {}
                    for key in pairs(LicenceTypes) do list[#list + 1] = key end
                    return list
                end)(), ', ')), 'info')
        end

        local citizenid = PoliceUtil.GetCitizenId(target)
        if not citizenid then return notify(src, 'target has no character', 'error') end

        Database.SetLicence(citizenid, licence, sub == 'grant' and 'valid' or 'revoked', GetPlayerName(src))
        notify(src, ('%s %s for %s'):format(
            sub == 'grant' and 'Granted' or 'Revoked', LicenceTypes[licence], GetPlayerName(target)), 'success')
        notify(target, ('Your %s was %s'):format(LicenceTypes[licence],
            sub == 'grant' and 'granted' or 'revoked'), sub == 'grant' and 'success' or 'error')
        return
    end

    return notify(src, 'usage: /license check|grant|revoke ...', 'info')
end, false)

-- ─── Admin / prison lockdown ────────────────────────────────
RegisterCommand(Config.Commands.policeadmin, function(src, args)
    if not PoliceUtil.IsAdmin(src) then return notify(src, 'Not authorised', 'error') end

    local sub = tostring(args[1] or 'help'):lower()

    if sub == 'stats' then
        local stats = Database.Stats()
        notify(src, ('Warrants %d, unpaid fines %d (%s), inmates %d, calls %d'):format(
            stats.warrants, stats.unpaid_fines, PoliceUtil.Money(stats.unpaid_value),
            stats.inmates, stats.calls), 'info')

    elseif sub == 'duty' then
        local target = tonumber(args[2])
        if not target then return notify(src, 'usage: /policeadmin duty <id> on|off', 'info') end
        local state = tostring(args[3] or 'on'):lower() == 'on'
        Duty.Force(target, state)
        notify(src, ('Duty %s for %s'):format(state and 'on' or 'off', tostring(target)), 'success')

    elseif sub == 'lockdown' then
        local ok, value = Prison.Lockdown(src)
        notify(src, ok and 'Lockdown started' or tostring(value), ok and 'success' or 'error')

    elseif sub == 'endlockdown' then
        Prison.EndLockdown()
        notify(src, 'Lockdown ended', 'success')

    elseif sub == 'unjail' then
        local citizenid, _, name = resolveCitizen(args[2])
        if not citizenid then return notify(src, 'usage: /policeadmin unjail <id|cid>', 'info') end
        local ok, value = Prison.Release(citizenid, 'admin release')
        notify(src, ok and ('Released ' .. tostring(name)) or tostring(value), ok and 'success' or 'error')

    else
        notify(src, 'Usage: /policeadmin stats | duty <id> on|off | lockdown | endlockdown | unjail <id>', 'info')
    end
end, false)

-- ─── Net events ──────────────────────────────────────────────
RegisterNetEvent('grand_police:server:ClientReady', function()
    local src = source
    if not online(src) then return end
    if not PoliceUtil.Cooldown('ready:' .. src, 5) then return end

    CreateThread(function()
        Wait(1500)
        if not online(src) then return end
        local job = PoliceUtil.Job(src) or {}
        local citizenid = PoliceUtil.GetCitizenId(src)
        local sentenceSeconds = citizenid and Database.SentenceRemaining(citizenid) or 0
        local jailed = sentenceSeconds > 0

        TriggerClientEvent('grand_police:client:Session', src, {
            duty = PoliceUtil.OnDuty(src),
            job = job.name,
            grade = job.grade,
            label = job.label,
            faction = job.faction,
            police = PoliceUtil.IsPolice(src),
            ems = PoliceUtil.IsEMS(src),
            wanted = citizenid and Wanted.Get(citizenid) or 0,
            jailed = jailed,
            sentence = sentenceSeconds,
            sentenceReason = jailed and Database.ActiveSentence(citizenid) and
                Database.ActiveSentence(citizenid).reason or nil,
            stations = Config.Stations,
            prison = Config.Prison,
            wantedConfig = Config.Wanted,
        })

        if jailed then
            local sentence = Database.ActiveSentence(citizenid)
            TriggerClientEvent('grand_police:client:Jailed', src, {
                id = sentence and sentence.id,
                minutes = math.ceil(sentenceSeconds / 60),
                reason = sentence and sentence.reason or 'Sentence',
                officer = sentence and sentence.officer_name or 'Court',
                spawn = Config.Prison.spawn,
                restore = true,
            })
        end

        if PoliceUtil.IsPolice(src) then
            TriggerClientEvent('grand_police:client:WantedList', src, Wanted.Board())
        end
        TriggerClientEvent('grand_police:client:Roster', src, Duty.Roster())
    end)
end)

RegisterNetEvent('grand_police:server:ToggleDuty', function(stationId)
    local src = source
    if not online(src) then return end
    local ok, value = Duty.Toggle(src, tonumber(stationId) or stationId)
    if not ok then notify(src, value, 'error') end
end)

RegisterNetEvent('grand_police:server:Escape', function()
    local src = source
    if not online(src) then return end
    Prison.Escape(src)
end)

RegisterNetEvent('grand_police:server:Panic', function()
    local src = source
    if not online(src) then return end
    if not PoliceUtil.IsEmergency(src) or not PoliceUtil.OnDuty(src) then return end
    if not PoliceUtil.Cooldown('panic:' .. src, Config.Calls.panicCooldownSeconds or 60) then return end
    PL.CreateCall(src, 'panic', ('OFFICER PANIC: %s'):format(GetPlayerName(src)), 4)
end)

RegisterNetEvent('grand_police:server:RequestWanted', function()
    local src = source
    if not online(src) or not PoliceUtil.IsPolice(src) then return end
    TriggerClientEvent('grand_police:client:WantedList', src, Wanted.Board())
end)

RegisterNetEvent('grand_police:server:RequestRevive', function(targetSrc)
    local src = source
    if not online(src) then return end
    if not PoliceUtil.IsEMS(src) or not PoliceUtil.OnDuty(src) then
        return notify(src, Config.Text.noDuty, 'error')
    end
    if not PoliceUtil.Cooldown('revive:' .. src, 5) then
        return notify(src, Config.Text.rateLimited, 'error')
    end

    targetSrc = tonumber(targetSrc)
    if not online(targetSrc) then return notify(src, Config.Text.noTarget, 'error') end
    if targetSrc == src then return end
    if not distanceCheck(src, targetSrc, 6.0) then
        return notify(src, Config.Text.tooFar, 'error')
    end

    local targetPed = GetPlayerPed(targetSrc)
    if not targetPed or targetPed == 0 then return notify(src, Config.Text.noTarget, 'error') end
    if not IsEntityDead(targetPed) and not IsPedDeadOrDying(targetPed, true) then
        return notify(src, 'That player is not downed', 'error')
    end

    SetEntityHealth(targetPed, 200)
    TriggerClientEvent('grand_police:client:Revive', targetSrc)
    notify(src, Config.Text.revived:format(GetPlayerName(targetSrc)), 'success')
    notify(targetSrc, ('You were revived by %s'):format(GetPlayerName(src)), 'success')

    local cid = PoliceUtil.GetCitizenId(src)
    local targetCid = PoliceUtil.GetCitizenId(targetSrc)
    if cid and targetCid then
        Database.AddEvidence({
            citizenid = targetCid,
            case_ref = ('EMS-%d'):format(os.time()),
            label = 'Revived by EMS',
            detail = ('Paramedic %s'):format(GetPlayerName(src) or cid),
            officer_citizenid = cid,
            officer_name = GetPlayerName(src),
        })
    end
end)


-- ─── Exports ─────────────────────────────────────────────────
exports('IsPolice', function(src) return PoliceUtil.IsPolice(src) end)
exports('IsEMS', function(src) return PoliceUtil.IsEMS(src) end)
exports('OnDuty', function(src) return PoliceUtil.OnDuty(src) end)
exports('Wanted', function(target) return Wanted.Get(target) end)
exports('SetWanted', function(target, stars, reason) return Wanted.Set(target, stars, reason) end)
exports('ClearWanted', function(target) return Wanted.Clear(target) end)
exports('Jail', function(target, minutes, reason, officerSrc)
    return Prison.Jail(target, minutes, reason, officerSrc)
end)
exports('Release', function(target, reason) return Prison.Release(target, reason) end)
exports('Fine', function(target, amount, reason, officerSrc)
    local citizenid, _, name = resolveCitizen(target)
    if not citizenid then return false end
    amount = PoliceUtil.Clamp(PoliceUtil.Int(amount) or 0, Config.Fines.min, Config.Fines.max)
    local officerCid, officerName
    if officerSrc then
        officerCid = PoliceUtil.GetCitizenId(officerSrc)
        officerName = GetPlayerName(officerSrc)
    end
    return Database.CreateFine({
        citizenid = citizenid,
        name = name,
        officer_citizenid = officerCid,
        officer_name = officerName or 'System',
        offence = nil,
        reason = reason or 'Fine',
        amount = amount,
        dueHours = Config.Fines.defaultDueHours,
    })
end)
exports('PayFine', function(fineId) return Database.MarkFinePaid(fineId) end)
exports('CreateCall', function(src, kind, message, priority)
    return PL.CreateCall(src, kind, message, priority)
end)
exports('ActiveCalls', function(limit) return PL.ActiveCalls(limit) end)
exports('DutyCount', function(faction) return Duty.Count(faction) end)
exports('GetRecord', function(target)
    local citizenid = resolveCitizen(target)
    return citizenid and Database.Record(citizenid) or nil
end)
exports('HasLicence', function(target, licence)
    local citizenid = resolveCitizen(target)
    if not citizenid then return false end
    local row = Database.Licence(citizenid, licence)
    return row ~= nil and row.status == 'valid'
end)
exports('Stats', function() return Database.Stats() end)
exports('Stations', function() return Config.Stations end)
exports('PrisonRelease', function(target, reason) return Prison.Release(target, reason) end)

-- ─── Lifecycle ───────────────────────────────────────────────
AddEventHandler('onResourceStart', function(resource)
    if resource ~= RESOURCE then return end

    CreateThread(function()
        Wait(1200)
        Database.Bootstrap()
        Duty.Boot()
        Wanted.Boot()
        Prison.Boot()
        PoliceUtil.Log('info', 'Grand Police online')
    end)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    for _, row in ipairs(Database.Roster()) do
        Database.EndDuty(row.citizenid)
    end
    TriggerClientEvent('grand_police:client:ClearMap', -1)
    PoliceUtil.Log('info', 'Grand Police stopped')
end)

AddEventHandler('playerDropped', function()
    local src = source
    Duty.PlayerDropped(src)
end)

return PL
