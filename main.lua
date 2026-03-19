-- WorldSatNav Main Module
-- Orchestrates all components and provides addon lifecycle management

local api = require("api")
local constants = require("WorldSatNav/constants")
local coordinates = require("WorldSatNav/coordinates")
local bagOverlay = require("WorldSatNav/bag_overlay")
local mapRenderer = require("WorldSatNav/map_renderer")
local gps = require("WorldSatNav/gps")
local uiWindows = require("WorldSatNav/ui_windows")
local ships = require("WorldSatNav/ships")
local settings = require("WorldSatNav/settings")
local helpers = require("WorldSatNav/helpers")
local events = require("WorldSatNav/events")
local regions = require("WorldSatNav/regions")
local shapes = require("WorldSatNav/shapes")

local WorldSatNav = {
	name = "WorldSatNav",
	author = "Madpeter",
	version = "1.0.4",
	desc = "Lets fucking go!"
}

-- Module state
local satNavWindow = nil
local overlayWnd = nil
TRACK_WINDOW = nil
local lastUpdate = 0

-- Handle map click to select closest treasure map marker for GPS tracking

local function ReRenderMap()
	if ships.IsInShipMode() then
		ships.DisplayShips(true)
		ships.RestoreNextShipButton()
	elseif events.InEventsMode() then
		events.DisplayEvents(true)
	else
		mapRenderer.render()
	end
end


local function getNearestMarker(mapX, mapY)
	local closestMarker = nil
	local closestDistance = math.huge

	local dataSource = {}
	if ships.IsInShipMode() then
		dataSource = ships.getShipData() or {}
	elseif events.InEventsMode() then
		dataSource = events.getEventData() or {}
	else 
		helpers.iterateTreasureMaps(function(_, _, info)
			table.insert(dataSource, info)
		end)
	end

	for _, info in pairs(dataSource) do
		local xPos, yPos = coordinates.getMapDrawPoint(
			info.longitudeDir, info.latitudeDir,
			info.longitudeDeg or 0, info.longitudeMin or 0, info.longitudeSec or 0,
			info.latitudeDeg or 0, info.latitudeMin or 0, info.latitudeSec or 0
		)

		local distance = math.sqrt((xPos - mapX)^2 + (yPos - mapY)^2)
		if distance < closestDistance then
			closestDistance = distance
			closestMarker = info
		end
	end
	
	-- If clicked within 30 pixels of a marker, start tracking		
	if closestDistance < 30 and closestMarker then
		if ships.IsInShipMode() then
			ships.SelectedShipClicked(closestMarker)
		elseif events.InEventsMode() then
			START_MAP_TRACKING(closestMarker)
		else
			START_MAP_TRACKING(closestMarker)
		end
	end
end

local zoomedIn = false
local settingsControls = {}

local lastVisableMode = false
local function toggleSettingsVisableZoom()
	local newMode = zoomedIn
	if lastVisableMode == newMode then
		return
	end
	lastVisableMode = newMode
	for _, control in pairs(settingsControls) do
		control:Show(not newMode)
	end
	for id, overlay in pairs(helpers.CheckBoxs) do
		if overlay.radioGroup == "mapMode" then
			helpers.ToggleCheckboxVisable(id, not newMode)
		end
	end
	helpers.ToggleCheckboxVisable("UseTeleportHint", not newMode)
	helpers.ToggleCheckboxVisable("EnableWorldEvents", not newMode)
	helpers.ToggleCheckboxVisable("OpenRealMap", not newMode)
end

local function ZoomMapControls(mapX, mapY)
	if zoomedIn == false then
		local region = regions.getRegionFromPixels(mapX, mapY)
		if region ~= nil then
			coordinates.UpdateRenderingSettings(region.centerPointX, region.centerPointY, 38.2, 39)
			mapRenderer.ChangeMapTexture(region.name)
			zoomedIn = true
		end
	else
		coordinates.ResetRenderingSettings()
		mapRenderer.ChangeMapTexture("*")
		zoomedIn = false
	end
end

local function onMapClick(mapX, mapY)
	if api.Input:IsControlKeyDown() then
		ZoomMapControls(mapX, mapY)
		toggleSettingsVisableZoom()
		ReRenderMap()
		return
	end
	getNearestMarker(mapX, mapY)
end

