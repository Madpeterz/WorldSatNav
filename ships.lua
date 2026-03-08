local api = require("api")

local shipsHelper = {}
local mapRenderer = require("WorldSatNav/map_renderer")
local helpers = require("WorldSatNav/helpers")
local settings = require("WorldSatNav/settings")

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
local function makeLocData(ship)
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
        id = ship.index,
        index = ship.index,
        nextindex = ship.nextindex,
        group = ship.group
    }
end

-- Finds the raw ship entry by index
local function findShipByIndex(idx)
    if shipData == nil then
        return nil
    end
    for _, ship in pairs(shipData) do
        if ship.index == idx then return ship end
    end
    return nil
end

-- Returns the first unvisited ship in the given group by walking the nextindex
-- chain from startShip within that group, then falling back to a full group scan.
local function findUnvisitedInGroup(group, startShip)
    -- Walk chain within group
    local seen = { [startShip.index] = true }
    local cur = startShip
    while true do
        local next = findShipByIndex(cur.nextindex)
        if next == nil or seen[next.index] or next.group ~= group then break end
        seen[next.index] = true
        if shipIndexVisited[next.index] == nil then return next end
        cur = next
    end
    if shipData == nil then
        return nil
    end
    -- Fallback: any unvisited in the group
    for _, ship in pairs(shipData) do
        if ship.group == group and shipIndexVisited[ship.index] == nil then
            return ship
        end
    end
    return nil
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

    local currentGroup = lastVistitedShip.group
    local startShip = findShipByIndex(lastVistitedShip.index)

    -- Step 1: stay in the current group if any unvisited ships remain in it
    if currentGroup ~= nil and startShip ~= nil then
        local candidate = findUnvisitedInGroup(currentGroup, startShip)
        if candidate ~= nil then
            StartNextShipTracking(makeLocData(candidate))
            return
        end
    end

    -- Step 2: current group is exhausted – before advancing, check lower-numbered
    -- groups for any unvisited ships (descending: e.g. group 2, then group 1, before group 4).
    if startShip == nil then
        api.Log:Info("No last visited ship found please select a ship manually")
        return
    end

    if currentGroup ~= nil then
        local allGroups = {}
        local groupSet = {}
        for _, ship in pairs(shipData) do
            if ship.group ~= nil and not groupSet[ship.group] then
                groupSet[ship.group] = true
                table.insert(allGroups, ship.group)
            end
        end
        table.sort(allGroups)
        -- Iterate descending so we check the closest lower group first
        for i = #allGroups, 1, -1 do
            local g = allGroups[i]
            if g < currentGroup then
                for _, ship in pairs(shipData) do
                    if ship.group == g then
                        local candidate = findUnvisitedInGroup(g, ship)
                        if candidate ~= nil then
                            StartNextShipTracking(makeLocData(candidate))
                            return
                        end
                        break
                    end
                end
            end
        end
    end

    -- Step 3: no lower group has unvisited ships – walk the nextindex chain to find
    -- the next higher group that still has unvisited ships.
    local startedAtIndex = startShip.index
    local seenDuringTraversal = {}
    local groupsChecked = {}
    if currentGroup ~= nil then groupsChecked[currentGroup] = true end

    local cur = startShip
    while true do
        local next = findShipByIndex(cur.nextindex)

        if next == nil or next.index == startedAtIndex or seenDuringTraversal[next.index] then
            api.Log:Info("No more unvisited ships found. toggle Show Ships to reset")
            return
        end

        seenDuringTraversal[next.index] = true

        local nextGroup = next.group
        if nextGroup ~= nil and not groupsChecked[nextGroup] then
            groupsChecked[nextGroup] = true
            -- Check this whole new group for unvisited ships
            local candidate = findUnvisitedInGroup(nextGroup, next)
            if candidate ~= nil then
                StartNextShipTracking(makeLocData(candidate))
                return
            end
            -- All visited in this group too – keep following the chain
        elseif nextGroup == nil and shipIndexVisited[next.index] == nil then
            StartNextShipTracking(makeLocData(next))
            return
        end

        cur = next
    end
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
            local locData = makeLocData(ship)
            table.insert(shipAddonData, locData)
            local icon = (ship.index == trackedShipId) and "ship3.png" or "ship.png"
            mapRenderer.renderDot(locData, 1, icon)
        end
    end
    shipsHelper.CreateNextShipButton()
end

return shipsHelper