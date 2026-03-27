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
local demos = require("WorldSatNav/demos")
local settings = require("WorldSatNav/settings")
local helpers = require("WorldSatNav/helpers")
local events = require("WorldSatNav/events")
local regions = require("WorldSatNav/regions")
local shapes = require("WorldSatNav/shapes")
local maps = require("WorldSatNav/maps")
local shareddata = require("WorldSatNav/shareddata")

local WorldSatNav = {
	name = "WorldSatNav",
	author = "Madpeter",
	version = "1.0.6",
	desc = "Lets fucking go!"
}

-- Module state
local satNavWindow = nil
local overlayWnd = nil
local gotoWindow = nil
local demoAddButton = nil
local demoWindow = nil
local demoWindowAlert = nil
TRACK_WINDOW = nil
local lastUpdate = 0

-- Handle map click to select closest treasure map marker for GPS tracking

local function ReRenderMap()
	if ships.IsInShipMode() then
		ships.DisplayShips(true)
		ships.RestoreNextShipButton()
		maps.HideNextMapButton()
	elseif demos.InDemoMode() then
		demos.DisplayDemos(true)
		maps.HideNextMapButton()
	elseif events.InEventsMode() then
		events.DisplayEvents(true)
		maps.HideNextMapButton()
	else
		mapRenderer.render()
		maps.RestoreNextMapButton()
	end
end


local function getNearestMarker(mapX, mapY)
	local closestMarker = nil
	local closestDistance = math.huge

	if ships.IsInShipMode() then
		local dataSource = ships.getShipData() or {}
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
		if closestDistance < 30 and closestMarker then
			ships.SelectedShipClicked(closestMarker)
		end
	elseif demos.InDemoMode() then
		local dataSource = demos.getDemoData() or {}
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
		if closestDistance < 30 and closestMarker then
			START_MAP_TRACKING(closestMarker)
		end
	elseif events.InEventsMode() then
		local dataSource = events.getEventData() or {}
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
		if closestDistance < 30 and closestMarker then
			START_MAP_TRACKING(closestMarker)
		end
	else
		-- Use rendered dot positions directly to ensure consistent coordinates
		for _, marker in pairs(mapRenderer.getRenderedDots()) do
			if marker:IsVisible() and marker.ItemData ~= nil and marker.drawX ~= nil then
				local distance = math.sqrt((marker.drawX - mapX)^2 + (marker.drawY - mapY)^2)
				if distance < closestDistance then
					closestDistance = distance
					closestMarker = marker.ItemData
				end
			end
		end
		if closestDistance < 30 and closestMarker then
			maps.SelectedMapClicked(closestMarker)
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
		if overlay.radioGroup == "trackMode" then
			helpers.ToggleCheckboxVisable(id, not newMode)
		end
	end
	helpers.ToggleCheckboxVisable("UseTeleportHint", not newMode)
	helpers.ToggleCheckboxVisable("EnableWorldEvents", not newMode)
	helpers.ToggleCheckboxVisable("OpenRealMap", not newMode)
	helpers.ToggleCheckboxVisable("EnableLocationOutput", not newMode)
	helpers.ToggleCheckboxVisable("EnableAlertDemo", not newMode)
	helpers.ToggleCheckboxVisable("showDemoCreatePlus", not newMode)
	helpers.ToggleCheckboxVisable("DrawDemosInNextHour", not newMode)
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
		local selectedx, selectedy = coordinates.getMapDrawPoint(
			itemData.longitudeDir, itemData.latitudeDir,
			itemData.longitudeDeg or 0, itemData.longitudeMin or 0, itemData.longitudeSec or 0,
			itemData.latitudeDeg or 0, itemData.latitudeMin or 0, itemData.latitudeSec or 0
		)
		local counter = 0
    	helpers.iterateTreasureMaps(function(_, _, info)
			local x,y = coordinates.getMapDrawPoint(
				info.longitudeDir, info.latitudeDir,
				info.longitudeDeg or 0, info.longitudeMin or 0, info.longitudeSec or 0,
				info.latitudeDeg  or 0, info.latitudeMin  or 0, info.latitudeSec  or 0
			)
			if x == selectedx and y == selectedy then
				counter = counter + 1
			end
		end)
		targetType = targetType .. " (" .. counter .. ")"
	elseif(itemData.isship ~= nil) then
		targetType = "Ship ".. itemData.index .." (group ".. itemData.group ..")"
	elseif(itemData.isdemo ~= nil) then
		targetType = "Building demo"
	elseif(itemData.isevent ~= nil) then
		targetType = "Event ".. itemData.type
	elseif(itemData.iscustom ~= nil) then
		targetType = "Custom location"
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
	local arrowPath = api.baseDir .. "/WorldSatNav/images/arrows6/" .. direction .. ".png"
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
		if settings.Get("trackingMode") == "compass" then
			updateNavArrow(navDir)
		elseif settings.Get("trackingMode") == "guide" then	
			if navDir == "here" then
				updateNavArrow(navDir)
			else			
				updateNavArrow(relativeDir)
			end
		end
	end

	TRACK_WINDOW.distanceLabel:SetMoveEffectType(1, "circle", 0, 0, 0.3, 0.2)
	TRACK_WINDOW.distanceLabel:SetMoveEffectCircle(1, 0, -40)
	TRACK_WINDOW.distanceLabel.style:SetFontSize(60)
