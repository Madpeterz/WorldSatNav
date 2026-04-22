
local api = require("api")
local helpers = require("WorldSatNav/helpers")
local regionmap = require("WorldSatNav/regionmap")
local constants = require("WorldSatNav/constants")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")
local maprendering = require("WorldSatNav/maprendering")
local tracking = require("WorldSatNav/tracking")
local treasuremaps = {}

local BAG_POLL_INTERVAL = 100
local bagIsVisible = false
local bagPollElapsed = 0
local lastBagSignature = nil
local lastBagSignatureAge = 0

local BagIconStorage = {}
local MainUIWindow = nil

local function SextantFromInfo(info)
	local sextant = {}
	sextant.longitude = info.longitudeDir
	sextant.latitude = info.latitudeDir
	sextant.deg_long = info.longitudeDeg
	sextant.min_long = info.longitudeMin
	sextant.sec_long = info.longitudeSec
	sextant.deg_lat =   info.latitudeDeg
	sextant.min_lat =  info.latitudeMin
	sextant.sec_lat = info.latitudeSec
	return sextant
end

local function renderMapFromStorage(sextant, count)
	if count > 3 then
		count = 3
	end
	return {
		sextant = sextant,
		texture = "icons/marker"..count..".png",
		sourceType = "Map",
		customIconSize = 7,
	}
end

local lastSentSignature = nil
function treasuremaps.RequestMapsForRender()
	local grouppedMaps = {}
    helpers.iterateTreasureMaps(function(_, _, info)
		local mapSextant = SextantFromInfo(info)
        local key = helpers.SextantKey(mapSextant)
        if grouppedMaps[key] ~= nil then
            grouppedMaps[key].count = grouppedMaps[key].count + 1
		else
            grouppedMaps[key] = {count = 1, sextant = mapSextant}
		end
	end)
	local bulkRenderData = {}
	for _, mapInfo in pairs(grouppedMaps) do
		table.insert(bulkRenderData, renderMapFromStorage(mapInfo.sextant, mapInfo.count))
	end
	eventbus.TriggerEvent(eventtopics.topics.icons.BulkDrawIconsAndRedraw, bulkRenderData)
	lastSentSignature = treasuremaps.GetRenderCode()
end

function treasuremaps.GetNextMap()
	helpers.DevLog("GetNextMap called")
    local curCoords = api.Map:GetPlayerSextants()
    if curCoords == nil then
		helpers.DevLog("GetNextMap abort: player sextants nil")
        api.Log:Info("WorldSatNav: Cannot get player position")
        return
    end
	local playerRegionCode, playerRegionName = regionmap.GetRegionForSextant(curCoords)
    if playerRegionCode == nil or playerRegionName == nil then
		helpers.DevLog("GetNextMap abort: player region unknown")
        api.Log:Info("WorldSatNav: Cannot determine player region")
        return
    end

    -- Collect all inventory maps that belong to the player's region
    local regionMaps = {}
    if playerRegionCode == "?" then
		helpers.DevLog("GetNextMap abort: player region code '?' ")
		api.Log:Info("WorldSatNav: Player region unknown, showing all maps in inventory, open map and select next map")
		return
	end
	local mapregioncounters = {}
	helpers.iterateTreasureMaps(function(_, _, info)
		local sextant = SextantFromInfo(info)
		local _, mapRegionName = regionmap.GetRegionForSextant(sextant)
		local SextantKey = helpers.SextantKey(sextant)
		if string.sub(SextantKey, 1, 5) == "W1217" then
			helpers.DevLog("Found map in inventory with region: " .. tostring(mapRegionName).." "..SextantKey)
		end
		mapregioncounters[mapRegionName] = (mapregioncounters[mapRegionName] or 0) + 1
		if mapRegionName == playerRegionName then
			table.insert(regionMaps, sextant)
		end
	end)
	helpers.DebugDumpValue("Treasure maps found in inventory by region", mapregioncounters)
    if #regionMaps == 0 then
		helpers.DevLog("GetNextMap abort: no maps found in region " .. tostring(playerRegionName))
        api.Log:Info("WorldSatNav: No maps found in player region " .. playerRegionName .." open map and select next")
        return
    end

    -- Sort ascending by distance from the player
    table.sort(regionMaps, function(a, b)
        return helpers.distSqToPlayer(a, curCoords) < helpers.distSqToPlayer(b, curCoords)
    end)
	eventbus.TriggerEvent(eventtopics.topics.tracking.custom, regionMaps[1], "Next map in region: " .. playerRegionName, true)
