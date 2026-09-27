local api = require("api")
local coordinates = require("WorldSatNav/core/coordinates")
local constants = require("WorldSatNav/core/constants")
local helpers = require("WorldSatNav/helpers")
local settings = require("WorldSatNav/core/settings")
local gps = require("WorldSatNav/features/gps")
local regionmap = require("WorldSatNav/ui/regionmap")
local dawnsdrop = require("WorldSatNav/features/dawnsdrop")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")

local tracking = {}

local TRACK_WINDOW = nil
local lastArrowDir = ""

local targetSextant = nil
local targetName = nil
local targetXMap = nil
local targetYMap = nil
local currentTrackedType = nil

-- Bag changes are debounced and then the tracked map location is recounted.
-- Deliberately ignores the REMOVED_ITEM/BAG_UPDATE payloads: the bag slot
-- widgets iterateTreasureMaps reads can still hold the consumed map when
-- REMOVED_ITEM fires, and the payload shape differs between the two events.
local INVENTORY_RECOUNT_DEBOUNCE = 400
local inventoryRecountPending = false
local inventoryRecountElapsed = 0

local currentNextButtonCallback = nil
local EVENT_NEXT_MAP = eventtopics.topics.tracking.nextMap
local EVENT_NEXT_SHIP = eventtopics.topics.tracking.nextShip
local EVENT_NEXT_GUIDED = eventtopics.topics.tracking.nextGuided

-- Teleport-vs-walk model. Walking straight to the target takes
-- directDistance / WALK_SPEED_MPS. Teleporting to the nearest same-region
-- Teleport POI then walking the rest takes TELEPORT_FIXED_COST_S +
-- poiToTargetDistance / WALK_SPEED_MPS. Break-even: teleport only wins when it
-- shaves more than TELEPORT_FIXED_COST_S * WALK_SPEED_MPS (~251m) off the walk.
local WALK_SPEED_MPS = 13.2
local TELEPORT_FIXED_COST_S = 19 -- 2s load + 9s portal cast + 4s location lookup + 4s buffer

-- Decision computed once, when a new target starts tracking (see
-- EvaluateTeleportPlan / setTargetGoto). nil = walking straight is at least as
-- fast, or no usable teleport / distance data.
local teleportPlan = nil
-- Player's region name when teleportPlan was computed. Once the player leaves it
-- (teleported / crossed a border), the plan is spent: drop the hint and show a
-- live walking distance instead.
local teleportPlanOriginRegion = nil

-- Distance between two sextants in the same "metres" the tracker displays.
-- coordinates.CalculateDistance returns raw game units; gps.getGPSGuideText
-- applies a 3.2/3.6 correction to match observed distances, so mirror it here.
local function MetersBetweenSextants(a, b)
	local d = coordinates.CalculateDistance(a, b)
	if d == nil or d == math.huge then
		return nil
	end
	return d * (3.2 / 3.6)
end

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

-- Distance trend: is the player getting closer to or further from the target?
-- Measured against a reference distance that only moves once the live distance
-- has changed by TREND_STEP_M, so sextant rounding noise cannot flip it.
-- The colour holds at full strength for TREND_HOLD_S seconds after the last
-- step, then fades back to white over TREND_FADE_S (stopped, or moving
-- sideways to the target).
local TREND_STEP_M = 1.0
local TREND_HOLD_S = 1
local TREND_FADE_S = 1.5
local TREND_COLORS = {
	closer = {0.4, 1, 0.4},
	further = {1, 0.45, 0.45},
}
local trendRefDistance = nil
local trendSinceStepS = 0 -- seconds since the last step, advanced by tracking.onUpdate's dt
local currentTrend = "neutral"

local function ResetDistanceTrend()
	trendRefDistance = nil
	trendSinceStepS = 0
	currentTrend = "neutral"
end

local function SetTrend(trend, detail)
	if trend ~= currentTrend then
		helpers.DevLog("Tracking trend: " .. currentTrend .. " -> " .. trend .. (detail or ""))
	end
	currentTrend = trend
end

