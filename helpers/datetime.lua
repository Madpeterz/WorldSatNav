local api = require("api")
local settingsModule = require("WorldSatNav/core/settings")
local log = require("WorldSatNav/helpers/log")

local datetime = {}

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

local calibratedTimeState = {
    lastKnownLocalTime = nil,
    lastReturnedTimestamp = nil,
}

function datetime.AdvanceCurrentTimestamp(dt)
    local deltaMsec = tonumber(dt)
    if deltaMsec == nil then
        return
    end

    if calibratedTimeState.lastReturnedTimestamp == nil then
        datetime.GetCurrentTimestamp()
    end

    if calibratedTimeState.lastReturnedTimestamp ~= nil and deltaMsec > 0 then
        calibratedTimeState.lastReturnedTimestamp = calibratedTimeState.lastReturnedTimestamp + (deltaMsec / 1000)
    end
end

function datetime.GetCurrentTimestamp()
    local localTime = api.Time:GetLocalTime()
    if type(localTime) == "number" then
        if calibratedTimeState.lastKnownLocalTime == nil or localTime > calibratedTimeState.lastKnownLocalTime then
            calibratedTimeState.lastKnownLocalTime = localTime
        end
        if calibratedTimeState.lastReturnedTimestamp == nil or localTime > calibratedTimeState.lastReturnedTimestamp then
            calibratedTimeState.lastReturnedTimestamp = localTime
        end
    end

    return calibratedTimeState.lastReturnedTimestamp or localTime
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

    if year ~= nil and year < 100 then
        year = year + 2000
    end
    if month ~= nil and month >= 0 and month <= 11 and dateValue.tm_mon ~= nil then
        month = month + 1
    end

    return year, month, day, hour, min, sec
end

local function unixToDateTable(timestamp)
    if os ~= nil and type(os.date) == "function" then
        local date = os.date("*t", timestamp)
        if type(date) == "table" then
            return {
                year = date.year,
                month = date.month,
                day = date.day,
                hour = date.hour,
                min = date.min,
                sec = date.sec,
            }
        end
    end

    local seconds = math.floor(timestamp)
    local days = math.floor(seconds / 86400)
    local rem = seconds - (days * 86400)
    local hour = math.floor(rem / 3600)
    rem = rem - (hour * 3600)
    local min = math.floor(rem / 60)
    local sec = rem - (min * 60)

    local function isLeapYear(value)
        if value % 400 == 0 then
            return true
        end
        if value % 100 == 0 then
            return false
        end
        return value % 4 == 0
    end

    local year = 1970
    while true do
        local daysInYear = isLeapYear(year) and 366 or 365
        if days < daysInYear then
            break
        end
        days = days - daysInYear
        year = year + 1
    end

    local daysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    if isLeapYear(year) then
        daysPerMonth[2] = 29
    end

    local month = 1
    while month <= 12 and days >= daysPerMonth[month] do
        days = days - daysPerMonth[month]
        month = month + 1
    end

    local day = days + 1

    return {
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
    }
end