-- Start GPS tracking for a treasure map
function START_MAP_TRACKING(itemData, ShowMapMarker)
	if itemData == nil then
		return
	end

	bagOverlay.hide()
	
	-- Set GPS target
	local targetType = "?"
	if(itemData.grade ~= nil) then
		targetType = "Map " .. itemData.grade..""
	elseif(itemData.isship ~= nil) then
		targetType = "Ship ".. itemData.index .." (group ".. itemData.group ..")"
	elseif(itemData.isevent ~= nil) then
		targetType = "Event ".. itemData.type
	end
	gps.setTarget(itemData, targetType)
	
	-- Open world map to the location
	local xMap = coordinates.longitudeSextantToDegrees(
		itemData.longitudeDir,
		itemData.longitudeDeg or 0,
		itemData.longitudeMin or 0,
		itemData.longitudeSec or 0
	)
	local yMap = coordinates.latitudeSextantToDegrees(
		itemData.latitudeDir,
		itemData.latitudeDeg or 0,
		itemData.latitudeMin or 0,
		itemData.latitudeSec or 0
	)
	local useMapMarker = ShowMapMarker == nil or ShowMapMarker
	if useMapMarker then
		if settings.Get("OpenRealMap") == true then
			api.Map:ToggleMapWithPortal(constants.game.portalZoneId, xMap, yMap, constants.game.portalZoomLevel)
		end
		if satNavWindow ~= nil then
			satNavWindow:Show(false)
		end
	end
	api.Log:Info("GPS active going to " .. targetType)
	if TRACK_WINDOW ~= nil then 
		TRACK_WINDOW:Show(true)
	end
end

-- Handle tracking window close
local function onTrackingWindowClose()
	gps.clearTarget()
end

local lastArrowDir = ""
local function updateNavArrow(direction)
	if TRACK_WINDOW == nil or TRACK_WINDOW.arrow == nil then
		return
	end
	if direction == lastArrowDir then
		return
	end
	lastArrowDir = direction
	local arrowPath = api.baseDir .. "/WorldSatNav/images/arrows/" .. direction .. ".png"
	TRACK_WINDOW.arrow:SetTexture(arrowPath)
end

-- Update tracking window display
local function updateTrackingData()
	if TRACK_WINDOW == nil or not TRACK_WINDOW:IsVisible() or not gps.hasTarget() then
		return
	end
	
	local curCoords = api.Map:GetPlayerSextants()
	local targetSextant = gps.getTargetSextant()
	
	if targetSextant == nil then
		return
	end
	
	-- Check if teleport is needed (different regions)
	local bkScaleHX  = coordinates.renderingSettings.scaleHX
	local bkScaleHY  = coordinates.renderingSettings.scaleHY
	local bkCenterX  = coordinates.renderingSettings.centerPointX
	local bkCenterY  = coordinates.renderingSettings.centerPointY
	coordinates.ResetRenderingSettings()

	local x,y = coordinates.getMapDrawPoint(
		targetSextant.longitude, targetSextant.latitude,
		targetSextant.deg_long or 0, targetSextant.min_long or 0, targetSextant.sec_long or 0,
		targetSextant.deg_lat or 0, targetSextant.min_lat or 0, targetSextant.sec_lat or 0
	)
	local regionNameTarget = shapes.getShapeAt(x, y)
	x,y = coordinates.getMapDrawPoint(
			curCoords.longitude, curCoords.latitude,
			curCoords.deg_long or 0, curCoords.min_long or 0, curCoords.sec_long or 0,
			curCoords.deg_lat or 0, curCoords.min_lat or 0, curCoords.sec_lat or 0
		)
	local regionNamePlayer = shapes.getShapeAt(x, y)

	coordinates.renderingSettings.scaleHX      = bkScaleHX
	coordinates.renderingSettings.scaleHY      = bkScaleHY
	coordinates.renderingSettings.centerPointX = bkCenterX
	coordinates.renderingSettings.centerPointY = bkCenterY

	regionNameTarget = regionNameTarget:match("/(.+)") or regionNameTarget
	regionNamePlayer = regionNamePlayer:match("/(.+)") or regionNamePlayer
	
	local useTeleport = false
	if regionNamePlayer ~= "?" and regionNameTarget ~= "?" then
		if regionNamePlayer ~= regionNameTarget then
			useTeleport = true
		end
	end

	TRACK_WINDOW.markNameLabel:SetText(gps.getTargetName())
	local navDir, navDistance, navDistanceScale, bearing, relativeDir = gps.getNavigationText()

	if useTeleport and settings.Get("UseTeleportHint") and navDistanceScale ~= "m" then
		TRACK_WINDOW.distanceLabel:SetText("teleport to " .. regionNameTarget)
		updateNavArrow("portal2")
	else
		TRACK_WINDOW.distanceLabel:SetText(string.format("%.1f %s", navDistance, navDistanceScale))
		if navDir == "here" then
			updateNavArrow(navDir)
		else			
			updateNavArrow(relativeDir)
		end
		
	end

	TRACK_WINDOW.distanceLabel:SetMoveEffectType(1, "circle", 0, 0, 0.3, 0.2)
	TRACK_WINDOW.distanceLabel:SetMoveEffectCircle(1, 0, -40)
	TRACK_WINDOW.distanceLabel.style:SetFontSize(60)
