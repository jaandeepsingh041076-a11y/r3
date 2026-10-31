-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/client/prison.lua
--  Bolingbroke HUD: sentence countdown, lockdown banner and the
--  escape watchdog. Everything is server-verified.
-- ─────────────────────────────────────────────────────────────

PoliceClient = PoliceClient or {}
local C = PoliceClient

C.Jailed = false
C.SentenceEndsAt = 0
C.SentenceReason = nil
C.Lockdown = false
C.LockdownUntil = 0
C.LastEscapeReport = 0

local function notify(message, kind)
    PoliceUtil.Notify(message, kind)
end

local function applyJail(payload)
    C.Jailed = true
    local minutes = tonumber(payload.minutes) or 0
    C.SentenceEndsAt = GetGameTimer() + math.floor(minutes * 60000)
    C.SentenceReason = payload.reason
    C.Officer = payload.officer

    local spawn = payload.spawn or Config.Prison.spawn
    if spawn then
        SetEntityCoords(PlayerPedId(), spawn.x, spawn.y, spawn.z, false, false, false, true)
        if spawn.w then SetEntityHeading(PlayerPedId(), spawn.w) end
    end

    notify(('SENTENCED: %d minutes - %s'):format(minutes, tostring(payload.reason or 'court order')), 'error')
end

RegisterNetEvent('grand_police:client:Jailed', function(payload)
    applyJail(payload or {})
end)

RegisterNetEvent('grand_police:client:Released', function(reason)
    C.Jailed = false
    C.SentenceEndsAt = 0
    C.SentenceReason = nil
    notify(('Released from Bolingbroke (%s)'):format(tostring(reason or 'time served')), 'success')
end)

RegisterNetEvent('grand_police:client:Teleport', function(coords)
    if not coords then return end
    SetEntityCoords(PlayerPedId(), coords.x, coords.y, coords.z, false, false, false, true)
    if coords.w then SetEntityHeading(PlayerPedId(), coords.w) end
end)

RegisterNetEvent('grand_police:client:Lockdown', function(active, until_)
    C.Lockdown = active == true
    C.LockdownUntil = tonumber(until_) or 0
    if C.Lockdown then
        notify('BOLINGBROKE LOCKDOWN: return to your cells immediately', 'error')
    else
        notify('Lockdown lifted', 'success')
    end
end)

-- ─── HUD ─────────────────────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 500

        if C.Jailed then
            sleep = 0
            local remaining = math.max(0, C.SentenceEndsAt - GetGameTimer())
            local seconds = math.floor(remaining / 1000)
            local minutes = math.floor(seconds / 60)
            local secs = seconds % 60

            SetTextScale(0.46, 0.46)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 90, 90, 235)
            SetTextOutline()
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString('BOLINGBROKE PENITENTIARY')
            DrawText(0.5, 0.03)

            SetTextScale(0.62, 0.62)
            SetTextColour(255, 255, 255, 240)
            SetTextEntry('STRING')
            AddTextComponentString(('%02d:%02d'):format(minutes, secs))
            DrawText(0.5, 0.065)

            SetTextScale(0.30, 0.30)
            SetTextColour(210, 210, 210, 220)
            SetTextEntry('STRING')
            AddTextComponentString(tostring(C.SentenceReason or 'Sentence'))
            DrawText(0.5, 0.098)

            if C.Lockdown then
                SetTextScale(0.40, 0.40)
                SetTextColour(255, 40, 40, 240)
                SetTextEntry('STRING')
                AddTextComponentString('LOCKDOWN ACTIVE')
                DrawText(0.5, 0.13)
            end
        elseif C.Lockdown then
            sleep = 0
            SetTextScale(0.38, 0.38)
            SetTextFont(4)
            SetTextProportional(1)
            SetTextColour(255, 60, 60, 235)
            SetTextOutline()
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString('BOLINGBROKE LOCKDOWN')
            DrawText(0.5, 0.04)
        end

        Wait(sleep)
    end
end)

-- ─── Escape watchdog ─────────────────────────────────────────
CreateThread(function()
    while true do
        Wait(2000)
        if C.Jailed then
            local coords = GetEntityCoords(PlayerPedId())
            local distance = #(coords - Config.Prison.spawn)
            if distance > (Config.Prison.releaseRadius or 180.0) then
                local now = GetGameTimer()
                if now - C.LastEscapeReport > 30000 then
                    C.LastEscapeReport = now
                    notify('You are outside the prison perimeter. Return immediately.', 'error')
                    TriggerServerEvent('grand_police:server:Escape')
                end
            end
        end
    end
end)

-- ─── Prison info command ─────────────────────────────────────
RegisterCommand('sentence', function()
    if not C.Jailed then
        notify('You are not serving a sentence', 'info')
        return
    end
    local seconds = math.max(0, math.floor((C.SentenceEndsAt - GetGameTimer()) / 1000))
    notify(('Time remaining: %s (%s)'):format(
        PoliceUtil.FormatTime(seconds), tostring(C.SentenceReason or 'sentence')), 'info')
end, false)

-- ─── Visitor marker ──────────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 800
        local coords = GetEntityCoords(PlayerPedId())
        local visitor = Config.Prison.visitor
        if visitor and #(coords - visitor) < 40.0 then
            sleep = 0
            DrawMarker(1, visitor.x, visitor.y, visitor.z - 0.95,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0,
                120, 180, 255, 100, false, true, 2, false, nil, nil, false)

            local onScreen, sx, sy = GetScreenCoordFromWorldCoord(visitor.x, visitor.y, visitor.z + 1.0)
            if onScreen then
                SetTextScale(0.32, 0.32)
                SetTextFont(4)
                SetTextProportional(1)
                SetTextColour(200, 220, 255, 235)
                SetTextOutline()
                SetTextEntry('STRING')
                AddTextComponentString('Bolingbroke Visitor Center')
                DrawText(sx, sy)
            end
        end
        Wait(sleep)
    end
end)

return C
