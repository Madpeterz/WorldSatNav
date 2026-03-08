-- WorldSatNav Region Management
-- Handles region boundary detection and region-specific metadata

local constants = require("WorldSatNav/constants")

local Regions = {}

-- Region boundary definitions (pixel coordinates on the map)
local regionBoundaries = {
	-- currently shared map image with Haranya, so center point is the same, but boundaries are different
	{name = "Castaway", x = 368.7, y = 346.1, width = 74.2, height = 162.7, centerPointX = 360, centerPointY = -270},
	{name = "Castaway", x = 441.7, y = 346.3, width = 62.4, height = 30.9, centerPointX = 360, centerPointY = -270},
	{name = "Castaway", x = 331.5, y = 485.4, width = 38.6, height = 22.3, centerPointX = 360, centerPointY = -270},
	-- currently shared map image with Nuia, so center point is the same, but boundaries are different
	{name = "Halcy Glf", x = 215.9, y = 526.2, width = 37, height = 66.8, centerPointX = 501, centerPointY = 559.6}, 
	{name = "Halcy Glf", x = 249.8, y = 507.5, width = 81, height = 85.7, centerPointX = 501, centerPointY = 550.35},
	{name = "Halcy Glf", x = 297.3, y = 502.6, width = 34, height = 8.5, centerPointX = 501, centerPointY = 506.6},


	{name = "Nuia", x = 164.8, y = 308.7, width = 203, height = 178.1, centerPointX = 658, centerPointY = -180},
	{name = "Nuia", x = 95.1, y = 414, width = 236, height = 178.1, centerPointX = 658, centerPointY = -180},
	{name = "Haranya", x = 443.1, y = 376.4, width = 299.5, height = 273.9, centerPointX = 360, centerPointY = -270},
	{name = "Haranya", x = 333, y = 507.4, width = 111.5, height = 145.5, centerPointX = 360, centerPointY = -270},
	{name = "Auroria", x = 291.7, y = 30.2, width = 288, height = 159.1, centerPointX = 410, centerPointY = 51},
	{name = "Arcadian", x = 368.1, y = 307.2, width = 272.7, height = 38.9, centerPointX = 4140, centerPointY = -41},
	{name = "Arcadian", x = 305.2, y = 188.2, width = 335.4, height = 121.1, centerPointX = 410, centerPointY = -41},
}

-- Helper function to check if a point is within a box
local function inBox(x, y, boxX, boxY, boxWidth, boxHeight)
	return x >= boxX and x <= boxX + boxWidth and y >= boxY and y <= boxY + boxHeight
end

-- Get region name from pixel coordinates
-- If multiple regions overlap, returns the one whose center is closest
function Regions.getRegionFromPixels(x, y)
	local closestRegion = nil
	local closestDistance = math.huge
	for _, region in ipairs(regionBoundaries) do
		if inBox(x, y, region.x, region.y, region.width, region.height) then
			return region
		end
	end
	return nil
end

-- Get the color for a specific region
function Regions.getRegionColor(regionName)
	return constants.regionColors[regionName] or constants.regionColors["?"]
end

-- Get list of all unique region names
function Regions.getAllRegionNames()
	return {"Nuia", "Haranya", "Halcy Glf", "Castaway", "Arcadian", "Auroria"}
end

return Regions
