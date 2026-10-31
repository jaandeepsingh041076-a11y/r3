-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/server/traffic.lua
--  Traffic stops, breathalyzers and vehicle impound. Distance is
--  always re-checked on the server; plates are format-checked.
-- ─────────────────────────────────────────────────────────────

Traffic = Traffic or {}
local T = Traffic

T.LastStops = {}
T.StopsThisHour = {}

local function officer(src)
    local citizenid = PoliceUtil.GetCitizenId(src)
    local name = GetPlayerName(src) or citizenid or tostring(src)
    return citizenid, name
end

local function guard(src)
    if not PoliceUtil.IsPolice(src) then return false, 'only law enforcement may do that' end
    if not PoliceUtil.OnDuty(src) then return false, Config.Text.noDuty end
    return true
end

local function withinRange(src, targetSrc, maxDistance)
    local a = PoliceUtil.CoordsOf(src)
    local b = PoliceUtil.CoordsOf(targetSrc)
    if not a or not b then return false end
    return PoliceUtil.Distance(a, b) <= (maxDistance or Config.Traffic.maxDistance or 12.0)
end

-- ─── Stops ───────────────────────────────────────────────────
function T.Stop(src, targetSrc, plate, reason)
    local ok, err = guard(src)
    if not ok then return false, err end

    targetSrc = tonumber(targetSrc)
    if not targetSrc or not GetPlayerName(targetSrc) then return false, Config.Text.noTarget end
    if targetSrc == src then return false, 'you cannot stop yourself' end
    if not withinRange(src, targetSrc, Config.Traffic.maxDistance + 8.0) then
        return false, Config.Text.tooFar
    end
    if not PoliceUtil.Cooldown('stop:' .. src, 8) then return false, Config.Text.rateLimited end

    local officerCid, officerName = officer(src)
    local driverCid = PoliceUtil.GetCitizenId(targetSrc)
    if not driverCid then return false, 'driver has no loaded character' end

    plate = PoliceUtil.SanitizePlate(plate)
    if plate == '' then plate = nil end

    local id = Database.CreateStop({
        officer_citizenid = officerCid,
        officer_name = officerName,
        driver_citizenid = driverCid,
        driver_name = GetPlayerName(targetSrc),
        plate = plate,
        reason = reason or 'Traffic stop',
        notes = nil,
    })
    if not id then return false, 'stop could not be logged' end

    T.LastStops[src] = id
    TriggerClientEvent('grand_police:client:StopLogged', src, id, targetSrc, plate)

    PoliceUtil.Notify(targetSrc, ('You are being pulled over by %s'):format(officerName), 'warning')
    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'traffic',
        priority = 2,
        message = ('Traffic stop #%d by %s%s'):format(id, officerName,
            plate and (' on plate ' .. plate) or ''),
        citizenid = driverCid,
        src = targetSrc,
    })
    return true, id
end

function T.CloseStop(src, id)
    local ok, err = guard(src)
    if not ok then return false, err end

    id = PoliceUtil.Int(id) or T.LastStops[src]
    if not id then return false, 'no active stop' end

    local rows = Database.ActiveStops(PoliceUtil.GetCitizenId(src))
    local owned = false
    for _, row in ipairs(rows) do
        if tonumber(row.id) == id then owned = true break end
    end
    if not owned then return false, 'that stop is not yours' end

    if not Database.CloseStop(id) then return false, 'stop already closed' end
    T.LastStops[src] = nil
    TriggerClientEvent('grand_police:client:MdtNotice', src, ('Stop #%d closed'):format(id), 'success')
    return true
end

