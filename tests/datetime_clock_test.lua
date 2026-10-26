-- helpers/datetime.lua: NormalizeUnixTime, the interpolated clock, SecondsUntil.
return function(t, env)
    local NOW = 1700000000

    local function load(apiOpts)
        local api = env.reset(apiOpts or { now = NOW })
        return env.require("helpers/datetime"), api
    end

    t.test("NormalizeUnixTime floors numbers and numeric strings", function()
        local datetime = load()
        t.eq(datetime.NormalizeUnixTime(1700000000), 1700000000)
        t.eq(datetime.NormalizeUnixTime(1700000000.9), 1700000000)
        t.eq(datetime.NormalizeUnixTime("1700000000"), 1700000000)
    end)

    t.test("NormalizeUnixTime scales milliseconds to seconds", function()
        local datetime = load()
        t.eq(datetime.NormalizeUnixTime(1700000000123), 1700000000)
    end)

    t.test("NormalizeUnixTime rejects unusable values", function()
        local datetime = load()
        t.isnil(datetime.NormalizeUnixTime(nil))
        t.isnil(datetime.NormalizeUnixTime("abc"))
        t.isnil(datetime.NormalizeUnixTime({}))
        t.isnil(datetime.NormalizeUnixTime(0 / 0))
        t.isnil(datetime.NormalizeUnixTime(math.huge))
        t.isnil(datetime.NormalizeUnixTime(-math.huge))
    end)

    t.test("SerializeUnixTime writes whole seconds as a digit string", function()
        local datetime = load()
        t.eq(datetime.SerializeUnixTime(1792990000.75), "1792990000")
        t.eq(datetime.SerializeUnixTime("1792990000"), "1792990000")
        t.isnil(datetime.SerializeUnixTime(nil))
        t.isnil(datetime.SerializeUnixTime("abc"))
    end)

    t.test("SecondsToTime splits hours, minutes, seconds", function()
        local datetime = load()
        local h, m, s = datetime.SecondsToTime(3661)
        t.eq(h, 1)
        t.eq(m, 1)
        t.eq(s, 1)
    end)

    t.test("GetCurrentTimestampText passes engine digits through untouched", function()
        env.withEngineNumbers(function()
            local datetime = load({ now = "1792990123" })
            t.eq(datetime.GetCurrentTimestampText(), "1792990123")
        end)
    end)

    t.test("GetCurrentTimestampText trims whitespace and a zero fraction", function()
        for _, raw in ipairs({ " 1792990123 ", "1792990123.0", "1792990123." }) do
            local datetime = load({ now = raw })
            t.eq(datetime.GetCurrentTimestampText(), "1792990123", "clock " .. raw)
        end
    end)

    t.test("GetCurrentTimestampText scales millisecond text to seconds", function()
        local datetime = load({ now = "1792990123456" })
        t.eq(datetime.GetCurrentTimestampText(), "1792990123")
    end)

    t.test("GetCurrentTimestampText reads a non-string value by its tostring", function()
        local raw = setmetatable({}, { __tostring = function() return "1792990123" end })
        local datetime = load({ now = raw })
        t.eq(datetime.GetCurrentTimestampText(), "1792990123")
    end)

    t.test("GetCurrentTimestampText falls back to the clock for a plain number", function()
        local datetime = load({ now = NOW })
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(750)
        t.eq(datetime.GetCurrentTimestampText(), "1700000000")
    end)

    t.test("GetCurrentTimestampText is nil when the clock is unusable", function()
        for _, bad in ipairs({ "abc", {}, false }) do
            local datetime = load({ now = bad })
            t.isnil(datetime.GetCurrentTimestampText(), "clock " .. tostring(bad))
        end
    end)

    t.test("GetCurrentTimestamp returns GetLocalTime", function()
        local datetime = load()
        t.eq(datetime.GetCurrentTimestamp(), NOW)
    end)

    t.test("GetCurrentTimestamp accepts a numeric string from the engine", function()
        local datetime = load({ now = "1700000000" })
        t.eq(datetime.GetCurrentTimestamp(), NOW)
    end)

    t.test("GetCurrentTimestamp scales a millisecond clock", function()
        local datetime = load({ now = NOW * 1000 })
        t.eq(datetime.GetCurrentTimestamp(), NOW)
    end)

    t.test("GetCurrentTimestamp is nil when the clock is unusable", function()
        for _, bad in ipairs({ "abc", {}, false }) do
            local datetime = load({ now = bad })
            t.isnil(datetime.GetCurrentTimestamp(), "clock " .. tostring(bad))
            t.isnil(datetime.SecondsUntil(NOW + 5))
        end
    end)

    t.test("GetCurrentTimestamp is nil when GetLocalTime returns nothing", function()
        local datetime = load({ now = nil })
        t.isnil(datetime.GetCurrentTimestamp())
    end)

    t.test("SecondsUntil counts down to a future time", function()
        local datetime = load()
        t.eq(datetime.SecondsUntil(NOW + 100), 100)
        t.eq(datetime.SecondsUntil(NOW - 20), -20)
    end)

    t.test("SecondsUntil rejects a non-numeric target", function()
        local datetime = load()
        t.isnil(datetime.SecondsUntil(nil))
        t.isnil(datetime.SecondsUntil("soon"))
    end)

    t.test("AdvanceCurrentTimestamp interpolates between whole-second polls", function()
        local datetime = load()
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(500)
        t.near(datetime.SecondsUntil(NOW + 100), 99.5, 1e-9)
        datetime.AdvanceCurrentTimestamp(250)
        t.near(datetime.SecondsUntil(NOW + 100), 99.25, 1e-9)
    end)

    t.test("AdvanceCurrentTimestamp ignores zero, negative and bad deltas", function()
        local datetime = load()
        datetime.AdvanceCurrentTimestamp(0)
        datetime.AdvanceCurrentTimestamp(-50)
        datetime.AdvanceCurrentTimestamp(nil)
        datetime.AdvanceCurrentTimestamp("x")
        t.eq(datetime.SecondsUntil(NOW + 10), 10)
    end)

    t.test("a newer GetLocalTime tick replaces the interpolation", function()
        local datetime, api = load()
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(500)
        api._now = NOW + 1
        t.eq(datetime.SecondsUntil(NOW + 100), 99)
    end)

    t.test("a GetLocalTime that lags a few seconds does not rewind the clock", function()
        local datetime = load()
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(2500)
        t.near(datetime.SecondsUntil(NOW + 100), 97.5, 1e-9)
    end)

    t.test("a backward clock step (DST fall-back) resyncs instead of sticking ahead", function()
        local datetime, api = load()
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(1000)
        api._now = NOW - 3600
        t.eq(datetime.SecondsUntil(NOW + 100), 3700)
        -- and it keeps tracking from the new base
        api._now = NOW - 3599
        t.eq(datetime.SecondsUntil(NOW + 100), 3699)
    end)

    t.test("a forward clock step (DST spring-forward) is adopted immediately", function()
        local datetime, api = load()
        datetime.GetCurrentTimestamp()
        api._now = NOW + 3600
        t.eq(datetime.SecondsUntil(NOW + 4000), 400)
    end)

    t.test("a long frame hitch does not leave the clock permanently ahead", function()
        local datetime, api = load()
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(120000) -- 2 minutes of dt, clock barely moved
        api._now = NOW + 1
        t.eq(datetime.SecondsUntil(NOW + 100), 99)
    end)

    t.test("SecondsUntil stays exact at full 1.8e9 magnitudes", function()
        local big = 1792960000
        local datetime = load({ now = big })
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(500)
        t.near(datetime.SecondsUntil(big + 1000), 999.5, 1e-9)
    end)
end
