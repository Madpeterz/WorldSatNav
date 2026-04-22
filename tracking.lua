local api = require("api")
local coordinates = require("WorldSatNav/coordinates")
local constants = require("WorldSatNav/constants")
local helpers = require("WorldSatNav/helpers")
local settings = require("WorldSatNav/settings")
local gps = require("WorldSatNav/gps")
local regionmap = require("WorldSatNav/regionmap")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")

local tracking = {}

local TRACK_WINDOW = nil
local lastArrowDir = ""

local targetSextant = nil
local targetName = nil

local currentNextButtonCallback = nil
local EVENT_NEXT_MAP = eventtopics.topics.tracking.nextMap
local EVENT_NEXT_SHIP = eventtopics.topics.tracking.nextShip

local function NormalizeSextant(sextant)
	if sextant == nil then
		return nil
	end
	local normalized = {
		longitude = sextant.longitudeDir or sextant.longitude,
		latitude = sextant.latitudeDir or sextant.latitude,
		deg_long = sextant.longitudeDeg or sextant.deg_long or sextant.degLong,
		min_long = sextant.longitudeMin or sextant.min_long or sextant.minLong,
		sec_long = sextant.longitudeSec or sextant.sec_long or sextant.secLong,
		deg_lat = sextant.latitudeDeg or sextant.deg_lat or sextant.degLat,
		min_lat = sextant.latitudeMin or sextant.min_lat or sextant.minLat,
		sec_lat = sextant.latitudeSec or sextant.sec_lat or sextant.secLat
	}
	if normalized.min_long == nil then normalized.min_long = 0 end
	if normalized.sec_long == nil then normalized.sec_long = 0 end
	if normalized.min_lat == nil then normalized.min_lat = 0 end
	if normalized.sec_lat == nil then normalized.sec_lat = 0 end
	return normalized
end

local function InvokeNextMapCallback()
	helpers.DevLog("Publishing next map event")
	eventbus.TriggerEvent(EVENT_NEXT_MAP)
end

local function InvokeNextShipCallback()
	eventbus.TriggerEvent(EVENT_NEXT_SHIP)
end

function tracking.IsActive()
	if TRACK_WINDOW == nil then
		return false
	end
	return TRACK_WINDOW:IsVisible()
end

local function CreateNextButton()
	if TRACK_WINDOW == nil then
		return
	end
	TRACK_WINDOW.nextBtn = TRACK_WINDOW:CreateChildWidget("button", "nextBtn", 0, true)
	TRACK_WINDOW.nextBtn:AddAnchor("TOPLEFT", TRACK_WINDOW, 0, TRACK_WINDOW:GetHeight()+5)
	TRACK_WINDOW.nextBtn:SetExtent(90*settings.Get("uiDrawScale"), 30*settings.Get("uiDrawScale"))
	api.Interface:ApplyButtonSkin(TRACK_WINDOW.nextBtn, BUTTON_BASIC.DEFAULT)
	TRACK_WINDOW.nextBtn:Show(true)
	TRACK_WINDOW.nextBtn:Enable(true)
	TRACK_WINDOW.nextBtn:Raise()
	function TRACK_WINDOW.nextBtn:OnClick()
		helpers.DevLog("Next button clicked")
		if currentNextButtonCallback ~= nil then
			helpers.DevLog("Invoking next button callback")
			currentNextButtonCallback()
		else 
			helpers.DevLog("Next button clicked but no callback assigned")
		end
	end
	TRACK_WINDOW.nextBtn:SetHandler("OnClick", TRACK_WINDOW.nextBtn.OnClick)
end