end

local function DEMO_ALERT_TOGGLE(demoentry)
	if demoWindowAlert == nil then 
		helpers.DevLog("Demo alert window not initialized yet")
		return
	end
	demoWindowAlert.targetInfo = demoentry
	if demoWindowAlert:IsVisible() == false and demoWindowAlert.targetInfo ~= nil then
		helpers.DevLog("Showing demo alert for demo starting at " .. tostring(demoentry.startat))
		demoWindowAlert.remainingSeconds = math.max(0, (demoentry.startat or 0) - helpers.GetCurrentTimestamp())
		demoWindowAlert.elapsedSinceStartSeconds = math.max(0, helpers.GetCurrentTimestamp() - (demoentry.startat or 0))
		demoWindowAlert:Show(true)
		local x, y = coordinates.getMapDrawPoint(
			demoentry.longitudeDir, demoentry.latitudeDir,
			demoentry.longitudeDeg or 0, demoentry.longitudeMin or 0, demoentry.longitudeSec or 0,
			demoentry.latitudeDeg or 0, demoentry.latitudeMin or 0, demoentry.latitudeSec or 0
		)
		local regionname = shapes.getShapeAt(x, y) or "[?]"
		regionname = regionname:match("/(.+)") or regionname
		demoWindowAlert.regionLabel:SetText(regionname)
		demoWindowAlert.ownerLabel:SetText(demoentry.ownername or "[?]")
		demoWindowAlert.buildingLabel:SetText(demoentry.buildingname or "[?]")
		demoWindowAlert.timetostart:SetText("[?]")
	else
		demoWindowAlert.remainingSeconds = nil
		demoWindowAlert.elapsedSinceStartSeconds = nil
		demoWindowAlert:Show(false)
	end
end

local function DEMO_ALERT_TRIGGER_CHECK()
	if demoWindowAlert == nil or settings.Get("EnableAlertDemo") == false or demoWindowAlert.targetInfo ~= nil then 
		return
	end
	local targetInfo = demos.getNextAlert()
	if targetInfo ~= nil then
		helpers.DevLog("Triggering demo alert for demo starting at " .. tostring(targetInfo.startat))
		DEMO_ALERT_TOGGLE(targetInfo)
	end
end

local function DEMO_ALERT_UPDATE_TIME(dt)
	if demoWindowAlert == nil or demoWindowAlert.targetInfo == nil then 
		return
	end
	if not demoWindowAlert:IsVisible() then
		return
	end
	local deltaSeconds = 0
	if type(dt) == "number" and dt > 0 then
		deltaSeconds = dt / 1000
	end

	if type(demoWindowAlert.remainingSeconds) ~= "number" then
		demoWindowAlert.remainingSeconds = math.max(0, (demoWindowAlert.targetInfo.startat or 0) - helpers.GetCurrentTimestamp())
	end
	if type(demoWindowAlert.elapsedSinceStartSeconds) ~= "number" then
		demoWindowAlert.elapsedSinceStartSeconds = math.max(0, helpers.GetCurrentTimestamp() - (demoWindowAlert.targetInfo.startat or 0))
	end

	if demoWindowAlert.remainingSeconds > 0 then
		demoWindowAlert.remainingSeconds = math.max(0, demoWindowAlert.remainingSeconds - deltaSeconds)
	else
		demoWindowAlert.elapsedSinceStartSeconds = demoWindowAlert.elapsedSinceStartSeconds + deltaSeconds
	end

	local secsRemaining = demoWindowAlert.remainingSeconds
	local setText = "[?]"
	if secsRemaining <= 0 then
		if demoWindowAlert.elapsedSinceStartSeconds >= (60 * 30) then
			DEMO_ALERT_TOGGLE(nil)
			api.Log:Info("Demo event ended, closing alert")
			return
		end
		setText = "Now"
	else
		local displayRemaining = math.max(0, math.ceil(secsRemaining))
		local mins = math.floor(displayRemaining / 60)
		local secs = displayRemaining % 60
		setText = string.format("%d:%02d", mins, secs)
	end
	if setText ~= demoWindowAlert.timetostart:GetText() then
		demoWindowAlert.timetostart:SetText(setText)
	end
