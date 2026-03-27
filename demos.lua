local api = require("api")
local mapRenderer = require("WorldSatNav/map_renderer")
local helpers = require("WorldSatNav/helpers")
local settings = require("WorldSatNav/settings")

local demos = {}

local demosFile = "WorldSatNav/data/demos.dat"
local storedDemos = {}
local inDemoMode = false

local function normalizeTimestamp(value)
    local numericValue = tonumber(value)
    if numericValue == nil then
        return nil
    end
    return math.floor(numericValue)
end

local function serializeTimestamp(value)
    local normalizedValue = normalizeTimestamp(value)
    if normalizedValue == nil then
        return nil
    end
    return string.format("%.0f", normalizedValue)
end

local function isUpcomingWithinWindow(timestamp, nowTime, windowSeconds)
    if type(timestamp) ~= "number" then
        return false
    end
    local timeUntilEvent = timestamp - nowTime
    return timeUntilEvent >= 0 and timeUntilEvent < windowSeconds
end

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
        startat = normalizeTimestamp(entry.startat),
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
        helpers.DevLog("No demo data found at " .. demosFile .. ", starting with empty list")
        entries = {}
    end
    local nowTime = helpers.GetCurrentTimestamp()
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

local function ensureDemosLoaded()
    if #storedDemos > 0 then
        return true
    end
    return loadDemos()
end

function demos.saveDemos()
    local entriesToSave = {}
    for _, demo in ipairs(storedDemos) do
        local entry = {
            ownername = demo.ownername,
            buildingname = demo.buildingname,
            startat = serializeTimestamp(demo.startat),
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

function demos.getNextAlert()
    if not ensureDemosLoaded() then
        return nil
    end
    local nowTime = helpers.GetCurrentTimestamp()
    for _, demo in ipairs(storedDemos) do
        if demo.hadAlert == false then
            local timeUntilDemo = demo.startat - nowTime
            if isUpcomingWithinWindow(demo.startat, nowTime, 60 * 5) then
                local mins = math.floor(timeUntilDemo / 60)
                local secs = math.floor(timeUntilDemo % 60)
                helpers.DevLog("Demo " .. demo.id .. " is upcoming within 5 minutes, returning for alert (" .. mins .. " minutes and " .. secs .. " seconds until start)")
                demo.hadAlert = true
                return demo
            elseif timeUntilDemo >= -(60 * 30) then
                local elapsedSeconds = math.abs(timeUntilDemo)
                local mins = math.floor(elapsedSeconds / 60)
                local secs = math.floor(elapsedSeconds % 60)
                helpers.DevLog("Demo " .. demo.id .. " started within the last 30 minutes (" .. mins .. " minutes and " .. secs .. " seconds ago), returning for alert")
                demo.hadAlert = true
                return demo
            end
        end
    end
    return nil
end

function demos.CreateDemo(regionname, ownername, buildingname, dateText, timeText, timestamp)
    local playerSextants = api.Map:GetPlayerSextants()
    if type(playerSextants) ~= "table" then
        api.Log:Info("WorldSatNav: Unable to create demo because player coordinates are unavailable.")
        return false
    end

    local demoTimestamp = timestamp
    if demoTimestamp == nil then
        demoTimestamp = helpers.ParseDateTimeToUnixtime(dateText, timeText)
    end
    demoTimestamp = normalizeTimestamp(demoTimestamp)
    if type(demoTimestamp) ~= "number" then
        api.Log:Info("WorldSatNav: Unable to create demo because the date/time could not be converted.")
        return false
    end

    local nextIndex = #storedDemos + 1
    local newDemo = {
        longitudeDir = playerSextants.longitude,
        longitudeDeg = playerSextants.deg_long,
        longitudeMin = playerSextants.min_long,
        longitudeSec = playerSextants.sec_long,
        latitudeDir = playerSextants.latitude,
        latitudeDeg = playerSextants.deg_lat,
        latitudeMin = playerSextants.min_lat,
        latitudeSec = playerSextants.sec_lat,
        isdemo = true,
        id = nextIndex,
        index = nextIndex,
        ownername = ownername,
        buildingname = buildingname,
        startat = demoTimestamp,
        hadAlert = false
    }

    table.insert(storedDemos, newDemo)
    demos.saveDemos()
    helpers.DevLog(string.format("Created demo '%s' for '%s' in region '%s' at %d", tostring(buildingname), tostring(ownername), tostring(regionname), demoTimestamp))
    return true
end

function demos.RenderDemos()
    helpers.DevLog("Rendering demos, total count: " .. #storedDemos)
    if not ensureDemosLoaded() then
        return nil
    end

    mapRenderer.hideDots()
    mapRenderer.renderPlayerMarker()
    local nowTime = helpers.GetCurrentTimestamp()
    for _, demo in ipairs(storedDemos) do
        local drawdemo = true
        if settings.Get("DrawDemosInNextHour") == true then
            drawdemo = isUpcomingWithinWindow(demo.startat, nowTime, 60 * 60)
            if drawdemo == false and type(demo.startat) == "number" then
                local timeUntilDemo = demo.startat - nowTime
                if timeUntilDemo >= (60 * 60) then
                    helpers.DevLog("Not rendering demo " .. demo.id .. " because it is scheduled for more than 1 hour in the future (" .. timeUntilDemo .. " seconds until start)")
                else
                    helpers.DevLog("Not rendering demo " .. demo.id .. " because it has already started (" .. math.abs(timeUntilDemo) .. " seconds ago)")
                end
            end
        end
        if drawdemo == true then
            helpers.DevLog("Rendering demo: " .. (demo.ownername or "unknown") .. " at " .. (demo.buildingname or "unknown location"))
            mapRenderer.renderDot(demo, 1, "demo.png", 24, 24)
        end
    end
end

function demos.DisplayDemos(enabled)
    inDemoMode = enabled == true
    if inDemoMode then
        demos.RenderDemos()
    end
end

return demos