function tracking.AssignNextButton(workerTarget, callback)
	helpers.DevLog("AssignNextButton called with workerTarget: " .. tostring(workerTarget))
	if TRACK_WINDOW == nil then
		helpers.DevLog("Tracking window not initialized, cannot assign next button")
		return
	end
	if TRACK_WINDOW:IsVisible() == false then
		helpers.DevLog("Tracking window not visible, cannot assign next button")
		return
	end
	if workerTarget == nil or callback == nil then
		helpers.DevLog("Invalid worker target or callback, hiding next button")
		if TRACK_WINDOW.nextBtn ~= nil then
			TRACK_WINDOW.nextBtn:Show(false)
		end
		return
	end
	if TRACK_WINDOW.nextBtn == nil then
		helpers.DevLog("Next button not found, creating next button")
		CreateNextButton()
	end
	helpers.DevLog("Assigning next button with target: " .. workerTarget)
	TRACK_WINDOW.nextBtn:SetText("Next "..workerTarget)
	TRACK_WINDOW.nextBtn:Show(true)
	currentNextButtonCallback = callback
	helpers.DevLog("Next button assigned callback "..tostring(callback))
end



local function updateNavArrow(direction)
	if TRACK_WINDOW == nil or TRACK_WINDOW.arrow == nil then
		return
	end
	if direction == lastArrowDir then
		return
	end
	lastArrowDir = direction
	local arrowPath = constants.folderPath.."images/arrows/" .. direction .. ".png"
	TRACK_WINDOW.arrow:SetTexture(arrowPath)
end

local sharedDataLastUpdate = 0
local updateTicker = 0
local function UpdateSharedData(dt)
	-- Throttled updates (run every 750ms)
	sharedDataLastUpdate = sharedDataLastUpdate + dt
	if sharedDataLastUpdate < settings.Get("LocationOutputRateLimit") then
		return
	end
	updateTicker = updateTicker + dt
	local writeFile = {
		time = api.Time:GetLocalTime(),
		location = api.Map:GetPlayerSextants(),
		updateTicker = updateTicker
	}
	api.File:Write("WorldSatNav/Data/"..settings.Get("LocationOutputFile"), writeFile)
	if updateTicker > 10000 then
		updateTicker = 0 -- reset ticker every 10 seconds to prevent overflow, just a helper so you can see file updates even if time has not changed
	end
	sharedDataLastUpdate = 0
end

local function updateTrackingData()

	if TRACK_WINDOW == nil or not TRACK_WINDOW:IsVisible() or targetSextant == nil then
		return
	end
	
	local _, regionNameTarget = regionmap.GetRegionForSextant(targetSextant)
	local _, regionNamePlayer = regionmap.GetRegionForSextant(api.Map:GetPlayerSextants())

	local useTeleport = false
	if regionNamePlayer ~= "?" and regionNameTarget ~= "?" then
		if regionNamePlayer ~= regionNameTarget then
			useTeleport = true
		end
	end
	if targetName == nil then
		targetName = "undefined"
	end
	if TRACK_WINDOW.markNameLabel:GetText() ~= targetName then
		TRACK_WINDOW.markNameLabel:SetText(targetName)
	end
	TRACK_WINDOW.markNameLabel:SetText(targetName)
	if TRACK_WINDOW.markNameLabel.fontSize == nil then
		TRACK_WINDOW.markNameLabel.fontSize = 18
	end
	local fontsize = 18;
	local stringlen = string.len(targetName)
	if(stringlen > 22) then
		fontsize = math.floor(18 - ((15 / 22) * (stringlen - 22)))
	end
	local appliedFontSize = TRACK_WINDOW.markNameLabel.fontSize
	if appliedFontSize ~= fontsize then
		TRACK_WINDOW.markNameLabel.style:SetFontSize(fontsize)
		TRACK_WINDOW.markNameLabel.fontSize = fontsize
	end
	local navDir, navDistance, navDistanceScale, bearing, relativeDir = gps.getNavigationText(targetSextant)
	
	if useTeleport and settings.Get("UseTeleportHint") and navDistanceScale ~= "m" then
		TRACK_WINDOW.distanceLabel:SetText("teleport to " .. regionNameTarget)
		updateNavArrow("portal2")
	else
		TRACK_WINDOW.distanceLabel:SetText(string.format("%.1f %s", navDistance, navDistanceScale))
		if settings.Get("trackingMode") == "Compass" then
			updateNavArrow(navDir)
		elseif settings.Get("trackingMode") == "Guide" then	
			if navDir == "here" then
				updateNavArrow(navDir)
			else			
				updateNavArrow(relativeDir)
			end
		end
	end
	TRACK_WINDOW.distanceLabel.style:SetFontSize(20)
