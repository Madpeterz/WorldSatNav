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

-- Zones a player can pick (TimeZone setting) instead of trusting the game clock.
-- offset is standard time in seconds east of UTC; dst names a rule in DST_RULES.
-- "auto" has no offset: it reads the game clock and corrects it via os.date.
local TIME_ZONE_AUTO = "auto"
local TIME_ZONES = {
    { id = TIME_ZONE_AUTO, label = "Auto (game clock)" },
    { id = "US_Pacific", label = "UTC-8 US Pacific (PST/PDT)", offset = -8 * 3600, dst = "us" },
    { id = "US_Mountain", label = "UTC-7 US Mountain (MST/MDT)", offset = -7 * 3600, dst = "us" },
    { id = "US_Arizona", label = "UTC-7 Arizona (MST)", offset = -7 * 3600 },
    { id = "US_Central", label = "UTC-6 US Central (CST/CDT)", offset = -6 * 3600, dst = "us" },
    { id = "US_Eastern", label = "UTC-5 US Eastern (EST/EDT)", offset = -5 * 3600, dst = "us" },
    { id = "Brazil", label = "UTC-3 Brazil (BRT)", offset = -3 * 3600 },
    { id = "UTC", label = "UTC", offset = 0 },
    { id = "UK", label = "UTC+0 UK / Ireland (GMT/BST)", offset = 0, dst = "eu" },
    { id = "EU_Central", label = "UTC+1 Central Europe (CET/CEST)", offset = 3600, dst = "eu" },
    { id = "EU_Eastern", label = "UTC+2 Eastern Europe (EET/EEST)", offset = 2 * 3600, dst = "eu" },
    { id = "Moscow", label = "UTC+3 Moscow (MSK)", offset = 3 * 3600 },
    { id = "Gulf", label = "UTC+4 Gulf (GST)", offset = 4 * 3600 },
    { id = "India", label = "UTC+5:30 India (IST)", offset = 5 * 3600 + 1800 },
    { id = "China", label = "UTC+8 China / Singapore", offset = 8 * 3600 },
    { id = "Japan", label = "UTC+9 Japan / Korea", offset = 9 * 3600 },
    { id = "AU_Eastern", label = "UTC+10 Sydney (AEST/AEDT)", offset = 10 * 3600, dst = "au" },
}

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

-- Whole unix seconds as a digit string, or nil. api.File:Write formats numbers with
-- %g (e.g. 1.79299e+009), which drops digits, so timestamps are written as strings.
function datetime.SerializeUnixTime(value)
    local seconds = datetime.NormalizeUnixTime(value)
    if seconds == nil then
        return nil
    end
    return string.format("%.0f", seconds)
end

-- GetLocalTime as exact unix-seconds text, or nil. The engine hands GetLocalTime over
-- with every digit intact, but turning it into a number rounds it to 128s steps, so the
-- digits are passed through as-is when they can be. Falls back to the clock otherwise.
function datetime.GetCurrentTimestampText()
    local rawLocalTime = api.Time:GetLocalTime()
    if rawLocalTime ~= nil and type(rawLocalTime) ~= "number" then
        local digits = tostring(rawLocalTime):match("^%s*(%d+)%.?0*%s*$")
        if digits ~= nil then
            -- Same cut-off as MILLISECOND_THRESHOLD (1e11 has 12 digits).
            if #digits >= 12 then
                digits = digits:sub(1, -4)
            end
            return digits
        end
    end
    return datetime.SerializeUnixTime(datetime.GetCurrentTimestamp())
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

-- Moves whole days out of (or into) `second` so it ends up in [0, 86400).
local function normalizeDaySecond(days, second)
    local dayShift = math.floor(second / SECONDS_PER_DAY)
    return days + dayShift, second - (dayShift * SECONDS_PER_DAY)
end

-- (days, secondOfDay) in UTC for unix seconds given as a number or a digit string. A
-- string is long-divided digit by digit, so GetCurrentTimestampText's exact digits
-- never pass through a unix-sized number.
local function utcDaySecond(timestamp)
    if type(timestamp) == "string" then
        local days, remainder = 0, 0
        for digit in timestamp:gmatch("%d") do
            remainder = (remainder * 10) + tonumber(digit)
            days = (days * 10) + math.floor(remainder / SECONDS_PER_DAY)
            remainder = remainder % SECONDS_PER_DAY
        end
        return days, remainder
    end
    local days = math.floor(timestamp / SECONDS_PER_DAY)
    return days, math.floor(timestamp - (days * SECONDS_PER_DAY))
