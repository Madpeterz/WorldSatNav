-- helpers/countdown.lua: form parsing, repeat scheduling, drift-free deadlines.
return function(t, env)
    local NOW = 1792990123

    local function load(apiOpts)
        local api = env.reset(apiOpts or { now = NOW })
        return env.require("helpers/countdown"), env.require("helpers/datetime"), api
    end

    t.test("ParseField accepts blank as zero and whole numbers only", function()
        local countdown = load()
        t.eq(countdown.ParseField(nil), 0)
        t.eq(countdown.ParseField(""), 0)
        t.eq(countdown.ParseField("   "), 0)
        t.eq(countdown.ParseField(" 12 "), 12)
        t.isnil(countdown.ParseField("1.5"))
        t.isnil(countdown.ParseField("-1"))
        t.isnil(countdown.ParseField("abc"))
    end)

    t.test("DurationFromFields adds days, hours and mins", function()
        local countdown = load()
        t.eq(countdown.DurationFromFields("1", "2", "3"), 86400 + 7200 + 180)
        t.eq(countdown.DurationFromFields("", "", "90"), 5400)
    end)

    t.test("DurationFromFields rejects zero, bad and oversized input", function()
        local countdown = load()
        local seconds, err = countdown.DurationFromFields("", "0", "")
        t.isnil(seconds)
        t.truthy(err)
        t.isnil(countdown.DurationFromFields("x", "", ""))
        t.isnil(countdown.DurationFromFields("181", "", ""))
        t.eq(countdown.DurationFromFields("180", "", ""), 180 * 86400)
    end)

    t.test("FormatInterval drops empty parts", function()
        local countdown = load()
        t.eq(countdown.FormatInterval(86400 + 7200 + 180), "1d 2h 3m")
        t.eq(countdown.FormatInterval(2700), "45m")
        t.eq(countdown.FormatInterval(3600), "1h")
        t.eq(countdown.FormatInterval(0), "0m")
    end)

    t.test("NextRepeatSecondsLeft steps from the due time, not from now", function()
        local countdown = load()
        t.eq(countdown.NextRepeatSecondsLeft(0, 3600), 3600)
        t.eq(countdown.NextRepeatSecondsLeft(-10, 3600), 3590)
        t.eq(countdown.NextRepeatSecondsLeft(-3600, 3600), 3600)
    end)

    t.test("NextRepeatSecondsLeft skips runs missed while offline in one step", function()
        local countdown = load()
        -- Due 2h 1m 40s ago on an hourly timer: two runs missed, next is in 58m 20s.
        t.eq(countdown.NextRepeatSecondsLeft(-7300, 3600), 3500)
    end)

    t.test("NextRepeatSecondsLeft rejects a zero interval and keeps a future time", function()
        local countdown = load()
        t.isnil(countdown.NextRepeatSecondsLeft(-5, 0))
        t.isnil(countdown.NextRepeatSecondsLeft(-5, nil))
        t.eq(countdown.NextRepeatSecondsLeft(25, 3600), 25)
    end)

    t.test("a deadline counts down with the clock", function()
        local countdown, _, api = load()
        local deadline = countdown.NewDeadline(300)
        t.near(countdown.SecondsLeft(deadline), 300, 0.5)
        api._now = NOW + 100
        t.near(countdown.SecondsLeft(deadline), 200, 0.5)
        api._now = NOW + 350
        t.near(countdown.SecondsLeft(deadline), -50, 0.5)
    end)

    t.test("deadlines fire on the second whatever the engine's 128s rounding", function()
        -- Regression: the rounded number clock made timers fire up to ~1 min early/late.
        env.withEngineNumbers(function()
            for _, start in ipairs({ 1792990000, 1792990050, 1792990100, 1792990127 }) do
                local countdown, datetime, api = load({ now = tostring(start) })
                local deadline = countdown.NewDeadline(300)
                local firedAfter = nil
                for second = 1, 400 do
                    api._now = tostring(start + second)
                    datetime.AdvanceCurrentTimestamp(1000)
                    if firedAfter == nil and countdown.SecondsLeft(deadline) <= 0 then
                        firedAfter = second
                    end
                end
                t.eq(firedAfter, 300, "start " .. start)
            end
        end)
    end)

    t.test("a deadline survives a save and load", function()
        env.withEngineNumbers(function()
            local countdown, _, api = load({ now = tostring(NOW) })
            local deadline = countdown.NewDeadline(5 * 60)
            api._now = tostring(NOW + 20)
            local anchorText, offsetText = countdown.SerializeDeadline(deadline)
            t.eq(anchorText, tostring(NOW))
            t.eq(offsetText, "300")
            local loaded = countdown.DeserializeDeadline(anchorText, offsetText)
            t.eq(countdown.SecondsLeft(loaded), 280)
        end)
    end)

    t.test("DigitsDifference is exact across the low-digit boundary", function()
        env.withEngineNumbers(function()
            local countdown = load()
            t.eq(countdown.DigitsDifference("1792999999", "1792999998"), 1)
            t.eq(countdown.DigitsDifference("1793000001", "1792999999"), 2)
            t.eq(countdown.DigitsDifference("1792990123", "1793000123"), -10000)
            t.eq(countdown.DigitsDifference("123", "100"), 23)
            t.isnil(countdown.DigitsDifference("17929x0123", "1"))
            t.isnil(countdown.DigitsDifference(nil, "1"))
        end)
    end)

    t.test("no clock means no deadline", function()
        local countdown = load({ now = nil })
        t.isnil(countdown.NewDeadline(60))
        t.isnil(countdown.SecondsLeft(nil))
        t.isnil(countdown.DeserializeDeadline(nil, "5"))
        t.isnil(countdown.DeserializeDeadline("1792990123", "x"))
    end)

    t.test("FormatSecondsRemaining matches TimeRemaining wording", function()
        local _, datetime = load()
        t.eq(datetime.FormatSecondsRemaining(nil), "Unknown")
        t.eq(datetime.FormatSecondsRemaining(0), "Now/Passed")
        t.eq(datetime.FormatSecondsRemaining(90), "1 mins & 30 secs")
        t.eq(datetime.FormatSecondsRemaining(2 * 3600 + 300), "2 hours & 5 mins")
    end)

    t.test("FormatUserClockShortAt is exact to the minute on the user's clock", function()
        env.withEngineNumbers(function()
            local now = env.utc(2026, 11, 22, 10, 0, 0)
            local _, datetime = load({ now = tostring(now), settings = { TimeZone = "UTC" } })
            t.eq(datetime.FormatUserClockShortAt(tostring(now), 3600 + 59), "11:00 22-11")
            t.eq(datetime.FormatUserClockShortAt(tostring(now), 14 * 3600), "00:00 23-11")
            t.isnil(datetime.FormatUserClockShortAt("unknown", 0))
            t.isnil(datetime.FormatUserClockShortAt(tostring(now), nil))
        end)
    end)
end
