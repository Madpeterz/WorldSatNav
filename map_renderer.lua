-- WorldSatNav Map Renderer
-- Handles map marker/dot rendering and texture management

local api = require("api")
local constants = require("WorldSatNav/constants")
local coordinates = require("WorldSatNav/coordinates")
local gps = require("WorldSatNav/gps")
local helpers = require("WorldSatNav/helpers")

local MapRenderer = {}

-- State
local mapWindow = nil
local mapDrawable = nil
local renderedDots = {}
local selectedMapItem = nil
local flashState = false
local flashToggleTimer = 0
local currentRegion = "*"

MapRenderer.IsMapOpen = function()
	return mapWindow ~= nil and mapWindow:IsVisible()
end

-- Apply texture and correct size to a marker widget
local function applyMarkerTexture(marker, totalatpoint, customIcon, customsizeWidth, customsizeHeight)
	local sizeX, sizeY = 18/2, 17/2
	if customIcon == nil then
		marker:SetTexture(api.baseDir .. "/WorldSatNav/images/marker"..totalatpoint..".png")
	else
		marker:SetTexture(api.baseDir .. "/WorldSatNav/images/" .. customIcon)
		if customIcon == "player2.png" then
			sizeX, sizeY = 18, 18
		end
	end
	if customsizeWidth ~= nil and customsizeHeight ~= nil then
		sizeX, sizeY = customsizeWidth, customsizeHeight
	end
	marker:SetExtent(sizeX, sizeY)
end

-- Internal marker pooling
local function getOrCreateMarkerFromPool(totalatpoint, customIcon, customsizeWidth, customsizeHeight)
	if totalatpoint == nil or totalatpoint < 1 then totalatpoint = 1 end
	if totalatpoint > 3 then totalatpoint = 3 end

	-- Try to reuse existing hidden marker
	for _, marker in pairs(renderedDots) do
		if marker ~= nil and not marker:IsVisible() then
			applyMarkerTexture(marker, totalatpoint, customIcon, customsizeWidth, customsizeHeight)
			return marker
		end
	end

	-- Create new marker
	if mapWindow == nil then
		return nil
	end
	local marker = mapWindow:CreateImageDrawable("yes", "overlay")
	applyMarkerTexture(marker, totalatpoint, customIcon, customsizeWidth, customsizeHeight)
	table.insert(renderedDots, marker)
	return marker
end

-- Hide all dots
local function hideDots()
	for _, marker in pairs(renderedDots) do
		if marker ~= nil and marker:IsVisible() then
			marker:Show(false)
			marker.ItemData = nil
		end
	end
end

-- Place a marker at pixel coordinates if within map bounds
local function placeMarker(xPos, yPos, totalatpoint, customIcon, itemData, customsizeWidth, customsizeHeight)
	if xPos < 0 + 30 or xPos > constants.map.width - 30 or yPos < 0 + 20 or yPos > constants.map.height - 20 then
		return
	end
	local marker = getOrCreateMarkerFromPool(totalatpoint, customIcon, customsizeWidth, customsizeHeight)
	if marker ~= nil then
		marker.ItemData = itemData
		marker.drawX = xPos
		marker.drawY = yPos
		marker:AddAnchor("TOPLEFT", mapDrawable, xPos - marker:GetWidth()/2, yPos - marker:GetHeight()/2)
		marker:Show(true)
	end
end

-- Render a single treasure map as a dot on the map
local function renderMapToDot(info, totalatpoint, customIcon, customsizeWidth, customsizeHeight)
	if info.longitudeDir and info.latitudeDir then
		local xPos, yPos = coordinates.getMapDrawPoint(
			info.longitudeDir, info.latitudeDir,
			info.longitudeDeg or 0, info.longitudeMin or 0, info.longitudeSec or 0,
			info.latitudeDeg or 0, info.latitudeMin or 0, info.latitudeSec or 0
		)
		placeMarker(xPos, yPos, totalatpoint, customIcon, info, customsizeWidth, customsizeHeight)
	end
end

function MapRenderer.renderPlayerMarker()
	local p = gps.GetCurrentPosition()
	if p == nil then
		return
	end
	local xPos, yPos = coordinates.getMapDrawPoint(
		p.longitude, p.latitude,
		p.deg_long, p.min_long, p.sec_long,
		p.deg_lat, p.min_lat, p.sec_lat
	)
	placeMarker(xPos, yPos, 1, "player2.png", nil)
end

-- Public API

