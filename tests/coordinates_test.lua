-- core/coordinates.lua: sextant normalisation and conversions.
return function(t, env)
    local function load()
        env.reset({ now = 1700000000 })
        return env.require("core/coordinates"), env.require("core/constants")
    end

    t.test("NormalizeSextant maps engine-native field names", function()
        local coordinates = load()
        local normalized = coordinates.NormalizeSextant({
            longitudeDir = "W", longitudeDeg = 12, longitudeMin = 3, longitudeSec = 4,
            latitudeDir = "S", latitudeDeg = 5, latitudeMin = 6, latitudeSec = 7,
        })
        t.deepEq(normalized, {
            longitude = "W", deg_long = 12, min_long = 3, sec_long = 4,
            latitude = "S", deg_lat = 5, min_lat = 6, sec_lat = 7,
        })
    end)

    t.test("NormalizeSextant keeps the addon's own short form", function()
        local coordinates = load()
        local original = {
            longitude = "E", deg_long = 12, min_long = 3, sec_long = 4,
            latitude = "N", deg_lat = 5, min_lat = 6, sec_lat = 7,
        }
        t.deepEq(coordinates.NormalizeSextant(original), original)
    end)

    t.test("NormalizeSextant accepts camelCase names", function()
        local coordinates = load()
        local normalized = coordinates.NormalizeSextant({
            longitude = "E", degLong = 12, minLong = 3, secLong = 4,
            latitude = "N", degLat = 5, minLat = 6, secLat = 7,
        })
        t.eq(normalized.deg_long, 12)
        t.eq(normalized.min_lat, 6)
        t.eq(normalized.sec_lat, 7)
    end)

    t.test("NormalizeSextant defaults missing minutes and seconds to zero", function()
        local coordinates = load()
        local normalized = coordinates.NormalizeSextant({ longitude = "E", deg_long = 1, latitude = "N", deg_lat = 2 })
        t.eq(normalized.min_long, 0)
        t.eq(normalized.sec_long, 0)
        t.eq(normalized.min_lat, 0)
        t.eq(normalized.sec_lat, 0)
    end)

    t.test("NormalizeSextant returns nil for nil and writes into a target table", function()
        local coordinates = load()
        t.isnil(coordinates.NormalizeSextant(nil))
        local target = {}
        local result = coordinates.NormalizeSextant({ longitude = "E", deg_long = 9 }, target)
        t.eq(result, target)
        t.eq(target.deg_long, 9)
    end)

    t.test("toDecimalDegrees signs West and South negative", function()
        local coordinates = load()
        t.near(coordinates.toDecimalDegrees("E", 10, 30, 36), 10.51)
        t.near(coordinates.toDecimalDegrees("N", 10, 30, 36), 10.51)
        t.near(coordinates.toDecimalDegrees("W", 10, 30, 36), -10.51)
        t.near(coordinates.toDecimalDegrees("S", 10, 30, 36), -10.51)
    end)

    local render = { zeroPointX = 100, zeroPointY = 200, XCordScale = 10, YCordScale = 20 }

    t.test("SextantToMapCoordinates: east/south is positive from the zero point", function()
        local coordinates = load()
        local x, y = coordinates.SextantToMapCoordinates({
            longitude = "E", deg_long = 2, min_long = 30, sec_long = 0,
            latitude = "S", deg_lat = 1, min_lat = 0, sec_lat = 0,
        }, render)
        t.near(x, 125)
        t.near(y, 220)
    end)

    t.test("SextantToMapCoordinates: west flips x, north flips y", function()
        local coordinates = load()
        local x, y = coordinates.SextantToMapCoordinates({
            longitude = "W", deg_long = 2, min_long = 30, sec_long = 0,
            latitude = "N", deg_lat = 1, min_lat = 0, sec_lat = 0,
        }, render)
        t.near(x, 75)
        t.near(y, 180)
    end)

    t.test("SextantToMapCoordinates accepts engine-native names", function()
        local coordinates = load()
        local x, y = coordinates.SextantToMapCoordinates({
            longitudeDir = "E", longitudeDeg = 1, longitudeMin = 0, longitudeSec = 0,
            latitudeDir = "S", latitudeDeg = 1, latitudeMin = 0, latitudeSec = 0,
        }, render)
        t.near(x, 110)
        t.near(y, 220)
    end)

    t.test("SextantToMapCoordinates returns nil, nil for invalid input", function()
        local coordinates = load()
        local x, y = coordinates.SextantToMapCoordinates(nil, render)
        t.isnil(x)
        t.isnil(y)
        x, y = coordinates.SextantToMapCoordinates({ longitude = "E", deg_long = 1 }, render)
        t.isnil(x)
        t.isnil(y)
        x, y = coordinates.SextantToMapCoordinates({
            longitude = "E", deg_long = 1, latitude = "S", deg_lat = 1,
        }, nil)
        t.isnil(x)
        t.isnil(y)
        -- missing degrees (min/sec default to 0 via NormalizeSextant)
        x, y = coordinates.SextantToMapCoordinates({ longitude = "E", latitude = "N" }, render)
        t.isnil(x)
        t.isnil(y)
    end)

    -- Calibration anchors. Level 3 is BASE_RENDER; level 0 uses its own constants.
    local level0 = { zeroPointX = 311, zeroPointY = 122, XCordScale = 14.60, YCordScale = 14.40 }
    local anchorSextant = { longitude = "E", deg_long = 2, min_long = 0, sec_long = 0,
                            latitude = "S", deg_lat = 1, min_lat = 0, sec_lat = 0 }

    local function loadWithAnchor(offX, offY)
        local coordinates = load()
        local base = coordinates.BASE_RENDER
        local x, y = coordinates.SextantToMapCoordinates(anchorSextant, base)
        coordinates.SetAnchors({ { px = x + offX, py = y + offY, sextant = anchorSextant } })
        return coordinates, base, x, y
    end

    t.test("anchors: corrected position is exact at the anchor", function()
        local coordinates, base, x, y = loadWithAnchor(12, -8)
        local cx, cy = coordinates.SextantToMapCoordinates(anchorSextant, base)
        t.near(cx, x + 12, 1e-6)
        t.near(cy, y - 8, 1e-6)
    end)

    t.test("anchors: correction scales to other zoom levels", function()
        local coordinates, base = loadWithAnchor(12, -8)
        local before = load()
        local plainX, plainY = before.SextantToMapCoordinates(anchorSextant, level0)
        local cx, cy = coordinates.SextantToMapCoordinates(anchorSextant, level0)
        t.near(cx - plainX, 12 * level0.XCordScale / base.XCordScale, 1e-6)
        t.near(cy - plainY, -8 * level0.YCordScale / base.YCordScale, 1e-6)
    end)

    t.test("anchors: correction fades with distance and is zero past the radius", function()
        local coordinates = loadWithAnchor(10, 0)
        local near = coordinates.AnchorCorrection(2 + 0.5, 1)
        local mid = coordinates.AnchorCorrection(2 + (coordinates.ANCHOR_RADIUS / 2), 1)
        local edge = coordinates.AnchorCorrection(2 + coordinates.ANCHOR_RADIUS * 0.99, 1)
        local far = coordinates.AnchorCorrection(2 + coordinates.ANCHOR_RADIUS + 0.1, 1)
        t.truthy(near > mid and mid > edge and edge > 0, "correction should shrink with distance")
        t.near(mid, 5, 1e-6) -- a lone anchor gives half its residual at half the radius
        t.eq(far, 0)
    end)

    t.test("anchors: two anchors blend between them", function()
        local coordinates = load()
        local base = coordinates.BASE_RENDER
        local west = { longitude = "E", deg_long = 1, min_long = 0, sec_long = 0, latitude = "S", deg_lat = 1, min_lat = 0, sec_lat = 0 }
        local east = { longitude = "E", deg_long = 3, min_long = 0, sec_long = 0, latitude = "S", deg_lat = 1, min_lat = 0, sec_lat = 0 }
        local wx, wy = coordinates.SextantToMapCoordinates(west, base)
        local ex, ey = coordinates.SextantToMapCoordinates(east, base)
        t.eq(coordinates.SetAnchors({
            { px = wx + 10, py = wy, sextant = west },
            { px = ex + 20, py = ey, sextant = east },
        }), 2)
        local dx = coordinates.AnchorCorrection(2, 1)
        t.truthy(dx > 10 and dx < 20, "midpoint correction should sit between the residuals, got " .. tostring(dx))
    end)

    t.test("anchors: map-to-values undoes the correction", function()
        local coordinates, base = loadWithAnchor(15, 9)
        local nearby = { longitude = "E", deg_long = 2, min_long = 40, sec_long = 0,
                         latitude = "S", deg_lat = 0, min_lat = 30, sec_lat = 0 }
        for _, settings in ipairs({ base, level0 }) do
            local x, y = coordinates.SextantToMapCoordinates(nearby, settings)
            local longValue, latValue = coordinates.MapCoordinatesToValues(x, y, settings)
            t.near(longValue, 2 + 40 / 60, 1e-4)
            t.near(latValue, 0.5, 1e-4)
        end
    end)

    t.test("anchors: none set leaves the linear formula alone", function()
        local coordinates = load()
        t.eq(coordinates.GetAnchorCount(), 0)
        local x, y = coordinates.SextantToMapCoordinates(anchorSextant, render)
        t.near(x, 120)
        t.near(y, 220)
        local longValue, latValue = coordinates.MapCoordinatesToValues(120, 220, render)
        t.near(longValue, 2)
        t.near(latValue, 1)
    end)

    t.test("anchors: invalid entries are skipped", function()
        local coordinates = load()
        t.eq(coordinates.SetAnchors({
            { px = 1, py = 2 },
            { px = "x", py = 2, sextant = anchorSextant },
            { px = 1, py = 2, sextant = { longitude = "E" } },
            { px = "10.5", py = 20, sextant = anchorSextant },
        }), 1)
        t.eq(coordinates.SetAnchors(nil), 0)
    end)

    t.test("ToBasePixels round-trips through a level's linear constants", function()
        local coordinates = load()
        local base = coordinates.BASE_RENDER
        local x0, y0 = coordinates.SextantToMapCoordinates(anchorSextant, level0)
        local bx, by = coordinates.ToBasePixels(x0, y0, level0)
        local x3, y3 = coordinates.SextantToMapCoordinates(anchorSextant, base)
        t.near(bx, x3, 1e-6)
        t.near(by, y3, 1e-6)
    end)

    t.test("CalculateDistance is zero for the same point", function()
        local coordinates = load()
        local point = { longitude = "E", deg_long = 3, min_long = 2, sec_long = 1,
                        latitude = "N", deg_lat = 4, min_lat = 5, sec_lat = 6 }
        t.eq(coordinates.CalculateDistance(point, point), 0)
    end)

    t.test("CalculateDistance scales degrees by coordCoef", function()
        local coordinates, constants = load()
        local origin = { longitude = "E", deg_long = 0, latitude = "N", deg_lat = 0 }
        local oneEast = { longitude = "E", deg_long = 1, latitude = "N", deg_lat = 0 }
        t.near(coordinates.CalculateDistance(origin, oneEast), 1 / constants.coordCoef, 1e-6)
        local threeFourFive = { longitude = "E", deg_long = 3, latitude = "N", deg_lat = 4 }
        t.near(coordinates.CalculateDistance(origin, threeFourFive), 5 / constants.coordCoef, 1e-6)
    end)

    t.test("CalculateDistance crosses the meridian and equator", function()
        local coordinates, constants = load()
        local a = { longitude = "W", deg_long = 1, latitude = "S", deg_lat = 1 }
        local b = { longitude = "E", deg_long = 1, latitude = "N", deg_lat = 1 }
        t.near(coordinates.CalculateDistance(a, b), math.sqrt(8) / constants.coordCoef, 1e-6)
    end)

    t.test("CalculateDistance is infinite when a point or direction is missing", function()
        local coordinates = load()
        local point = { longitude = "E", deg_long = 1, latitude = "N", deg_lat = 1 }
        t.eq(coordinates.CalculateDistance(nil, point), math.huge)
        t.eq(coordinates.CalculateDistance(point, nil), math.huge)
        t.eq(coordinates.CalculateDistance(point, { deg_long = 1, deg_lat = 1 }), math.huge)
    end)

    t.test("sextant-to-degrees conversions use the map offsets", function()
        local coordinates, constants = load()
        t.near(coordinates.longitudeSextantToDegrees("E", 0, 0, 0), 21 / constants.coordCoef, 1e-6)
        t.near(coordinates.latitudeSextantToDegrees("N", 0, 0, 0), 28 / constants.coordCoef, 1e-6)
        t.near(coordinates.longitudeSextantToDegrees("W", 21, 0, 0), 0, 1e-6)
        t.near(coordinates.latitudeSextantToDegrees("S", 28, 0, 0), 0, 1e-6)
    end)
end