end

function OPEN_GOTO_WINDOW()

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

local function DEMO_AUTOHIDE_PLUS()
	if demoAddButton == nil then 
		helpers.DevLog("Demo add button not initialized yet")
		return
	end
	if demoWindow == nil then 
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	if settings.Get("showDemoCreatePlus") == true then
		local unitid = api.Unit:GetUnitId("target")
		if unitid == nil then
			helpers.DevLog("DEMO_WINDOW_AUTO: No target selected")
			if demoAddButton:IsVisible() then
				demoAddButton:Show(false)
			end
			if demoWindow:IsVisible() then
				demoWindow:Show(false)
			end
			return
		end
		local targetpos = gps.GetCurrentPosition()
		local targetdetails = api.Unit:GetUnitInfoById(unitid)
		if targetdetails.type ~= "housing" then
			helpers.DevLog("DEMO_WINDOW_AUTO: Target is not a housing unit")
			if demoAddButton:IsVisible() then
				demoAddButton:Show(false)
			end
			if demoWindow:IsVisible() then
				demoWindow:Show(false)
			end
			return
		end
		local targetpos = gps.GetCurrentPosition()
		local targetdetails = api.Unit:GetUnitInfoById(unitid)
		if targetdetails.type ~= "housing" then
			helpers.DevLog("DEMO_WINDOW_AUTO: Target is not a housing unit")
			if demoAddButton:IsVisible() then
				demoAddButton:Show(false)
			end
			if demoWindow:IsVisible() then
				demoWindow:Show(false)
			end
			return
		end
		if not demoAddButton:IsVisible() then
			demoAddButton:Show(true)
		end
	end
end

-- Update loop
local function onUpdate(dt)
	helpers.AdvanceCurrentTimestamp(dt)

	-- Update flash animation on every frame (needs to run at frame rate)
	if settings.Get("EnableLocationOutput") then
		shareddata.onUpdate(dt)
	end
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
	DEMO_AUTOHIDE_PLUS()
	DEMO_ALERT_UPDATE_TIME(dt+constants.timing.updateRate)
	DEMO_ALERT_TRIGGER_CHECK()
	
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

local function DEMO_WINDOW_TOGGLE()
	if demoWindow == nil then 
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	demoWindow:Show(not demoWindow:IsVisible())
	if demoWindow:IsVisible() then
		demoWindow.regionnameInput:SetText("")
		demoWindow.ownernameInput:SetText("")
		helpers.SelectComboBoxByText(demoWindow.buildingnameInput, "Unknown", "Unknown")
		demoWindow.dateinput:SetText("")
		demoWindow.timeinput:SetText("")
	end
end

local function redrawDemos()
	if demos.InDemoMode() then
		ships.DisplayShips(false)
		demos.DisplayDemos(true)
		events.DisplayEvents(false)
		maps.HideNextMapButton()
	end
end

