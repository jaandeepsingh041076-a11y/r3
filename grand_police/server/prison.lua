-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/server/prison.lua
--  Bolingbroke: sentences, release, bail, lockdown and escape
--  handling. Court orders and admin releases both land here.
-- ─────────────────────────────────────────────────────────────

Prison = Prison or {}
local P = Prison

P.Booted = false
P.LockdownUntil = 0
P.LastLockdown = 0

-- ─── Helpers ─────────────────────────────────────────────────
local function resolve(target)
    if type(target) == 'number' then
        return PoliceUtil.GetCitizenId(target), target
    end
    if type(target) == 'string' and target ~= '' then
        return target, nil
    end
    return nil, nil
end

local function teleport(src, coords)
    src = tonumber(src)
    if not src or src <= 0 then return false end
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return false end
    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, true)
    TriggerClientEvent('grand_police:client:Teleport', src, coords)
    return true
end

local function broadcastPrison(eventName, ...)
    local args = table.pack(...)
    for _, srcText in ipairs(GetPlayers()) do
        local src = tonumber(srcText)
        local cid = PoliceUtil.GetCitizenId(src)
        if cid and P.IsJailed(cid) then
            TriggerClientEvent(eventName, src, table.unpack(args, 1, args.n))
        end
    end
end

-- ─── State ───────────────────────────────────────────────────
function P.IsJailed(target)
    local citizenid = resolve(target)
    if not citizenid then return false end
    return Database.ActiveSentence(citizenid) ~= nil
end

function P.Remaining(target)
    local citizenid = resolve(target)
    if not citizenid then return 0 end
    return Database.SentenceRemaining(citizenid)
end

function P.InLockdown()
    return os.time() < P.LockdownUntil
end

-- ─── Jail ────────────────────────────────────────────────────
--- Sends a player to Bolingbroke. Returns true, sentenceId.
function P.Jail(target, minutes, reason, officerSrc)
    local citizenid, src = resolve(target)
    if not citizenid then return false, 'no citizen' end
    if not src then
        src = PoliceUtil.TryExport('grand_core', 'GetSourceByCitizenId', citizenid)
        src = src and tonumber(src) or nil
    end

    minutes = PoliceUtil.Int(minutes) or Config.Prison.defaultMinutes
    minutes = PoliceUtil.Clamp(minutes, 1, Config.Prison.maxMinutes)
    reason = PoliceUtil.SanitizeText(reason or 'Court sentence', 190)

    local name = (src and GetPlayerName(src)) or citizenid
    local officerName, officerCid = 'Court', nil
    if officerSrc and tonumber(officerSrc) and tonumber(officerSrc) > 0 then
        officerCid = PoliceUtil.GetCitizenId(officerSrc)
        officerName = GetPlayerName(officerSrc) or officerCid
    end

    -- Extend an existing sentence rather than stacking two rows.
    local active = Database.ActiveSentence(citizenid)
    if active then
        local remaining = Database.SentenceRemaining(citizenid)
        minutes = PoliceUtil.Clamp(math.ceil(remaining / 60) + minutes, 1, Config.Prison.maxMinutes)
        Database.ReleaseSentence(citizenid, 'extended')
    end

    local id = Database.CreateSentence({
        citizenid = citizenid,
        name = name,
        officer_citizenid = officerCid,
        officer_name = officerName,
        reason = reason,
        minutes = minutes,
    })

    Wanted.Clear(citizenid, true)

    if src then
        teleport(src, Config.Prison.spawn)
        TriggerClientEvent('grand_police:client:Jailed', src, {
            id = id,
            minutes = minutes,
            reason = reason,
            officer = officerName,
            spawn = Config.Prison.spawn,
        })
        PoliceUtil.Notify(src, Config.Text.jailed:format(name, minutes), 'warning')
    end

    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'prison',
        priority = 2,
        message = ('%s was sentenced to %d minutes (%s)'):format(name, minutes, reason),
        citizenid = citizenid,
    })

    PoliceUtil.Log('info', ('jailed %s for %d minutes (%s)'):format(citizenid, minutes, reason))
    return true, id
end

--- Releases a citizen wherever they are. Safe for offline players.
function P.Release(target, reason)
    local citizenid = resolve(target)
    if not citizenid then return false end

    local sentence = Database.ActiveSentence(citizenid)
    if not sentence then return false, 'not serving a sentence' end

    Database.ReleaseSentence(citizenid, reason or 'released')
    Wanted.Clear(citizenid, true)

    local src = PoliceUtil.TryExport('grand_core', 'GetSourceByCitizenId', citizenid)
    src = src and tonumber(src) or nil
    if src then
        teleport(src, Config.Prison.release)
        TriggerClientEvent('grand_police:client:Released', src, reason or 'released')
        PoliceUtil.Notify(src, 'You have been released from Bolingbroke', 'success')
    end

    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'prison',
        priority = 1,
        message = ('%s was released (%s)'):format(
            sentence.name or citizenid, tostring(reason or 'released')),
        citizenid = citizenid,
    })
    return true
end

-- ─── Bail ────────────────────────────────────────────────────
function P.BailPrice(target)
    local remaining = P.Remaining(target)
    if remaining <= 0 then return 0 end
    local minutes = math.ceil(remaining / 60)
    return minutes * (Config.Prison.bailPerMinute or 250)