end

local function createTrackUI(onCloseCallback)
	TRACK_WINDOW = api.Interface:CreateEmptyWindow("TRACK_WINDOW")
	if TRACK_WINDOW == nil then
		helpers.DevLog("Failed to create tracking window")
		return nil
	end
	TRACK_WINDOW:AddAnchor("TOPLEFT", "UIParent", settings.Get("TrackingWindowX"), settings.Get("TrackingWindowY"))
	TRACK_WINDOW.bg = TRACK_WINDOW:CreateImageDrawable("trackwindowbg", "background")
	TRACK_WINDOW.bg:SetTexture(constants.folderPath.."images/trackerbackground.png")
	local bg = constants.tracking.backgroundColor
	TRACK_WINDOW.bg:SetColor(0.5, 0.5, 0.5, 0.6)
	TRACK_WINDOW.bg:SetExtent(275*settings.Get("uiDrawScale"), 115*settings.Get("uiDrawScale"))
	TRACK_WINDOW.bg:AddAnchor("TOPLEFT", TRACK_WINDOW, 0, 0)
	TRACK_WINDOW.bg:Show(true)
	TRACK_WINDOW:SetExtent(275*settings.Get("uiDrawScale"), 115*settings.Get("uiDrawScale"))
	TRACK_WINDOW:Show(false)

	TRACK_WINDOW.arrow = TRACK_WINDOW:CreateImageDrawable("trackarrow", "overlay")
	TRACK_WINDOW.arrow:SetTexture(constants.folderPath.."images/arrows/n.png")
	TRACK_WINDOW.arrow:AddAnchor("TOPLEFT", TRACK_WINDOW, 20, 30*settings.Get("uiDrawScale"))
	TRACK_WINDOW.arrow:SetExtent(64*settings.Get("uiDrawScale"), 64*settings.Get("uiDrawScale"))
	TRACK_WINDOW.arrow:Show(true)

	helpers.makeWindowDraggable(TRACK_WINDOW, nil,nil,true,true, "TrackingWindowX", "TrackingWindowY")

	-- Close button
	TRACK_WINDOW.closeBtn = TRACK_WINDOW:CreateChildWidget("button", "closeBtn", 0, true)
	TRACK_WINDOW.closeBtn:AddAnchor("TOPLEFT", TRACK_WINDOW, (275*settings.Get("uiDrawScale"))-(20*settings.Get("uiDrawScale")), 3*settings.Get("uiDrawScale"))
	api.Interface:ApplyButtonSkin(TRACK_WINDOW.closeBtn, BUTTON_BASIC.WINDOW_SMALL_CLOSE)
	TRACK_WINDOW.closeBtn:Show(true)

	function TRACK_WINDOW.OnClose(button, clicktype)
		TRACK_WINDOW:Show(false)
		if onCloseCallback then
			onCloseCallback()
		end
	end

	TRACK_WINDOW.closeBtn:SetHandler("OnClick", TRACK_WINDOW.OnClose)

	-- Labels
	local trackingLabel = helpers.createLabel('trackingLabel', TRACK_WINDOW, 'Tracking:', 0, 0)
	if trackingLabel == nil then
		helpers.DevLog("Failed to create tracking label")
		return TRACK_WINDOW
	end
	trackingLabel:RemoveAllAnchors()
	trackingLabel:AddAnchor('TOPLEFT', TRACK_WINDOW, 95*settings.Get("uiDrawScale"), 30*settings.Get("uiDrawScale"))
	ApplyTextColor(trackingLabel, FONT_COLOR.WHITE)

	-- Mark name label
	local markNameLabel = helpers.createLabel('markNameLabel', TRACK_WINDOW, 'undefined point', 0, 0)
	if markNameLabel == nil then
		helpers.DevLog("Failed to create mark name label")
		return TRACK_WINDOW
	end
	markNameLabel:RemoveAllAnchors()
	markNameLabel:AddAnchor('TOPLEFT', TRACK_WINDOW, 95*settings.Get("uiDrawScale"), 45*settings.Get("uiDrawScale"))
	ApplyTextColor(markNameLabel, FONT_COLOR.WHITE)
	TRACK_WINDOW.markNameLabel = markNameLabel

	-- Distance label
	local distanceLabel = helpers.createLabel('distanceLabel', TRACK_WINDOW, '100.3 m', 0, 0)
	if distanceLabel == nil then
		helpers.DevLog("Failed to create distance label")
		return TRACK_WINDOW
	end
	distanceLabel:RemoveAllAnchors()
	distanceLabel:AddAnchor('TOPLEFT', TRACK_WINDOW, 95*settings.Get("uiDrawScale"), 70*settings.Get("uiDrawScale"))
	ApplyTextColor(distanceLabel, FONT_COLOR.WHITE)
	TRACK_WINDOW.distanceLabel = distanceLabel
	
	return TRACK_WINDOW