local function DEMO_WINDOW_CREATE()
	if demoWindow == nil then 
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	helpers.DevLog("Creating demo with input data")
	local regionname = demoWindow.regionnameInput:GetText() or "Unknown"
	local ownername = demoWindow.ownernameInput:GetText() or "Unknown"
	local buildingname = helpers.getComboBoxValue(demoWindow.buildingnameInput, "Unknown")
	local date = demoWindow.dateinput:GetText() or "Unknown"
	local time = demoWindow.timeinput:GetText() or "Unknown"
	if buildingname == "Unknown" or ownername == "Unknown" or regionname == "Unknown" then
		api.Log:Info("SatNav: Invalid region, owner, or building input for demo creation")
		return
	end
	if date == "Unknown" or time == "Unknown" then
		api.Log:Info("SatNav: Invalid date or time input for demo creation")
		return
	end
	local timestamp, parseError = helpers.ParseDateTimeToUnixtime(date, time)
	if timestamp == nil then
		api.Log:Info("SatNav: " .. tostring(parseError))
		return
	end

	api.Log:Info(string.format("SatNav: Creating demo - Region: %s, Owner: %s, Building: %s, Date: %s, Time: %s", regionname, ownername, buildingname, date, time))
	if not demos.CreateDemo(regionname, ownername, buildingname, date, time, timestamp) then
		api.Log:Info("SatNav: Failed to create demo entry.")
	end
	DEMO_WINDOW_TOGGLE()
	redrawDemos()
end

local function DEMO_WINDOW_AUTO()
	if demoWindow == nil then 
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	local unitid = api.Unit:GetUnitId("target")
	if unitid == nil then
		helpers.DevLog("DEMO_WINDOW_AUTO: No target selected")
		return
	end
	local targetpos = gps.GetCurrentPosition()
	local targetdetails = api.Unit:GetUnitInfoById(unitid)
	if targetdetails.type ~= "housing" then
		helpers.DevLog("DEMO_WINDOW_AUTO: Target is not a housing unit")
		return
	end
	
	local ownername = targetdetails.owner_name or "Unknown"
	local buildingname = targetdetails.name or "Unknown"
	local x, y = coordinates.getMapDrawPoint(
		targetpos.longitude, targetpos.latitude,
		targetpos.deg_long or 0, targetpos.min_long or 0, targetpos.sec_long or 0,
		targetpos.deg_lat or 0, targetpos.min_lat or 0, targetpos.sec_lat or 0
	)
	local regionname = shapes.getShapeAt(x, y) or "Unknown"
	regionname = regionname:match("/(.+)") or regionname
	demoWindow.regionnameInput:SetText(regionname)
	demoWindow.ownernameInput:SetText(ownername)
	helpers.SelectComboBoxByText(demoWindow.buildingnameInput, buildingname, "Unknown")
	api.Log:Info(string.format("SatNav: Auto-filled demo info - Region: %s, Owner: %s, Building: %s", regionname, ownername, buildingname))
end



GOTO_TARGET_TEXT = ""
local function OPEN_GOTO_WINDOW()
	if gotoWindow == nil then
		helpers.DevLog("Goto window not initialized yet")
		return
	end
	helpers.DevLog("Opening Goto window")
	gotoWindow:RemoveAllAnchors()
	helpers.DevLog("Anchoring Goto window to " .. tostring(settings.Get("MainWindowX")+250) .. ", " .. tostring(settings.Get("MainWindowY")+350))
	gotoWindow:AddAnchor("TOPLEFT", "UIParent", settings.Get("MainWindowX")+250, settings.Get("MainWindowY")+350)
	GOTO_TARGET_TEXT = ""
	gotoWindow.textinput:SetText("")
	gotoWindow:Show(true)
	helpers.DevLog("Goto window shown")
end

local function ParseGotoTargetText(rawText)
	if rawText == nil then
		return nil
	end

	local text = rawText:match("^%s*(.-)%s*$")
	if text == nil or text == "" then
		return nil
	end

	local pattern = "^(%d+)%s*°%s*(%d+)%s*'%s*(%d+)%s*\"%s*([NS])%s*,%s*(%d+)%s*°%s*(%d+)%s*'%s*(%d+)%s*\"%s*([EW])%s*$"
	local latDeg, latMin, latSec, latDir, longDeg, longMin, longSec, longDir = text:upper():match(pattern)
	if latDeg == nil then
		return nil
	end

	return {
		latitudeDir = latDir,
		latitudeDeg = tonumber(latDeg),
		latitudeMin = tonumber(latMin),
		latitudeSec = tonumber(latSec),
		longitudeDir = longDir,
		longitudeDeg = tonumber(longDeg),
		longitudeMin = tonumber(longMin),
		longitudeSec = tonumber(longSec),
		iscustom = true
	}
end

