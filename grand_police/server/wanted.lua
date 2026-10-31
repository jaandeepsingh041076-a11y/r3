-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/server/wanted.lua
--  Wanted levels, decay, and the live suspect board pushed to
--  on-duty officers. The database is the source of truth; the
--  in-memory cache only exists so lookups are instant.
-- ─────────────────────────────────────────────────────────────

Wanted = Wanted or {}
local W = Wanted

W.Cache = {}          -- [citizenid] = { stars, reason, lastCrime }
W.Booted = false
W.LastSync = 0

-- ─── Lookup ──────────────────────────────────────────────────
local function resolve(target)
    if type(target) == 'number' then
        return PoliceUtil.GetCitizenId(target), target
    end
    if type(target) == 'string' and target ~= '' then
        return target, nil
    end
    return nil, nil
end

function W.Get(target)
    local citizenid = resolve(target)
    if not citizenid then return 0 end

    local cached = W.Cache[citizenid]
    if cached then return tonumber(cached.stars) or 0 end

    local row = Database.Wanted(citizenid)
    local stars = row and tonumber(row.stars) or 0
    if row then
        W.Cache[citizenid] = {
            stars = stars,
            reason = row.reason,
            lastCrime = row.last_crime_at,
        }
    end
    return stars
end

function W.Info(target)
    local citizenid = resolve(target)
    if not citizenid then return nil end
    local row = Database.Wanted(citizenid)
    if not row then return nil end
    return row, citizenid
end

function W.IsWanted(target)
    return W.Get(target) > 0
end

-- ─── Mutations ───────────────────────────────────────────────
--- Sets an absolute wanted level and pushes it to dispatch.
function W.Set(target, stars, reason, silent)
    local citizenid, src = resolve(target)
    if not citizenid then return false, 'no citizen' end

    stars = PoliceUtil.Clamp(PoliceUtil.Int(stars) or 0, 0, Config.Wanted.maxStars)
    reason = PoliceUtil.SanitizeText(reason or '', 190)

    Database.SetWanted(citizenid, stars, reason)
    W.Cache[citizenid] = { stars = stars, reason = reason, lastCrime = os.time() }

    -- Keep the record card in sync.
    Database.UpsertRecord(citizenid, nil, nil, nil, { wanted = stars })

    if not silent then
        W.Sync()
        if stars > 0 then
            PoliceUtil.Broadcast('police', 'grand_police:client:Dispatch', {
                kind = 'wanted',
                priority = stars >= 4 and 4 or (stars >= 2 and 3 or 2),
                message = ('10-80: %s is now %d star wanted (%s)'):format(
                    tostring(src and GetPlayerName(src) or citizenid), stars, reason),
                citizenid = citizenid,
            })
        end
    end

    PoliceUtil.Log('info', ('wanted %s -> %d stars (%s)'):format(citizenid, stars, reason))
    return true, stars
end

function W.Add(target, stars, reason)
    local current = W.Get(target)
    return W.Set(target, math.min(current + (PoliceUtil.Int(stars) or 1), Config.Wanted.maxStars), reason)
end

function W.Clear(target, silent)
    local citizenid = resolve(target)
    if not citizenid then return false end

    Database.ClearWanted(citizenid)
    W.Cache[citizenid] = { stars = 0, reason = nil, lastCrime = os.time() }
    Database.UpsertRecord(citizenid, nil, nil, nil, { wanted = 0 })

    if not silent then W.Sync() end

    local src = PoliceUtil.TryExport('grand_core', 'GetSourceByCitizenId', citizenid)
    if src then
        TriggerClientEvent('grand_police:client:WantedCleared', tonumber(src))
    end
    return true
end

-- ─── Sync to on-duty police ──────────────────────────────────
--- Builds the suspect board. Coordinates are only ever included
--- for players who are online.
function W.Board()
    local rows = Database.WantedList(50)
    local board = {}

    for _, row in ipairs(rows) do
        local stars = tonumber(row.stars) or 0
        if stars > 0 then
            local src = PoliceUtil.TryExport('grand_core', 'GetSourceByCitizenId', row.citizenid)
            local entry = {
                citizenid = row.citizenid,
                name = row.name,
                stars = stars,
                reason = row.reason,
                lastCrime = row.last_crime_at,
            }

            if src then
                src = tonumber(src)
                local coords = PoliceUtil.CoordsOf(src)
                if coords then
                    entry.src = src
                    entry.x = coords.x
                    entry.y = coords.y
                    entry.z = coords.z
                end
            end

            board[#board + 1] = entry
        end
    end

    return board
end

function W.Sync()
    if os.time() - W.LastSync < 2 then return end
    W.LastSync = os.time()
    PoliceUtil.Broadcast('police', 'grand_police:client:WantedList', W.Board())
end

-- ─── Decay ───────────────────────────────────────────────────
function W.Decay()
    local changed = Database.DecayWanted(Config.Wanted.decayMinutes or 8)
    if changed and changed > 0 then
        W.Cache = {}
        W.Sync()
        PoliceUtil.Debug('%d wanted levels decayed', changed)
    end
end

-- ─── Boot ────────────────────────────────────────────────────
function W.Boot()
    if W.Booted then return end
    W.Booted = true

    -- Hydrate cache for anyone with an active level.
    for _, row in ipairs(Database.WantedList(200)) do
        W.Cache[row.citizenid] = {
            stars = tonumber(row.stars) or 0,
            reason = row.reason,
            lastCrime = row.last_crime_at,
        }
    end

    CreateThread(function()
        while true do
            Wait(math.max(30, Config.Wanted.decayIntervalSeconds or 120) * 1000)
            W.Decay()
        end
    end)

    CreateThread(function()
        while true do
            Wait(Config.Blips.wantedUpdateMs or 5000)
            W.Sync()
        end
    end)
end

return W