end


function tracking.setTargetGoto(sextant, name, ShowMapMarker)
	local normalizedSextant = NormalizeSextant(sextant)
	if normalizedSextant == nil or normalizedSextant.longitude == nil or normalizedSextant.latitude == nil
		or normalizedSextant.deg_long == nil or normalizedSextant.deg_lat == nil then
		helpers.DevLog("Invalid sextant for tracking target, cannot update")
		return
	end
	targetSextant = normalizedSextant
	targetName = name
	ShowMapMarker = ShowMapMarker or false
	if TRACK_WINDOW == nil then
		helpers.DevLog("tracking window not initialized, cannot set target")
		return
	end
	if TRACK_WINDOW:IsVisible() == false then
		TRACK_WINDOW:Show(true)
	end
	local xMap = coordinates.longitudeSextantToDegrees(
		normalizedSextant.longitude,
		normalizedSextant.deg_long or 0,
		normalizedSextant.min_long or 0,
		normalizedSextant.sec_long or 0
	)
	local yMap = coordinates.latitudeSextantToDegrees(
		normalizedSextant.latitude,
		normalizedSextant.deg_lat or 0,
		normalizedSextant.min_lat or 0,
		normalizedSextant.sec_lat or 0
	)
	if (ShowMapMarker == true) and (settings.Get("OpenRealMap") == true) then
		helpers.DevLog("Showing map marker for target sextant at coordinates: " .. xMap .. ", " .. yMap)
		api.Map:ToggleMapWithPortal(constants.game.portalZoneId, xMap, yMap, constants.game.portalZoomLevel)
	end
	helpers.DevLog("Attempting to link next button to "..name.."")
	if name == "Map" then
		helpers.DevLog("Assigning next button to map callback")
		tracking.AssignNextButton("Map", InvokeNextMapCallback)
	elseif name == "Ship" then
		helpers.DevLog("Assigning next button to ship callback")
		tracking.AssignNextButton("Ship", InvokeNextShipCallback)
	else
		helpers.DevLog("No valid target type provided for next button callback, hiding next button")
		tracking.AssignNextButton(nil, nil)
	end
	helpers.DevLog("Target set to sextant: " .. helpers.SextantKey(normalizedSextant) .. " with name: " .. tostring(name))
	updateTrackingData()
end


local lastUpdate = 0
function tracking.onUpdate(dt)
	UpdateSharedData(dt)
	lastUpdate = lastUpdate + dt
	if lastUpdate < (constants.timing.updateRate/1.25) then
		return
	end
    lastUpdate = 0
	updateTrackingData()

end

function tracking.OnLoad()
    TRACK_WINDOW = createTrackUI(nil)
	eventbus.WatchEvent(eventtopics.topics.tracking.custom, tracking.setTargetGoto, "tracking")
	eventbus.WatchEvent(eventtopics.topics.tracking.start, tracking.setTargetGoto, "tracking")
end

function tracking.OnUnload()
	if TRACK_WINDOW ~= nil then
		if TRACK_WINDOW:IsVisible() then
			TRACK_WINDOW:Show(false)
		end
		api.Interface:Free(TRACK_WINDOW)
		TRACK_WINDOW = nil
	end
end

return tracking