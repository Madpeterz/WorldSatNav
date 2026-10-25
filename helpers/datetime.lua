local api = require("api")
local settingsModule = require("WorldSatNav/core/settings")
local log = require("WorldSatNav/helpers/log")

local datetime = {}

-- Every timestamp the addon stores, loads, or shares is unix seconds in the frame of
-- api.Time:GetLocalTime(). Wall-clock text is only used for user input/display and is
-- converted at the edge by ParseDateTimeToUnixtime / FormatTimestampToDateTime.
--
-- This engine's Lua numbers round like a 32-bit float (~24-bit mantissa), so a unix
-- time (~1.8e9) can only be held in steps of 128s. To keep that from compounding, all
-- date math here is done on small numbers (day counts, seconds within a day, offsets
-- from a base day) and a unix-sized value is built once, at the very end. Compare
-- times with SecondsUntil, which subtracts before the precision is lost.

local SECONDS_PER_DAY = 86400
-- Anything at or above this is assumed to be milliseconds (1e11 s is the year 5138).
local MILLISECOND_THRESHOLD = 100000000000
-- Our interpolated clock may run ahead of a coarse GetLocalTime by a few seconds; only
-- a bigger gap (a real clock change such as DST) snaps it back.
local CLOCK_SNAP_SECONDS = 30
-- Largest gap between the user's clock and the game's clock that is treated as DST.
local MAX_DST_LEAD_SECONDS = 3600
local DST_ROUNDING_SECONDS = 900

function datetime.SecondsToTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return hours, mins, secs
end

local function formatTwoDigits(value)
    local numericValue = tonumber(value)
    if numericValue == nil then
        return "00"
    end
    if numericValue < 10 then
        return "0" .. tostring(numericValue)
    end
    return tostring(numericValue)
end

local function firstDefined(...)
    local values = {...}
    for _, value in ipairs(values) do
        if value ~= nil then
            return value
        end
    end
    return nil
end

-- Number of seconds, or nil for nil/NaN/inf/non-numeric input. Millisecond values are
-- scaled down. Does not round.
local function toSeconds(value)
    local numericValue = tonumber(value)
    if numericValue == nil or numericValue ~= numericValue
        or numericValue > 1e300 or numericValue < -1e300 then
        return nil
    end
    if math.abs(numericValue) >= MILLISECOND_THRESHOLD then
        numericValue = numericValue / 1000
    end
    return numericValue
end

-- Whole unix seconds, or nil when the value is not a usable timestamp. Use this on
-- anything read back from a file or share code, and before writing one.
function datetime.NormalizeUnixTime(value)
    local seconds = toSeconds(value)
    if seconds == nil then
        return nil
    end
    return math.floor(seconds)
end

-- Clock = last GetLocalTime poll (base) + time elapsed since, accumulated from frame
-- deltas. Keeping the two apart lets SecondsUntil stay exact even though base itself
-- is too large to add a fraction of a second to.
local clockState = {
    base = nil,
    elapsed = 0,
}

function datetime.GetCurrentTimestamp()
    local rawLocalTime = api.Time:GetLocalTime()
    -- toSeconds goes through tonumber, so a numeric string from the engine works too.
    local localTime = toSeconds(rawLocalTime)
    if localTime == nil and not clockState.warnedBadClock then
        clockState.warnedBadClock = true
        log.DevLog("GetCurrentTimestamp: GetLocalTime returned unusable " .. type(rawLocalTime) .. ": " .. tostring(rawLocalTime))
    end
    if localTime ~= nil then
        if clockState.base == nil then
            clockState.base = localTime
            clockState.elapsed = 0
        else
            local drift = (localTime - clockState.base) - clockState.elapsed
            if drift > 0 or math.abs(drift) > CLOCK_SNAP_SECONDS then
                if drift < 0 then
                    log.DevLog("GetCurrentTimestamp: clock stepped back " .. string.format("%.0f", -drift) .. "s, resyncing")
                end
                clockState.base = localTime
                clockState.elapsed = 0
            end
        end
    end

    if clockState.base ~= nil then
        return clockState.base + clockState.elapsed
    end
    return nil
end

-- Smooths the one-second GetLocalTime between polls.
function datetime.AdvanceCurrentTimestamp(dt)
    local deltaMsec = tonumber(dt)
    if deltaMsec == nil then
        return
    end

    if clockState.base == nil then
        datetime.GetCurrentTimestamp()
    end

    if clockState.base ~= nil and deltaMsec > 0 then
        clockState.elapsed = clockState.elapsed + (deltaMsec / 1000)
    end
end