-- @return string "closer", "further" or "neutral"
-- @return number strength 0-1 of the trend colour (1 = full colour, 0 = white)
function tracking.GetDistanceTrend()
	if targetSextant == nil then
		return "neutral", 0
	end
	local liveM = MetersBetweenSextants(api.Map:GetPlayerSextants(), targetSextant)
	if liveM == nil then
		return "neutral", 0
	end
	if trendRefDistance == nil then
		trendRefDistance = liveM
		trendSinceStepS = 0
		currentTrend = "neutral"
		return currentTrend, 0
	end

	local delta = liveM - trendRefDistance
	if math.abs(delta) >= TREND_STEP_M then
		-- A step long after the previous one while "stopped" points at position
		-- drift re-triggering the colour; log it to confirm in DEV_MODE.
		if trendSinceStepS >= TREND_HOLD_S then
			helpers.DevLog(string.format("Tracking trend: step %.2fm after %.1fs idle", delta, trendSinceStepS))
		end
		SetTrend(delta < 0 and "closer" or "further", string.format(" (step %.2fm)", delta))
		trendRefDistance = liveM
		trendSinceStepS = 0
	end

	if currentTrend == "neutral" then
		return currentTrend, 0
	end
	local fadeElapsed = trendSinceStepS - TREND_HOLD_S
	if fadeElapsed <= 0 then
		return currentTrend, 1
	end
	if fadeElapsed >= TREND_FADE_S then
		SetTrend("neutral")
		return currentTrend, 0
	end
	return currentTrend, 1 - fadeElapsed / TREND_FADE_S
end

-- Colours a distance label: the trend colour blended toward white by
-- (1 - strength). Skips the style call when the blended colour is unchanged.
function tracking.ApplyDistanceTrendColor(label, trend, strength)
	if label == nil or label.style == nil then
		return
	end
	local white = FONT_COLOR.WHITE
	local color = TREND_COLORS[trend]
	strength = color and (strength or 1) or 0
	color = color or white
	local r = white[1] + (color[1] - white[1]) * strength
	local g = white[2] + (color[2] - white[2]) * strength
	local b = white[3] + (color[3] - white[3]) * strength
	local key = string.format("%.2f,%.2f,%.2f", r, g, b)
	if label.appliedTrendColor == key then
		return
	end
	label.appliedTrendColor = key
	-- Always via style:SetColor: ApplyTextColor alone does not override a
	-- colour previously set on the style, so green/red would stick.
	label.style:SetColor(r, g, b, 1)
end

local function InvokeNextMapCallback()
	helpers.DevLog("Publishing next map event")
	eventbus.TriggerEvent(EVENT_NEXT_MAP)
end

local function InvokeNextShipCallback()
	eventbus.TriggerEvent(EVENT_NEXT_SHIP)
end

local function InvokeNextGuidedCallback()
	eventbus.TriggerEvent(EVENT_NEXT_GUIDED)
end

function tracking.IsActive()
	if TRACK_WINDOW == nil then
		return false
	end
	return TRACK_WINDOW:IsVisible()
end

-- The radar panel replaces this window's UI while enabled. Keeps TRACK_WINDOW
-- hidden in that case, and restores it (for the current target, if any) once
-- radar is turned back off. Called from setTargetGoto and on radar.setEnabled.
-- radarEnabled: optional override; the radar.setEnabled payload is passed in
-- because this watcher can run before radar's has saved the new setting.
function tracking.RefreshWindowVisibility(radarEnabled)
	if TRACK_WINDOW == nil or targetSextant == nil then
		return
	end
	if radarEnabled == nil then
		radarEnabled = settings.Get("RadarEnabled")
	end
	local shouldShow = radarEnabled ~= true
	if TRACK_WINDOW:IsVisible() == shouldShow then
		return
	end
	TRACK_WINDOW:Show(shouldShow)
	if shouldShow then
		-- AssignNextButton no-ops while the window is hidden, so a target set
		-- while radar was enabled never got its Next button wired up. Redo it
		-- now that the window is visible again.
		tracking.RefreshNextButton()
	end
end

