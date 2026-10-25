-- helpers/sharecode.lua: demo share codes (building + sextant + owner + unix time).
return function(t, env)
    local EPOCH = 1700000000

    local function load()
        env.reset({ now = EPOCH })
        return env.require("helpers/sharecode")
    end

    local function sextant(overrides)
        local value = {
            longitude = "W", deg_long = 123, min_long = 45, sec_long = 59,
            latitude = "S", deg_lat = 87, min_lat = 12, sec_lat = 34,
        }
        for key, v in pairs(overrides or {}) do
            value[key] = v
        end
        return value
    end

    t.test("encode then decode returns the same data", function()
        local sharecode = load()
        local code = sharecode.Encode(5, sextant(), "Tony", EPOCH + 123456789 % 4000000)
        local buildingId, decoded, owner, unixtime = sharecode.Decode(code)
        t.eq(buildingId, 5)
        t.deepEq(decoded, sextant())
        t.eq(owner, "Tony")
        t.eq(unixtime, EPOCH + 123456789 % 4000000)
    end)

    t.test("every direction combination survives", function()
        local sharecode = load()
        for _, lon in ipairs({ "E", "W" }) do
            for _, lat in ipairs({ "N", "S" }) do
                local original = sextant({ longitude = lon, latitude = lat })
                local _, decoded = sharecode.Decode(sharecode.Encode(1, original, "x", EPOCH + 100))
                t.deepEq(decoded, original, lon .. lat)
            end
        end
    end)

    t.test("field extremes survive", function()
        local sharecode = load()
        local extremes = {
            sextant({ deg_long = 0, min_long = 0, sec_long = 0, deg_lat = 0, min_lat = 0, sec_lat = 0 }),
            sextant({ deg_long = 255, min_long = 59, sec_long = 59, deg_lat = 127, min_lat = 59, sec_lat = 59 }),
            sextant({ sec_long = 15 }),
            sextant({ sec_long = 16 }),
            sextant({ sec_long = 48 }),
        }
        for index, original in ipairs(extremes) do
            local _, decoded = sharecode.Decode(sharecode.Encode(127, original, "x", EPOCH + 100))
            t.deepEq(decoded, original, "case " .. index)
        end
    end)

    t.test("building ids 0 to 127 all round-trip", function()
        local sharecode = load()
        for id = 0, 127 do
            local decodedId = sharecode.Decode(sharecode.Encode(id, sextant(), "x", EPOCH + 100))
            t.eq(decodedId, id)
        end
    end)

    t.test("times round-trip across the low/high word boundary", function()
        local sharecode = load()
        local deltas = { 0, 1, 255, 256, 65535, 65536, 65537, 1000000, 83296000, 4000000000 }
        for _, delta in ipairs(deltas) do
            local _, _, _, unixtime = sharecode.Decode(sharecode.Encode(1, sextant(), "x", EPOCH + delta))
            t.eq(unixtime, EPOCH + delta, "delta " .. delta)
        end
    end)

    t.test("a missing time encodes as the epoch", function()
        local sharecode = load()
        local _, _, _, unixtime = sharecode.Decode(sharecode.Encode(1, sextant(), "x", nil))
        t.eq(unixtime, EPOCH)
    end)

    t.test("code layout: 14 blob characters, a pipe, then the owner", function()
        local sharecode = load()
        local code = sharecode.Encode(1, sextant(), "June", EPOCH + 5)
        t.truthy(code:match("^[A-Za-z0-9%-_]+|June$"), code)
        t.eq(#code:match("^([^|]*)|"), 14)
    end)

    t.test("owner text is preserved verbatim, including pipes and spaces", function()
        local sharecode = load()
        for _, owner in ipairs({ "June", "Mary Ann", "a|b|c", "Zoë" }) do
            local _, _, decodedOwner = sharecode.Decode(sharecode.Encode(1, sextant(), owner, EPOCH + 5))
            t.eq(decodedOwner, owner)
        end
    end)

    t.test("empty and missing owners decode as an empty string", function()
        local sharecode = load()
        local _, _, owner = sharecode.Decode(sharecode.Encode(1, sextant(), "", EPOCH + 5))
        t.eq(owner, "")
        local code = sharecode.Encode(1, sextant(), nil, EPOCH + 5)
        t.eq(code:sub(-1), "|")
        _, _, owner = sharecode.Decode(code)
        t.eq(owner, "")
    end)

    t.test("Decode returns nil without a separator", function()
        local sharecode = load()
        t.isnil(sharecode.Decode("NwcdGQJZBYquCA"))
        t.isnil(sharecode.Decode(""))
    end)

    t.test("sample codes decode and re-encode to themselves", function()
        local sharecode = load()
        for _, code in ipairs({ "NwcdGQJZBYquCA|June", "NwcdGQJZBYquAA|June" }) do
            local buildingId, decoded, owner, unixtime = sharecode.Decode(code)
            t.eq(owner, "June")
            t.truthy(unixtime > EPOCH, "time after the epoch")
            t.eq(sharecode.Encode(buildingId, decoded, owner, unixtime), code)
        end
    end)

    t.test("the two sample codes differ by exactly 8 seconds", function()
        local sharecode = load()
        local _, _, _, later = sharecode.Decode("NwcdGQJZBYquCA|June")
        local _, _, _, earlier = sharecode.Decode("NwcdGQJZBYquAA|June")
        t.eq(later - earlier, 8)
    end)

    t.test("decode adds the large part before the low word (one rounding on 32-bit floats)", function()
        -- With 32-bit-float arithmetic EPOCH + hi*65536 is exact (both multiples of 128), so
        -- the final add is the only rounding. Check the structure on exact doubles: the
        -- decoded value equals EPOCH + hi*65536 + lo for a spread of low words.
        local sharecode = load()
        for lo = 0, 65535, 8191 do
            local delta = 1300 * 65536 + lo
            local _, _, _, unixtime = sharecode.Decode(sharecode.Encode(1, sextant(), "x", EPOCH + delta))
            t.eq(unixtime, EPOCH + 1300 * 65536 + lo)
        end
    end)
end