local function CLOSE_GOTO_WINDOW()
	if gotoWindow == nil then
		helpers.DevLog("Goto window not initialized yet")
		return
	end
	local inputText = GOTO_TARGET_TEXT
	if gotoWindow.textinput ~= nil and gotoWindow.textinput.GetText ~= nil then
		inputText = gotoWindow.textinput:GetText() or inputText
	end
	GOTO_TARGET_TEXT = inputText or ""
	gotoWindow:Show(false)
	helpers.DevLog("Closing Goto window with text: " .. tostring(GOTO_TARGET_TEXT))
	if GOTO_TARGET_TEXT ~= "" then
		local itemData = ParseGotoTargetText(GOTO_TARGET_TEXT)
		if itemData ~= nil then
			helpers.DevLog("Parsed GOTO input successfully")
			START_MAP_TRACKING(itemData, true)
		else
			helpers.DevLog("Failed to parse GOTO input")
		end
	end
end

local function DEMO_ALERT_STARTTRACK()
	if demoWindowAlert == nil then 
		helpers.DevLog("Demo alert window not initialized yet")
		return
	end
	local targetInfo = demoWindowAlert.targetInfo
	if targetInfo == nil then
		helpers.DevLog("No target info set for demo alert tracking")
		return
	end
	START_MAP_TRACKING(targetInfo, true)
end

