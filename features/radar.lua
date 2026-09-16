local api = require("api")
local coordinates = require("WorldSatNav/core/coordinates")
local constants = require("WorldSatNav/core/constants")
local helpers = require("WorldSatNav/helpers")
local settings = require("WorldSatNav/core/settings")
local gps = require("WorldSatNav/features/gps")
local tracking = require("WorldSatNav/features/tracking")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")

local radar = {}

local RADAR_WINDOW = nil
local radarTargetSextant = nil
local radarTargetName = nil
local radarCurrentType = nil -- raw tracked type ("Map"/"Ship"/"Dawns"/...), drives the Next button
local radarTargetXMap = nil
local radarTargetYMap = nil
local currentBackgroundMode = nil -- "close" or "far", tracked to avoid redundant SetTexture calls

-- Raw distance from gps is noisy at the radar's fast poll rate. Smoothed
-- toward the raw value each tick instead of snapping to it.
local smoothedRadius = nil
local SMOOTHING_FACTOR = 0.12

-- In player-facing mode, angle = target bearing - player movement direction.
-- Movement direction is derived from tiny per-tick position deltas and is
-- noisy even walking dead straight, which rocks the dot left/right at a
-- fixed radius. Smoothed as a scalar angle (not lerped sin/cos, which cuts
-- a chord inside the circle and drags the dot toward the center mid-turn)
-- by stepping toward the raw angle along the shortest wrap-safe direction,
-- so the dot instead sweeps along the arc at a constant radius.
local smoothedAngleDeg = nil
local ANGLE_SMOOTHING_FACTOR = 0.09

local WINDOW_SIZE = 300
local TITLE_HEIGHT = 30
local DISTANCE_HEIGHT = 30
local PANEL_HEIGHT = TITLE_HEIGHT + WINDOW_SIZE + DISTANCE_HEIGHT
local CLOSE_FAR_THRESHOLD_M = 300

-- Incoming sextants from tracking events use engine-native field names
-- (longitudeDir, longitudeDeg, ...); coordinates.CalculateDistance and
-- gps.lua expect the shorter longitude/deg_long/... names. Mirrors
-- tracking.lua's NormalizeSextant.
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

-- Same empirical correction factor tracking.lua's MetersBetweenSextants and
-- gps.lua's getGPSGuideText apply to coordinates.CalculateDistance's raw output.
local function MetersBetweenSextants(a, b)
	local d = coordinates.CalculateDistance(a, b)
	if d == nil or d == math.huge then
		return nil
	end
	return d * (3.2 / 3.6)
end

-- Ordered {min, max, pxMin, pxMax} bands. Radius is linearly interpolated
-- within the matching band by (distance - min) / (max - min).
local closeBands = {
	{min = 0, max = 49, pxMin = 0, pxMax = 30},
	{min = 50, max = 150, pxMin = 31, pxMax = 72},
	{min = 150, max = 300, pxMin = 73, pxMax = 122},
}
local farBands = {
	{min = 300, max = 400, pxMin = 23, pxMax = 43},
	{min = 400, max = 600, pxMin = 44, pxMax = 69},
	{min = 600, max = 1000, pxMin = 70, pxMax = 99},
	{min = 1000, max = 1500, pxMin = 100, pxMax = 130},
}

local function PixelRadiusForDistance(distanceM)
	local bands = distanceM <= CLOSE_FAR_THRESHOLD_M and closeBands or farBands
	for i = 1, #bands do
		local band = bands[i]
		if distanceM >= band.min and distanceM <= band.max then
			local fraction = (distanceM - band.min) / (band.max - band.min)
			return band.pxMin + fraction * (band.pxMax - band.pxMin)
		end
	end
	if distanceM > CLOSE_FAR_THRESHOLD_M then
		return 130 -- beyond 1500m, capped
	end
	return 0
end

local function setBackgroundMode(mode)
	if RADAR_WINDOW == nil or RADAR_WINDOW.background == nil or mode == currentBackgroundMode then
		return
	end
	currentBackgroundMode = mode
	local texture = mode == "close" and "range_close.png" or "range_far.png"
	RADAR_WINDOW.background:SetTexture(constants.folderPath .. "images/radar/" .. texture)
end

