-- helpers/datetime.lua: ParseDateTimeToUnixtime (typed wall-clock -> unix seconds),
-- including DST handling and the TimeToDate / os.date fallbacks.
return function(t, env)
    local utc = env.utc

    -- Game frame and user zone are configurable per test.
    --   gameZone: offset function the game's TimeToDate uses (false = TimeToDate unusable)
    --   userZone: offset function behind os.date("*t") (nil = os.date missing)
    --   settings: addon settings table (DSToffset etc.)
    local function load(now, opts)
        opts = opts or {}
        local api = env.reset({ now = now, gameZone = opts.gameZone, settings = opts.settings })
        env.setUserZone(opts.userZone == nil and env.fixedZone(0) or opts.userZone)
        if opts.userZone == false then
            env.setUserZone(nil)
        end
        return env.require("helpers/datetime"), api
    end

    local NOW = utc(2023, 11, 14, 12, 0, 0)

    t.test("parses YYYY-MM-DD and HH:MM:SS", function()
        local datetime = load(NOW)
        t.eq(datetime.ParseDateTimeToUnixtime("2023-11-14", "22:13:20"), 1700000000)
    end)

    t.test("parses DD-MM-YYYY and HH:MM", function()
        local datetime = load(NOW)
        t.eq(datetime.ParseDateTimeToUnixtime("14-11-2023", "22:13"), 1700000000 - 20)
    end)

    t.test("accepts any non-digit separator and single-digit parts", function()
        local datetime = load(NOW)
        t.eq(datetime.ParseDateTimeToUnixtime("2023/11/4", "7:05"), utc(2023, 11, 4, 7, 5, 0))
        t.eq(datetime.ParseDateTimeToUnixtime("4.11.2023", "07:05:09"), utc(2023, 11, 4, 7, 5, 9))
    end)

    t.test("trims surrounding whitespace", function()
        local datetime = load(NOW)
        t.eq(datetime.ParseDateTimeToUnixtime("  2023-11-14 ", " 22:13:20 "), 1700000000)
    end)

    t.test("rejects missing or non-string input", function()
        local datetime = load(NOW)
        t.isnil(datetime.ParseDateTimeToUnixtime(nil, "10:00"))
        t.isnil(datetime.ParseDateTimeToUnixtime("2023-11-14", nil))
        t.isnil(datetime.ParseDateTimeToUnixtime(20231114, "10:00"))
        local _, err = datetime.ParseDateTimeToUnixtime("", "10:00")
        t.eq(err, "Date and time are required.")
        _, err = datetime.ParseDateTimeToUnixtime("2023-11-14", "   ")
        t.eq(err, "Date and time are required.")
    end)

    t.test("rejects badly formatted dates and times", function()
        local datetime = load(NOW)
        local _, err = datetime.ParseDateTimeToUnixtime("14 Nov 2023", "10:00")
        t.eq(err, "Date format must be YYYY-MM-DD or DD-MM-YYYY.")
        _, err = datetime.ParseDateTimeToUnixtime("23-11-14", "10:00")
        t.eq(err, "Date format must be YYYY-MM-DD or DD-MM-YYYY.")
        _, err = datetime.ParseDateTimeToUnixtime("2023-11-14", "1000")
        t.eq(err, "Time format must be HH:MM or HH:MM:SS.")
        _, err = datetime.ParseDateTimeToUnixtime("2023-11-14", "HH:MM")
        t.eq(err, "Time format must be HH:MM or HH:MM:SS.")
    end)

    t.test("rejects out-of-range fields", function()
        local datetime = load(NOW)
        local function errorFor(date, time)
            local ts, err = datetime.ParseDateTimeToUnixtime(date, time)
            t.isnil(ts, date .. " " .. time)
            return err
        end
        t.eq(errorFor("2023-13-01", "10:00"), "Month must be between 1 and 12.")
        t.eq(errorFor("2023-00-10", "10:00"), "Month must be between 1 and 12.")
        t.eq(errorFor("2023-04-31", "10:00"), "Day is out of range for the selected month.")
        t.eq(errorFor("2023-04-00", "10:00"), "Day is out of range for the selected month.")
        t.truthy(errorFor("2023-04-10", "24:00"):find("Hour must be between 0 and 23", 1, true))
        t.truthy(errorFor("2023-04-10", "12:60"):find("Minute must be between 0 and 59", 1, true))
        t.truthy(errorFor("2023-04-10", "12:30:60"):find("Second must be between 0 and 59", 1, true))
    end)

    t.test("leap days", function()
        local datetime = load(NOW)
        t.eq(datetime.ParseDateTimeToUnixtime("2028-02-29", "00:00"), utc(2028, 2, 29, 0, 0, 0))
        t.isnil(datetime.ParseDateTimeToUnixtime("2027-02-29", "00:00"))
        t.isnil(datetime.ParseDateTimeToUnixtime("2100-02-29", "00:00")) -- century, not a leap year
        t.eq(datetime.ParseDateTimeToUnixtime("2000-02-29", "00:00"), utc(2000, 2, 29, 0, 0, 0))
    end)

    t.test("midnight and end of day", function()
        local datetime = load(NOW)
        t.eq(datetime.ParseDateTimeToUnixtime("2026-12-31", "23:59:59"), utc(2026, 12, 31, 23, 59, 59))
        t.eq(datetime.ParseDateTimeToUnixtime("2027-01-01", "00:00"), utc(2027, 1, 1, 0, 0, 0))
    end)

    t.test("fails cleanly when there is no clock", function()
        local datetime = load(nil)
        local ts, err = datetime.ParseDateTimeToUnixtime("2023-11-14", "10:00")
        t.isnil(ts)
        t.eq(err, "Current time is unavailable.")
    end)

    -- A game whose clock ignores DST (fixed UTC+1) and a user in central Europe
    -- (CET/CEST). In summer the user's wall clock is one hour ahead of the game's.
    local GAME_CET = env.fixedZone(3600)
    local USER_CET = env.euZone(3600)

    t.test("DST is detected automatically when os.date exists (summer)", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        -- 20:00 CEST == 18:00 UTC
        t.eq(datetime.ParseDateTimeToUnixtime("2026-07-01", "20:00"), utc(2026, 7, 1, 18, 0, 0))
    end)

    t.test("no DST correction in winter", function()
        local datetime = load(utc(2026, 1, 10, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        -- 20:00 CET == 19:00 UTC
        t.eq(datetime.ParseDateTimeToUnixtime("2026-01-10", "20:00"), utc(2026, 1, 10, 19, 0, 0))
    end)

    t.test("a target after the DST end uses the winter offset even when 'now' is summer", function()
        -- Europe's clocks go back on 2026-10-25. Typed on the 20th for the 26th.
        local datetime = load(utc(2026, 10, 20, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        -- 12:00 CET on the 26th == 11:00 UTC
        t.eq(datetime.ParseDateTimeToUnixtime("2026-10-26", "12:00"), utc(2026, 10, 26, 11, 0, 0))
    end)

    t.test("a target after the DST start uses the summer offset even when 'now' is winter", function()
        -- Europe's clocks go forward on 2026-03-29.
        local datetime = load(utc(2026, 3, 20, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        -- 12:00 CEST on the 30th == 10:00 UTC
        t.eq(datetime.ParseDateTimeToUnixtime("2026-03-30", "12:00"), utc(2026, 3, 30, 10, 0, 0))
    end)

    t.test("a target before the DST end on the same day keeps the summer offset", function()
        local datetime = load(utc(2026, 10, 24, 10, 0, 0), { gameZone = GAME_CET, userZone = USER_CET })
        -- 01:30 CEST on the 25th (before the 03:00->02:00 change) == 23:30 UTC on the 24th
        t.eq(datetime.ParseDateTimeToUnixtime("2026-10-25", "01:30"), utc(2026, 10, 24, 23, 30, 0))
    end)

    t.test("a game clock that already follows DST needs no correction", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), { gameZone = USER_CET, userZone = USER_CET })
        t.eq(datetime.ParseDateTimeToUnixtime("2026-07-01", "20:00"), utc(2026, 7, 1, 18, 0, 0))
    end)

    t.test("a large user/game zone gap is not mistaken for DST", function()
        -- user is 5h ahead of the game; beyond the 1h DST window so ignored
        local datetime = load(NOW, { gameZone = env.fixedZone(0), userZone = env.fixedZone(5 * 3600) })
        t.eq(datetime.ParseDateTimeToUnixtime("2023-11-14", "20:00"), utc(2023, 11, 14, 20, 0, 0))
    end)

    t.test("falls back to the manual DSToffset setting when os.date is missing", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), {
            gameZone = env.fixedZone(0), userZone = false, settings = { DSToffset = true },
        })
        t.eq(datetime.ParseDateTimeToUnixtime("2026-07-01", "20:00"), utc(2026, 7, 1, 19, 0, 0))
    end)

    t.test("manual DSToffset off means no correction", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), {
            gameZone = env.fixedZone(0), userZone = false, settings = { DSToffset = false },
        })
        t.eq(datetime.ParseDateTimeToUnixtime("2026-07-01", "20:00"), utc(2026, 7, 1, 20, 0, 0))
    end)

    t.test("DSToffset defaults to off", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), { gameZone = env.fixedZone(0), userZone = false })
        t.eq(datetime.ParseDateTimeToUnixtime("2026-07-01", "20:00"), utc(2026, 7, 1, 20, 0, 0))
    end)

    t.test("manual DSToffset crossing midnight lands on the previous day", function()
        local datetime = load(utc(2026, 7, 1, 10, 0, 0), {
            gameZone = env.fixedZone(0), userZone = false, settings = { DSToffset = true },
        })
        t.eq(datetime.ParseDateTimeToUnixtime("2026-07-02", "00:30"), utc(2026, 7, 1, 23, 30, 0))
    end)

    t.test("game zone offset is honoured (typed time is on the game clock)", function()
        local datetime = load(utc(2026, 1, 10, 10, 0, 0), {
            gameZone = env.fixedZone(2 * 3600), userZone = env.fixedZone(2 * 3600),
        })
        t.eq(datetime.ParseDateTimeToUnixtime("2026-01-10", "20:00"), utc(2026, 1, 10, 18, 0, 0))
    end)

    t.test("falls back to treating GetLocalTime as wall-clock seconds when TimeToDate is nil", function()
        local datetime = load(utc(2026, 1, 10, 10, 0, 0), { gameZone = false })
        t.eq(datetime.ParseDateTimeToUnixtime("2026-01-10", "20:00"), utc(2026, 1, 10, 20, 0, 0))
    end)

    t.test("learns that TimeToDate wants milliseconds", function()
        local datetime, api = load(utc(2026, 1, 10, 10, 0, 0))
        api._timeToDate = function(timestamp)
            if timestamp < 1e11 then
                return nil
            end
            return os.date("!*t", timestamp / 1000)
        end
        t.eq(datetime.ParseDateTimeToUnixtime("2026-01-10", "20:00"), utc(2026, 1, 10, 20, 0, 0))
    end)

    t.test("accepts a TimeToDate table with minute/second field names and string values", function()
        local datetime, api = load(utc(2026, 1, 10, 10, 0, 0))
        api._timeToDate = function(timestamp)
            local d = env.utcFields(timestamp)
            return { year = tostring(d.year), month = tostring(d.month), day = tostring(d.day),
                     hour = tostring(d.hour), minute = tostring(d.min), second = tostring(d.sec) }
        end
        t.eq(datetime.ParseDateTimeToUnixtime("2026-01-10", "20:00"), utc(2026, 1, 10, 20, 0, 0))
    end)

    t.test("accepts a two-digit year and a zero-based tm_mon table", function()
        local datetime, api = load(utc(2026, 1, 10, 10, 0, 0))
        api._timeToDate = function(timestamp)
            local d = env.utcFields(timestamp)
            return { tm_year = d.year - 2000, tm_mon = d.month - 1, tm_mday = d.day,
                     tm_hour = d.hour, tm_min = d.min, tm_sec = d.sec }
        end
        t.eq(datetime.ParseDateTimeToUnixtime("2026-01-10", "20:00"), utc(2026, 1, 10, 20, 0, 0))
    end)

    t.test("result is always a whole number", function()
        local datetime = load(utc(2026, 1, 10, 10, 0, 0) + 0.7)
        local ts = datetime.ParseDateTimeToUnixtime("2026-01-10", "20:00:30")
        t.eq(ts, math.floor(ts))
    end)
end