-- Addon initialization
local function OnLoad()
	-- Load settings
	settings.LoadSettings()
	-- Create windows
	TRACK_WINDOW = uiWindows.createTRACK_WINDOW(onTrackingWindowClose)
	satNavWindow = uiWindows.createMainWindow(onMapClick, TOGGLE_MAIN_WINDOW, OPEN_GOTO_WINDOW)
	overlayWnd = uiWindows.createOverlayButton(TOGGLE_MAIN_WINDOW)
	gotoWindow = uiWindows.createGotoWindow()
	demoAddButton = uiWindows.createDemoPlusButton(DEMO_WINDOW_TOGGLE)
	demoWindow = uiWindows.createDemoWindow(DEMO_WINDOW_TOGGLE, DEMO_WINDOW_AUTO, DEMO_WINDOW_CREATE)
	demoWindowAlert = uiWindows.createDemoAlertWindow(DEMO_ALERT_TOGGLE, DEMO_ALERT_STARTTRACK)
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
	function gotoWindow:OnClose()
		CLOSE_GOTO_WINDOW()
	end
	demoWindow:SetHandler("OnClose", DEMO_WINDOW_TOGGLE)
	demoWindow:SetHandler("OnCloseByEsc", DEMO_WINDOW_TOGGLE)

	gotoWindow.submit:SetHandler("OnClick", gotoWindow.OnClose)
	gotoWindow:SetHandler("OnClose", gotoWindow.OnClose)
	gotoWindow:SetHandler("OnCloseByEsc", gotoWindow.OnClose)

	satNavWindow:SetHandler("OnClose", satNavWindow.OnClose)
	satNavWindow:SetHandler("OnCloseByEsc", satNavWindow.OnClose)
	satNavWindow:SetHandler("OnEvent", satNavWindow.EventListener)
    satNavWindow:RegisterEvent("WORLD_MESSAGE")
	satNavWindow:RegisterEvent("CHAT_MESSAGE")
	
	-- Initialize modules
	bagOverlay.initialize()
	mapRenderer.initialize(satNavWindow, satNavWindow.mapDrawable)
	maps.CreateNextMapButton()
	
	
	-- Initial render
	satNavWindow:Show(false)
	mapRenderer.render()

	-- settings
	local mylabel = helpers.createLabel("SettingsTextLabel", satNavWindow, "Settings", 125, 80, 14)
	mylabel:SetExtent(200, 30)
	mylabel.style:SetColor(0, 0, 0, 1)
	mylabel:Show(true)
	table.insert(settingsControls, mylabel)

	helpers.CreateSkinnedCheckbox("UseTeleportHint", satNavWindow, "Use Teleports", 30, 105, settings.Get("UseTeleportHint"), function(checked)
		settings.Update("UseTeleportHint", checked)
	end)

	helpers.CreateSkinnedCheckbox("EnableWorldEvents", satNavWindow, "World Events", 155, 105, settings.Get("EnableWorldEvents"), function(checked)
		settings.Update("EnableWorldEvents", checked)
	end)
	helpers.CreateSkinnedCheckbox("OpenRealMap", satNavWindow, "Real Map", 30, 140, settings.Get("OpenRealMap"), function(checked)
		settings.Update("OpenRealMap", checked)
	end)

	helpers.CreateSkinnedCheckbox("EnableLocationOutput", satNavWindow, "Location Output", 155, 140, settings.Get("EnableLocationOutput"), function(checked)
		settings.Update("EnableLocationOutput", checked)
	end)
	helpers.CreateSkinnedCheckbox("EnableAlertDemo", satNavWindow, "Alert 4 Demo", 30, 175, settings.Get("EnableAlertDemo"), function(checked)
		settings.Update("EnableAlertDemo", checked)
	end)
	helpers.CreateSkinnedCheckbox("showDemoCreatePlus", satNavWindow, "UI Demo +", 155, 175, settings.Get("showDemoCreatePlus"), function(checked)
		settings.Update("showDemoCreatePlus", checked)
		demoAddButton:Show(checked)
	end)
	helpers.CreateSkinnedCheckbox("DrawDemosInNextHour", satNavWindow, "Show Demos in Next Hour", 65, 205, settings.Get("DrawDemosInNextHour"), function(checked)
		settings.Update("DrawDemosInNextHour", checked)
		redrawDemos()
	end)

	

	local mylabel3 = helpers.createLabel("SettingsTextLabel3", satNavWindow, "Tracking", 30, 227, 14)
	mylabel3:SetExtent(200, 30)
	mylabel3.style:SetColor(0, 0, 0, 1)
	mylabel3:Show(true)
	table.insert(settingsControls, mylabel3)

	helpers.CreateSkinnedCheckbox("trackModeGuideCheckbox1", satNavWindow, "Guide", 30, 252, settings.Is("trackingMode","guide"), function(checked)
		if checked then
			settings.Update("trackingMode", "guide")
		end
	end, nil, nil, "trackMode")
	
	helpers.CreateSkinnedCheckbox("trackModeGuideCheckbox2", satNavWindow, "Compass", 30+75, 252, settings.Is("trackingMode","compass"), function(checked)
		if checked then
			settings.Update("trackingMode", "compass")
		end
	end, nil, nil, "trackMode")


	helpers.CreateSkinnedCheckbox("showMapsCheckbox", satNavWindow, "Maps", 375+10, 31, true, function(checked)
		ships.DisplayShips(false)
		demos.DisplayDemos(false)
		events.DisplayEvents(false)
		mapRenderer.render()
		maps.RestoreNextMapButton()
	end, nil, nil, "mapMode", "overlay", false)

	helpers.CreateSkinnedCheckbox("showShipCheckbox", satNavWindow, "Ships", 375+75+7+10, 31, false, function(checked)
		ships.DisplayShips(true)
		demos.DisplayDemos(false)
		events.DisplayEvents(false)
		maps.HideNextMapButton()
	end, nil, nil, "mapMode", "overlay", false)

	helpers.CreateSkinnedCheckbox("ShowEventsCheckbox", satNavWindow, "Events", 375+150+14+5+10, 31, false, function(checked)
		ships.DisplayShips(false)
		demos.DisplayDemos(false)
		events.DisplayEvents(true)
		maps.HideNextMapButton()
	end, nil, nil, "mapMode", "overlay", false)

	helpers.CreateSkinnedCheckbox("ShowDemosCheckbox", satNavWindow, "Demos", 375+225+21+5+10, 31, false, function(checked)
		ships.DisplayShips(false)
		demos.DisplayDemos(true)
		events.DisplayEvents(false)
		maps.HideNextMapButton()
	end, nil, nil, "mapMode", "overlay", false)

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
	maps.HideNextMapButton()

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
	if gotoWindow ~= nil then 
		gotoWindow:Show(false)
		api.Interface:Free(gotoWindow)
		gotoWindow = nil
	end
	if demoAddButton ~= nil then 
		demoAddButton:Show(false)
		api.Interface:Free(demoAddButton)
		demoAddButton = nil
	end
	if demoWindow ~= nil then 
		demoWindow:Show(false)
		api.Interface:Free(demoWindow)
		demoWindow = nil
	end
	if demoWindowAlert ~= nil then 
		demoWindowAlert:Show(false)
		api.Interface:Free(demoWindowAlert)
		demoWindowAlert = nil
	end
end

WorldSatNav.OnLoad = OnLoad
WorldSatNav.OnUnload = OnUnload

return WorldSatNav