end

-- Toggle main window and overlays
function TOGGLE_MAIN_WINDOW()
	if satNavWindow == nil then
		return
	end
	
	local showWnd = not satNavWindow:IsVisible()
	satNavWindow:Show(showWnd)
	
	if showWnd == false then
		bagOverlay.hide()
		events.SetAutoUpdates(false)
	else
		-- reset map zoom when reopening and reset texture
		coordinates.ResetRenderingSettings()
		mapRenderer.ChangeMapTexture("*")
		zoomedIn = false
		toggleSettingsVisableZoom()
		ReRenderMap()
		bagOverlay.show()
	end
end

-- Update loop
local function onUpdate(dt)
	-- Update flash animation on every frame (needs to run at frame rate)
	if satNavWindow ~= nil and satNavWindow:IsVisible() then
		local needsRender = false
		
		-- Handle flash mode item selection
		local currentItemSelected = api.Cursor:GetCursorInfo()
		
		if currentItemSelected == nil then
			-- Clear selection when nothing is being held
			if bagOverlay.hasUsedFlashMode() then
				mapRenderer.setSelectedMapItem(nil)
				bagOverlay.setFlashMode(false)
				bagOverlay.resetFlashModeUsed()
				needsRender = true
			end
		else
			-- Check if holding a treasure map
			local currentItemIndex = api.Cursor:GetCursorPickedBagItemIndex()
			local currentItemStore = api.Bag:GetBagItemInfo(1, currentItemIndex)
			
			if currentItemStore ~= nil and 
			   currentItemStore.name ~= nil and 
			   currentItemStore.name == constants.game.treasureMapItemName then
				
				-- Flash the selected map marker
				bagOverlay.markFlashModeUsed()
				bagOverlay.setFlashMode(true)
				
				-- Only set selected item if it changed (to avoid resetting flash state)
				local currentSelected = mapRenderer.getSelectedMapItem()
				local itemChanged = true
				if currentSelected ~= nil then
					-- Check if it's the same treasure map by comparing coordinates
					if currentSelected.longitudeDir == currentItemStore.longitudeDir and
					   currentSelected.latitudeDir == currentItemStore.latitudeDir and
					   currentSelected.longitudeDeg == currentItemStore.longitudeDeg and
					   currentSelected.longitudeMin == currentItemStore.longitudeMin and
					   currentSelected.longitudeSec == currentItemStore.longitudeSec and
					   currentSelected.latitudeDeg == currentItemStore.latitudeDeg and
					   currentSelected.latitudeMin == currentItemStore.latitudeMin and
					   currentSelected.latitudeSec == currentItemStore.latitudeSec then
						itemChanged = false
					end
				end
				
				if itemChanged then
					mapRenderer.setSelectedMapItem(currentItemStore)
				end
				
				-- Update flash timer (runs every frame for smooth animation)
				mapRenderer.updateFlash(dt)
				needsRender = true
			end
		end
		
		-- Render if flash state changed
		if needsRender then
			ReRenderMap()
		end
	end
	
	-- Throttled updates (run every 500ms)
	lastUpdate = lastUpdate + dt
	if lastUpdate < constants.timing.updateRate then
		return
	end
	lastUpdate = 0
	
	-- Update bag overlays if active
	if bagOverlay.isActive() then
		bagOverlay.update()
	end
	
	-- Update player movement tracking for GPS
	if gps.hasTarget() then
		gps.updateMovementTracking()
		updateTrackingData()
	end
end

