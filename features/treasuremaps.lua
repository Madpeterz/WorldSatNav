
local api = require("api")
local helpers = require("WorldSatNav/helpers")
local regionmap = require("WorldSatNav/ui/regionmap")
local constants = require("WorldSatNav/core/constants")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")
local maprendering = require("WorldSatNav/ui/maprendering")
local tracking = require("WorldSatNav/features/tracking")
local settings = require("WorldSatNav/core/settings")
local treasuremaps = {}

local BAG_POLL_INTERVAL = 100
local bagIsVisible = false
local bagPollElapsed = 0
local lastBagSignature = nil
local lastBagSignatureAge = 0
local bagUpdatePending = false
local bagUpdateDebounceElapsed = 0
local BAG_UPDATE_DEBOUNCE = 300

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

local function renderMapFromStorage(sextant, count, grade)
	local textureCount = count
	if textureCount > 3 then
		textureCount = 3
	end
	return {
		sextant = sextant,
		texture = "icons/marker"..textureCount..".png",
		sourceType = "Map",
		customIconSize = 7,
		count = count,
		grade = grade,
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
            grouppedMaps[key] = {count = 1, sextant = mapSextant, grade = info.grade}
		end
	end)
	local bulkRenderData = {}
	for _, mapInfo in pairs(grouppedMaps) do
		table.insert(bulkRenderData, renderMapFromStorage(mapInfo.sextant, mapInfo.count, mapInfo.grade))
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
        tracking.AssignNextButton(nil, nil)
        return
    end
	-- Next map behavior: 1 = nearest in my region only, 2 = nearest anywhere, 3 = my region first then anywhere
	local nextMapMode = settings.Get("NextMapMode") or 1
	local playerRegionCode, playerRegionName = regionmap.GetRegionForSextant(curCoords)
	local haveRegion = playerRegionCode ~= nil and playerRegionName ~= nil and playerRegionCode ~= "?"
	if nextMapMode == 1 and not haveRegion then
		helpers.DevLog("GetNextMap abort: player region unknown (mode 1)")
		api.Log:Info("WorldSatNav: Cannot determine player region, open map and select next map")
		tracking.AssignNextButton(nil, nil)
		return
	end

	-- Collect inventory maps, split into those in the player's region and all of them
	local regionMaps = {}
	local allMaps = {}
	local mapregioncounters = {}
	local gradeBySextantKey = {}
	helpers.iterateTreasureMaps(function(_, _, info)
		local sextant = SextantFromInfo(info)
		local _, mapRegionName = regionmap.GetRegionForSextant(sextant)
		local SextantKey = helpers.SextantKey(sextant)
		if string.sub(SextantKey, 1, 5) == "W1217" then
			helpers.DevLog("Found map in inventory with region: " .. tostring(mapRegionName).." "..SextantKey)
		end
		mapregioncounters[mapRegionName] = (mapregioncounters[mapRegionName] or 0) + 1
		gradeBySextantKey[SextantKey] = info.grade
		table.insert(allMaps, sextant)
		if haveRegion and mapRegionName == playerRegionName then
			table.insert(regionMaps, sextant)
		end
	end)
	helpers.DebugDumpValue("Treasure maps found in inventory by region", mapregioncounters)

	-- Pick the candidate pool based on the configured behavior
	local candidateMaps
	if nextMapMode == 2 then
		candidateMaps = allMaps
	elseif nextMapMode == 3 then
		candidateMaps = (#regionMaps > 0) and regionMaps or allMaps
	else
		candidateMaps = regionMaps
	end

	if #candidateMaps == 0 then
		helpers.DevLog("GetNextMap abort: no candidate maps for mode " .. tostring(nextMapMode))
		api.Log:Info("WorldSatNav: No treasure maps to track, open map and select next")
		tracking.AssignNextButton(nil, nil)
		return
	end

	-- Sort ascending by distance from the player
	table.sort(candidateMaps, function(a, b)
		return helpers.distSqToPlayer(a, curCoords) < helpers.distSqToPlayer(b, curCoords)
	end)
	local targetKey = helpers.SextantKey(candidateMaps[1])
	local mapsAtLocation = 0
	for _, sextant in ipairs(candidateMaps) do
		if helpers.SextantKey(sextant) == targetKey then
			mapsAtLocation = mapsAtLocation + 1
		end
	end
	local targetDisplayName = "Map (" .. mapsAtLocation .. ")"
	local targetGrade = gradeBySextantKey[targetKey]
	if targetGrade ~= nil then
		targetDisplayName = targetDisplayName .. " [" .. targetGrade .. "]"
	end
	eventbus.TriggerEvent(eventtopics.topics.tracking.custom, candidateMaps[1], "Map", true,
		targetDisplayName)
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
			if regionGroup ~= nil then
				local spaceIndex = string.find(regionGroup, " ")
				if spaceIndex ~= nil then
					regionGroup = string.sub(regionGroup, 1, spaceIndex - 1)
				end
			end
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

function treasuremaps.handleBagUpdate()
	-- debounced: each event resets the timer, so a burst of BAG_UPDATE events
	-- only triggers a signature refresh once activity settles for BAG_UPDATE_DEBOUNCE ms
	bagUpdatePending = true
	bagUpdateDebounceElapsed = 0
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
	if bagUpdatePending then
		bagUpdateDebounceElapsed = bagUpdateDebounceElapsed + dt
		if bagUpdateDebounceElapsed >= BAG_UPDATE_DEBOUNCE then
			bagUpdatePending = false
			bagUpdateDebounceElapsed = 0
			lastBagSignature = nil
			lastBagSignatureAge = 0
			helpers.DevLog("Expired bag signature due to update (debounced)")
		end
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
		if lastBagSignatureAge > (BAG_POLL_INTERVAL * 500) then
			lastBagSignature = nil
			lastBagSignatureAge = 0
			helpers.DevLog("Expired bag signature due to age")
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
	eventbus.WatchEvent(eventtopics.topics.bag.updated, treasuremaps.handleBagUpdate, "treasuremaps")
	eventbus.WatchEvent(eventtopics.topics.bag.itemRemoved, treasuremaps.handleBagUpdate, "treasuremaps")
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