-- Radar's window is only shown when radar is enabled and a target is active;
-- the old tracking.lua window covers the disabled case (see its own
-- RefreshWindowVisibility, which this keeps in sync with).
function radar.RefreshWindowVisibility()
	if RADAR_WINDOW == nil or radarTargetSextant == nil then
		return
	end
	local shouldShow = settings.Get("RadarEnabled") == true
	if RADAR_WINDOW:IsVisible() ~= shouldShow then
		RADAR_WINDOW:Show(shouldShow)
	end
end

local function updateNextButton()
	if RADAR_WINDOW == nil or RADAR_WINDOW.nextBtn == nil then
		return
	end
	local label = nil
	if radarCurrentType == "Map" then
		label = "Next Map"
	elseif radarCurrentType == "Ship" then
		label = "Next Ship"
	elseif radarCurrentType == "Dawns" then
		label = "Next point"
	end
	if label ~= nil then
		RADAR_WINDOW.nextBtn:SetText(label)
		RADAR_WINDOW.nextBtn:Show(true)
	else
		RADAR_WINDOW.nextBtn:Show(false)
	end
end

function radar.update(dt)
	if RADAR_WINDOW == nil or not RADAR_WINDOW:IsVisible() or radarTargetSextant == nil then
		return
	end

	local playerSextant = api.Map:GetPlayerSextants()
	local distanceM = MetersBetweenSextants(playerSextant, radarTargetSextant)
	if distanceM == nil then
		return
	end

	local _, _, _, bearing = gps.getNavigationText(radarTargetSextant)
	bearing = bearing or 0

	setBackgroundMode(distanceM <= CLOSE_FAR_THRESHOLD_M and "close" or "far")

	local angle = bearing - (gps.GetPlayerMovementDirection() or 0)

	local scale = settings.Get("uiDrawScale")
	local rawRadius = PixelRadiusForDistance(distanceM) * scale
	local rawAngle = angle % 360

	if smoothedAngleDeg == nil then
		smoothedAngleDeg = rawAngle
	else
		-- Shortest signed delta in (-180, 180], so the step never takes the
		-- long way around through the wrap point.
		local delta = (rawAngle - smoothedAngleDeg + 180) % 360 - 180
		smoothedAngleDeg = (smoothedAngleDeg + delta * ANGLE_SMOOTHING_FACTOR) % 360
	end

	if smoothedRadius == nil then
		smoothedRadius = rawRadius
	else
		smoothedRadius = smoothedRadius + (rawRadius - smoothedRadius) * SMOOTHING_FACTOR
	end

	-- Offset derived directly from the smoothed angle/radius (polar space)
	-- so the dot sweeps along the arc at a constant radius during a turn.
	local rad = math.rad(smoothedAngleDeg)
	local xOffset = smoothedRadius * math.sin(rad)
	local yOffset = (TITLE_HEIGHT * scale) - (smoothedRadius * math.cos(rad))

	-- target.png is a WINDOW_SIZE-sized canvas with its dot pre-centered, so
	-- shifting the whole image by (xOffset, yOffset) moves the embedded dot
	-- from the circle's center to the correct on-screen spot.
	RADAR_WINDOW.dot:RemoveAllAnchors()
	RADAR_WINDOW.dot:AddAnchor("TOPLEFT", RADAR_WINDOW, xOffset, yOffset)

	if RADAR_WINDOW.distanceLabel ~= nil then
		local line1, line2, isTeleport = tracking.GetDistanceDisplayText()
		if isTeleport then
			local text = line1
			if line2 ~= nil and line2 ~= "" then
				text = text .. " " .. line2
			end
			RADAR_WINDOW.distanceLabel:SetText(text)
		else
			RADAR_WINDOW.distanceLabel:SetText(string.format("Distance: %.1fm", distanceM))
		end
	end
end

