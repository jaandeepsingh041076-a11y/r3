-- ─────────────────────────────────────────────────────────────
--  resources/[grand_systems]/grand_police/shared/util.lua
--  Shared helpers. Defines the global `PoliceUtil` used by both
--  sides. Framework-agnostic: grand_core exports only.
-- ─────────────────────────────────────────────────────────────

PoliceUtil = PoliceUtil or {}
local U = PoliceUtil

U.Server = IsDuplicityVersion and IsDuplicityVersion() or false
U.Cooldowns = {}

-- ─── Guarded exports ─────────────────────────────────────────
function U.TryExport(resource, name, ...)
    if type(resource) ~= 'string' or type(name) ~= 'string' then return nil end
    if GetResourceState(resource) ~= 'started' then return nil end
    local args = table.pack(...)
    local ok, result = pcall(function()
        return exports[resource][name](table.unpack(args, 1, args.n))
    end)
    return ok and result or nil
end

-- ─── Logging ─────────────────────────────────────────────────
function U.Log(level, message, ...)
    if level == 'debug' and not Config.Debug then return end
    local text = select('#', ...) > 0 and string.format(tostring(message), ...) or tostring(message)
    print(('^4[grand_police]^7 %s'):format(text))
end

function U.Debug(...)
    if Config.Debug then U.Log('debug', ...) end
end

-- ─── Identity / job ──────────────────────────────────────────
function U.GetCitizenId(src)
    src = tonumber(src)
    if not src then return nil end
    local cid = U.TryExport('grand_core', 'GetCitizenId', src)
    if type(cid) == 'string' and cid ~= '' then return cid end
    return nil
end

function U.GetIdentifier(src)
    src = tonumber(src)
    if not src then return nil end
    local identifier = U.TryExport('grand_core', 'GetIdentifier', src)
    if type(identifier) == 'string' and identifier ~= '' then return identifier end
    return GetPlayerIdentifierByType(src, 'license')
end

--- Returns job name, grade, onDuty and faction.
function U.Job(src)
    local job = U.TryExport('grand_core', 'GetJob', tonumber(src) or 0)
    if type(job) ~= 'table' then return nil end
    return {
        name = job.job or job.name,
        grade = tonumber(job.grade) or 0,
        onDuty = job.onDuty == true,
        label = job.label,
        type = job.type,
        faction = job.faction,
    }
end

function U.JobName(src)
    local job = U.Job(src)
    return job and job.name or nil
end

function U.IsPolice(src)
    local job = U.Job(src)
    if not job then return false end
    if job.faction == 'police' or job.faction == 'federal' then return true end
    for _, name in ipairs(Config.Jobs.police or {}) do
        if job.name == name then return true end
    end
    return false
end

function U.IsEMS(src)
    local job = U.Job(src)
    if not job then return false end
    if job.faction == 'ems' then return true end
    for _, name in ipairs(Config.Jobs.ems or {}) do
        if job.name == name then return true end
    end
    return false
end

function U.IsEmergency(src)
    return U.IsPolice(src) or U.IsEMS(src)
end

function U.OnDuty(src)
    local flag = U.TryExport('grand_core', 'IsOnDuty', tonumber(src) or 0)
    if flag ~= nil then return flag == true end
    local job = U.Job(src)
    return job ~= nil and job.onDuty == true
end

function U.Grade(src)
    local job = U.Job(src)
    return job and job.grade or 0
end

function U.GradeLabel(jobName, grade)
    local labels = Config.Grades[jobName]
    if not labels then return ('Grade %d'):format(grade or 0) end
    return labels[(tonumber(grade) or 0) + 1] or ('Grade %d'):format(grade or 0)
end

function U.IsSupervisor(src)
    if not U.Server then return false end
    if IsPlayerAceAllowed(tonumber(src) or 0, Config.Permissions.supervisor) then return true end
    return U.Grade(src) >= (Config.SupervisorGrade or 2)
end

function U.IsAdmin(src)
    if not U.Server then return false end
    src = tonumber(src) or 0
    if src == 0 then return true end
    if IsPlayerAceAllowed(src, Config.Permissions.admin) then return true end
    for _, group in ipairs(Config.Permissions.aceGroups or {}) do
        if IsPlayerAceAllowed(src, group) then return true end
    end
    return false
end

function U.InList(list, value)
    for _, entry in ipairs(list or {}) do
        if entry == value then return true end
    end
    return false
end

