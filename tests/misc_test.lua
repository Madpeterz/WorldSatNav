-- helpers/misc.lua: throttle and the treasure-map bag iterator.
return function(t, env)
    local function load()
        env.reset({ now = 1700000000 })
        return env.require("helpers/misc")
    end

    t.test("throttle waits for the interval", function()
        local misc = load()
        local calls = 0
        local run = misc.throttle(100, function()
            calls = calls + 1
        end)
        run(40)
        run(40)
        t.eq(calls, 0)
        run(40)
        t.eq(calls, 1)
    end)

    t.test("throttle resets without carrying the overshoot", function()
        local misc = load()
        local calls = 0
        local run = misc.throttle(100, function()
            calls = calls + 1
        end)
        run(250)
        t.eq(calls, 1)
        run(50)
        t.eq(calls, 1)
        run(50)
        t.eq(calls, 2)
    end)

    t.test("throttle forwards dt and extra arguments", function()
        local misc = load()
        local seen = nil
        local run = misc.throttle(10, function(...)
            seen = { ... }
            return "result"
        end)
        t.eq(run(20, "a", "b"), "result")
        t.deepEq(seen, { 20, "a", "b" })
    end)

    t.test("throttle treats a nil dt as zero", function()
        local misc = load()
        local calls = 0
        local run = misc.throttle(10, function()
            calls = calls + 1
        end)
        run(nil)
        t.eq(calls, 0)
        run(10)
        t.eq(calls, 1)
    end)

    t.test("throttle with a zero interval fires every call", function()
        local misc = load()
        local calls = 0
        local run = misc.throttle(0, function()
            calls = calls + 1
        end)
        run(1)
        run(1)
        run(0)
        t.eq(calls, 3)
    end)

    t.test("iterateTreasureMaps calls back for treasure maps only", function()
        local misc = load()
        local constants = env.require("core/constants")
        local function button(name)
            return { GetInfo = function() return name and { name = name } or nil end }
        end
        local frame = { slots = { btns = {
            [1] = button(constants.game.treasureMapItemName),
            [2] = button("Something Else"),
            [3] = button(nil),
            [4] = button(constants.game.treasureMapItemName),
        } } }
        local savedAddon, savedUic = ADDON, UIC
        ADDON = { GetContent = function() return frame end }
        UIC = { BAG = 1 }
        local seen = {}
        local ok, err = pcall(misc.iterateTreasureMaps, function(slot)
            table.insert(seen, slot)
        end)
        ADDON, UIC = savedAddon, savedUic
        t.truthy(ok, err)
        table.sort(seen)
        t.deepEq(seen, { 1, 4 })
    end)

    t.test("iterateTreasureMaps does nothing without a bag", function()
        local misc = load()
        local savedAddon, savedUic = ADDON, UIC
        ADDON = { GetContent = function() return nil end }
        UIC = { BAG = 1 }
        local called = false
        local ok, err = pcall(misc.iterateTreasureMaps, function()
            called = true
        end)
        ADDON, UIC = savedAddon, savedUic
        t.truthy(ok, err)
        t.falsy(called)
    end)
end
