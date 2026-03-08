-- WorldSatNav Bag Overlay
-- Manages slot overlays showing treasure map regions in bag UI

local api = require("api")
local constants = require("WorldSatNav/constants")
local regions = require("WorldSatNav/regions")
local coordinates = require("WorldSatNav/coordinates")
local helpers = require("WorldSatNav/helpers")

local BagOverlay = {}

-- State
local slotOverlaysByRegion = {
	["Nuia"] = {},
	["Haranya"] = {},
	["Halcy Glf"] = {},
	["Castaway"] = {},
	["Arcadian"] = {},
	["Auroria"] = {},
}
local slotOverlaysAll = {}
local overlaysActive = false
local flashMode = false
local usedFlashMode = false

-- Get or create an overlay label for a specific bag slot and region
local function getOrCreateLabelFromPool(slotIndex, slotBtn, region)
	local existingOverlay = slotOverlaysByRegion[region] and slotOverlaysByRegion[region][slotIndex]
	
	if existingOverlay then
		if not existingOverlay:IsVisible() then
			existingOverlay:Show(true)
		end
		return existingOverlay
	end
	
	-- No overlay exists for this slot, create a new one
	local overlayName = "tmOverlay_" .. slotIndex .. "_" .. region
	local overlay = slotBtn:CreateChildWidget("button", overlayName, 0, true)
	overlay:SetExtent(slotBtn:GetWidth(), constants.overlay.height)
	overlay:AddAnchor("BOTTOM", slotBtn, 0, constants.overlay.heightOffset)
	overlay.style:SetFontSize(constants.overlay.fontSize)
	overlay.style:SetAlign(ALIGN.CENTER)
	overlay.style:SetShadow(true)
	overlay:SetText(region)
	
	-- Create background with region-specific color
	local color = regions.getRegionColor(region)
	overlay.bg = overlay:CreateColorDrawable(color[1], color[2], color[3], color[4], "background")
	overlay.bg:AddAnchor("TOPLEFT", overlay, 0, 0)
	overlay.bg:AddAnchor("BOTTOMRIGHT", overlay, 0, 0)
	
	-- Store in appropriate pool
	if not slotOverlaysByRegion[region] then
		slotOverlaysByRegion[region] = {}
	end
	slotOverlaysByRegion[region][slotIndex] = overlay
	table.insert(slotOverlaysAll, overlay)
	
	return overlay
end

-- Hide overlays that are no longer needed
local function hideNotInUseLabels(activeSlotsMap)
	for regionName, overlays in pairs(slotOverlaysByRegion) do
		for slotIndex, overlay in pairs(overlays) do
			if not (activeSlotsMap[regionName] and activeSlotsMap[regionName][slotIndex]) and overlay then
				overlay:Show(false)
			end
		end
	end
end

-- Apply overlays to all treasure maps in bags
local function applyLabelToMaps()
	overlaysActive = true

	-- Track which slot+region combinations have treasure maps
	local activeSlotsMap = {}

	helpers.iterateTreasureMaps(function(slotIndex, btn, info)
		local region = coordinates.getRegionFromSextant(
			info.longitudeDir, info.latitudeDir,
			info.longitudeDeg, info.longitudeMin, info.longitudeSec,
			info.latitudeDeg, info.latitudeMin, info.latitudeSec
		)
		local regionname = "?"
		if region ~= nil then
			regionname = region.name
		end
		if not activeSlotsMap[regionname] then
			activeSlotsMap[regionname] = {}
		end
		activeSlotsMap[regionname][slotIndex] = true
		getOrCreateLabelFromPool(slotIndex, btn, regionname)
	end)

	-- Hide overlays for slots that no longer have treasure maps
	hideNotInUseLabels(activeSlotsMap)
end

-- Public API

--- Initialize the bag overlay system
-- Currently no special initialization is required
function BagOverlay.initialize()
	-- Nothing special needed for initialization
end

--- Update all active overlays to reflect current bag contents
-- Call this when bag contents may have changed
function BagOverlay.update()
	if overlaysActive then
		applyLabelToMaps()
	end
end

--- Show region labels on all treasure maps in the bag
function BagOverlay.show()
	applyLabelToMaps()
end

--- Hide all bag slot overlays
function BagOverlay.hide()
	overlaysActive = false
	for _, overlay in pairs(slotOverlaysAll) do
		if overlay then
			overlay:Show(false)
		end
	end
end

--- Toggle overlays on or off
function BagOverlay.toggle()
	if overlaysActive then
		BagOverlay.hide()
	else
		BagOverlay.show()
	end
end

--- Check if overlays are currently active
-- @return boolean true if overlays are visible
function BagOverlay.isActive()
	return overlaysActive
end

--- Clean up all overlay widgets and reset state
function BagOverlay.cleanup()
	BagOverlay.hide()
	-- Widgets will be cleaned up by parent window destruction
end

-- Flash mode support (for highlighting selected items)

--- Enable or disable flash mode for highlighting selected maps
-- @param enabled boolean true to enable flash mode
function BagOverlay.setFlashMode(enabled)
	flashMode = enabled
end

--- Check if flash mode is currently enabled
-- @return boolean true if flash mode is active
function BagOverlay.isFlashMode()
	return flashMode
end

--- Check if user has used flash mode during this session
-- @return boolean true if flash mode has been used
function BagOverlay.hasUsedFlashMode()
	return usedFlashMode
end

--- Mark that flash mode has been used this session
function BagOverlay.markFlashModeUsed()
	usedFlashMode = true
end

--- Reset the flash mode used flag (call after finishing flash mode cleanup)
function BagOverlay.resetFlashModeUsed()
	usedFlashMode = false
end

return BagOverlay