function datetime.FormatTimestampToDateTime(timestamp)
    local numericTimestamp = tonumber(timestamp)
    log.DevLog("FormatTimestampToDateTime called with timestamp: " .. (numericTimestamp and string.format("%.0f", numericTimestamp) or tostring(timestamp)))
    if type(numericTimestamp) ~= "number" then
        return "Invalid Timestamp"
    end
    numericTimestamp = math.floor(numericTimestamp + 0.5)
    local dateTable = api.Time:TimeToDate(numericTimestamp)
    if dateTable == nil then
        dateTable = api.Time:TimeToDate(numericTimestamp * 1000)
    end
    if dateTable == nil then
        dateTable = api.Time:TimeToDate(numericTimestamp / 1000)
    end
    if dateTable == nil then
        local fallbackTimestamp = numericTimestamp
        if fallbackTimestamp > 100000000000 then
            fallbackTimestamp = math.floor((fallbackTimestamp / 1000) + 0.5)
        end
        dateTable = unixToDateTable(fallbackTimestamp)
    end
    if dateTable == nil then
        log.DevLog("FormatTimestampToDateTime: TimeToDate failed for " .. tostring(numericTimestamp))
        return "Invalid Date"
    end
    local year, month, day, hour, min, sec = extractDateParts(dateTable)
    if year == nil or month == nil or day == nil or hour == nil or min == nil or sec == nil then
        return "Invalid Date"
    end
    return string.format("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, min, sec)
end

function datetime.TimeRemaining(futureTimestamp, multilineOutput)
    multilineOutput = multilineOutput or false
    local currentTimestamp = datetime.GetCurrentTimestamp()
    local remainingSeconds = futureTimestamp - currentTimestamp
    if remainingSeconds <= 0 then
        return "Now/Passed"
    end
    remainingSeconds = math.floor(remainingSeconds + 0.5)
    local hours, mins, secs = datetime.SecondsToTime(remainingSeconds)
    if hours > 0 then
        if multilineOutput then
            return string.format("%d hours\n\r%d mins & %d secs", hours, mins, secs)
        end
        return string.format("%d hours, %d mins & %d secs", hours, mins, secs)
    end
    if mins > 0 then
        return string.format("%d mins & %d secs", mins, secs)
    end
    return string.format("%d secs", secs)
end

function datetime.getTodayDateText()
	local localTime = api.Time:GetLocalTime()
    local dateraw = api.Time:TimeToDate(localTime)
	if dateraw == nil then
        log.DevLog("getTodayDateText: Unable to get date table from local time, got: " .. type(dateraw))
        return "DD-MM-YYYY"
	end

    local year, month, day = extractDateParts(dateraw)
	if year == nil or month == nil or day == nil then
        return "DD-MM-YYYY"
	end

    return formatTwoDigits(day) .. "-" .. formatTwoDigits(month) .. "-" .. tostring(year)
end

local function dateTimeToUnixtimeUtcLike(year, month, day, hour, min, sec)
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

    local function isLeapYear(value)
        if value % 400 == 0 then
            return true
        end
        if value % 100 == 0 then
            return false
        end
        return value % 4 == 0
    end

    local daysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    local maxDay = daysPerMonth[month]
    if month == 2 and isLeapYear(year) then
        maxDay = 29
    end

    if day < 1 or day > maxDay then
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

    local daysSinceEpoch = 0
    if year >= 1970 then
        for currentYear = 1970, year - 1 do
            daysSinceEpoch = daysSinceEpoch + (isLeapYear(currentYear) and 366 or 365)
        end
    else
        for currentYear = 1969, year, -1 do
            daysSinceEpoch = daysSinceEpoch - (isLeapYear(currentYear) and 366 or 365)
        end
    end

    for currentMonth = 1, month - 1 do
        daysSinceEpoch = daysSinceEpoch + daysPerMonth[currentMonth]
        if currentMonth == 2 and isLeapYear(year) then
            daysSinceEpoch = daysSinceEpoch + 1
        end
    end

    daysSinceEpoch = daysSinceEpoch + (day - 1)

    return daysSinceEpoch * 86400 + hour * 3600 + min * 60 + sec
end

local function adjustDateByDays(year, month, day, deltaDays)
    local function isLeapYear(value)
        if value % 400 == 0 then
            return true
        end
        if value % 100 == 0 then
            return false
        end
        return value % 4 == 0
    end

    local function daysInMonth(y, m)
        local daysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
        if m == 2 and isLeapYear(y) then
            return 29
        end
        return daysPerMonth[m]
    end

    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    deltaDays = tonumber(deltaDays) or 0

    while deltaDays ~= 0 do
        if deltaDays > 0 then
            local dim = daysInMonth(year, month)
            if day < dim then
                day = day + 1
                deltaDays = deltaDays - 1
            else
                day = 1
                month = month + 1
                if month > 12 then
                    month = 1
                    year = year + 1
                end
                deltaDays = deltaDays - 1
            end
        else
            if day > 1 then
                day = day - 1
                deltaDays = deltaDays + 1
            else
                month = month - 1
                if month < 1 then
                    month = 12
                    year = year - 1
                end
                day = daysInMonth(year, month)
                deltaDays = deltaDays + 1
            end
        end
    end

    return year, month, day
end

local function dateTimeToLocalUnixtime(year, month, day, hour, min, sec)
    if os ~= nil and type(os.time) == "function" then
        local timestamp = os.time({
            year = year,
            month = month,
            day = day,
            hour = hour or 0,
            min = min or 0,
            sec = sec or 0,
        })
        if timestamp ~= nil then
            return timestamp
        end
    end

    local timestamp, errorMessage = dateTimeToUnixtimeUtcLike(year, month, day, hour, min, sec)
    if timestamp == nil then
        return nil, errorMessage
    end

    local now = datetime.GetCurrentTimestamp()
    if type(now) ~= "number" then
        return timestamp
    end

    local nowDate = api.Time:TimeToDate(now)
    local nowYear, nowMonth, nowDay, nowHour, nowMin, nowSec = extractDateParts(nowDate)
    if nowYear == nil or nowMonth == nil or nowDay == nil or nowHour == nil or nowMin == nil or nowSec == nil then
        return timestamp
    end

    local utcLikeNow = dateTimeToUnixtimeUtcLike(nowYear, nowMonth, nowDay, nowHour, nowMin, nowSec)
    if utcLikeNow == nil then
        return timestamp
    end

    return timestamp + (now - utcLikeNow)
end

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
    if settingsModule.Get("DSToffset") == true then
         hour = hour - 1
    end

    if hour < 0 or hour > 23 then
        local dayShift = math.floor(hour / 24)
        hour = hour - (dayShift * 24)
        year, month, day = adjustDateByDays(year, month, day, dayShift)
    end

    return dateTimeToLocalUnixtime(year, month, day, hour, min, sec)
end

return datetime
