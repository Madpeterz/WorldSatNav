-- helpers/buildings.lua: building catalog, and its fit with the share-code format.
return function(t, env)
    local function load()
        env.reset({ now = 1700000000 })
        return env.require("helpers/buildings")
    end

    t.test("Unknown is id 0", function()
        local buildings = load()
        t.eq(buildings.GetBuildingId("Unknown"), 0)
        t.eq(buildings.GetBuildingNameById(0), "Unknown")
    end)

    -- Ids are positions in BuildingNames and are baked into shared codes, so a duplicate
    -- entry cannot simply be deleted without renumbering everything after it. This list is
    -- the known exceptions; any new duplicate should fail.
    local KNOWN_DUPLICATES = { ["Gazebo Farm"] = true }

    t.test("names are unique apart from the known legacy duplicates", function()
        local buildings = load()
        local seen = {}
        for _, name in ipairs(buildings.GetBuildingNames()) do
            if not KNOWN_DUPLICATES[name] then
                t.falsy(seen[name], "duplicate building name: " .. name)
            end
            seen[name] = true
        end
    end)

    t.test("ids map back to their names", function()
        local buildings = load()
        for index, name in ipairs(buildings.GetBuildingNames()) do
            t.eq(buildings.GetBuildingNameById(index - 1), name)
            if not KNOWN_DUPLICATES[name] then
                t.eq(buildings.GetBuildingId(name), index - 1, name)
            end
        end
    end)

    t.test("a duplicated name still resolves to a valid id that maps back to it", function()
        local buildings = load()
        local id = buildings.GetBuildingId("Gazebo Farm")
        t.truthy(id ~= nil)
        t.eq(buildings.GetBuildingNameById(id), "Gazebo Farm")
    end)

    t.test("ids fit the share code's 7-bit building field", function()
        local buildings = load()
        t.truthy(#buildings.GetBuildingNames() <= 128, "more than 128 buildings no longer fit in a share code")
    end)

    t.test("every building survives a share-code round trip", function()
        local buildings = load()
        local sharecode = env.require("helpers/sharecode")
        local sextant = {
            longitude = "E", deg_long = 100, min_long = 20, sec_long = 30,
            latitude = "N", deg_lat = 50, min_lat = 40, sec_lat = 10,
        }
        for _, name in ipairs(buildings.GetBuildingNames()) do
            local id = buildings.GetBuildingId(name)
            local decodedId = sharecode.Decode(sharecode.Encode(id, sextant, "owner", 1700000100))
            t.eq(buildings.GetBuildingNameById(decodedId), name)
        end
    end)

    t.test("lookups for unknown ids and names are nil", function()
        local buildings = load()
        t.isnil(buildings.GetBuildingId("Not A Building"))
        t.isnil(buildings.GetBuildingNameById(9999))
        t.isnil(buildings.GetBuildingNameById(-5))
        t.isnil(buildings.GetBuildingNameById("abc"))
        t.isnil(buildings.GetBuildingNameById(nil))
    end)

    t.test("numeric strings work as ids", function()
        local buildings = load()
        t.eq(buildings.GetBuildingNameById("0"), "Unknown")
    end)
end