-- Fully stop tracking: clear the tracked point and hide the window entirely,
-- rather than leaving a stale target with dead Next/Show buttons.
function tracking.Stop()
	targetSextant = nil
	targetName = nil
	targetXMap = nil
	targetYMap = nil
	currentTrackedType = nil
	currentNextButtonCallback = nil
	lastArrowDir = ""
	teleportPlan = nil
	teleportPlanOriginRegion = nil
	inventoryRecountPending = false
	ResetDistanceTrend()
	if TRACK_WINDOW == nil then
		return
	end
	if TRACK_WINDOW.nextBtn ~= nil then
		TRACK_WINDOW.nextBtn:Show(false)
	end
	if TRACK_WINDOW.showBtn ~= nil then
		TRACK_WINDOW.showBtn:Show(false)
	end
	if TRACK_WINDOW:IsVisible() then
		TRACK_WINDOW:Show(false)
	end
end

-- Dispatches the Next button to the callback for currentTrackedType. Shared by
-- setTargetGoto (new target) and RefreshWindowVisibility (window re-shown
-- after being hidden while radar owned the UI).
function tracking.RefreshNextButton()
	if currentTrackedType == "Map" then
		tracking.AssignNextButton("Map", InvokeNextMapCallback)
	elseif currentTrackedType == "Ship" then
		tracking.AssignNextButton("Ship", InvokeNextShipCallback)
	elseif currentTrackedType == "Dawns" then
		tracking.AssignNextButton("point", InvokeNextGuidedCallback)
	else
		tracking.AssignNextButton(nil, nil)
	end
end

local function CreateNextButton()
	if TRACK_WINDOW == nil then
		return
	end
	TRACK_WINDOW.nextBtn = TRACK_WINDOW:CreateChildWidget("button", "nextBtn", 0, true)
	TRACK_WINDOW.nextBtn:AddAnchor("TOPLEFT", TRACK_WINDOW, 15*settings.Get("uiDrawScale"), TRACK_WINDOW:GetHeight()+5)
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
	if settings.Get("EnableLocationOutput") ~= true then
		return
	end
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
	api.File:Write("WorldSatNav/data/"..settings.Get("LocationOutputFile"), writeFile)
	if updateTicker > 10000 then
		updateTicker = 0 -- reset ticker every 10 seconds to prevent overflow, just a helper so you can see file updates even if time has not changed
	end
	sharedDataLastUpdate = 0
end

-- Longer than this many chars, a "teleport: Region / Place" hint is split onto a
-- second line (distanceLabel2) at the " / " so it fits the fixed 335px window.
local TELEPORT_HINT_WRAP_LEN = 24

-- Sets the primary distance/hint line, and the optional wrapped second line.
local function SetDistanceText(line1, line2)
	if TRACK_WINDOW == nil or TRACK_WINDOW.distanceLabel == nil then
		return
	end
	local hasSecond = line2 ~= nil and line2 ~= ""
	-- Wrapped hints run smaller so long place names still fit the window width.
	local fontSize = hasSecond and 16 or 20
	TRACK_WINDOW.distanceLabel:SetText(line1 or "")
	TRACK_WINDOW.distanceLabel.style:SetFontSize(fontSize)
	if TRACK_WINDOW.distanceLabel2 ~= nil then
		TRACK_WINDOW.distanceLabel2:SetText(hasSecond and line2 or "")
		TRACK_WINDOW.distanceLabel2.style:SetFontSize(fontSize)
		TRACK_WINDOW.distanceLabel2:Show(hasSecond)
	end
end

-- Builds the (line1, line2) pair for a teleport hint, wrapping at " / " when long.
local function TeleportHintLines(name)
	local hint = "teleport: " .. name
	if string.len(hint) <= TELEPORT_HINT_WRAP_LEN then
		return hint, nil
	end
	local region, place = string.match(name, "^(.-) / (.+)$")
	if region == nil then
		return hint, nil
	end
	return "teleport: " .. region .. " /", place
end

