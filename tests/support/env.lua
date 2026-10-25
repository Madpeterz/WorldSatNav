-- Test environment: resolves "WorldSatNav/..." requires to the repo, and provides a
-- fake `api` plus helpers for building deterministic clocks and time zones.
local env = {}

local root = nil
local realDate = os.date
local realTime = os.time

function env.setRoot(path)
    root = path
end

function env.install()
    local loaders = package.loaders or package.searchers
    table.insert(loaders, 2, function(name)
        local relative = name:match("^WorldSatNav/(.+)$")
        if relative == nil then
            return "\n\tnot a WorldSatNav module '" .. name .. "'"
        end
        local path = root .. "/" .. relative .. ".lua"
        local file = io.open(path, "r")
        if file == nil then
            return "\n\tno file '" .. path .. "'"
        end
        file:close()
        local chunk, err = loadfile(path)
        if chunk == nil then
            error(err)
        end
        return chunk
    end)
end

-- ---------------------------------------------------------------------------
-- Calendar helpers (pure arithmetic, independent of the host's time zone)
-- ---------------------------------------------------------------------------

local function daysFromCivil(year, month, day)
    if month <= 2 then
        year = year - 1
    end
    local era = math.floor(year / 400)
    local yearOfEra = year - era * 400
    local monthPrime = (month + 9) % 12
    local dayOfYear = math.floor((153 * monthPrime + 2) / 5) + day - 1
    local dayOfEra = yearOfEra * 365 + math.floor(yearOfEra / 4) - math.floor(yearOfEra / 100) + dayOfYear
    return era * 146097 + dayOfEra - 719468
end

-- Unix seconds for a UTC wall-clock reading.
function env.utc(year, month, day, hour, min, sec)
    return daysFromCivil(year, month, day) * 86400 + (hour or 0) * 3600 + (min or 0) * 60 + (sec or 0)
end

-- UTC date table (year, month, day, hour, min, sec) for unix seconds.
function env.utcFields(timestamp)
    return realDate("!*t", timestamp)
end

local function lastSundayDays(year, month)
    local nextYear, nextMonth = year, month + 1
    if nextMonth > 12 then
        nextMonth = 1
        nextYear = year + 1
    end
    local lastDay = daysFromCivil(nextYear, nextMonth, 1) - 1
    local weekday = (lastDay + 4) % 7 -- 0 = Sunday (1970-01-01 was a Thursday)
    return lastDay - weekday
end

-- Offset-from-UTC function for a European zone: standardOffset seconds, +1h between the
-- last Sunday of March and the last Sunday of October (both at 01:00 UTC).
function env.euZone(standardOffset)
    return function(timestamp)
        local year = env.utcFields(timestamp).year
        local dstStart = lastSundayDays(year, 3) * 86400 + 3600
        local dstEnd = lastSundayDays(year, 10) * 86400 + 3600
        if timestamp >= dstStart and timestamp < dstEnd then
            return standardOffset + 3600
        end
        return standardOffset
    end
end

function env.fixedZone(offsetSeconds)
    return function()
        return offsetSeconds
    end
end

-- ---------------------------------------------------------------------------
-- Fake `api`
-- ---------------------------------------------------------------------------

-- opts.now: value GetLocalTime returns (settable later via api._now)
-- opts.gameZone: offset function for TimeToDate (default UTC); false = TimeToDate returns nil
-- opts.settings: table returned by GetSettings
function env.newApi(opts)
    opts = opts or {}
    local api = {
        baseDir = "mock",
        _now = opts.now,
        _settings = opts.settings,
        _logs = {},
        _saved = {},
        _files = {},
        _gameZone = opts.gameZone == nil and env.fixedZone(0) or opts.gameZone,
    }
    api.Log = {
        Info = function(_, message)
            table.insert(api._logs, tostring(message))
        end,
    }
    api.Time = {
        GetLocalTime = function()
            return api._now
        end,
        TimeToDate = function(_, timestamp)
            if api._timeToDate ~= nil then
                return api._timeToDate(timestamp)
            end
            if api._gameZone == false or type(timestamp) ~= "number" then
                return nil
            end
            return realDate("!*t", timestamp + api._gameZone(timestamp))
        end,
    }
    api.GetSettings = function()
        return api._settings
    end
    api.SaveSettings = function(name, tbl)
        table.insert(api._saved, { name = name, settings = tbl })
    end
    api.File = {
        Read = function(_, path)
            return api._files[path]
        end,
        Write = function(_, path, tbl)
            api._files[path] = tbl
        end,
    }
    return api
end

-- Make os.date("*t", t) answer for a simulated user zone (nil = remove os.date entirely).
function env.setUserZone(zone)
    if zone == nil then
        os.date = nil
        return
    end
    os.date = function(format, timestamp)
        if format == "*t" then
            return realDate("!*t", timestamp + zone(timestamp))
        end
        return realDate(format, timestamp)
    end
end

function env.restoreOs()
    os.date = realDate
    os.time = realTime
end

-- Fresh module state for every test: drop cached WorldSatNav modules, install a new api.
function env.reset(apiOpts)
    for name in pairs(package.loaded) do
        if name:match("^WorldSatNav/") then
            package.loaded[name] = nil
        end
    end
    env.restoreOs()
    env.api = env.newApi(apiOpts)
    package.loaded["api"] = env.api
    package.preload["api"] = function()
        return env.api
    end
    return env.api
end

function env.require(name)
    return require("WorldSatNav/" .. name)
end

return env
