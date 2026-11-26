-- WorldSatNav map calibration
-- Loads the anchor points (known sextant -> true zoom-3.png pixel) that
-- core/coordinates uses to correct the linear map formula, and provides the
-- DEV_MODE capture tool: stand somewhere, click where you really are on the map,
-- and that pair is saved as an anchor.
local api = require("api")
local helpers = require("WorldSatNav/helpers")
local constants = require("WorldSatNav/core/constants")
local coordinates = require("WorldSatNav/core/coordinates")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")
local settingsModule = require("WorldSatNav/core/settings")

local TOPICS = eventtopics.topics

local calibration = {}

local ANCHORS_FILE_PATH = "WorldSatNav/data/calibration.dat"
local ANCHOR_ICON_TEXTURE = "icons/marker3.png"
local ANCHOR_ICON_SIZE = 9
local BUTTON_LABEL_OFF = "Calibrate"
local BUTTON_LABEL_ON = "Done"

-- { { px = number, py = number, sextant = { longitude, deg_long, ... } }, ... }
-- px/py are zoom-3.png pixels, rounded to 0.1 (api.File:Write keeps 6
-- significant digits, so 4047.3 survives).
local anchors = {}
local active = false
local calibrateButton = nil

local function Chat(message)
	api.Chat:DispatchChatMessage(4, "[WorldSatNav] " .. message)
end

local function RoundTenth(value)
	return math.floor((value * 10) + 0.5) / 10
end

local function CopySextant(sextant)
	return {
		longitude = sextant.longitude,
		latitude = sextant.latitude,
		deg_long = sextant.deg_long,
		min_long = sextant.min_long,
		sec_long = sextant.sec_long,
		deg_lat = sextant.deg_lat,
		min_lat = sextant.min_lat,
		sec_lat = sextant.sec_lat,
	}
end

local function FindAnchorIndex(sextant)
	local key = helpers.SextantKey(sextant)
	for index, anchor in ipairs(anchors) do
		if helpers.SextantKey(anchor.sextant) == key then
			return index
		end
	end
	return nil
end