-- Runs once per new target (setTargetGoto). Picks the nearest same-region
-- Teleport POI and compares "teleport then walk the rest" against "walk straight
-- there". Sets teleportPlan only when teleporting is strictly faster.
local function EvaluateTeleportPlan()
	teleportPlan = nil
	teleportPlanOriginRegion = nil
	if targetSextant == nil or not settings.Get("UseTeleportHint") then
		return
	end
	local playerSextant = api.Map:GetPlayerSextants()
	local directM = MetersBetweenSextants(playerSextant, targetSextant)
	if directM == nil then
		return
	end
	local filtered = settings.Get("TeleportHintFiltered") ~= false
	local teleport = dawnsdrop.FindNearestTeleport(targetSextant, filtered)
	if teleport == nil or teleport.location == nil then
		return
	end
	local poiToTargetM = MetersBetweenSextants(teleport.location, targetSextant)
	if poiToTargetM == nil then
		return
	end
	local walkSeconds = directM / WALK_SPEED_MPS
	local teleportSeconds = TELEPORT_FIXED_COST_S + (poiToTargetM / WALK_SPEED_MPS)
	if teleportSeconds >= walkSeconds then
		helpers.DevLog(string.format(
			"Teleport plan: walk %.0fm (%.0fs) beats teleport via '%s' (%.0fs) - no hint",
			directM, walkSeconds, tostring(teleport.name), teleportSeconds))
		return
	end
	teleportPlan = {
		name = teleport.name,
		savedSeconds = walkSeconds - teleportSeconds,
		poiToTargetM = poiToTargetM,
	}
	local _, originRegion = regionmap.GetRegionForSextant(playerSextant)
	if originRegion ~= nil and originRegion ~= "?" then
		teleportPlanOriginRegion = originRegion
	end
	helpers.DevLog(string.format(
		"Teleport plan: teleport via '%s' saves %.0fs vs walking %.0fm (origin region: %s)",
		tostring(teleport.name), teleportPlan.savedSeconds, directM, tostring(teleportPlanOriginRegion)))
end

-- Shared distance/teleport-hint text builder used by both TRACK_WINDOW and
-- radar.lua's distance field. Retires an expired teleport plan as a side
-- effect (same lifecycle updateTrackingData always applied). Independent of
-- TRACK_WINDOW's visibility, so radar can call it while that window is hidden.
-- Returns: line1, line2 (nil unless a wrapped teleport hint), isTeleportHint
function tracking.GetDistanceDisplayText()
	if targetSextant == nil then
		return "", nil, false
	end

	local _, regionNameTarget = regionmap.GetRegionForSextant(targetSextant)
	local _, regionNamePlayer = regionmap.GetRegionForSextant(api.Map:GetPlayerSextants())

	-- The teleport plan is only valid from the region it was computed in. Once the
	-- player teleports (or walks) into a different region, retire it so tracking
	-- falls back to a live distance readout.
	if teleportPlan ~= nil and teleportPlanOriginRegion ~= nil
		and regionNamePlayer ~= "?" and regionNamePlayer ~= teleportPlanOriginRegion then
		helpers.DevLog("Tracking: player left origin region '" .. teleportPlanOriginRegion
			.. "' (now '" .. regionNamePlayer .. "') - dropping teleport hint")
		teleportPlan = nil
		teleportPlanOriginRegion = nil
	end

	-- teleportPlan is decided once per target in EvaluateTeleportPlan. Suppress the
	-- hint once walking straight from where the player is now beats teleporting -
	-- i.e. after the teleport has happened, or the player has walked close enough.
	-- Region equality is not a usable proxy here: the nearest teleport POI is
	-- often in the same region as both the player and a coastal/ship target, so
	-- comparing regions hid the hint for targets teleporting would still shorten.
	local useTeleport = teleportPlan ~= nil
	if useTeleport then
		local liveDirectM = MetersBetweenSextants(api.Map:GetPlayerSextants(), targetSextant)
		if liveDirectM ~= nil and teleportPlan.poiToTargetM ~= nil then
			-- Same break-even as EvaluateTeleportPlan: teleporting only wins when it
			-- shaves more than the fixed teleport cost (~251m of walking) off the trip.
			local shavedM = liveDirectM - teleportPlan.poiToTargetM
			if shavedM <= TELEPORT_FIXED_COST_S * WALK_SPEED_MPS then
				useTeleport = false
			end
		end
	end

	local _, navDistance, navDistanceScale = gps.getNavigationText(targetSextant)

	if useTeleport and navDistanceScale ~= "m" then
		if teleportPlan.name ~= nil and teleportPlan.name ~= "" then
			local line1, line2 = TeleportHintLines(teleportPlan.name)
			return line1, line2, true
		end
		return "teleport to " .. regionNameTarget, nil, true
	end

	return string.format("%.1f %s", navDistance, navDistanceScale), nil, false
end

