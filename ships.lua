local api = require("api")


local shipsHelper = {}
local mapRenderer = require("WorldSatNav/map_renderer")
local helpers = require("WorldSatNav/helpers")
local settings = require("WorldSatNav/settings")
local coordinates = require("WorldSatNav/coordinates")

local InShipMode = false
local shipData = nil
local shipDataFilePath = "WorldSatNav/data/ships.dat"
local shipAddonData = {}
local nextShipsButton = nil
local shipIndexVisited = {}
local lastVistitedShip = nil
local trackedShipId = nil

-- Show or hide the "Next Ship" button (nil-safe)
local function setNextButtonVisible(visible)
    if nextShipsButton == nil then return end
    nextShipsButton:Show(visible)
    nextShipsButton:Enable(visible)
end

shipsHelper.IsInShipMode = function()
    return InShipMode
end

shipsHelper.getShipData = function()
    return shipAddonData
end

function ExpireOldShipVisits()
    if shipIndexVisited == nil then
        return
    end

    local currentTime = api.Time:GetLocalTime()
    for index, visitTime in pairs(shipIndexVisited) do
        local timeSinceVisit = currentTime - visitTime
        if timeSinceVisit > 7200 then -- 120 minutes = 7200 seconds
            shipIndexVisited[index] = nil
        end
    end
end

function StartNextShipTracking(targetShip, showMapMarker)
    local wMapMarker = showMapMarker or false
    lastVistitedShip = targetShip
    trackedShipId = targetShip.index
    shipIndexVisited[trackedShipId] = api.Time:GetLocalTime()
    START_MAP_TRACKING(targetShip, wMapMarker)
    -- If the map window is already open, re-render so the new tracked ship is highlighted
    if mapRenderer.IsMapOpen() then
        shipsHelper.DisplayShips(true)
    end
end



-- Returns a locData table for the given raw ship entry, or nil
local function makeLocData(ship, index)
    local sx = ship.sextant
    return {
        longitudeDir = sx.longitude,
        longitudeDeg = sx.deg_long,
        longitudeMin = sx.min_long,
        longitudeSec = sx.sec_long,
        latitudeDir = sx.latitude,
        latitudeDeg = sx.deg_lat,
        latitudeMin = sx.min_lat,
        latitudeSec = sx.sec_lat,
        isship = true,
        isevent = false,
        ismap = false,
        id = index,
        index = index,
    }
end

local function getShipDegCoords(entry)
    if entry == nil then
        return nil, nil
    end
    local lon = entry.longitudeDeg or (entry.sextant and entry.sextant.deg_long)
    local lat = entry.latitudeDeg or (entry.sextant and entry.sextant.deg_lat)
    return lon, lat
end