function radar.setTarget(sextant, name, showMapMarker, displayName)
	local normalizedSextant = NormalizeSextant(sextant)
	if normalizedSextant == nil or normalizedSextant.longitude == nil or normalizedSextant.latitude == nil
		or normalizedSextant.deg_long == nil or normalizedSextant.deg_lat == nil then
		helpers.DevLog("Invalid sextant for radar target, cannot update")
		return
	end
	radarTargetSextant = normalizedSextant
	radarTargetName = displayName or name
	radarCurrentType = name
	smoothedRadius = nil
	smoothedAngleDeg = nil
	radarTargetXMap = coordinates.longitudeSextantToDegrees(
		normalizedSextant.longitude,
		normalizedSextant.deg_long or 0,
		normalizedSextant.min_long or 0,
		normalizedSextant.sec_long or 0
	)
	radarTargetYMap = coordinates.latitudeSextantToDegrees(
		normalizedSextant.latitude,
		normalizedSextant.deg_lat or 0,
		normalizedSextant.min_lat or 0,
		normalizedSextant.sec_lat or 0
	)

	if RADAR_WINDOW == nil then
		return
	end

	if RADAR_WINDOW.titleLabel ~= nil then
		RADAR_WINDOW.titleLabel:SetText("Target: " .. tostring(radarTargetName or "undefined"))
	end
	updateNextButton()
	if RADAR_WINDOW.showBtn ~= nil then
		RADAR_WINDOW.showBtn:Show(settings.Get("EnableShowOnTracking") == true)
	end

	radar.RefreshWindowVisibility()
	tracking.RefreshWindowVisibility()

	currentBackgroundMode = nil -- force a texture refresh for the new target
	radar.update(0)
end

function radar.clearTarget()
	radarTargetSextant = nil
	radarTargetName = nil
	radarCurrentType = nil
	radarTargetXMap = nil
	radarTargetYMap = nil
	smoothedRadius = nil
	smoothedAngleDeg = nil
	if RADAR_WINDOW ~= nil then
		if RADAR_WINDOW.nextBtn ~= nil then
			RADAR_WINDOW.nextBtn:Show(false)
		end
		if RADAR_WINDOW.showBtn ~= nil then
			RADAR_WINDOW.showBtn:Show(false)
		end
		if RADAR_WINDOW:IsVisible() then
			RADAR_WINDOW:Show(false)
		end
	end
end

-- Called from configui when the "Radar: Enable" checkbox changes. Reconciles
-- both windows immediately for whatever target is currently being tracked.
function radar.SetEnabled(enabled)
	settings.Update("RadarEnabled", enabled)
	radar.RefreshWindowVisibility()
	tracking.RefreshWindowVisibility()
end