end

function P.Bail(src)
    src = tonumber(src)
    if not src then return false, 'invalid player' end
    if not Config.Prison.bailEnabled then return false, 'bail is suspended' end

    local citizenid = PoliceUtil.GetCitizenId(src)
    if not citizenid then return false, 'no character' end
    if not P.IsJailed(citizenid) then return false, 'you are not in prison' end

    local price = P.BailPrice(citizenid)
    if price <= 0 then
        P.Release(citizenid, 'time served')
        return true, 0
    end

    local money = PoliceUtil.GetMoney(src)
    local bank = tonumber(money.bank) or 0
    local cash = tonumber(money.cash) or 0
    local paid = false

    if bank >= price then
        paid = PoliceUtil.RemoveMoney(src, 'bank', price, 'Bail')
    elseif cash >= price then
        paid = PoliceUtil.RemoveMoney(src, 'cash', price, 'Bail')
    end

    if not paid then
        return false, ('you cannot afford the %s bail'):format(PoliceUtil.Money(price))
    end

    P.Release(citizenid, 'posted bail')
    return true, price
end

-- ─── Lockdown ────────────────────────────────────────────────
function P.Lockdown(src)
    src = tonumber(src)
    if not PoliceUtil.IsPolice(src) or not PoliceUtil.OnDuty(src) then
        return false, Config.Text.noDuty
    end
    if not PoliceUtil.IsSupervisor(src) then
        return false, 'supervisor clearance required'
    end

    local now = os.time()
    if now < P.LockdownUntil then
        return false, 'a lockdown is already active'
    end
    if now - P.LastLockdown < (Config.Prison.lockdownCooldown or 1800) then
        return false, 'lockdown cooldown is still active'
    end

    P.LastLockdown = now
    P.LockdownUntil = now + (Config.Prison.lockdownMinutes or 10) * 60

    broadcastPrison('grand_police:client:Lockdown', true, P.LockdownUntil)
    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'prison',
        priority = 4,
        message = ('BOLINGBROKE LOCKDOWN initiated by %s'):format(GetPlayerName(src) or tostring(src)),
    })
    PoliceUtil.Log('info', 'prison lockdown started by %s', tostring(src))
    return true
end

function P.EndLockdown()
    P.LockdownUntil = 0
    broadcastPrison('grand_police:client:Lockdown', false, 0)
end

-- ─── Escape ──────────────────────────────────────────────────
--- Called by the client when a jailed player leaves the prison
--- radius. The server re-checks the coordinates before punishing.
function P.Escape(src)
    src = tonumber(src)
    if not src then return false end

    local citizenid = PoliceUtil.GetCitizenId(src)
    if not citizenid or not P.IsJailed(citizenid) then return false end
    if not PoliceUtil.Cooldown('escape:' .. citizenid, 30) then return false end

    local coords = PoliceUtil.CoordsOf(src)
    if not coords then return false end
    if PoliceUtil.Distance(coords, Config.Prison.spawn) < (Config.Prison.releaseRadius or 180.0) then
        return false
    end

    local sentence = Database.ActiveSentence(citizenid)
    if not sentence then return false end

    -- Escape = extra time, a fine, and the sentence restarts.
    local extra = Config.Prison.escapeExtraMinutes or 60
    local total = math.min(
        math.ceil(Database.SentenceRemaining(citizenid) / 60) + extra,
        Config.Prison.maxMinutes
    )
    Database.ReleaseSentence(citizenid, 'escaped')
    Database.CreateSentence({
        citizenid = citizenid,
        name = sentence.name,
        officer_citizenid = 'system',
        officer_name = 'Bolingbroke',
        reason = 'Escape from custody',
        minutes = total,
    })
    Database.CreateFine({
        citizenid = citizenid,
        name = sentence.name,
        officer_citizenid = 'system',
        officer_name = 'Bolingbroke',
        offence = 'escape',
        reason = 'Escape from custody',
        amount = Config.Prison.fineOnEscape or 10000,
        dueHours = 72,
    })

    teleport(src, Config.Prison.spawn)
    TriggerClientEvent('grand_police:client:Jailed', src, {
        minutes = total,
        reason = 'Escape from custody',
        officer = 'Bolingbroke',
        spawn = Config.Prison.spawn,
    })

    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'prison',
        priority = 4,
        message = ('ESCAPE: %s left Bolingbroke. Sentence extended to %d minutes.'):format(
            sentence.name or citizenid, total),
        citizenid = citizenid,
    })
    return true, total
end

-- ─── Boot / sweep ────────────────────────────────────────────
function P.Boot()
    if P.Booted then return end
    P.Booted = true

    CreateThread(function()
        Wait(8000)

        -- Release everyone whose sentence expired while the server was down.
        for _, sentence in ipairs(Database.DueSentences()) do
            P.Release(sentence.citizenid, 'time served')
        end

        while true do
            Wait((Config.Prison.sentenceCheckSeconds or 30) * 1000)

            for _, sentence in ipairs(Database.DueSentences()) do
                P.Release(sentence.citizenid, 'time served')
            end

            if P.LockdownUntil > 0 and os.time() >= P.LockdownUntil then
                P.EndLockdown()
            end
        end
    end)
end

return P
