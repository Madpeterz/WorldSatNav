local api = require("api")
local mapRenderer = require("WorldSatNav/map_renderer")
local helpers = require("WorldSatNav/helpers")

local demos = {}

local demosFile = "WorldSatNav/data/demos.dat"
local storedDemos = {}
local inDemoMode = false

local function resolveLocation(entry)
    if type(entry) ~= "table" then
        return {}
    end
    if type(entry.location) == "table" then
        return entry.location
    end
    return entry
end

local function makeLocData(entry, index)
    local location = resolveLocation(entry)
    local locData = {
        longitudeDir = location.longitude,
        longitudeDeg = location.deg_long,
        longitudeMin = location.min_long,
        longitudeSec = location.sec_long,
        latitudeDir = location.latitude,
        latitudeDeg = location.deg_lat,
        latitudeMin = location.min_lat,
        latitudeSec = location.sec_lat,
        isdemo = true,
        id = index,
        index = index,
        ownername = entry.ownername,
        buildingname = entry.buildingname,
        startat = entry.startat,
        hadAlert = false
    }
    return locData
end

local function loadDemos()
    helpers.DevLog("Loading demo data from " .. demosFile)
    local entries = api.File:Read(demosFile)
    helpers.DevLog("Raw demo data handle: " .. tostring(entries))
    if type(entries) == "table" then
        helpers.DevLog("Raw demo data entries: " .. tostring(#entries))
    end
    if entries == nil then
        api.Log:Info("WorldSatNav: Failed to load demo data from " .. demosFile .. "")
        return false
    end
    local nowTime = api.Time:GetLocalTime()
    storedDemos = {}
    for index, entry in ipairs(entries) do
        local datapoint = makeLocData(entry, index)
        if datapoint.startat ~= nil and type(datapoint.startat) == "number" then
            local ageSeconds = nowTime - datapoint.startat
            if ageSeconds > (60 * 60) then
                helpers.DevLog("skipping entry " .. index .. " due to startat being more than 1 hour in the past (" .. ageSeconds .. " seconds old)")
            else
                table.insert(storedDemos, datapoint)
            end
        end
    end
    if #storedDemos ~= #entries then
        helpers.DevLog("Filtered out " .. (#entries - #storedDemos) .. " old demo entries, " .. #storedDemos .. " remain")
        demos.saveDemos()
    end
    helpers.DevLog("Loaded " .. #storedDemos .. " demo entries")
    return true
end

function demos.saveDemos()
    local entriesToSave = {}
    for _, demo in ipairs(storedDemos) do
        local entry = {
            ownername = demo.ownername,
            buildingname = demo.buildingname,
            startat = demo.startat,
            location = {
                longitude = demo.longitudeDir,
                deg_long = demo.longitudeDeg,
                min_long = demo.longitudeMin,
                sec_long = demo.longitudeSec,
                latitude = demo.latitudeDir,
                deg_lat = demo.latitudeDeg,
                min_lat = demo.latitudeMin,
                sec_lat = demo.latitudeSec
            }
        }
        table.insert(entriesToSave, entry)
    end
    api.File:Write(demosFile, entriesToSave)
    helpers.DevLog("Saved " .. #entriesToSave .. " demos to " .. demosFile)
end

function demos.InDemoMode()
    return inDemoMode
end

function demos.getDemoData()
    return storedDemos
end

function demos.RenderDemos()
    helpers.DevLog("Rendering demos, total count: " .. #storedDemos)
    if not loadDemos() then
        return
    end

    mapRenderer.hideDots()
    mapRenderer.renderPlayerMarker()
    for _, demo in ipairs(storedDemos) do
        helpers.DevLog("Rendering demo: " .. (demo.ownername or "unknown") .. " at " .. (demo.buildingname or "unknown location"))
        mapRenderer.renderDot(demo, 1, "demo.png", 24, 24)
    end
end

function demos.DisplayDemos(enabled)
    inDemoMode = enabled == true
    if inDemoMode then
        demos.RenderDemos()
    end
end

return demos