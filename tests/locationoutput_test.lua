-- features/locationoutput.lua: what ends up in data/location.dat.
return function(t, env)
    local NOW = 1792990123
    local PATH = "WorldSatNav/data/location.dat"
    local SEXTANTS = {
        deg_long = 6, min_long = 34, sec_long = 14, longitude = "W",
        deg_lat = 17, min_lat = 13, sec_lat = 10, latitude = "S",
    }

    local function load(stored)
        local api = env.reset({ now = NOW, settings = stored or { EnableLocationOutput = true } })
        api.Map = {
            GetPlayerSextants = function()
                return SEXTANTS
            end,
        }
        return env.require("features/locationoutput"), api
    end

    -- api.File:Write prints numbers with %g, which keeps only 6 significant digits.
    local function asWrittenByEngine(value)
        if type(value) == "number" then
            return string.format("%g", value)
        end
        return value
    end

    t.test("time survives the engine's number formatting as exact unix seconds", function()
        local locationoutput, api = load()
        locationoutput.Update(1000)
        local written = api._files[PATH]
        t.truthy(written ~= nil, "location.dat was not written")
        t.eq(type(written.time), "string")
        t.eq(asWrittenByEngine(written.time), tostring(NOW))
        t.eq(tonumber(asWrittenByEngine(written.time)), NOW)
    end)

    t.test("time is whole seconds even while the clock is interpolating", function()
        local locationoutput, api = load()
        local datetime = env.require("helpers/datetime")
        datetime.GetCurrentTimestamp()
        datetime.AdvanceCurrentTimestamp(750)
        locationoutput.Update(1000)
        t.eq(api._files[PATH].time, tostring(NOW))
    end)

    t.test("engine text time is written with every digit, not rounded to 128s", function()
        env.withEngineNumbers(function()
            local locationoutput, api = load()
            api._now = "1792990123"
            locationoutput.Update(1000)
            t.eq(api._files[PATH].time, "1792990123")
        end)
    end)

    t.test("time moves on every second, like GetLocalTime does", function()
        env.withEngineNumbers(function()
            local locationoutput, api = load()
            api._now = "1792990123"
            locationoutput.Update(1000)
            api._now = "1792990124"
            locationoutput.Update(1000)
            t.eq(api._files[PATH].time, "1792990124")
        end)
    end)

    t.test("engine text time in milliseconds is written as seconds", function()
        local locationoutput, api = load()
        api._now = "1792990123456"
        locationoutput.Update(1000)
        t.eq(api._files[PATH].time, "1792990123")
    end)

    t.test("location is the player's sextants", function()
        local locationoutput, api = load()
        locationoutput.Update(1000)
        t.eq(api._files[PATH].location, SEXTANTS)
    end)

    t.test("nothing is written until the rate limit has passed", function()
        local locationoutput, api = load({ EnableLocationOutput = true, LocationOutputRateLimit = 1000 })
        locationoutput.Update(400)
        t.isnil(api._files[PATH])
        locationoutput.Update(600)
        t.truthy(api._files[PATH] ~= nil, "location.dat was not written after the rate limit")
    end)

    t.test("nothing is written while location output is disabled", function()
        local locationoutput, api = load({ EnableLocationOutput = false })
        locationoutput.Update(5000)
        t.isnil(api._files[PATH])
    end)

    t.test("LocationOutputFile picks the file name", function()
        local locationoutput, api = load({ EnableLocationOutput = true, LocationOutputFile = "where.dat" })
        locationoutput.Update(1000)
        t.truthy(api._files["WorldSatNav/data/where.dat"] ~= nil, "custom output file was not written")
    end)

    -- tracking.lua needs the UI to load, so check its source instead: location.dat
    -- only updates if the game's UPDATE loop still reaches locationoutput.Update.
    t.test("location output is wired into the game's update loop", function()
        local tracking = env.readSource("features/tracking.lua")
        t.truthy(tracking:find('require%("WorldSatNav/features/locationoutput"%)'), "tracking.lua does not require locationoutput")
        local onUpdate = tracking:match("function tracking%.onUpdate%(dt%)(.-)\r?\nend")
        t.truthy(onUpdate ~= nil, "tracking.onUpdate not found")
        t.truthy(onUpdate:find("locationoutput%.Update%(dt%)"), "tracking.onUpdate does not call locationoutput.Update(dt)")
        local main = env.readSource("main.lua")
        t.truthy(main:find("tracking%.onUpdate%(dt%)"), "main.lua UPDATE loop does not call tracking.onUpdate(dt)")
    end)
end