local function updateTrackingData()

	if TRACK_WINDOW == nil or not TRACK_WINDOW:IsVisible() or targetSextant == nil then
		return
	end

	local _, regionNameTarget = regionmap.GetRegionForSextant(targetSextant)

	if TRACK_WINDOW.showBtn ~= nil then
		local showEnabled = settings.Get("EnableShowOnTracking")
		if showEnabled and currentTrackedType == "Map" then
			local hasMapsRemaining = false
			helpers.iterateTreasureMaps(function(_, _, info)
				if hasMapsRemaining then
					return
				end
				local mapSextant = SextantFromInfo(info)
				local _, mapRegionName = regionmap.GetRegionForSextant(mapSextant)
				if mapRegionName == regionNameTarget then
					hasMapsRemaining = true
				end
			end)
			if not hasMapsRemaining then
				showEnabled = false
			end
		end
		if TRACK_WINDOW.showBtn:IsVisible() ~= showEnabled then
			TRACK_WINDOW.showBtn:Show(showEnabled)
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
	if fontsize < 10 then
		fontsize = 10
	end
	local appliedFontSize = TRACK_WINDOW.markNameLabel.fontSize
	if appliedFontSize ~= fontsize then
		TRACK_WINDOW.markNameLabel.style:SetFontSize(fontsize)
		TRACK_WINDOW.markNameLabel.fontSize = fontsize
	end
	local navDir, _, _, _, relativeDir = gps.getNavigationText(targetSextant)
	local line1, line2, isTeleport = tracking.GetDistanceDisplayText()
	SetDistanceText(line1, line2)
	local trend, strength = tracking.GetDistanceTrend()
	if isTeleport then
		trend = "neutral"
	end
	tracking.ApplyDistanceTrendColor(TRACK_WINDOW.distanceLabel, trend, strength)

	if isTeleport then
		updateNavArrow("portal2")
	else
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
	TRACK_WINDOW.bg:SetExtent(335*settings.Get("uiDrawScale"), 125*settings.Get("uiDrawScale"))
	TRACK_WINDOW.bg:AddAnchor("TOPLEFT", TRACK_WINDOW, 0, 0)
	TRACK_WINDOW.bg:Show(true)
	TRACK_WINDOW:SetExtent(335*settings.Get("uiDrawScale"), 125*settings.Get("uiDrawScale"))
	TRACK_WINDOW:Show(false)

	TRACK_WINDOW.arrow = TRACK_WINDOW:CreateImageDrawable("trackarrow", "overlay")
	TRACK_WINDOW.arrow:SetTexture(constants.folderPath.."images/arrows/n.png")
	TRACK_WINDOW.arrow:AddAnchor("TOPLEFT", TRACK_WINDOW, 20, 30*settings.Get("uiDrawScale"))
	TRACK_WINDOW.arrow:SetExtent(64*settings.Get("uiDrawScale"), 64*settings.Get("uiDrawScale"))
	TRACK_WINDOW.arrow:Show(true)

	helpers.makeWindowDraggable(TRACK_WINDOW, nil,nil,true,true, "TrackingWindowX", "TrackingWindowY")

	-- Close button
	TRACK_WINDOW.closeBtn = TRACK_WINDOW:CreateChildWidget("button", "closeBtn", 0, true)
	TRACK_WINDOW.closeBtn:AddAnchor("TOPLEFT", TRACK_WINDOW, (335*settings.Get("uiDrawScale"))-(20*settings.Get("uiDrawScale")), 3*settings.Get("uiDrawScale"))
	api.Interface:ApplyButtonSkin(TRACK_WINDOW.closeBtn, BUTTON_BASIC.WINDOW_SMALL_CLOSE)
	TRACK_WINDOW.closeBtn:Show(true)

	function TRACK_WINDOW.OnClose(button, clicktype)
		TRACK_WINDOW:Show(false)
		if onCloseCallback then
			onCloseCallback()
		end
		-- Closing the tracker ends tracking (clears the map target ring too),
		-- matching the radar's close button.
		eventbus.TriggerEvent(eventtopics.topics.tracking.stop)
	end

	TRACK_WINDOW.closeBtn:SetHandler("OnClick", TRACK_WINDOW.OnClose)

	-- Show button (opens the real map at the tracked location)
	TRACK_WINDOW.showBtn = TRACK_WINDOW:CreateChildWidget("button", "showBtn", 0, true)
	TRACK_WINDOW.showBtn:AddAnchor("TOPLEFT", TRACK_WINDOW, 190*settings.Get("uiDrawScale"), TRACK_WINDOW:GetHeight()+5)
	TRACK_WINDOW.showBtn:SetExtent(90*settings.Get("uiDrawScale"), 30*settings.Get("uiDrawScale"))
	api.Interface:ApplyButtonSkin(TRACK_WINDOW.showBtn, BUTTON_BASIC.DEFAULT)
	TRACK_WINDOW.showBtn:SetText("Show")
	TRACK_WINDOW.showBtn:Show(true)
	TRACK_WINDOW.showBtn:Enable(true)
	TRACK_WINDOW.showBtn:Raise()
	function TRACK_WINDOW.showBtn:OnClick()
		if targetXMap == nil or targetYMap == nil then
			helpers.DevLog("Show button clicked but no tracked target coordinates available")
			return
		end
		helpers.DevLog("Show button clicked, opening real map at tracked location")
		api.Map:ToggleMapWithPortal(constants.game.portalZoneId, targetXMap, targetYMap, constants.game.portalZoomLevel)
	end
	TRACK_WINDOW.showBtn:SetHandler("OnClick", TRACK_WINDOW.showBtn.OnClick)

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
	distanceLabel:AddAnchor('TOPLEFT', TRACK_WINDOW, 95*settings.Get("uiDrawScale"), 66*settings.Get("uiDrawScale"))
	ApplyTextColor(distanceLabel, FONT_COLOR.WHITE)
	TRACK_WINDOW.distanceLabel = distanceLabel

	-- Second distance line: only shown when a teleport hint wraps (see SetDistanceText).
	local distanceLabel2 = helpers.createLabel('distanceLabel2', TRACK_WINDOW, '', 0, 0)
	if distanceLabel2 ~= nil then
		distanceLabel2:RemoveAllAnchors()
		distanceLabel2:AddAnchor('TOPLEFT', TRACK_WINDOW, 95*settings.Get("uiDrawScale"), 88*settings.Get("uiDrawScale"))
		ApplyTextColor(distanceLabel2, FONT_COLOR.WHITE)
		distanceLabel2:Show(false)
		TRACK_WINDOW.distanceLabel2 = distanceLabel2
	end

	return TRACK_WINDOW
