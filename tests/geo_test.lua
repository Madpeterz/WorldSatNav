-- helpers/geo.lua: sextant keys, formatting and squared distance.
return function(t, env)
    local function load()
        env.reset({ now = 1700000000 })
        return env.require("helpers/geo")
    end

    local sample = {
        longitude = "E", deg_long = 12, min_long = 34, sec_long = 56,
        latitude = "N", deg_lat = 7, min_lat = 8, sec_lat = 9,
    }

    t.test("SextantKey concatenates every component", function()
        local geo = load()
        t.eq(geo.SextantKey(sample), "E123456N789")
    end)

    t.test("SextantKey distinguishes points that only differ in one component", function()
        local geo = load()
        local seen = {}
        local variants = {
            sample,
            { longitude = "W", deg_long = 12, min_long = 34, sec_long = 56, latitude = "N", deg_lat = 7, min_lat = 8, sec_lat = 9 },
            { longitude = "E", deg_long = 12, min_long = 34, sec_long = 57, latitude = "N", deg_lat = 7, min_lat = 8, sec_lat = 9 },
            { longitude = "E", deg_long = 12, min_long = 34, sec_long = 56, latitude = "S", deg_lat = 7, min_lat = 8, sec_lat = 9 },
            { longitude = "E", deg_long = 12, min_long = 34, sec_long = 56, latitude = "N", deg_lat = 7, min_lat = 8, sec_lat = 10 },
        }
        for _, variant in ipairs(variants) do
            local key = geo.SextantKey(variant)
            t.falsy(seen[key], "duplicate key " .. key)
            seen[key] = true
        end
    end)

    t.test("SextantKey tolerates nil and partial sextants", function()
        local geo = load()
        t.eq(geo.SextantKey(nil), "??000000")
        t.eq(geo.SextantKey({}), "?000?000")
    end)

    t.test("SextantKey is stable for equal sextants", function()
        local geo = load()
        local copy = {}
        for k, v in pairs(sample) do
            copy[k] = v
        end
        t.eq(geo.SextantKey(sample), geo.SextantKey(copy))
    end)

    t.test("FormatSextant prints latitude then longitude with degree signs", function()
        local geo = load()
        t.eq(geo.FormatSextant(sample), "7\194\17608'09\"N 12\194\17634'56\"E")
    end)

    t.test("FormatSextant handles nil and missing fields", function()
        local geo = load()
        t.eq(geo.FormatSextant(nil), "??")
        t.eq(geo.FormatSextant({}), "0\194\17600'00\"? 0\194\17600'00\"?")
    end)

    t.test("distSqToPlayer is zero for the same point", function()
        local geo = load()
        t.eq(geo.distSqToPlayer(sample, sample), 0)
    end)

    t.test("distSqToPlayer is squared decimal-degree distance", function()
        local geo = load()
        local a = { longitude = "E", deg_long = 0, min_long = 0, sec_long = 0, latitude = "N", deg_lat = 0, min_lat = 0, sec_lat = 0 }
        local b = { longitude = "E", deg_long = 3, min_long = 0, sec_long = 0, latitude = "N", deg_lat = 4, min_lat = 0, sec_lat = 0 }
        t.near(geo.distSqToPlayer(a, b), 25)
        t.near(geo.distSqToPlayer(b, a), 25)
    end)

    t.test("distSqToPlayer respects direction signs", function()
        local geo = load()
        local west = { longitude = "W", deg_long = 1, min_long = 0, sec_long = 0, latitude = "N", deg_lat = 0, min_lat = 0, sec_lat = 0 }
        local east = { longitude = "E", deg_long = 1, min_long = 0, sec_long = 0, latitude = "N", deg_lat = 0, min_lat = 0, sec_lat = 0 }
        t.near(geo.distSqToPlayer(west, east), 4)
    end)

    t.test("distSqToPlayer reads engine-native names", function()
        local geo = load()
        local native = {
            longitudeDir = "E", longitudeDeg = 3, longitudeMin = 0, longitudeSec = 0,
            latitudeDir = "N", latitudeDeg = 4, latitudeMin = 0, latitudeSec = 0,
        }
        local origin = { longitude = "E", deg_long = 0, min_long = 0, sec_long = 0, latitude = "N", deg_lat = 0, min_lat = 0, sec_lat = 0 }
        t.near(geo.distSqToPlayer(native, origin), 25)
    end)

    t.test("distSqToPlayer is infinite for nil or incomplete input", function()
        local geo = load()
        t.eq(geo.distSqToPlayer(nil, sample), math.huge)
        t.eq(geo.distSqToPlayer(sample, nil), math.huge)
        t.eq(geo.distSqToPlayer({ deg_long = 1 }, sample), math.huge)
        t.eq(geo.distSqToPlayer(sample, { longitude = "E", latitude = "N" }), math.huge)
    end)
end