shipsHelper.GetNextShip = function()
    ExpireOldShipVisits()
    if lastVistitedShip == nil then
        api.Log:Info("No last visited ship found please select a ship manually")
        return
    end
    if shipData == nil then
        api.Log:Info("ship data is not loaded, please reload addon")
        return
    end
    if not lastVistitedShip or not lastVistitedShip.index then
        helpers.DevLog("No valid last visited ship for distance calculation")
        return
    end
    local lastLon, lastLat = getShipDegCoords(lastVistitedShip)
    if lastLon == nil or lastLat == nil then
        helpers.DevLog("No valid coordinates on last visited ship, cannot calculate next ship")
        return
    end

    helpers.DevLog("Finding next ship after index " .. tostring(lastVistitedShip.index))
    -- Debug: log shipData and lastVistitedShip
    helpers.DevLog("shipData type: " .. type(shipData))
    if type(shipData) == "table" then
        local count = 0
        for k, v in pairs(shipData) do count = count + 1 end
        helpers.DevLog("shipData entries: " .. tostring(count))
    else
        helpers.DevLog("shipData is not a table!")
    end
    helpers.DevLog("lastVistitedShip: " .. tostring(lastVistitedShip))
    local shipsWithin5km = {}
    local enteredLoop = false
    for _, ship in pairs(shipData) do
        enteredLoop = true
        helpers.DevLog("Looping ship: " .. tostring(ship) .. ", index: " .. tostring(ship and ship.index))
        -- Dump ship table fields for debugging
        if type(ship) == "table" then
            local fieldDump = ""
            for k, v in pairs(ship) do
                fieldDump = fieldDump .. tostring(k) .. "=" .. tostring(v) .. ", "
            end
            helpers.DevLog("Ship fields: " .. fieldDump)
        end
        if ship == nil then
            helpers.DevLog("Encountered nil ship entry in data, skipping")
        elseif ship.index == nil then
            helpers.DevLog("Encountered ship entry with no index, skipping: " .. tostring(ship))
        elseif shipIndexVisited[ship.index] ~= nil then
            helpers.DevLog("Ship index " .. tostring(ship.index) .. " already visited at " .. tostring(shipIndexVisited[ship.index]) .. ", skipping")
        elseif ship.index == trackedShipId then
            helpers.DevLog("Ship index " .. tostring(ship.index) .. " is currently being tracked, skipping")
        else
            -- Fast bounding-box check: skip if longitudeDeg or latitudeDeg differ by more than 5
            local shipLon, shipLat = getShipDegCoords(ship)
            if shipLon == nil or shipLat == nil then
                helpers.DevLog("Ship index " .. tostring(ship.index) .. " has no valid coordinates, skipping")
            else
                local Acheck = math.abs(lastLon - shipLon)
                local Bcheck = math.abs(lastLat - shipLat)
                if Acheck > 5 or Bcheck > 5 then
                    helpers.DevLog("Ship index " .. tostring(ship.index) .. " skipped by bounding box check (deg diff > 5) - Acheck: " .. tostring(Acheck) .. ", Bcheck: " .. tostring(Bcheck))
                else
                    helpers.DevLog("Calculating distance for ship index " .. tostring(ship.index) .. " using sextant fields.")
                    local distance = coordinates.CalculateDistance(lastVistitedShip, ship)
                    helpers.DevLog("Calculated distance for ship index " .. tostring(ship.index) .. ": " .. tostring(distance) .. " meters")
                    if distance <= 2500 then
                        local x, y = coordinates.getMapDrawPoint(ship.longitudeDir, ship.latitudeDir, ship.longitudeDeg, ship.longitudeMin, ship.longitudeSec, ship.latitudeDeg, ship.latitudeMin, ship.latitudeSec)
                        local xx, yy = coordinates.getMapDrawPoint(lastVistitedShip.longitudeDir, lastVistitedShip.latitudeDir, lastVistitedShip.longitudeDeg, lastVistitedShip.longitudeMin, lastVistitedShip.longitudeSec, lastVistitedShip.latitudeDeg, lastVistitedShip.latitudeMin, lastVistitedShip.latitudeSec)
                        local xxdif = math.abs(xx - x)
                        local yydif = math.abs(yy - y)
                        local dif = math.sqrt(xxdif * xxdif + yydif * yydif)
                        table.insert(shipsWithin5km, {ship = ship, distance = dif})
                    end
                end
            end
        end
    end
    if not enteredLoop then
        helpers.DevLog("Did not enter shipData loop at all!")
    end
    helpers.DevLog("Found " .. tostring(#shipsWithin5km) .. " unvisited ships within 5km")
    if #shipsWithin5km == 0 then
        api.Log:Info("No nearby ships found within 2.5km")
        return
    end
    table.sort(shipsWithin5km, function(a, b) return a.distance < b.distance end)
    local nextShip = shipsWithin5km[1].ship
    StartNextShipTracking( makeLocData(nextShip, nextShip.index), false)
end

shipsHelper.HideNextShipButton = function()
    setNextButtonVisible(false)
end

shipsHelper.RestoreNextShipButton = function()
    if lastVistitedShip ~= nil then
        setNextButtonVisible(true)
    end
end

shipsHelper.SelectedShipClicked = function(shipInfo)
    if shipInfo == nil or shipInfo.id == nil then
        helpers.DevLog("Invalid ship info for tracking: " .. tostring(shipInfo))
        return
    end
    StartNextShipTracking(shipInfo, true)
    setNextButtonVisible(true)
end

shipsHelper.CreateNextShipButton = function()
    if nextShipsButton ~= nil then
        return;
    end
    if TRACK_WINDOW == nil then
        return
    end
    nextShipsButton = helpers.createButton("NextShipButton", TRACK_WINDOW,  "Next Ship", 10, TRACK_WINDOW:GetHeight() + 3)
    
    function nextShipsButton:OnClick()
        shipsHelper.GetNextShip()
    end
    
    nextShipsButton:SetHandler("OnClick", nextShipsButton.OnClick)
    setNextButtonVisible(false)
end

shipsHelper.DisplayShips = function(enableShipMode)
    -- If parameter is provided (from checkbox), use it as the desired state
    local shouldEnable = not InShipMode
    if enableShipMode ~= nil then
        shouldEnable = enableShipMode
    end
    
    -- Only update state if it's changing
    if InShipMode ~= shouldEnable then
        InShipMode = shouldEnable
        shipIndexVisited = {}
        trackedShipId = nil
        setNextButtonVisible(false)
    end
    
    if InShipMode == false then
        mapRenderer.render()
        return
    end
    if shipData == nil then
        shipData = api.File:Read(shipDataFilePath)
        -- Add index to each ship entry after loading
        if shipData ~= nil then
            local idx = 1
            for _, ship in pairs(shipData) do
                ship.index = idx
                -- Optionally, copy sextant fields to top level for easier access elsewhere
                if ship.sextant then
                    ship.longitudeDir = ship.sextant.longitude
                    ship.longitudeDeg = ship.sextant.deg_long
                    ship.longitudeMin = ship.sextant.min_long
                    ship.longitudeSec = ship.sextant.sec_long
                    ship.latitudeDir = ship.sextant.latitude
                    ship.latitudeDeg = ship.sextant.deg_lat
                    ship.latitudeMin = ship.sextant.min_lat
                    ship.latitudeSec = ship.sextant.sec_lat
                end
                idx = idx + 1
            end
        end
    end
    if shipData == nil then
         return
    end
    InShipMode = true
    shipAddonData = {}
    mapRenderer.hideDots()
    mapRenderer.renderPlayerMarker()
    for _, ship in pairs(shipData) do
        if shipIndexVisited[ship.index] == nil or ship.index == trackedShipId then
            local locData = makeLocData(ship, ship.index)
            table.insert(shipAddonData, locData)
            local icon = (ship.index == trackedShipId) and "ship3.png" or "ship.png"
            mapRenderer.renderDot(locData, 1, icon)
        end
    end
    shipsHelper.CreateNextShipButton()
end

return shipsHelper