-- ─── Notifications ───────────────────────────────────────────
function U.Notify(target, message, kind)
    message = tostring(message or '')
    kind = kind or 'info'

    if U.Server then
        local src = tonumber(target)
        if not src then return end
        local sent = U.TryExport('grand_core', 'Notify', src, message, kind)
        if sent == nil then
            TriggerClientEvent('grand_police:client:Notify', src, message, kind)
        end
        return
    end

    if GetResourceState('ox_lib') == 'started' then
        local ok = pcall(function()
            lib.notify({ description = message, type = kind })
        end)
        if ok then return end
    end

    local colours = {
        error = { 244, 67, 54 }, success = { 76, 175, 80 },
        warning = { 255, 193, 7 }, info = { 190, 210, 255 },
    }
    TriggerEvent('chat:addMessage', {
        color = colours[kind] or colours.info,
        multiline = true,
        args = { 'Police', message },
    })
end

--- Broadcast to every on-duty member of a faction (server side).
function U.Broadcast(faction, eventName, ...)
    if not U.Server then return end
    local args = table.pack(...)
    for _, srcText in ipairs(GetPlayers()) do
        local src = tonumber(srcText)
        local isTarget = false
        if faction == 'police' then
            isTarget = U.IsPolice(src) and U.OnDuty(src)
        elseif faction == 'ems' then
            isTarget = U.IsEMS(src) and U.OnDuty(src)
        elseif faction == 'all' then
            isTarget = U.IsEmergency(src) and U.OnDuty(src)
        end
        if isTarget then
            TriggerClientEvent(eventName, src, table.unpack(args, 1, args.n))
        end
    end
end

-- ─── Money ───────────────────────────────────────────────────
function U.GetMoney(src)
    local money = U.TryExport('grand_core', 'GetMoney', tonumber(src) or 0)
    if type(money) == 'table' then return money end
    return { cash = 0, bank = 0, crypto = 0 }
end

function U.RemoveMoney(src, kind, amount, reason)
    local result = U.TryExport('grand_core', 'RemoveMoney', tonumber(src) or 0, kind, amount, reason)
    if result ~= nil then return result == true end
    return false
end

function U.AddMoney(src, kind, amount, reason)
    local result = U.TryExport('grand_core', 'AddMoney', tonumber(src) or 0, kind, amount, reason)
    if result ~= nil then return result == true end
    return false
end

-- ─── Formatting / sanitising ─────────────────────────────────
function U.Int(value)
    local n = tonumber(value)
    if not n or n ~= n then return nil end
    return math.floor(n)
end

function U.Clamp(value, low, high)
    if low and value < low then value = low end
    if high and value > high then value = high end
    return value
end

function U.Money(amount)
    local text = tostring(math.floor(tonumber(amount) or 0))
    while true do
        local replaced, count = text:gsub('^(%d+)(%d%d%d)', '%1,%2')
        text = replaced
        if count == 0 then break end
    end
    return '$' .. text
end

function U.FormatTime(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    if hours > 0 then
        return ('%dh %02dm'):format(hours, minutes)
    end
    if minutes > 0 then
        return ('%dm %02ds'):format(minutes, secs)
    end
    return ('%ds'):format(secs)
end

function U.SanitizeText(raw, maxLen)
    if type(raw) ~= 'string' then return '' end
    local text = raw:gsub('[%c]', ' '):gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return text:sub(1, maxLen or 190)
end

function U.SanitizeKey(raw)
    if type(raw) ~= 'string' then return '' end
    return (raw:lower():gsub('[^%w_%-]', '')):sub(1, 48)
end

function U.SanitizePlate(raw)
    if type(raw) ~= 'string' then return '' end
    return (raw:upper():gsub('[^%w]', '')):sub(1, 8)
end

function U.Cooldown(key, seconds)
    local now = os.time()
    local until_ = U.Cooldowns[key]
    if until_ and now < until_ then return false, until_ - now end
    U.Cooldowns[key] = now + math.max(1, math.floor(seconds or 1))
    return true
end

function U.PruneCooldowns()
    local now = os.time()
    for key, until_ in pairs(U.Cooldowns) do
        if until_ <= now then U.Cooldowns[key] = nil end
    end
end

function U.Distance(a, b)
    if not a or not b then return math.huge end
    return #(vector3(a.x, a.y, a.z) - vector3(b.x, b.y, b.z))
end

function U.CoordsOf(src)
    local ped = GetPlayerPed(tonumber(src) or 0)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

function U.Offence(id)
    return Config.OffenceIndex[U.SanitizeKey(tostring(id or ''))]
end

function U.OffenceList()
    return Config.Offences
end

function U.WantedColour(stars)
    stars = tonumber(stars) or 0
    if stars >= 5 then return 1 end
    if stars >= 4 then return 1 end
    if stars >= 3 then return 49 end
    if stars >= 2 then return 47 end
    return 46
end

return U