-- Addon initialization
local function OnLoad()
	-- Load settings
	settings.LoadSettings()
	-- Create windows
	TRACK_WINDOW = uiWindows.createTRACK_WINDOW(onTrackingWindowClose)
	satNavWindow = uiWindows.createMainWindow(onMapClick, TOGGLE_MAIN_WINDOW)
	overlayWnd = uiWindows.createOverlayButton(TOGGLE_MAIN_WINDOW)
	
	-- Set up OnClose handler for main window
	function satNavWindow:OnClose()
		TOGGLE_MAIN_WINDOW()
	end
	function satNavWindow:EventListener(event, ...)
		if(event == "WORLD_MESSAGE") then 
			events.WorldMessageProcessor(event,unpack(arg))
		elseif(event == "CHAT_MESSAGE") then 
			events.WorldMessageProcessorChat(event,unpack(arg))
		end
	end
	satNavWindow:SetHandler("OnClose", satNavWindow.OnClose)
	satNavWindow:SetHandler("OnCloseByEsc", satNavWindow.OnClose)
	satNavWindow:SetHandler("OnEvent", satNavWindow.EventListener)
    satNavWindow:RegisterEvent("WORLD_MESSAGE")
	satNavWindow:RegisterEvent("CHAT_MESSAGE")
	
	-- Initialize modules
	bagOverlay.initialize()
	mapRenderer.initialize(satNavWindow, satNavWindow.mapDrawable)
	
	
	-- Initial render
	satNavWindow:Show(false)
	mapRenderer.render()

	-- settings
	local mylabel = helpers.createLabel("SettingsTextLabel", satNavWindow, "Settings", 125, 100, 14)
	mylabel:SetExtent(200, 30)
	mylabel.style:SetColor(0, 0, 0, 1)
	mylabel:Show(true)
	table.insert(settingsControls, mylabel)

	helpers.CreateSkinnedCheckbox("UseTeleportHint", satNavWindow, "Use Teleport in tracker", 50, 130+(35*0), settings.Get("UseTeleportHint"), function(checked)
		settings.Update("UseTeleportHint", checked)
	end)

	helpers.CreateSkinnedCheckbox("EnableWorldEvents", satNavWindow, "Enable World Events", 50, 130+(35*1), settings.Get("EnableWorldEvents"), function(checked)
		settings.Update("EnableWorldEvents", checked)
	end)
	helpers.CreateSkinnedCheckbox("OpenRealMap", satNavWindow, "Open Real Map", 50, 130+(35*2), settings.Get("OpenRealMap"), function(checked)
		settings.Update("OpenRealMap", checked)
	end)


	local mylabel2 = helpers.createLabel("SettingsTextLabel2", satNavWindow, "Mode", 125, 120+(35*3), 14)
	mylabel2:SetExtent(200, 30)
	mylabel2.style:SetColor(0, 0, 0, 1)
	mylabel2:Show(true)
	table.insert(settingsControls, mylabel2)

	helpers.CreateSkinnedCheckbox("showMapsCheckbox", satNavWindow, "Maps", 30, 145+(35*3), true, function(checked)
		ships.DisplayShips(false)
		events.DisplayEvents(false)
		mapRenderer.render()
	end, nil, nil, "mapMode")

	helpers.CreateSkinnedCheckbox("showShipCheckbox", satNavWindow, "Ships", 30+75, 145+(35*3), false, function(checked)
		ships.DisplayShips(true)
		events.DisplayEvents(false)
	end, nil, nil, "mapMode")

	helpers.CreateSkinnedCheckbox("ShowEventsCheckbox", satNavWindow, "Events", 30+150, 145+(35*3), false, function(checked)
		ships.DisplayShips(false)
		events.DisplayEvents(true)
	end, nil, nil, "mapMode")

	-- Register update loop
	api.On("UPDATE", onUpdate)
end

-- Addon cleanup
local function OnUnload()
	api.On("UPDATE", function() return end)
	
	-- Clean up modules
	bagOverlay.cleanup()
	mapRenderer.cleanup()
	gps.clearTarget()
	ships.HideNextShipButton()

	-- Clean up windows
	if satNavWindow ~= nil then 
		satNavWindow:ReleaseHandler("OnEvent")
		satNavWindow:Show(false)
		api.Interface:Free(satNavWindow)
		satNavWindow = nil
	end
	if overlayWnd ~= nil then 
		overlayWnd:Show(false)
		api.Interface:Free(overlayWnd)
		overlayWnd = nil
	end
	if TRACK_WINDOW ~= nil then 
		TRACK_WINDOW:Show(false)
		api.Interface:Free(TRACK_WINDOW)
		TRACK_WINDOW = nil
	end
end

WorldSatNav.OnLoad = OnLoad
WorldSatNav.OnUnload = OnUnload

return WorldSatNav