---@diagnostic disable: undefined-global
local api = require("api")

local mapsHelper = {}

local helpers = require("WorldSatNav/helpers")
local coordinates = require("WorldSatNav/coordinates")
local shapes = require("WorldSatNav/shapes")

local nextMapButton = nil

local function setNextButtonVisible(visible)
    if nextMapButton == nil then return end
    nextMapButton:Show(visible)
    nextMapButton:Enable(visible)
end

-- Squared decimal-degree distance between a map item and the current player coords
local function distSqToPlayer(info, curCoords)
    local lon1 = coordinates.toDecimalDegrees(info.longitudeDir, info.longitudeDeg or 0, info.longitudeMin or 0, info.longitudeSec or 0)
    local lat1 = coordinates.toDecimalDegrees(info.latitudeDir,  info.latitudeDeg  or 0, info.latitudeMin  or 0, info.latitudeSec  or 0)
    local lon2 = coordinates.toDecimalDegrees(curCoords.longitude, curCoords.deg_long or 0, curCoords.min_long or 0, curCoords.sec_long or 0)
    local lat2 = coordinates.toDecimalDegrees(curCoords.latitude,  curCoords.deg_lat  or 0, curCoords.min_lat  or 0, curCoords.sec_lat  or 0)
    return (lon1 - lon2)^2 + (lat1 - lat2)^2
end

-- Find the next closest unvisited map in the player's current region and start tracking it
mapsHelper.GetNextMap = function()
    local curCoords = api.Map:GetPlayerSextants()
    if curCoords == nil then
        api.Log:Info("WorldSatNav: Cannot get player position")
        return
    end

    local x,y = coordinates.getMapDrawPoint(
        curCoords.longitude, curCoords.latitude,
        curCoords.deg_long or 0, curCoords.min_long or 0, curCoords.sec_long or 0,
        curCoords.deg_lat  or 0, curCoords.min_lat  or 0, curCoords.sec_lat  or 0
    )
	local playerRegion = shapes.getShapeAt(x, y)
    if playerRegion == nil then
        api.Log:Info("WorldSatNav: Cannot determine player region")
        return
    end

    -- Collect all inventory maps that belong to the player's region
    local regionMaps = {}
    if playerRegion ~= "?" then
        helpers.iterateTreasureMaps(function(_, _, info)
            local x,y = coordinates.getMapDrawPoint(
                info.longitudeDir, info.latitudeDir,
                info.longitudeDeg or 0, info.longitudeMin or 0, info.longitudeSec or 0,
                info.latitudeDeg  or 0, info.latitudeMin  or 0, info.latitudeSec  or 0
            )
            local region = shapes.getShapeAt(x, y)
            if region == playerRegion then
                table.insert(regionMaps, info)
            end
        end)
    end
    if #regionMaps == 0 then
        api.Log:Info("WorldSatNav: No maps found in player region " .. playerRegion .." open map and select next")
        return
    end

    -- Sort ascending by distance from the player
    table.sort(regionMaps, function(a, b)
        return distSqToPlayer(a, curCoords) < distSqToPlayer(b, curCoords)
    end)

    local selected = regionMaps[1]
    START_MAP_TRACKING(selected, false)
    setNextButtonVisible(true)
end

function mapsHelper.SelectedMapClicked(mapInfo)
    if mapInfo == nil then return end
    START_MAP_TRACKING(mapInfo, true)
    setNextButtonVisible(true)
end

function mapsHelper.HideNextMapButton()
    setNextButtonVisible(false)
end

function mapsHelper.RestoreNextMapButton()
    setNextButtonVisible(true)
end

function mapsHelper.CreateNextMapButton()
    if nextMapButton ~= nil then return end
    if TRACK_WINDOW == nil then return end

    -- Position alongside the Next Ship button (which sits at x=10); place this one to its right
    nextMapButton = helpers.createButton("NextMapButton", TRACK_WINDOW, "Next Map", 70, TRACK_WINDOW:GetHeight() + 3)

    function nextMapButton:OnClick()
        mapsHelper.GetNextMap()
    end
    nextMapButton:SetHandler("OnClick", nextMapButton.OnClick)
    setNextButtonVisible(false)
end

return mapsHelper