-- ─── Breathalyzer ────────────────────────────────────────────
function T.Breathalyzer(src, targetSrc)
    local ok, err = guard(src)
    if not ok then return false, err end

    targetSrc = tonumber(targetSrc) or src
    if not GetPlayerName(targetSrc) then return false, Config.Text.noTarget end
    if not withinRange(src, targetSrc, 6.0) then return false, Config.Text.tooFar end
    if not PoliceUtil.Cooldown('breath:' .. src .. ':' .. targetSrc, Config.Traffic.breathalyzerCooldown or 30) then
        return false, 'breathalyzer recycling'
    end

    -- Weighted result: most stops are clean, some are over the limit.
    local roll = math.random(1, 100)
    local bac
    if roll <= 62 then
        bac = math.random(0, 39) / 1000          -- 0.000 - 0.039
    elseif roll <= 82 then
        bac = math.random(40, 79) / 1000         -- 0.040 - 0.079
    else
        bac = math.random(80, 180) / 1000        -- 0.080 - 0.180
    end

    local driverCid = PoliceUtil.GetCitizenId(targetSrc)
    local driverName = GetPlayerName(targetSrc) or tostring(targetSrc)
    local over = bac >= 0.08

    if over and driverCid then
        local offence = Config.OffenceIndex.dui
        Wanted.Set(driverCid, math.max(Wanted.Get(driverCid), offence.stars or 2),
            'DUI (breathalyzer)')
        Database.CreateFine({
            citizenid = driverCid,
            name = driverName,
            officer_citizenid = PoliceUtil.GetCitizenId(src),
            officer_name = GetPlayerName(src),
            offence = offence.id,
            reason = ('Breathalyzer %.3f'):format(bac),
            amount = offence.fine,
            dueHours = Config.Fines.defaultDueHours,
        })
    end

    TriggerClientEvent('grand_police:client:Breathalyzer', src, targetSrc, bac, over)
    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'traffic',
        priority = over and 3 or 1,
        message = ('Breathalyzer: %s = %.3f (%s)'):format(driverName, bac, over and 'OVER LIMIT' or 'clean'),
        citizenid = driverCid,
    })
    return true, bac, over
end

-- ─── Impound ─────────────────────────────────────────────────
function T.Impound(src, plate, targetSrc)
    local ok, err = guard(src)
    if not ok then return false, err end

    plate = PoliceUtil.SanitizePlate(plate)
    if plate == '' then return false, 'usage: /impound <plate>' end

    targetSrc = tonumber(targetSrc)
    if targetSrc and GetPlayerName(targetSrc) then
        if not withinRange(src, targetSrc, 20.0) then return false, Config.Text.tooFar end
    end

    local vehicle = Database.VehicleByPlate(plate)
    if not vehicle then return false, 'no vehicle with that plate in the garage system' end
    if tonumber(vehicle.state) == 2 then return false, 'that vehicle is already impounded' end

    local officerCid = PoliceUtil.GetCitizenId(src)
    local fee = Config.Traffic.impoundFee or 2500
    local days = Config.Traffic.impoundDays or 7

    if not Database.SetVehicleState(plate, 2) then return false, 'vehicle state update failed' end
    local id = Database.ImpoundVehicle(plate, vehicle.citizenid, vehicle.model, officerCid, fee, days)

    if not id then
        Database.SetVehicleState(plate, 1)
        return false, 'impound record failed'
    end

    PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
        kind = 'impound',
        priority = 1,
        message = ('Vehicle %s impounded by %s (fee %s)'):format(
            plate, GetPlayerName(src) or tostring(src), PoliceUtil.Money(fee)),
        citizenid = vehicle.citizenid,
    })

    local ownerSrc = PoliceUtil.TryExport('grand_core', 'GetSourceByCitizenId', vehicle.citizenid)
    if ownerSrc and tonumber(ownerSrc) then
        PoliceUtil.Notify(tonumber(ownerSrc),
            ('Your vehicle %s was impounded. Release fee: %s'):format(plate, PoliceUtil.Money(fee)), 'warning')
    end

    TriggerClientEvent('grand_police:client:MdtNotice', src,
        ('Impounded %s (record #%d)'):format(plate, id), 'success')
    return true, id, fee
end

function T.ReleaseImpound(src, plate)
    local ok, err = guard(src)
    if not ok then return false, err end

    plate = PoliceUtil.SanitizePlate(plate)
    if plate == '' then return false, 'usage: /impound release <plate>' end

    local record = Database.Impounded(plate)
    if not record then return false, 'that plate is not impounded' end

    if not Database.ReleaseImpound(plate) then return false, 'release failed' end
    Database.SetVehicleState(plate, 1)

    TriggerClientEvent('grand_police:client:MdtNotice', src, ('Released %s'):format(plate), 'success')
    return true
end

function T.List(src)
    local ok, err = guard(src)
    if not ok then return false, err end
    local citizenid = PoliceUtil.GetCitizenId(src)
    local rows = Database.ActiveStops(citizenid)
    TriggerClientEvent('grand_police:client:MdtStops', src, rows or {})
    return true, rows
end

return T