-- Seconds from now until `timestamp` (negative once it has passed), or nil without a
-- usable clock. Prefer this over comparing against GetCurrentTimestamp: the
-- subtraction happens before the 128s rounding of unix-sized values.
function datetime.SecondsUntil(timestamp)
    local target = tonumber(timestamp)
    if target == nil then
        return nil
    end
    datetime.GetCurrentTimestamp()
    if clockState.base == nil then
        return nil
    end
    return (target - clockState.base) - clockState.elapsed
end

local function extractDateParts(dateValue)
    if type(dateValue) ~= "table" then
        return nil, nil, nil, nil, nil, nil
    end

    local year = firstDefined(dateValue.year, dateValue.years, dateValue.wYear, dateValue.tm_year)
    local month = firstDefined(dateValue.month, dateValue.mon, dateValue.months, dateValue.wMonth, dateValue.tm_mon)
    local day = firstDefined(dateValue.day, dateValue.mday, dateValue.wDay, dateValue.dayOfMonth, dateValue.tm_mday)
    local hour = firstDefined(dateValue.hour, dateValue.hours, dateValue.wHour, dateValue.tm_hour)
    local min = firstDefined(dateValue.min, dateValue.minute, dateValue.minutes, dateValue.wMinute, dateValue.tm_min)
    local sec = firstDefined(dateValue.sec, dateValue.second, dateValue.seconds, dateValue.wSecond, dateValue.tm_sec)

    year, month, day, hour, min, sec = tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(min), tonumber(sec)

    if year ~= nil and year < 100 then
        year = year + 2000
    end
    if month ~= nil and month >= 0 and month <= 11 and dateValue.tm_mon ~= nil then
        month = month + 1
    end

    return year, month, day, hour, min, sec
end

local function isLeapYear(value)
    if value % 400 == 0 then
        return true
    end
    if value % 100 == 0 then
        return false
    end
    return value % 4 == 0
end

local DAYS_PER_MONTH = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}

local function daysInMonth(year, month)
    if month == 2 and isLeapYear(year) then
        return 29
    end
    return DAYS_PER_MONTH[month]
end

-- Wall-clock fields -> (whole days since 1970-01-01, seconds into that day). Both are
-- small, so exact. Zone-less: only a way to do date arithmetic.
local function dateTimeToDaySecond(year, month, day, hour, min, sec)
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    hour = tonumber(hour) or 0
    min = tonumber(min) or 0
    sec = tonumber(sec) or 0

    if year == nil or month == nil or day == nil then
        return nil, "Date is incomplete."
    end

    local components = {year, month, day, hour, min, sec}
    for _, value in ipairs(components) do
        if value % 1 ~= 0 then
            return nil, "Date and time must use whole numbers."
        end
    end

    if month < 1 or month > 12 then
        return nil, "Month must be between 1 and 12."
    end
    if day < 1 or day > daysInMonth(year, month) then
        return nil, "Day is out of range for the selected month."
    end
    if hour < 0 or hour > 23 then
        return nil, "Hour must be between 0 and 23. given value was: " .. tostring(hour)
    end
    if min < 0 or min > 59 then
        return nil, "Minute must be between 0 and 59. given value was: " .. tostring(min)
    end
    if sec < 0 or sec > 59 then
        return nil, "Second must be between 0 and 59. given value was: " .. tostring(sec)
    end

    local days = 0
    if year >= 1970 then
        for currentYear = 1970, year - 1 do
            days = days + (isLeapYear(currentYear) and 366 or 365)
        end
    else
        for currentYear = 1969, year, -1 do
            days = days - (isLeapYear(currentYear) and 366 or 365)
        end
    end
    for currentMonth = 1, month - 1 do
        days = days + daysInMonth(year, currentMonth)
    end
    days = days + (day - 1)

    return days, hour * 3600 + min * 60 + sec
end

-- Inverse of the day part of dateTimeToDaySecond: year, month, day.
local function daysToDate(totalDays)
    local days = math.floor(totalDays)
    local year = 1970
    while days < 0 do
        year = year - 1
        days = days + (isLeapYear(year) and 366 or 365)
    end
    while true do
        local daysInYear = isLeapYear(year) and 366 or 365
        if days < daysInYear then
            break
        end
        days = days - daysInYear
        year = year + 1
    end

    local month = 1
    while month < 12 and days >= daysInMonth(year, month) do
        days = days - daysInMonth(year, month)
        month = month + 1
    end
    return year, month, days + 1
end

-- (days, secondOfDay) for a date table such as TimeToDate or os.date("*t") returns.
local function dateTableToDaySecond(dateTable)
    local year, month, day, hour, min, sec = extractDateParts(dateTable)
    year, month, day, hour, min, sec = tonumber(year), tonumber(month), tonumber(day), tonumber(hour), tonumber(min), tonumber(sec)
    if year == nil or month == nil or day == nil or hour == nil or min == nil or sec == nil then
        return nil, "missing field(s)"
    end
    return dateTimeToDaySecond(year, month, day, math.floor(hour), math.floor(min), math.floor(sec))
