-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/server/duty.lua
--  Duty toggling, station validation and the live roster.
--  grand_core owns the actual on-duty flag; this file keeps the
--  police shift log and pushes roster updates to clients.
-- ─────────────────────────────────────────────────────────────

Duty = Duty or {}
local D = Duty

D.RosterCache = {}
D.LastRosterPush = 0

-- ─── Helpers ─────────────────────────────────────────────────
function D.StationAt(coords)
    if not coords then return nil end
    local best, bestDistance = nil, math.huge
    for _, station in ipairs(Config.Stations) do
        local distance = PoliceUtil.Distance(coords, station.station)
        if distance < bestDistance then
            best, bestDistance = station, distance
        end
    end
    if best and bestDistance <= (Config.Duty.stationRadius + 6.0) then
        return best, bestDistance
    end
    return nil, bestDistance
end

function D.ServiceFor(station, src)
    if PoliceUtil.IsPolice(src) and station.services and station.services.police then
        return 'police'
    end
    if PoliceUtil.IsEMS(src) and station.services and station.services.ems then
        return 'ems'
    end
    return nil
end

local function stationPayload(station)
    if not station then return nil end
    return {
        id = station.id,
        label = station.label,
        short = station.short,
        station = station.station,
        spawn = station.spawn,
        garage = station.garage,
        armory = station.armory,
    }
end

D.Payload = stationPayload

function D.Name(src)
    local cid = PoliceUtil.GetCitizenId(src)
    local name = GetPlayerName(src) or cid or tostring(src)
    return name, cid
end

--- Pushes the roster to everyone on duty and returns it.
function D.PushRoster()
    local rows = Database.Roster()
    D.RosterCache = rows

    local payload = {}
    for _, row in ipairs(rows) do
        payload[#payload + 1] = {
            citizenid = row.citizenid,
            name = row.name,
            job = row.job,
            grade = row.grade,
            station = row.station,
            since = row.started_at,
        }
    end

    PoliceUtil.Broadcast('all', 'grand_police:client:Roster', payload)
    return payload
end

function D.Roster()
    return D.RosterCache
end

function D.Count(faction)
    local rows = Database.Roster()
    local count = 0
    for _, row in ipairs(rows) do
        if not faction then
            count = count + 1
        else
            local isPolice = PoliceUtil.InList(Config.Jobs.police, row.job)
            local isEMS = PoliceUtil.InList(Config.Jobs.ems, row.job)
            if (faction == 'police' and isPolice) or (faction == 'ems' and isEMS) then
                count = count + 1
            end
        end
    end
    return count
end

-- ─── Toggle ──────────────────────────────────────────────────
--- Server-authoritative duty toggle. `stationId` is advisory only;
--- the server re-checks the player's position against every
--- station, so a spoofed id cannot teleport a shift across the map.
function D.Toggle(src, stationId)
    src = tonumber(src)
    if not src or src <= 0 then return false, 'invalid player' end

    if not PoliceUtil.IsEmergency(src) then
        return false, Config.Text.noFaction
    end
    if not PoliceUtil.Cooldown('duty:' .. src, 3) then
        return false, Config.Text.rateLimited
    end

    local coords = PoliceUtil.CoordsOf(src)
    local station = D.StationAt(coords)
    if not station then
        return false, Config.Text.noStation
    end

    -- If the client supplied an id, it must be the same station.
    if stationId and stationId ~= '' then
        local claimed = Config.StationIndex[stationId]
        if claimed and claimed.id ~= station.id then
            return false, Config.Text.noStation
        end
    end

    local service = D.ServiceFor(station, src)
    if not service then
        return false, 'this station does not serve your department'
    end

    local onDuty = PoliceUtil.OnDuty(src)
    local citizenid = PoliceUtil.GetCitizenId(src)
    if not citizenid then return false, 'character not loaded' end

    local name = GetPlayerName(src) or citizenid
    local job = PoliceUtil.Job(src) or {}

    if onDuty then
        PoliceUtil.TryExport('grand_core', 'ToggleDuty', src, false)
        Database.EndDuty(citizenid)
        TriggerClientEvent('grand_police:client:DutyChanged', src, false, stationPayload(station))
        PoliceUtil.Notify(src, 'You are now 10-42 (off duty)', 'info')
    else
        PoliceUtil.TryExport('grand_core', 'ToggleDuty', src, true)
        Database.StartDuty(citizenid, name, job.name, job.grade or 0, station.id)
        TriggerClientEvent('grand_police:client:DutyChanged', src, true, stationPayload(station))
        PoliceUtil.Notify(src, ('You are now 10-8 at %s'):format(station.label), 'success')
    end

    D.PushRoster()
    PoliceUtil.Broadcast(service, 'grand_police:client:DutyFlash', {
        name = name,
        station = station.short,
        onDuty = not onDuty,
        service = service,
    })

    PoliceUtil.Log('info', ('%s %s at %s'):format(name, onDuty and 'went off duty' or 'came on duty', station.id))
    return true, not onDuty
end

--- Admin override: force a duty state without a station check.
function D.Force(src, state)
    src = tonumber(src)
    if not src or src <= 0 then return false end

    local citizenid = PoliceUtil.GetCitizenId(src)
    if not citizenid then return false, 'no character' end

    PoliceUtil.TryExport('grand_core', 'ToggleDuty', src, state == true)
    if state then
        local job = PoliceUtil.Job(src) or {}
        Database.StartDuty(citizenid, GetPlayerName(src) or citizenid, job.name, job.grade or 0, 'admin')
    else
        Database.EndDuty(citizenid)
    end

    TriggerClientEvent('grand_police:client:DutyChanged', src, state == true, nil)
    D.PushRoster()
    return true
end

--- Drops a player off the roster after they disconnect. Called from
--- main.lua's playerDropped handler.
function D.PlayerDropped(src)
    if not Config.Duty.autoOffDutyOnQuit then return end
    local citizenid = PoliceUtil.GetCitizenId(src)
    if not citizenid then return end
    Database.EndDuty(citizenid)
    D.LastRosterPush = 0
end

-- ─── Boot / reconcile ────────────────────────────────────────
function D.Boot()
    CreateThread(function()
        Wait(5000)
        D.PushRoster()

        while true do
            Wait(math.max(30, Config.Duty.rosterRefreshSeconds or 60) * 1000)

            -- Close rows belonging to players who are no longer online.
            local rows = Database.Roster()
            local online = {}
            for _, srcText in ipairs(GetPlayers()) do
                local cid = PoliceUtil.GetCitizenId(tonumber(srcText))
                if cid then online[cid] = true end
            end
            for _, row in ipairs(rows) do
                if not online[row.citizenid] then
                    Database.EndDuty(row.citizenid)
                end
            end

            D.PushRoster()
            Database.CloseStaleCalls(120)
            Database.ExpireWarrants()
            PoliceUtil.PruneCooldowns()
        end
    end)
end

return D
