-- features/timers.lua: create, fire, repeat without drift, finished state, save/load.
return function(t, env)
    local NOW = 1792990123
    local FILE = "WorldSatNav/data/timers.dat"
    local POSITION = { longitude = "W", latitude = "N", deg_long = 10, min_long = 5, sec_long = 0, deg_lat = 20, min_lat = 3, sec_lat = 0 }

    -- Loads timers against a fake clock/position and records every alert it raises.
    local function load(opts)
        opts = opts or {}
        local api = env.reset({ now = opts.now or NOW })
        api.Map = {
            GetPlayerSextants = function()
                return POSITION
            end,
        }
        if opts.files ~= nil then
            api._files = opts.files
        end
        local eventbus = env.require("core/eventbus")
        local topics = env.require("core/eventtopics").topics
        local alerts = {}
        eventbus.WatchEvent(topics.alert.show, function(data)
            table.insert(alerts, data)
        end, "test")
        local timers = env.require("features/timers")
        -- one onUpdate = one trigger check, then deliver the queued alert events
        local function tick()
            timers.onUpdate(1000)
            eventbus.ProcessDeferredEvents()
        end
        return timers, api, alerts, tick
    end

    local function savedRow(api, name)
        for _, row in ipairs(api._files[FILE] or {}) do
            if row.name == name then
                return row
            end
        end
        return nil
    end

    local function secondsLeftOf(api, name)
        local countdown = env.require("helpers/countdown")
        local row = savedRow(api, name)
        return countdown.SecondsLeft(countdown.DeserializeDeadline(row.anchor, row.offset))
    end

    t.test("creating a timer saves it at the player's position", function()
        local timers, api = load()
        t.truthy(timers.CreateTimer("Farm", 300, nil))
        local row = savedRow(api, "Farm")
        t.truthy(row)
        t.eq(row.kind, "single")
        t.eq(row.location.deg_long, 10)
        t.eq(type(row.anchor), "string")
        t.eq(type(row.offset), "string")
        t.isnil(row.firedAt)
        local color = tonumber(row.color)
        t.truthy(color >= 0 and color < env.require("core/constants").icons.orbCount, "color in orb range")
    end)

    t.test("no position means no timer", function()
        local timers, api = load()
        api.Map.GetPlayerSextants = function() return nil end
        t.falsy(timers.CreateTimer("Farm", 300, nil))
        t.isnil(api._files[FILE])
    end)

    t.test("a timer does not fire early", function()
        local timers, api, alerts, tick = load()
        timers.CreateTimer("Farm", 300, nil)
        api._now = NOW + 299
        tick()
        t.eq(#alerts, 0)
    end)

    t.test("a single timer fires once, then is kept as finished", function()
        local timers, api, alerts, tick = load()
        timers.CreateTimer("Farm", 300, nil)
        api._now = NOW + 301
        tick()
        t.eq(#alerts, 1)
        t.eq(alerts[1].title, "Timer: Farm")
        t.eq(alerts[1].source, "timer")
        t.eq(alerts[1].payload.trackType, "Timer")
        t.eq(alerts[1].countUpTo5Minutes, true)
        t.truthy(savedRow(api, "Farm").firedAt, "finished timer stays in the file")
        api._now = NOW + 4000
        for _ = 1, 20 do
            tick()
        end
        t.eq(#alerts, 1)
    end)

    t.test("a repeating timer resets to its interval from the due time", function()
        local timers, api, alerts, tick = load()
        timers.CreateTimer("Boss", 60, 3600)
        api._now = NOW + 70 -- noticed 10s late
        tick()
        t.eq(#alerts, 1)
        t.isnil(savedRow(api, "Boss").firedAt)
        -- next run is 1h after the due time (NOW + 60), not 1h after it was noticed
        t.near(secondsLeftOf(api, "Boss"), 3600 - 10, 0.5)
    end)

    t.test("a repeating timer skips runs missed while offline with one alert", function()
        local timers, api, alerts, tick = load()
        timers.CreateTimer("Boss", 60, 3600)
        api._now = NOW + 60 + 2 * 3600 + 100
        tick()
        t.eq(#alerts, 1)
        t.near(secondsLeftOf(api, "Boss"), 3600 - 100, 0.5)
        -- long overdue: shown as text, not a count-up the alert window would drop at once
        t.isnil(alerts[1].countdownSeconds)
        t.truthy(alerts[1].countdownText)
        for _ = 1, 20 do
            tick()
        end
        t.eq(#alerts, 1)
    end)

    t.test("timers due together alert one at a time", function()
        local timers, api, alerts, tick = load()
        timers.CreateTimer("A", 60, nil)
        timers.CreateTimer("B", 120, nil)
        api._now = NOW + 200
        tick()
        t.eq(#alerts, 1)
        t.eq(alerts[1].title, "Timer: A", "most overdue first")
        tick()
        t.eq(#alerts, 1, "second alert waits")
        for _ = 1, 10 do
            tick()
        end
        t.eq(#alerts, 2)
        t.eq(alerts[2].title, "Timer: B")
    end)

    t.test("timers survive a reload with their schedule intact", function()
        env.withEngineNumbers(function()
            local timers, api = load({ now = tostring(NOW) })
            timers.CreateTimer("Farm", 300, nil)
            timers.CreateTimer("Boss", 600, 7200)
            local files = api._files

            local reloaded, api2, alerts, tick = load({ now = tostring(NOW), files = files })
            reloaded.LoadTimers()
            -- saving again proves both rows were read back
            reloaded.RemoveTimer(999)
            reloaded.CreateTimer("Extra", 60, nil)
            t.truthy(savedRow(api2, "Farm"))
            t.eq(savedRow(api2, "Boss").kind, "repeating")
            t.eq(savedRow(api2, "Boss").every, "7200")
            t.near(secondsLeftOf(api2, "Farm"), 300, 0.5)
            t.near(secondsLeftOf(api2, "Boss"), 600, 0.5)
            t.eq(savedRow(api2, "Extra").id, "3", "ids continue after the loaded ones")
            t.eq(#alerts, 0)
            tick()
            t.eq(#alerts, 0)
        end)
    end)

    t.test("a finished timer stays finished after a reload", function()
        local timers, api, alerts, tick = load()
        timers.CreateTimer("Farm", 60, nil)
        api._now = NOW + 61
        tick()
        t.eq(#alerts, 1)
        local reloaded, _, alerts2, tick2 = load({ now = NOW + 61, files = api._files })
        reloaded.LoadTimers()
        for _ = 1, 10 do
            tick2()
        end
        t.eq(#alerts2, 0)
    end)

    t.test("RemoveTimer deletes from the file", function()
        local timers, api = load()
        timers.CreateTimer("Farm", 60, nil)
        t.truthy(timers.RemoveTimer(1))
        t.isnil(savedRow(api, "Farm"))
        t.falsy(timers.RemoveTimer(1))
    end)
end