end

-- TimeToDate has returned nil for plain unix seconds in the game, so also try the
-- unit it might want (milliseconds) and remember whichever answers.
local TIME_TO_DATE_SCALES = {1, 1000, 0.001}
local timeToDateScale = nil
local loggedDateFallback = false

local function timeToDateTable(timestamp)
    if timeToDateScale ~= nil then
        return api.Time:TimeToDate(timestamp * timeToDateScale)
    end
    for _, scale in ipairs(TIME_TO_DATE_SCALES) do
        local dateTable = api.Time:TimeToDate(timestamp * scale)
        if dateTable ~= nil then
            timeToDateScale = scale
            log.DevLog("TimeToDate answers for timestamps scaled by " .. tostring(scale))
            return dateTable
        end
    end
    return nil
end

-- The wall clock the game shows for `timestamp`, as (days, secondOfDay). When
-- TimeToDate cannot answer, GetLocalTime is treated as seconds on the wall clock
-- itself (the same assumption the pre-TimeToDate code made); userClockLead still
-- corrects it via os.date when that exists, or the manual DSToffset setting.
local function gameDaySecond(timestamp)
    local days, second = dateTableToDaySecond(timeToDateTable(timestamp))
    if days ~= nil then
        return days, second
    end
    if not loggedDateFallback then
        loggedDateFallback = true
        log.DevLog("TimeToDate unusable for " .. tostring(timestamp) .. ", treating GetLocalTime as wall-clock seconds; os available: " .. tostring(os ~= nil and type(os.date) == "function"))
    end
    local fallbackDays = math.floor(timestamp / SECONDS_PER_DAY)
    return fallbackDays, math.floor(timestamp - (fallbackDays * SECONDS_PER_DAY))
end

-- Seconds the user's real wall clock is ahead of the game's at `timestamp`. This is
-- the DST hour when the game's TimeToDate ignores daylight saving. Resolved per
-- timestamp (not once for "now") so a time past the next clock change gets the
-- offset that applies on that date. With os.date it is detected; without it the
-- manual DSToffset setting is the only signal.
local function userClockLead(timestamp, gameDays, gameSecond)
    if os ~= nil and type(os.date) == "function" then
        local ok, osDate = pcall(os.date, "*t", math.floor(timestamp))
        if ok then
            local osDays, osSecond = dateTableToDaySecond(osDate)
            if osDays ~= nil then
                local lead = ((osDays - gameDays) * SECONDS_PER_DAY) + (osSecond - gameSecond)
                lead = math.floor((lead / DST_ROUNDING_SECONDS) + 0.5) * DST_ROUNDING_SECONDS
                if math.abs(lead) <= MAX_DST_LEAD_SECONDS then
                    return lead
                end
                return 0
            end
        end
    end
    if settingsModule.Get("DSToffset") == true then
        return 3600
    end
    return 0
end

-- (days, secondOfDay) on the user's clock for a unix timestamp, or nil.
local function userClockDaySecond(timestamp)
    local gameDays, gameSecond = gameDaySecond(timestamp)
    if gameDays == nil then
        return nil
    end
    local shifted = gameSecond + userClockLead(timestamp, gameDays, gameSecond)
    local dayShift = math.floor(shifted / SECONDS_PER_DAY)
    return gameDays + dayShift, shifted - (dayShift * SECONDS_PER_DAY)
end

local function userClockParts(timestamp)
    local days, second = userClockDaySecond(timestamp)
    if days == nil then
        return nil
    end
    local year, month, day = daysToDate(days)
    local hour = math.floor(second / 3600)
    local min = math.floor((second % 3600) / 60)
    return year, month, day, hour, min, second % 60
end

-- Unix timestamp whose user-clock reading is (userDays, userSecond). Works in seconds
-- relative to today so every step is small and exact; only the final add is rounded.
-- Iterates because the game/user offsets depend on the answer when a clock change
-- sits between now and the target.
local function userClockToTimestamp(userDays, userSecond)
    local now = tonumber(datetime.GetCurrentTimestamp())
    if now == nil then
        return nil, "Current time is unavailable."
    end
    now = math.floor(now)
    local baseDay = math.floor(now / SECONDS_PER_DAY)
    local baseSeconds = baseDay * SECONDS_PER_DAY
    local userRelative = ((userDays - baseDay) * SECONDS_PER_DAY) + userSecond

    -- user clock minus unix time, relative to baseSeconds, at `timestamp`
    local function offsetAt(timestamp)
        local gameDays, gameSecond = gameDaySecond(timestamp)
        if gameDays == nil then
            return nil
        end
        local gameRelative = ((gameDays - baseDay) * SECONDS_PER_DAY) + gameSecond
        return gameRelative - (timestamp - baseSeconds) + userClockLead(timestamp, gameDays, gameSecond)
    end

    local offset = offsetAt(now)
    if offset == nil then
        return nil, "Game clock is unavailable."
    end
    local relative = userRelative - offset
    for _ = 1, 4 do
        local nextOffset = offsetAt(baseSeconds + relative)
        if nextOffset == nil then
            break
        end
        local refined = userRelative - nextOffset
        if refined == relative then
            break
        end
        relative = refined
    end
    return baseSeconds + relative