end

local function GetBagIconForIndex(slotIndex, SlotBtn)
	if BagIconStorage[slotIndex] ~= nil then
		return BagIconStorage[slotIndex]
	end
	local overlayName = "tmOverlay_" .. slotIndex
	local overlay = SlotBtn:CreateChildWidget("label", overlayName, 0, true)
	overlay:SetExtent(SlotBtn:GetWidth(), constants.overlay.height)
	overlay.style:SetFontSize(constants.overlay.fontSize)
	overlay.style:SetAlign(ALIGN.CENTER)
	overlay.style:SetShadow(true)
	overlay.bg = overlay:CreateColorDrawable(0, 0, 0, 0, "background")
	overlay.bg:AddAnchor("TOPLEFT", overlay, 0, 0)
	overlay.bg:AddAnchor("BOTTOMRIGHT", overlay, 0, 0)
	BagIconStorage[slotIndex] = overlay
	return overlay
end

local function hideBagOverlay()
	for _, icon in pairs(BagIconStorage) do
		if icon:IsVisible() == true then
			icon:Show(false)
		end
	end
end

local function showBagOverlay()
	local UsedBagIndexIcons = {}
	helpers.DevLog("Showing bag overlay, iterating bag items to determine which slots to show")
    helpers.iterateTreasureMaps(function(slotIndex, btn, info)
		local sextant = SextantFromInfo(info)
		local code, name = regionmap.GetRegionForSextant(sextant)
		local regionGroup = "?"
		if code == "N" then
			regionGroup = "Auroria"
		elseif code == "W" then
			regionGroup = "Nuia"
		elseif code == "E" then
			regionGroup = "Haranya"
		elseif code == "Sea" then
			regionGroup = name
		else
			regionGroup = "?"
		end
		local regionColorCode = constants.regionColors[regionGroup] or constants.regionColors["?"]
		UsedBagIndexIcons[slotIndex] = true
		local icon = GetBagIconForIndex(slotIndex, btn)
		icon:RemoveAllAnchors()
		icon:AddAnchor("BOTTOM", btn, 0, constants.overlay.heightOffset)
		icon:SetText(regionGroup)
		icon.bg:SetColor(unpack(regionColorCode))
		icon:Show(true)
	end)
	for slotIndex, icon in pairs(BagIconStorage) do
		if UsedBagIndexIcons[slotIndex] ~= true then
			icon:Show(false)
		end
	end
end