end

local function isBefore(days, second, otherDays, otherSecond)
    return days < otherDays or (days == otherDays and second < otherSecond)
end

-- Day count of the nth Sunday (n = -1: the last one) of a month.
local function sundayOfMonth(year, month, n)
    if n < 0 then
        local lastDay = dateTimeToDaySecond(year, month, daysInMonth(year, month))
        return lastDay - ((lastDay + 4) % 7) -- 1970-01-01 was a Thursday
    end
    local firstDay = dateTimeToDaySecond(year, month, 1)
    return firstDay + ((7 - ((firstDay + 4) % 7)) % 7) + ((n - 1) * 7)
end

-- year, standard offset -> UTC (day, second) daylight saving starts, then ends.
local DST_RULES = {
    -- last Sunday of March to last Sunday of October, both at 01:00 UTC
    eu = function(year)
        return sundayOfMonth(year, 3, -1), 3600, sundayOfMonth(year, 10, -1), 3600
    end,
    -- second Sunday of March 02:00 standard to first Sunday of November 02:00 daylight
    us = function(year, offset)
        local startDay, startSecond = normalizeDaySecond(sundayOfMonth(year, 3, 2), 7200 - offset)
        local endDay, endSecond = normalizeDaySecond(sundayOfMonth(year, 11, 1), 7200 - offset - 3600)
        return startDay, startSecond, endDay, endSecond
    end,
    -- first Sunday of October 02:00 standard to first Sunday of April 03:00 daylight
    au = function(year, offset)
        local startDay, startSecond = normalizeDaySecond(sundayOfMonth(year, 10, 1), 7200 - offset)
        local endDay, endSecond = normalizeDaySecond(sundayOfMonth(year, 4, 1), 10800 - offset - 3600)
        return startDay, startSecond, endDay, endSecond
    end,
}

-- Seconds `zone` is ahead of UTC at the UTC reading (utcDays, utcSecond).
local function timeZoneOffset(zone, utcDays, utcSecond)
    local rule = DST_RULES[zone.dst]
    if rule == nil then
        return zone.offset
    end
    local startDay, startSecond, endDay, endSecond = rule(daysToDate(utcDays), zone.offset)
    local afterStart = not isBefore(utcDays, utcSecond, startDay, startSecond)
    local beforeEnd = isBefore(utcDays, utcSecond, endDay, endSecond)
    local inDst
    if isBefore(startDay, startSecond, endDay, endSecond) then
        inDst = afterStart and beforeEnd
    else
        -- southern hemisphere: daylight time spans the new year
        inDst = afterStart or beforeEnd
    end
    if inDst then
        return zone.offset + 3600
    end
    return zone.offset
end

-- The picked zone, or nil for auto (and for an id this version does not know).
local function selectedTimeZone()
    local id = settingsModule.Get("TimeZone")
    for _, zone in ipairs(TIME_ZONES) do
        if zone.id == id and zone.offset ~= nil then
            return zone
        end
    end
    return nil
end

function datetime.GetTimeZoneLabels()
    local labels = {}
    for _, zone in ipairs(TIME_ZONES) do
        table.insert(labels, zone.label)
    end
    return labels
end

-- Label for a zone id; unknown ids read as auto, which is how they behave.
function datetime.GetTimeZoneLabel(id)
    for _, zone in ipairs(TIME_ZONES) do
        if zone.id == id then
            return zone.label
        end
    end
    return TIME_ZONES[1].label
end

function datetime.GetTimeZoneId(label)
    for _, zone in ipairs(TIME_ZONES) do
        if zone.label == label then
            return zone.id
        end
    end
    return nil
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
-- corrects it via os.date when that exists.
local function gameDaySecond(timestamp)
    local days, second = dateTableToDaySecond(timeToDateTable(timestamp))
    if days ~= nil then
        return days, second
    end
    if not loggedDateFallback then
        loggedDateFallback = true
        log.DevLog("TimeToDate unusable for " .. tostring(timestamp) .. ", treating GetLocalTime as wall-clock seconds; os available: " .. tostring(os ~= nil and type(os.date) == "function"))
    end
    return utcDaySecond(timestamp)
end