end

function datetime.FormatTimestampToDateTime(timestamp)
    local numericTimestamp = datetime.NormalizeUnixTime(timestamp)
    log.DevLog("FormatTimestampToDateTime called with timestamp: " .. tostring(numericTimestamp or timestamp))
    if numericTimestamp == nil then
        return "Invalid Timestamp"
    end
    local year, month, day, hour, min, sec = userClockParts(numericTimestamp)
    if year == nil then
        log.DevLog("FormatTimestampToDateTime: TimeToDate failed for " .. tostring(numericTimestamp))
        return "Invalid Date"
    end
    return string.format("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, min, sec)
end

-- Short real-world (user clock) reading of a unix timestamp, e.g. "20:30 02-11", or nil.
function datetime.FormatUserClockShort(timestamp)
    local numericTimestamp = datetime.NormalizeUnixTime(timestamp)
    if numericTimestamp == nil then
        return nil
    end
    local _, month, day, hour, min = userClockParts(numericTimestamp)
    if month == nil then
        log.DevLog("FormatUserClockShort: no date for " .. tostring(numericTimestamp))
        return nil
    end
    return string.format("%02d:%02d %02d-%02d", hour, min, day, month)
end

function datetime.TimeRemaining(futureTimestamp)
    local remainingSeconds = datetime.SecondsUntil(futureTimestamp)
    if remainingSeconds == nil then
        return "Unknown"
    end
    if remainingSeconds <= 0 then
        return "Now/Passed"
    end
    remainingSeconds = math.floor(remainingSeconds + 0.5)
    local hours, mins, secs = datetime.SecondsToTime(remainingSeconds)
    if hours > 0 then
        -- seconds are noise at this range
        return string.format("%d hours & %d mins", hours, mins)
    end
    if mins > 0 then
        return string.format("%d mins & %d secs", mins, secs)
    end
    return string.format("%d secs", secs)
end

function datetime.getTodayDateText()
    local now = tonumber(datetime.GetCurrentTimestamp())
    if now == nil then
        log.DevLog("getTodayDateText: current time is unavailable")
        return "DD-MM-YYYY"
    end
    local year, month, day = userClockParts(math.floor(now))
    if year == nil or month == nil or day == nil then
        log.DevLog("getTodayDateText: Unable to get date table from local time")
        return "DD-MM-YYYY"
    end

    return formatTwoDigits(day) .. "-" .. formatTwoDigits(month) .. "-" .. tostring(year)
end

-- Turns the date/time the user typed (their own clock) into unix seconds.
function datetime.ParseDateTimeToUnixtime(dateText, timeText)
    if type(dateText) ~= "string" or type(timeText) ~= "string" then
        return nil, "Date and time are required."
    end

    local trimmedDate = dateText:match("^%s*(.-)%s*$")
    local trimmedTime = timeText:match("^%s*(.-)%s*$")
    if trimmedDate == "" or trimmedTime == "" then
        return nil, "Date and time are required."
    end

    local year, month, day = trimmedDate:match("^(%d%d%d%d)%D(%d%d?)%D(%d%d?)$")
    if year == nil then
        day, month, year = trimmedDate:match("^(%d%d?)%D(%d%d?)%D(%d%d%d%d)$")
    end
    if year == nil then
        return nil, "Date format must be YYYY-MM-DD or DD-MM-YYYY."
    end

    local hour, min, sec = trimmedTime:match("^(%d%d?):(%d%d?):(%d%d?)$")
    if hour == nil then
        hour, min = trimmedTime:match("^(%d%d?):(%d%d?)$")
        sec = 0
    end
    if hour == nil then
        return nil, "Time format must be HH:MM or HH:MM:SS."
    end

    local userDays, userSecond = dateTimeToDaySecond(year, month, day, hour, min, sec)
    if userDays == nil then
        return nil, userSecond
    end

    local timestamp, convertError = userClockToTimestamp(userDays, userSecond)
    if timestamp == nil then
        return nil, convertError
    end
    timestamp = datetime.NormalizeUnixTime(timestamp)
    if timestamp == nil then
        return nil, "Date and time could not be converted."
    end
    return timestamp
end

return datetime