local function BuildBagSignature()
    local bagFrame = ADDON:GetContent(UIC.BAG)
    if not bagFrame or not bagFrame.slots or not bagFrame.slots.btns then
		helpers.DevLog("Bag frame or slots not found, cannot build bag signature")
        return nil
    end

    local entries = {}
	local slotIndexes = {}
	for slotIndex in pairs(bagFrame.slots.btns) do
		slotIndexes[#slotIndexes + 1] = slotIndex
	end
	table.sort(slotIndexes, function(a, b)
		local numericA = tonumber(a)
		local numericB = tonumber(b)
		if numericA ~= nil and numericB ~= nil then
			return numericA < numericB
		end
		return tostring(a) < tostring(b)
	end)

	for _, slotIndex in ipairs(slotIndexes) do
		local btn = bagFrame.slots.btns[slotIndex]
        local info = btn:GetInfo()
        if info ~= nil and info.name == constants.game.treasureMapItemName then
            local sextant = SextantFromInfo(info)
			local instanceToken = tostring(info.id or info.itemId or info.guid or info.uuid or info.serial or "")
			entries[#entries + 1] = tostring(slotIndex) .. ":" .. helpers.SextantKey(sextant) .. ":" .. instanceToken
        end
    end

	-- Use the canonical signature directly to avoid hash collisions.
	return table.concat(entries, ";")
end

local function CheckBagDisplayStatus()
    local bagFrame = ADDON:GetContent(UIC.BAG)
    if not bagFrame then
        return false
    end
    if bagFrame.IsVisible then
        return bagFrame:IsVisible()
    end
    return false
end

local UsingFlashMode = false
local selectedItem = nil

local function ExitFlashModeIfActive()
	if selectedItem ~= nil then
		maprendering.ExitFlashMode()
		selectedItem = nil
	end
end

local function FlashModeTick()
    local currentItemSelected = api.Cursor:GetCursorInfo()
	if currentItemSelected == nil then
		ExitFlashModeIfActive()
		return
	end
	local currentItemIndex = api.Cursor:GetCursorPickedBagItemIndex()
	if currentItemIndex == nil then
		ExitFlashModeIfActive()
		return
	end
	local currentItemStore = api.Bag:GetBagItemInfo(1, currentItemIndex)
	if currentItemStore == nil then
		ExitFlashModeIfActive()
		return
	end
	if currentItemStore.name == nil then
		ExitFlashModeIfActive()
		return
	end
	if currentItemStore.name ~= constants.game.treasureMapItemName then
		ExitFlashModeIfActive()
		return
	end
	local currentItemSextant = SextantFromInfo(currentItemStore)
	local currentItemKey = helpers.SextantKey(currentItemSextant)
	if currentItemKey ~= selectedItem then
		selectedItem = currentItemKey
		maprendering.FlashModeIcon(currentItemSextant, "icons/marker1.png", "Map", 10)
	end
end

function treasuremaps.onUpdate(dt)
    bagPollElapsed = bagPollElapsed + dt
    if bagPollElapsed < BAG_POLL_INTERVAL then
        return
    end
	bagPollElapsed = 0
	bagIsVisible = CheckBagDisplayStatus()
	if bagIsVisible == false then
		hideBagOverlay()
		lastBagSignature = nil
		return
	end
	if maprendering.MapUI:IsVisible() == false then
		hideBagOverlay()
		lastBagSignature = nil
		return
	end
	FlashModeTick()

    local currentSignature = BuildBagSignature()
    if currentSignature == nil then
        return
    end
    if currentSignature == lastBagSignature then
		lastBagSignatureAge = lastBagSignatureAge + BAG_POLL_INTERVAL
		if lastBagSignatureAge > (BAG_POLL_INTERVAL * 250) then
			lastBagSignature = nil
			lastBagSignatureAge = 0
			helpers.DevLog("Expired bag signature")
		end
        return
    end
    lastBagSignature = currentSignature
	lastBagSignatureAge = 0
	helpers.DevLog("Bag content changed, new signature: " .. currentSignature)
	if lastSentSignature ~= nil and currentSignature ~= lastSentSignature then
		helpers.DevLog("Bag signature differs from last sent map render signature, triggering map redraw")
		if maprendering.GetCurrentMode() == "maps" then
			helpers.DevLog("Current map mode is 'maps', triggering map redraw to update treasure map icons")
			maprendering.RequestModeRedraw()
		end
	end
    showBagOverlay()
end

function treasuremaps.OnLoad()
	eventbus.WatchEvent(eventtopics.topics.render.maps, treasuremaps.RequestMapsForRender, "treasuremaps")
	eventbus.WatchEvent(eventtopics.topics.UI.MainUILoaded, function(MainUI)
		MainUIWindow = MainUI
	end, "treasuremaps")
	eventbus.WatchEvent(eventtopics.topics.tracking.nextMap, treasuremaps.GetNextMap, "treasuremaps")
end

function treasuremaps.OnUnload()
	hideBagOverlay()
	for _, icon in pairs(BagIconStorage) do
		api.Interface:Free(icon)
	end
end

function treasuremaps.GetRenderCode()
	return BuildBagSignature()
end

return treasuremaps