--- Initialize the map renderer with window and drawable references
-- @param window widget the main window containing the map
-- @param drawable widget the image drawable that displays the map texture
function MapRenderer.initialize(window, drawable)
	mapWindow = window
	mapDrawable = drawable
	if mapWindow == nil or mapDrawable == nil then 
		return 
	end
	MapRenderer.ChangeMapTexture("*")
end

function MapRenderer.ChangeMapTexture(region)
	if mapWindow == nil or mapDrawable == nil then 
		return 
	end
	currentRegion = region
	local regionTextures = {
		["*"] = "world12.png",
		["Nuia"] = "world12_nuia.png",
		["Haranya"] = "world12_haranya.png",
		["Halcy Glf"] = "world12_nuia.png",
		["Castaway"] = "world12_haranya.png",
		["Arcadian"] = "world12_arcadian.png",
		["Auroria"] = "world12_auroria.png",
	}
	local textureFile = regionTextures[region] or regionTextures["*"]
	local texturePath = api.baseDir .. "/WorldSatNav/images/map/" .. textureFile
	mapDrawable:Show(false)
	mapDrawable:SetTexture(texturePath)
	mapDrawable:Show(true)
end

MapRenderer.hideDots = hideDots
MapRenderer.renderDot = renderMapToDot

local function MapToCordStringBase64(map)
	local latDir = map.latitudeDir or ""
	local lonDir = map.longitudeDir or ""
	local latDeg = map.latitudeDeg or 0
	local latMin = map.latitudeMin or 0
	local latSec = map.latitudeSec or 0
	local lonDeg = map.longitudeDeg or 0
	local lonMin = map.longitudeMin or 0
	local lonSec = map.longitudeSec or 0

	return string.format("%s%d_%d_%d_%s%d_%d_%d",
		latDir, latDeg, latMin, latSec,
		lonDir, lonDeg, lonMin, lonSec
	)
end
--- Render all treasure map markers on the map
-- Scans bag contents and places a marker dot for each treasure map
function MapRenderer.render()
	MapRenderer.ChangeMapTexture(currentRegion)
	hideDots()
	MapRenderer.renderPlayerMarker()

	-- If a specific map is selected (flash mode), only show that one when flash is on
	if selectedMapItem ~= nil then
		if flashState then
			renderMapToDot(selectedMapItem, 1)
		end
	else
		-- Normal mode: show all treasure maps
		local mapPointCounter = {}
		helpers.iterateTreasureMaps(function(_, _, info)
			local mapId = MapToCordStringBase64(info)
			if mapPointCounter[mapId] == nil then
				mapPointCounter[mapId] = {info, 1}
			else
				mapPointCounter[mapId][2] = mapPointCounter[mapId][2] + 1
			end
		end)
		
		-- Convert to array and sort by count (ascending)
		local sortedMaps = {}
		for _, value in pairs(mapPointCounter) do
			table.insert(sortedMaps, value)
		end
		table.sort(sortedMaps, function(a, b)
			return a[2] < b[2]  -- Sort by count: 1, 2, 3, etc.
		end)
		
		-- Render in sorted order
		for _, value in ipairs(sortedMaps) do
			local info = value[1]
			local totalAtPoint = value[2]
			renderMapToDot(info, totalAtPoint)
		end
	end
end

--- Get the list of all rendered marker dots
-- @return table array of marker widgets
function MapRenderer.getRenderedDots()
	return renderedDots
end

--- Clean up all markers and reset renderer state
function MapRenderer.cleanup()
	hideDots()
	renderedDots = {}
	selectedMapItem = nil
	flashState = false
end

--- Set the selected map item for flash mode
-- @param itemData table treasure map item info or nil to clear
function MapRenderer.setSelectedMapItem(itemData)
	selectedMapItem = itemData
	flashState = false
	flashToggleTimer = 0
end

--- Get the currently selected map item
-- @return table selected item data or nil
function MapRenderer.getSelectedMapItem()
	return selectedMapItem
end

--- Toggle flash state for the selected map marker
function MapRenderer.toggleFlash()
	flashState = not flashState
end

--- Update flash timer and toggle state when threshold is reached
-- @param dt number delta time in milliseconds
function MapRenderer.updateFlash(dt)
	if selectedMapItem == nil then
		return
	end
	
	flashToggleTimer = flashToggleTimer + dt
	
	-- Toggle flash every 500ms for visible blinking effect
	if flashToggleTimer >= 500 then
		flashToggleTimer = 0
		flashState = not flashState
	end
end

--- Get current flash state
-- @return boolean true if flash is currently on
function MapRenderer.getFlashState()
	return flashState
end

return MapRenderer
