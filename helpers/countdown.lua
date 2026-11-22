local datetime = require("WorldSatNav/helpers/datetime")

-- Countdown maths for user timers.
--
-- Timers need to fire to the second, but this engine's Lua numbers only hold a unix
-- time in 128s steps (see helpers/datetime.lua), and the shared interpolated clock
-- built on those numbers can be a minute or more out. So a deadline never touches a
-- unix-sized number: it is an `anchor` (the game clock's exact digit text when it was
-- set) plus an `offset` in seconds. Time since the anchor is worked out digit-wise
-- (DigitsDifference), so it stays exact to the second.
local countdown = {}

local SECONDS_PER_MINUTE = 60
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400
-- Largest duration accepted from the form (offsets beyond 2^24 s stop being exact).
countdown.MAX_DURATION_SECONDS = 180 * SECONDS_PER_DAY

-- A whole number >= 0 from a text field. Blank counts as 0. Returns nil when invalid.
function countdown.ParseField(text)
    if text == nil then
        return 0
    end
    local trimmed = tostring(text):match("^%s*(.-)%s*$")
    if trimmed == "" then
        return 0
    end
    if not trimmed:match("^%d+$") then
        return nil
    end
    return tonumber(trimmed)
end

-- Total seconds for a days/hours/mins triple of text fields.
-- Returns seconds, or nil plus a message the player can act on.
function countdown.DurationFromFields(daysText, hoursText, minsText)
    local days = countdown.ParseField(daysText)
    local hours = countdown.ParseField(hoursText)
    local mins = countdown.ParseField(minsText)
    if days == nil or hours == nil or mins == nil then
        return nil, "days, hours and mins must be whole numbers"
    end
    local total = days * SECONDS_PER_DAY + hours * SECONDS_PER_HOUR + mins * SECONDS_PER_MINUTE
    if total <= 0 then
        return nil, "must be at least 1 minute"
    end
    if total > countdown.MAX_DURATION_SECONDS then
        return nil, "must be 180 days or less"
    end
    return total
end

-- Splits seconds into whole days, hours and minutes (seconds dropped).
function countdown.SplitDuration(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local days = math.floor(seconds / SECONDS_PER_DAY)
    local hours = math.floor((seconds % SECONDS_PER_DAY) / SECONDS_PER_HOUR)
    local mins = math.floor((seconds % SECONDS_PER_HOUR) / SECONDS_PER_MINUTE)
    return days, hours, mins
end

-- Short label for an interval, e.g. "1d 2h 30m", "45m".
function countdown.FormatInterval(seconds)
    local days, hours, mins = countdown.SplitDuration(seconds)
    local parts = {}
    if days > 0 then
        table.insert(parts, days .. "d")
    end
    if hours > 0 then
        table.insert(parts, hours .. "h")
    end
    if mins > 0 or #parts == 0 then
        table.insert(parts, mins .. "m")
    end
    return table.concat(parts, " ")
end

-- Seconds left until the next run of a repeating timer that is due now.
-- secondsLeft is the current (<= 0) value; stepping from the old due time instead of
-- from "now" keeps the schedule from drifting, and every run missed while offline is
-- skipped in one step. Returns a value > 0, or nil when everySeconds is not usable.
function countdown.NextRepeatSecondsLeft(secondsLeft, everySeconds)
    everySeconds = tonumber(everySeconds)
    secondsLeft = tonumber(secondsLeft)
    if everySeconds == nil or everySeconds <= 0 or secondsLeft == nil then
        return nil
    end
    if secondsLeft > 0 then
        return secondsLeft
    end
    local missed = math.floor(-secondsLeft / everySeconds)
    return secondsLeft + (missed + 1) * everySeconds
end

-- Whole-second difference a - b between two unix timestamp digit strings, done on
-- the low 6 digits and the rest separately so every number stays small and exact.
local LOW_DIGITS = 6
local LOW_SCALE = 1000000
local function splitDigits(text)
    local digits = type(text) == "string" and text:match("^(%d+)$") or nil
    if digits == nil then
        return nil, nil
    end
    local cut = #digits - LOW_DIGITS
    if cut <= 0 then
        return 0, tonumber(digits)
    end
    return tonumber(digits:sub(1, cut)), tonumber(digits:sub(cut + 1))
end

function countdown.DigitsDifference(aText, bText)
    local aHigh, aLow = splitDigits(aText)
    local bHigh, bLow = splitDigits(bText)
    if aHigh == nil or bHigh == nil then
        return nil
    end
    return (aHigh - bHigh) * LOW_SCALE + (aLow - bLow)
end

-- Current time as exact unix-seconds digits. The engine hands GetLocalTime over as
-- exact digits; going through a number would round it to 128s steps.
local function nowText()
    local text = datetime.GetCurrentTimestampText()
    if type(text) ~= "string" or not text:match("^%d+$") then
        return nil
    end
    return text
end

-- A deadline `secondsFromNow` ahead, or nil when the game clock is unavailable.
function countdown.NewDeadline(secondsFromNow)
    secondsFromNow = tonumber(secondsFromNow)
    local anchor = nowText()
    if secondsFromNow == nil or anchor == nil then
        return nil
    end
    return {
        anchor = anchor,
        offset = math.floor(secondsFromNow + 0.5),
    }
end

-- Seconds until the deadline (negative once passed), or nil without a usable clock.
function countdown.SecondsLeft(deadline)
    if type(deadline) ~= "table" then
        return nil
    end
    local now = nowText()
    if now == nil then
        return nil
    end
    local elapsed = countdown.DigitsDifference(now, deadline.anchor)
    if elapsed == nil then
        return nil
    end
    return (tonumber(deadline.offset) or 0) - elapsed
end

-- File form of a deadline. Both parts are text: api.File:Write prints numbers with %g,
-- which would drop digits from either one.
function countdown.SerializeDeadline(deadline)
    if type(deadline) ~= "table" then
        return nil, nil
    end
    local offset = tonumber(deadline.offset)
    if splitDigits(deadline.anchor) == nil or offset == nil then
        return nil, nil
    end
    return deadline.anchor, string.format("%d", math.floor(offset + 0.5))
end

function countdown.DeserializeDeadline(anchorText, offsetText)
    local offset = tonumber(offsetText)
    if type(anchorText) ~= "string" or splitDigits(anchorText) == nil or offset == nil then
        return nil
    end
    return { anchor = anchorText, offset = offset }
end

return countdown
