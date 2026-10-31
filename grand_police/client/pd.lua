-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/client/pd.lua
--  Stations, map blips, duty markers, dispatch calls, wanted
--  suspect blips and the on-screen wanted readout.
--  NO NUI: markers, 3D text and chat only.
-- ─────────────────────────────────────────────────────────────

PoliceClient = PoliceClient or {}
local C = PoliceClient

C.Session = nil
C.OnDuty = false
C.Blips = {}
C.WantedBlips = {}
C.TempBlips = {}
C.Wanted = {}
C.DutyStation = nil
C.LastEscape = 0
C.DispatchLog = {}

local PREFIX = (Config.Blips and Config.Blips.prefix) or 'police_'

-- ─── Engine ──────────────────────────────────────────────────
local function engine(name, ...)
    if GetResourceState('grand_mechanic') ~= 'started' then return nil end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return exports['grand_mechanic'][name](table.unpack(args, 1, args.n))
    end)
    return ok and result or nil
end

local function addBlip(record)
    local engineId = engine('AddBlip', {
        id = record.id,
        coords = record.coords,
        sprite = record.sprite or 60,
        colour = record.colour or 'blue',
        scale = record.scale or 0.85,
        label = record.label,
        range = record.range or Config.Blips.drawDistance or 900.0,
        short = record.short == true,
    })

    if engineId then
        C.UsingEngine = true
        C.Blips[record.id] = engineId
        return engineId
    end

    local coords = record.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, record.sprite or 60)
    SetBlipColour(blip, 38)
    SetBlipScale(blip, record.scale or 0.85)
    SetBlipAsShortRange(blip, record.short == true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(tostring(record.label))
    EndTextCommandSetBlipName(blip)
    C.Blips[record.id] = blip
    return blip
end

local function removeBlip(id)
    local handle = C.Blips[id]
    if not handle then return end
    if C.UsingEngine then
        engine('RemoveBlip', handle)
    elseif type(handle) == 'number' then
        RemoveBlip(handle)
    end
    C.Blips[id] = nil
end

-- ─── Static map ──────────────────────────────────────────────
local function buildMap()
    for _, station in ipairs(Config.Stations) do
        addBlip({
            id = PREFIX .. 'station_' .. station.id,
            coords = station.station,
            sprite = station.blip and station.blip.sprite or 60,
            colour = station.blip and station.blip.colour or 'blue',
            scale = station.blip and station.blip.scale or 0.85,
            label = station.label,
            short = false,
        })
    end

    if Config.Blips.showPoi then
        for _, poi in ipairs(Config.Poi or {}) do
            addBlip({
                id = PREFIX .. 'poi_' .. poi.id,
                coords = poi.coords,
                sprite = poi.sprite or 1,
                colour = poi.colour or 'blue',
                scale = poi.scale or 0.8,
                label = poi.label,
                short = false,
            })
        end
    end
end

local function clearMap()
    for id in pairs(C.Blips) do removeBlip(id) end
    for cid in pairs(C.WantedBlips) do
        removeBlip(PREFIX .. 'wanted_' .. cid)
        C.WantedBlips[cid] = nil
    end
    C.Blips = {}
end

C.ClearMap = clearMap

-- ─── Session / duty ──────────────────────────────────────────
RegisterNetEvent('grand_police:client:Session', function(session)
    C.Session = session
    C.OnDuty = session and session.duty == true
    C.IsPolice = session and session.police == true
    C.IsEMS = session and session.ems == true
    C.SelfWanted = session and tonumber(session.wanted) or 0

    if session and (session.police or session.ems) then
        PoliceUtil.Notify(('LSPD/EMS terminal ready. /%s to toggle duty at a station.'):format(
            Config.Commands.duty), 'info')
    end
end)

RegisterNetEvent('grand_police:client:DutyChanged', function(onDuty, station)
    C.OnDuty = onDuty == true
    C.DutyStation = station
    if not onDuty then
        for cid in pairs(C.WantedBlips) do
            removeBlip(PREFIX .. 'wanted_' .. cid)
            C.WantedBlips[cid] = nil
        end
    end
end)

RegisterNetEvent('grand_police:client:Roster', function(rows)
    C.Roster = rows or {}
end)

RegisterNetEvent('grand_police:client:DutyFlash', function(info)
    if not info then return end
    TriggerEvent('chat:addMessage', {
        color = info.onDuty and { 120, 220, 140 } or { 200, 200, 200 },
        args = { 'Duty', ('%s %s at %s'):format(
            tostring(info.name), info.onDuty and '10-8' or '10-42', tostring(info.station)) },
    })
end)

-- ─── Wanted board ────────────────────────────────────────────
RegisterNetEvent('grand_police:client:WantedList', function(board)
    if not C.IsPolice then return end

    C.Wanted = board or {}
    local active = {}
    local localCoords = GetEntityCoords(PlayerPedId())
    local myServerId = GetPlayerServerId(PlayerId())

    for _, entry in ipairs(C.Wanted) do
        if entry.citizenid then
            if entry.src == myServerId then
                C.SelfWanted = tonumber(entry.stars) or 0
            end

            if entry.x and entry.y and entry.z then
                local distance = #(localCoords - vector3(entry.x, entry.y, entry.z))
                if distance <= (Config.Blips.wantedMaxBlipDistance or 1500.0) then
                    active[entry.citizenid] = true
                    local id = PREFIX .. 'wanted_' .. entry.citizenid
                    if C.WantedBlips[entry.citizenid] then
                        removeBlip(id)
                    end

                    addBlip({
                        id = id,
                        coords = vector3(entry.x, entry.y, entry.z),
                        sprite = 1,
                        colour = PoliceUtil.WantedColour(entry.stars),
                        scale = 0.9,
                        label = ('WANTED %d*: %s'):format(entry.stars, tostring(entry.name or entry.citizenid)),
                        short = true,
                    })
                    C.WantedBlips[entry.citizenid] = true
                end
            end
        end
    end

    for cid in pairs(C.WantedBlips) do
        if not active[cid] then
            removeBlip(PREFIX .. 'wanted_' .. cid)
            C.WantedBlips[cid] = nil
        end
    end
end)

RegisterNetEvent('grand_police:client:WantedCleared', function()
    C.SelfWanted = 0
end)

-- ─── Dispatch ────────────────────────────────────────────────
local function priorityLabel(priority)
    return (Config.Calls.priorities or {})[tonumber(priority) or 2] or 'Medium'
end

RegisterNetEvent('grand_police:client:Dispatch', function(call)
    if not call then return end

    local message = tostring(call.message or '')
    local label = priorityLabel(call.priority)
    local kind = tostring(call.kind or 'call'):upper()

    TriggerEvent('chat:addMessage', {
        color = { 255, 140, 80 },
        multiline = true,
        args = { ('DISPATCH [%s]'):format(label), ('%s: %s'):format(kind, message) },
    })

    if call.coords then
        local coords = call.coords
        if type(coords) == 'table' and coords.x then
            local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipSprite(blip, kind == 'PANIC' and 161 or 480)
            SetBlipColour(blip, kind == 'PANIC' and 1 or 47)
            SetBlipScale(blip, 1.0)
            SetBlipAsShortRange(blip, false)
            SetBlipFlashes(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName(('%s: %s'):format(kind, message))
            EndTextCommandSetBlipName(blip)
            C.TempBlips[#C.TempBlips + 1] = {
                handle = blip,
                expire = GetGameTimer() + (Config.Blips.callDuration or 180) * 1000,
            }
        end
    end

    C.DispatchLog[#C.DispatchLog + 1] = call
    if #C.DispatchLog > 30 then table.remove(C.DispatchLog, 1) end
end)

RegisterNetEvent('grand_police:client:Radio', function(payload)
    if not payload then return end
    TriggerEvent('chat:addMessage', {
        color = { 120, 180, 255 },
        args = { 'RADIO', ('%s: %s'):format(
            tostring(payload.name or 'unit'), tostring(payload.message or '')) },
    })
end)

-- ─── Temporary blip cleanup ──────────────────────────────────
CreateThread(function()
    while true do
        Wait(5000)
        local now = GetGameTimer()
        for index = #C.TempBlips, 1, -1 do
            local entry = C.TempBlips[index]
            if now >= entry.expire then
                RemoveBlip(entry.handle)
                table.remove(C.TempBlips, index)
            end
        end
    end
end)

-- ─── Station markers + duty prompt ───────────────────────────
CreateThread(function()
    while true do
        local sleep = 700
        local coords = GetEntityCoords(PlayerPedId())
        local nearest, nearestDistance = nil, math.huge

        for _, station in ipairs(Config.Stations) do
            local distance = #(coords - station.station)
            if distance < nearestDistance then
                nearest, nearestDistance = station, distance
            end

            if distance <= (Config.Blips.drawDistance or 900.0) then
                DrawMarker(1, station.station.x, station.station.y, station.station.z - 0.95,
                    0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.4, 2.4, 1.2,
                    60, 130, 255, 110, false, true, 2, false, nil, nil, false)
            end
        end

        if nearest and nearestDistance <= (Config.Duty.stationRadius or 22.0) then
            sleep = 0
            local onScreen, sx, sy = GetScreenCoordFromWorldCoord(
                nearest.station.x, nearest.station.y, nearest.station.z + 1.0)
            if onScreen then
                SetTextScale(0.34, 0.34)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextColour(200, 220, 255, 235)
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentString(('[E] Toggle duty - %s'):format(nearest.label))
                DrawText(sx, sy)
            end

            if IsControlJustReleased(0, 38) then
                TriggerServerEvent('grand_police:server:ToggleDuty', nearest.id)
            end
        end
        Wait(sleep)
    end
end)

-- ─── Wanted readout ──────────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 500
        local stars = tonumber(C.SelfWanted) or 0
        if stars > 0 then
            sleep = 0
            SetTextScale(0.42, 0.42)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 70, 70, 235)
            SetTextOutline()
            SetTextRightJustify(true)
            SetTextWrap(0.0, 0.98)
            SetTextEntry('STRING')
            AddTextComponentString(('WANTED %s'):format(string.rep('*', stars)))
            DrawText(0.0, 0.06)
        end
        Wait(sleep)
    end
end)

-- ─── Panic keybind (server-validated) ────────────────────────
RegisterCommand('polpanic', function()
    TriggerServerEvent('grand_police:server:Panic')
end, false)
RegisterKeyMapping('polpanic', 'Police panic button', 'keyboard', 'F10')

-- ─── Help ────────────────────────────────────────────────────
RegisterCommand('policehelp', function()
    TriggerEvent('chat:addMessage', {
        color = { 120, 180, 255 },
        multiline = true,
        args = { 'Police', table.concat({
            '/duty - toggle duty at a station',
            '/mdt - MDT terminal',
            '/wanted <id> <1-5> [reason]',
            '/arrest <id> [minutes] [reason]',
            '/fine <id> <offence|amount> [reason]',
            '/fines [id] - unpaid fines',
            '/payfine <fine_id>',
            '/warrant <id> <offence> <reason>',
            '/bolo <id|plate> <reason>',
            '/record <id> <charges>',
            '/evidence <id> <label> | <detail>',
            '/trafficstop <id> [plate] [reason]',
            '/breathalyzer <id>',
            '/impound <plate>',
            '/911 <message>  /ems <message>  /panic',
            '/radio <message>',
            '/revive <id>  /heal <id>',
            '/license check|grant|revoke',
        }, '\n') },
    })
end, false)

-- ─── Lifecycle ───────────────────────────────────────────────
AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    buildMap()
    CreateThread(function()
        Wait(2500)
        TriggerServerEvent('grand_police:server:ClientReady')
    end)
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    clearMap()
    engine('ClearBlips', PREFIX)
end)

return C