-- Seconds the user's real wall clock is ahead of the game's at `timestamp`. This is
-- the DST hour when the game's TimeToDate ignores daylight saving. Resolved per
-- timestamp (not once for "now") so a time past the next clock change gets the
-- offset that applies on that date. Needs os.date; without it the player has to pick
-- a time zone instead of auto.
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
    return 0
end

-- Seconds the user's clock is ahead of UTC at `timestamp`: the picked zone's offset,
-- or for auto the game clock's offset plus the os.date lead. Game and UTC readings
-- come from the same (possibly rounded) number, so their difference stays exact.
local function userClockOffset(timestamp)
    local utcDays, utcSecond = utcDaySecond(timestamp)
    local zone = selectedTimeZone()
    if zone ~= nil then
        return timeZoneOffset(zone, utcDays, utcSecond)
    end
    local gameDays, gameSecond = gameDaySecond(timestamp)
    local gameOffset = ((gameDays - utcDays) * SECONDS_PER_DAY) + (gameSecond - utcSecond)
    return gameOffset + userClockLead(timestamp, gameDays, gameSecond)
end

-- (days, secondOfDay) on the user's clock `delta` seconds after unix seconds `timestamp`
-- (number or digit string). The delta is added on the small day/second pair.
local function userClockDaySecondAfter(timestamp, delta)
    local days, second = utcDaySecond(timestamp)
    days, second = normalizeDaySecond(days, second + delta)
    return normalizeDaySecond(days, second + userClockOffset(tonumber(timestamp) + delta))
end

local function userClockDaySecond(timestamp)
    return userClockDaySecondAfter(timestamp, 0)
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
-- Iterates because the user's offset depends on the answer when a clock change sits
-- between now and the target.
local function userClockToTimestamp(userDays, userSecond)
    local now = tonumber(datetime.GetCurrentTimestamp())
    if now == nil then
        return nil, "Current time is unavailable."
    end
    now = math.floor(now)
    local baseDay = math.floor(now / SECONDS_PER_DAY)
    local baseSeconds = baseDay * SECONDS_PER_DAY
    local userRelative = ((userDays - baseDay) * SECONDS_PER_DAY) + userSecond

    local relative = userRelative - userClockOffset(now)
    for _ = 1, 4 do
        local refined = userRelative - userClockOffset(baseSeconds + relative)
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

-- Digit strings (GetCurrentTimestampText) are kept as text so they stay exact.
local function clockInput(timestamp)
    if type(timestamp) == "string" and timestamp:match("^%d+$") then
        return timestamp
    end
    return datetime.NormalizeUnixTime(timestamp)
end

local function formatClock(days, second)
    local year, month, day = daysToDate(days)
    return string.format("%02d:%02d %02d-%02d-%04d", math.floor(second / 3600), math.floor((second % 3600) / 60), day, month, year)
end

-- "HH:MM DD-MM-YYYY" in UTC for unix seconds or a timestamp digit string, or nil.
function datetime.FormatUtcClock(timestamp)
    local input = clockInput(timestamp)
    if input == nil then
        return nil
    end
    return formatClock(utcDaySecond(input))
end

-- Same as FormatUtcClock, on the user's clock (picked time zone, or auto).
function datetime.FormatUserClock(timestamp)
    local input = clockInput(timestamp)
    if input == nil then
        return nil
    end
    return formatClock(userClockDaySecond(input))
end

-- "DD-MM-YYYY at HH:MM" on the user's clock `secondsAhead` after `now` (unix seconds
-- or a timestamp digit string), or nil.
function datetime.FormatUserDateAt(now, secondsAhead)
    local input = clockInput(now)
    if input == nil or tonumber(secondsAhead) == nil then
        return nil
    end
    local days, second = userClockDaySecondAfter(input, secondsAhead)
    local year, month, day = daysToDate(days)
    return string.format("%02d-%02d-%04d at %02d:%02d", day, month, year, math.floor(second / 3600), math.floor((second % 3600) / 60))
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
    local days = math.floor(hours / 24)
    if days > 0 then
        -- minutes are noise at this range
        hours = hours - (days * 24)
        return string.format("%d %s & %d %s", days, days == 1 and "day" or "days", hours, hours == 1 and "hour" or "hours")
    end
    if hours > 0 then
        -- seconds are noise at this range
        return string.format("%d %s & %d mins", hours, hours == 1 and "hour" or "hours", mins)
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