local function LoadAnchors()
	local loaded = api.File:Read(ANCHORS_FILE_PATH)
	anchors = {}
	if type(loaded) == "table" then
		for _, anchor in ipairs(loaded) do
			local sextant = coordinates.NormalizeSextant(anchor.sextant)
			local px, py = tonumber(anchor.px), tonumber(anchor.py)
			if sextant ~= nil and px ~= nil and py ~= nil then
				anchors[#anchors + 1] = { px = px, py = py, sextant = CopySextant(sextant) }
			end
		end
	end
	local accepted = coordinates.SetAnchors(anchors)
	helpers.DevLog("Loaded " .. tostring(accepted) .. " map calibration anchors")
end

local function SaveAnchors()
	api.File:Write(ANCHORS_FILE_PATH, anchors)
	coordinates.SetAnchors(anchors)
end

-- Redraws the map with only the anchor markers (plus player/target), so the
-- player icon's corrected position can be compared against the real spot.
local function DrawAnchors()
	local iconsData = {}
	for _, anchor in ipairs(anchors) do
		iconsData[#iconsData + 1] = {
			sextant = anchor.sextant,
			texture = ANCHOR_ICON_TEXTURE,
			sourceType = "Calibration",
			customIconSize = ANCHOR_ICON_SIZE,
			label = "Anchor",
		}
	end
	eventbus.TriggerEvent(TOPICS.icons.BulkDrawIconsAndRedraw, iconsData)
end

local function UpdateButton()
	if calibrateButton == nil then
		return
	end
	calibrateButton:SetText(active and BUTTON_LABEL_ON or BUTTON_LABEL_OFF)
	local visible = constants.DEV_MODE == true
	calibrateButton:Show(visible)
	calibrateButton:Enable(visible)
end

local function SetActive(enabled, redraw)
	enabled = enabled == true
	if enabled == active then
		return
	end
	active = enabled
	eventbus.TriggerEventImmediate(TOPICS.calibration.modeChanged, active)
	UpdateButton()
	if active then
		Chat("Calibrating (" .. #anchors .. " anchors). Stand still, then click where you really are on the map. "
			.. "Clicking again from the same spot moves that anchor; click an anchor marker to delete it. "
			.. "Zoom in fully for accuracy.")
		DrawAnchors()
	else
		Chat("Calibration done, " .. #anchors .. " anchors saved")
		if redraw then
			eventbus.TriggerEvent(TOPICS.render.redrawMap)
		end
	end
end

-- px, py: the clicked spot as zoom-3.png pixels.
local function OnCalibrationClick(px, py)
	if not active or px == nil or py == nil then
		return
	end
	local playerSextant = coordinates.NormalizeSextant(api.Map:GetPlayerSextants())
	if playerSextant == nil or playerSextant.longitude == nil or playerSextant.latitude == nil then
		Chat("Cannot add anchor: player position unavailable")
		return
	end
	px, py = RoundTenth(px), RoundTenth(py)
	local index = FindAnchorIndex(playerSextant)
	local verb = "Moved"
	if index == nil then
		anchors[#anchors + 1] = { px = px, py = py, sextant = CopySextant(playerSextant) }
		index = #anchors
		verb = "Added"
	else
		anchors[index].px = px
		anchors[index].py = py
	end
	SaveAnchors()

	-- How far the plain formula is from the clicked spot, in zoom-3.png pixels.
	local base = coordinates.BASE_RENDER
	local longValue, latValue = coordinates.SextantToValues(playerSextant)
	local offX = px - (base.zeroPointX + (longValue * base.XCordScale))
	local offY = py - (base.zeroPointY + (latValue * base.YCordScale))
	Chat(string.format("%s anchor %d at %s (formula off by %.1f, %.1f px)", verb, index,
		helpers.SextantKey(playerSextant), offX, offY))
	DrawAnchors()
end

local function OnRemoveAnchor(sextant)
	if not active or sextant == nil then
		return
	end
	local index = FindAnchorIndex(sextant)
	if index == nil then
		return
	end
	table.remove(anchors, index)
	SaveAnchors()
	Chat("Removed anchor at " .. helpers.SextantKey(sextant) .. ", " .. #anchors .. " left")
	DrawAnchors()
end

local function MainUIReady(mapUI)
	if mapUI == nil then
		return
	end
	local uiScale = settingsModule.Get("uiDrawScale")
	-- Top-right above the map, clear of the dawnsdrop dev row on the left.
	calibrateButton = helpers.createButton("calibrateButton", mapUI, BUTTON_LABEL_OFF, 420 * uiScale, -30 * uiScale)
	calibrateButton:Raise()
	calibrateButton:SetHandler("OnClick", function()
		SetActive(not active, true)
	end)
	UpdateButton()
end

local function OnDevModeChanged()
	if constants.DEV_MODE ~= true then
		SetActive(false, true)
	end
	UpdateButton()
end

-- Mode switches, settings and closing the map all redraw (or hide) the map
-- themselves, so calibrating just ends without a redraw of its own.
local function StopWithoutRedraw()
	SetActive(false, false)
end

function calibration.IsActive()
	return active
end

function calibration.OnLoad()
	LoadAnchors()
	eventbus.WatchEvent(TOPICS.UI.MainUILoaded, MainUIReady, "calibration")
	eventbus.WatchEvent(TOPICS.dev.modeChanged, OnDevModeChanged, "calibration")
	eventbus.WatchEvent(TOPICS.calibration.mapClick, OnCalibrationClick, "calibration")
	eventbus.WatchEvent(TOPICS.calibration.removeAnchor, OnRemoveAnchor, "calibration")
	eventbus.WatchEvent(TOPICS.render.modeChanged, StopWithoutRedraw, "calibration")
	eventbus.WatchEvent(TOPICS.render.config, StopWithoutRedraw, "calibration")
	eventbus.WatchEvent(TOPICS.UI.close, StopWithoutRedraw, "calibration")
end

function calibration.OnUnload()
	active = false
	-- A child of the map window, which maprendering.OnUnload frees.
	calibrateButton = nil
end

return calibration