local function createRadarUI()
	local window = api.Interface:CreateEmptyWindow("RADAR_WINDOW")
	if window == nil then
		helpers.DevLog("Failed to create radar window")
		return nil
	end
	local scale = settings.Get("uiDrawScale")
	window:AddAnchor("TOPLEFT", "UIParent", settings.Get("RadarWindowX"), settings.Get("RadarWindowY"))
	window:SetExtent(WINDOW_SIZE * scale, PANEL_HEIGHT * scale)
	window:Show(false)

	-- Same background as tracking.lua's TRACK_WINDOW, sized to the whole panel
	-- so it shows behind the title/distance/button strips (the circle image
	-- itself is opaque and draws on top of it in the middle band).
	window.panelBackground = window:CreateImageDrawable("radarPanelBackground", "background")
	window.panelBackground:AddAnchor("TOPLEFT", window, 0, 0)
	window.panelBackground:SetExtent(WINDOW_SIZE * scale, PANEL_HEIGHT * scale)
	window.panelBackground:SetTexture(constants.folderPath .. "images/trackerbackground.png")
	window.panelBackground:SetColor(0.5, 0.5, 0.5, 0.6)
	window.panelBackground:Show(true)

	window.titleLabel = helpers.createLabel("radarTitleLabel", window, "Target: undefined", 10, 5, 14)
	ApplyTextColor(window.titleLabel, FONT_COLOR.WHITE)

	window.background = window:CreateImageDrawable("radarBackground", "background")
	window.background:AddAnchor("TOPLEFT", window, 0, TITLE_HEIGHT * scale)
	window.background:SetExtent(WINDOW_SIZE * scale, WINDOW_SIZE * scale)
	window.background:SetTexture(constants.folderPath .. "images/radar/range_far.png")
	window.background:Show(true)

	window.dot = window:CreateImageDrawable("radarDot", "overlay")
	window.dot:SetExtent(WINDOW_SIZE * scale, WINDOW_SIZE * scale)
	window.dot:AddAnchor("TOPLEFT", window, 0, TITLE_HEIGHT * scale)
	window.dot:SetTexture(constants.folderPath .. "images/radar/target.png")
	window.dot:Show(true)

	window.distanceLabel = helpers.createLabel("radarDistanceLabel", window, "Distance: 0.0m", 10, TITLE_HEIGHT + WINDOW_SIZE + 5, 14)
	ApplyTextColor(window.distanceLabel, FONT_COLOR.WHITE)

	helpers.makeWindowDraggable(window, nil, nil, true, true, "RadarWindowX", "RadarWindowY")

	window.closeBtn = window:CreateChildWidget("button", "radarCloseBtn", 0, true)
	window.closeBtn:AddAnchor("TOPLEFT", window, (WINDOW_SIZE * scale) - (20 * scale), 3 * scale)
	api.Interface:ApplyButtonSkin(window.closeBtn, BUTTON_BASIC.WINDOW_SMALL_CLOSE)
	window.closeBtn:Show(true)
	window.closeBtn:SetHandler("OnClick", radar.clearTarget)
	window:SetHandler("OnClose", radar.clearTarget)
	window:SetHandler("OnCloseByEsc", radar.clearTarget)

	-- Show/Next buttons render below the panel, mirroring tracking.lua's
	-- TRACK_WINDOW:GetHeight()+5 button placement.
	window.nextBtn = window:CreateChildWidget("button", "radarNextBtn", 0, true)
	window.nextBtn:AddAnchor("TOPLEFT", window, 15 * scale, window:GetHeight() + 5)
	window.nextBtn:SetExtent(90 * scale, 30 * scale)
	api.Interface:ApplyButtonSkin(window.nextBtn, BUTTON_BASIC.DEFAULT)
	window.nextBtn:Show(false)
	function window.nextBtn:OnClick()
		if radarCurrentType == "Map" then
			eventbus.TriggerEvent(eventtopics.topics.tracking.nextMap)
		elseif radarCurrentType == "Ship" then
			eventbus.TriggerEvent(eventtopics.topics.tracking.nextShip)
		elseif radarCurrentType == "Dawns" then
			eventbus.TriggerEvent(eventtopics.topics.tracking.nextGuided)
		end
	end
	window.nextBtn:SetHandler("OnClick", window.nextBtn.OnClick)

	window.showBtn = window:CreateChildWidget("button", "radarShowBtn", 0, true)
	window.showBtn:AddAnchor("TOPLEFT", window, 190 * scale, window:GetHeight() + 5)
	window.showBtn:SetExtent(90 * scale, 30 * scale)
	api.Interface:ApplyButtonSkin(window.showBtn, BUTTON_BASIC.DEFAULT)
	window.showBtn:SetText("Show")
	window.showBtn:Show(false)
	function window.showBtn:OnClick()
		if radarTargetXMap == nil or radarTargetYMap == nil then
			return
		end
		api.Map:ToggleMapWithPortal(constants.game.portalZoneId, radarTargetXMap, radarTargetYMap, constants.game.portalZoomLevel)
	end
	window.showBtn:SetHandler("OnClick", window.showBtn.OnClick)

	return window
end

local throttledRadarUpdate = helpers.throttle(constants.timing.trackingPoll / 4, radar.update)
function radar.onUpdate(dt)
	throttledRadarUpdate(dt)
end

function radar.OnLoad()
	RADAR_WINDOW = createRadarUI()
	eventbus.WatchEvent(eventtopics.topics.tracking.custom, radar.setTarget, "radar")
	eventbus.WatchEvent(eventtopics.topics.tracking.start, radar.setTarget, "radar")
	eventbus.WatchEvent(eventtopics.topics.tracking.stop, radar.clearTarget, "radar")
end

function radar.OnUnload()
	if RADAR_WINDOW ~= nil then
		if RADAR_WINDOW:IsVisible() then
			RADAR_WINDOW:Show(false)
		end
		api.Interface:Free(RADAR_WINDOW)
		RADAR_WINDOW = nil
	end
	radarTargetSextant = nil
	radarTargetName = nil
	radarCurrentType = nil
	radarTargetXMap = nil
	radarTargetYMap = nil
	smoothedRadius = nil
	smoothedAngleDeg = nil
	currentBackgroundMode = nil
end

return radar