end


function tracking.setTargetGoto(sextant, name, ShowMapMarker, displayName)
	local normalizedSextant = coordinates.NormalizeSextant(sextant)
	if normalizedSextant == nil or normalizedSextant.longitude == nil or normalizedSextant.latitude == nil
		or normalizedSextant.deg_long == nil or normalizedSextant.deg_lat == nil then
		helpers.DevLog("Invalid sextant for tracking target, cannot update")
		return
	end
	targetSextant = normalizedSextant
	targetName = displayName or name
	currentTrackedType = name
	ResetDistanceTrend()
	ShowMapMarker = ShowMapMarker or false
	if TRACK_WINDOW == nil then
		helpers.DevLog("tracking window not initialized, cannot set target")
		return
	end
	tracking.RefreshWindowVisibility()
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
	targetXMap = xMap
	targetYMap = yMap
	if (ShowMapMarker == true) and (settings.Get("OpenRealMap") == true) then
		helpers.DevLog("Showing map marker for target sextant at coordinates: " .. xMap .. ", " .. yMap)
		api.Map:ToggleMapWithPortal(constants.game.portalZoneId, xMap, yMap, constants.game.portalZoomLevel)
	end
	tracking.RefreshNextButton()
	helpers.DevLog("Target set to sextant: " .. helpers.SextantKey(normalizedSextant) .. " with name: " .. tostring(name))
	-- Decide teleport-vs-walk once here, not every frame in updateTrackingData.
	EvaluateTeleportPlan()
	if settings.Get("ShowTargetInfoInChat") == true then
		local _, regionName = regionmap.GetRegionForSextant(normalizedSextant)
		api.Chat:DispatchChatMessage(4, "[WorldSatNav] Tracking target set to: " .. tostring(targetName).. " at " .. helpers.FormatSextant(normalizedSextant).." in region: " .. tostring(regionName))
	end
	updateTrackingData()
