-- helpers/datetime.lua: display side (FormatTimestampToDateTime, FormatUserClockShort,
-- getTodayDateText, TimeRemaining) and parse/format round trips.
return function(t, env)
    local utc = env.utc

    local function load(now, opts)
        opts = opts or {}
        local api = env.reset({ now = now, gameZone = opts.gameZone, settings = opts.settings })
        env.setUserZone(opts.userZone == nil and env.fixedZone(0) or opts.userZone)
        return env.require("helpers/datetime"), api
    end

    local GAME_CET = env.fixedZone(3600)
    local USER_CET = env.euZone(3600)

    t.test("FormatTimestampToDateTime formats the user clock", function()
        local datetime = load(utc(2026, 10, 25, 12, 0, 0))
        t.eq(datetime.FormatTimestampToDateTime(utc(2026, 10, 25, 20, 30, 15)), "2026-10-25 20:30:15")
    end)

    t.test("FormatTimestampToDateTime pads single digits", function()
        local datetime = load(utc(2026, 1, 1, 0, 0, 0))
        t.eq(datetime.FormatTimestampToDateTime(utc(2026, 2, 3, 4, 5, 6)), "2026-02-03 04:05:06")
    end)

    t.test("FormatTimestampToDateTime applies the DST gap between game and user clock", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        -- 18:00 UTC: game shows 19:00, the user's CEST clock shows 20:00
        t.eq(datetime.FormatTimestampToDateTime(utc(2026, 7, 1, 18, 0, 0)), "2026-07-01 20:00:00")
        -- winter: both show 19:00
        t.eq(datetime.FormatTimestampToDateTime(utc(2026, 12, 1, 18, 0, 0)), "2026-12-01 19:00:00")
    end)

    t.test("FormatTimestampToDateTime rejects unusable input", function()
        local datetime = load(utc(2026, 1, 1, 0, 0, 0))
        t.eq(datetime.FormatTimestampToDateTime(nil), "Invalid Timestamp")
        t.eq(datetime.FormatTimestampToDateTime("abc"), "Invalid Timestamp")
    end)

    t.test("FormatUserClockShort gives HH:MM DD-MM", function()
        local datetime = load(utc(2026, 10, 25, 12, 0, 0))
        t.eq(datetime.FormatUserClockShort(utc(2026, 11, 2, 20, 30, 59)), "20:30 02-11")
    end)

    t.test("FormatUserClockShort rolls the date over with the DST gap", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        -- 22:30 UTC -> game 23:30 -> user 00:30 the next day
        t.eq(datetime.FormatUserClockShort(utc(2026, 7, 1, 22, 30, 0)), "00:30 02-07")
    end)

    t.test("FormatUserClockShort is nil for bad input", function()
        local datetime = load(utc(2026, 1, 1, 0, 0, 0))
        t.isnil(datetime.FormatUserClockShort(nil))
        t.isnil(datetime.FormatUserClockShort("x"))
    end)

    t.test("getTodayDateText gives DD-MM-YYYY", function()
        local datetime = load(utc(2026, 10, 5, 12, 0, 0))
        t.eq(datetime.getTodayDateText(), "05-10-2026")
    end)

    t.test("getTodayDateText uses the user clock across midnight", function()
        local datetime = load(utc(2026, 7, 1, 22, 30, 0), { gameZone = GAME_CET, userZone = USER_CET })
        t.eq(datetime.getTodayDateText(), "02-07-2026")
    end)

    t.test("getTodayDateText has a placeholder when the clock is missing", function()
        local datetime = load(nil)
        t.eq(datetime.getTodayDateText(), "DD-MM-YYYY")
    end)

    t.test("TimeRemaining: hours drop the seconds", function()
        local now = utc(2026, 1, 1, 0, 0, 0)
        local datetime = load(now)
        t.eq(datetime.TimeRemaining(now + 3 * 3600 + 20 * 60 + 31), "3 hours & 20 mins")
        t.eq(datetime.TimeRemaining(now + 3600), "1 hour & 0 mins")
        t.eq(datetime.TimeRemaining(now + 23 * 3600 + 59 * 60 + 59), "23 hours & 59 mins")
    end)

    t.test("TimeRemaining: days and hours from a full day up", function()
        local now = utc(2026, 1, 1, 0, 0, 0)
        local datetime = load(now)
        t.eq(datetime.TimeRemaining(now + 86400), "1 day & 0 hours")
        t.eq(datetime.TimeRemaining(now + 86400 + 3600 + 59 * 60), "1 day & 1 hour")
        t.eq(datetime.TimeRemaining(now + 2 * 86400 + 3 * 3600 + 40), "2 days & 3 hours")
        t.eq(datetime.TimeRemaining(now + 10 * 86400 + 23 * 3600), "10 days & 23 hours")
    end)

    t.test("TimeRemaining: minutes and seconds under an hour", function()
        local now = utc(2026, 1, 1, 0, 0, 0)
        local datetime = load(now)
        t.eq(datetime.TimeRemaining(now + 22 * 60 + 40), "22 mins & 40 secs")
        t.eq(datetime.TimeRemaining(now + 3599), "59 mins & 59 secs")
    end)

    t.test("TimeRemaining: seconds only under a minute", function()
        local now = utc(2026, 1, 1, 0, 0, 0)
        local datetime = load(now)
        t.eq(datetime.TimeRemaining(now + 40), "40 secs")
    end)

    t.test("TimeRemaining is a single line", function()
        local now = utc(2026, 1, 1, 0, 0, 0)
        local datetime = load(now)
        for _, offset in ipairs({ 5, 700, 20000 }) do
            t.falsy(datetime.TimeRemaining(now + offset):find("[\r\n]"))
        end
    end)

    t.test("TimeRemaining: passed and unknown", function()
        local now = utc(2026, 1, 1, 0, 0, 0)
        local datetime = load(now)
        t.eq(datetime.TimeRemaining(now), "Now/Passed")
        t.eq(datetime.TimeRemaining(now - 5), "Now/Passed")
        t.eq(datetime.TimeRemaining(nil), "Unknown")
        local noClock = load(nil)
        t.eq(noClock.TimeRemaining(1700000000), "Unknown")
    end)

    t.test("parse and format round-trip across DST in both directions", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        local samples = {
            utc(2026, 7, 15, 8, 30, 0),   -- summer
            utc(2026, 12, 15, 8, 30, 0),  -- winter
            utc(2026, 10, 26, 11, 0, 0),  -- day after DST end
            utc(2027, 3, 30, 10, 0, 0),   -- day after the following DST start
            utc(2026, 7, 1, 22, 30, 0),   -- crosses local midnight
        }
        for _, ts in ipairs(samples) do
            local text = datetime.FormatTimestampToDateTime(ts)
            local date, time = text:match("^(%d+%-%d+%-%d+) (%d+:%d+:%d+)$")
            t.truthy(date, "format " .. tostring(text))
            t.eq(datetime.ParseDateTimeToUnixtime(date, time), ts, "round trip of " .. text)
        end
    end)

    t.test("parse and format round-trip when TimeToDate is unavailable", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), { gameZone = false })
        local ts = utc(2026, 8, 9, 7, 6, 5)
        local text = datetime.FormatTimestampToDateTime(ts)
        t.eq(text, "2026-08-09 07:06:05")
        t.eq(datetime.ParseDateTimeToUnixtime("2026-08-09", "07:06:05"), ts)
    end)
end
