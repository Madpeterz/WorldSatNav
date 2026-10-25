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