end

function tracking.forceInventoryUpdateForTracking()
	if currentTrackedType ~= "Map" or targetSextant == nil then
		return
	end
	inventoryRecountPending = true
	inventoryRecountElapsed = 0
end

local function RecountTrackedMaps()
	if currentTrackedType ~= "Map" or targetSextant == nil then
		return
	end
	-- If the user closed the tracking window, a bag update must not silently
	-- re-open it via the auto-next-map path below. In radar mode TRACK_WINDOW
	-- is always hidden; closing the radar fires tracking.stop instead, so
	-- targetSextant (checked above) covers that case.
	if TRACK_WINDOW == nil then
		return
	end
	if settings.Get("RadarEnabled") ~= true and not TRACK_WINDOW:IsVisible() then
		return
	end
	local targetKey = helpers.SextantKey(targetSextant)
	local mapCount = 0
	local mapGrade = nil
	local mapsInRegion = 0
	local _, playerRegionName = regionmap.GetRegionForSextant(api.Map:GetPlayerSextants())
	helpers.iterateTreasureMaps(function(_, _, info)
		local mapSextant = SextantFromInfo(info)
		if helpers.SextantKey(mapSextant) == targetKey then
			mapCount = mapCount + 1
			mapGrade = info.grade
		end
		local _, mapRegionName = regionmap.GetRegionForSextant(mapSextant)
		if playerRegionName ~= nil and playerRegionName ~= "?" and mapRegionName == playerRegionName then
			mapsInRegion = mapsInRegion + 1
		end
	end)
	local newDisplayName = "Map (" .. mapCount .. ")"
	if mapGrade ~= nil then
		newDisplayName = newDisplayName .. " [" .. mapGrade .. "]"
	end
	-- Unrelated bag changes recount to the same name; nothing to do.
	if newDisplayName == targetName then
		return
	end
	helpers.DevLog("Maps remaining at tracked location: " .. mapCount .. ", in player region: " .. mapsInRegion)
	local nextMapMode = settings.Get("NextMapMode") or 1
	if nextMapMode ~= 2 and mapsInRegion > 0 and settings.Get("ShowTargetInfoInChat") == true then
		api.Chat:DispatchChatMessage(4, "[WorldSatNav] You have " .. mapsInRegion .. " more map(s) in your current region.")
	end
	targetName = newDisplayName
	updateTrackingData()
	eventbus.TriggerEvent(eventtopics.topics.tracking.targetRenamed, newDisplayName)
	if mapCount == 0 and settings.Get("AutoGotoNextMap") == true then
		InvokeNextMapCallback()
	end
end

local function UpdateInventoryRecount(dt)
	if not inventoryRecountPending then
		return
	end
	inventoryRecountElapsed = inventoryRecountElapsed + (dt or 0)
	if inventoryRecountElapsed < INVENTORY_RECOUNT_DEBOUNCE then
		return
	end
	inventoryRecountPending = false
	inventoryRecountElapsed = 0
	RecountTrackedMaps()
end

local throttledTrackingData = helpers.throttle(constants.timing.trackingPoll, updateTrackingData)
function tracking.onUpdate(dt)
	trendSinceStepS = trendSinceStepS + (tonumber(dt) or 0) / 1000
	UpdateSharedData(dt)
	throttledTrackingData(dt)
	UpdateInventoryRecount(dt)
end

function tracking.OnLoad()
    TRACK_WINDOW = createTrackUI(nil)
	eventbus.WatchEvent(eventtopics.topics.tracking.custom, tracking.setTargetGoto, "tracking")
	eventbus.WatchEvent(eventtopics.topics.tracking.start, tracking.setTargetGoto, "tracking")
	eventbus.WatchEvent(eventtopics.topics.tracking.stop, tracking.Stop, "tracking")
	eventbus.WatchEvent(eventtopics.topics.bag.itemRemoved, tracking.forceInventoryUpdateForTracking, "tracking")
	eventbus.WatchEvent(eventtopics.topics.bag.updated, tracking.forceInventoryUpdateForTracking, "tracking")
	eventbus.WatchEvent(eventtopics.topics.radar.setEnabled, tracking.RefreshWindowVisibility, "tracking")
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