-- WorldSatNav Region Management
-- Handles region boundary detection and region-specific metadata

local constants = require("WorldSatNav/constants")
local api = require("api")
local shapes = require("WorldSatNav/shapes")

local Regions = {}

-- Region boundary definitions (pixel coordinates on the map)

-- Region IDs based on shape map (from shapes.lua):
-- 0	out of bounds
-- 1	Auroria (black)
-- 2	Castaway (green)
-- 3	Nuia (blue)
-- 4	Arcadian (gray)
-- 5	Halcy Glf (yellow)
-- 6	Haranya (red)


local regionBoundaries = {
	-- currently shared map image with Haranya, so center point is the same, but boundaries are different
	{name = "Castaway", rid=2, centerPointX = 360, centerPointY = -270},
	{name = "Castaway", rid=2, centerPointX = 360, centerPointY = -270},
	{name = "Castaway", rid=2, centerPointX = 360, centerPointY = -270},
	-- currently shared map image with Nuia, so center point is the same, but boundaries are different
	{name = "Halcy Glf", rid=6, centerPointX = 501, centerPointY = 559.6}, 
	{name = "Halcy Glf", rid=6, centerPointX = 501, centerPointY = 550.35},
	{name = "Halcy Glf", rid=6, centerPointX = 501, centerPointY = 506.6},


	{name = "Nuia", rid=3, centerPointX = 658, centerPointY = -180},
	{name = "Nuia", rid=3, centerPointX = 658, centerPointY = -180},
	{name = "Haranya", rid=7, centerPointX = 360, centerPointY = -270},
	{name = "Haranya", rid=7, centerPointX = 360, centerPointY = -270},
	{name = "Auroria", rid=1, centerPointX = 410, centerPointY = 51},
	{name = "Arcadian", rid=4, centerPointX = 4140, centerPointY = -41},
	{name = "Arcadian", rid=4, centerPointX = 410, centerPointY = -41},
}

-- Get region name from pixel coordinates
-- If multiple regions overlap, returns the one whose center is closest
function Regions.getRegionFromPixels(x, y)
	local rid = shapes.get_shape(x, y)
	local matchedRegion = nil
	for _, region in pairs(regionBoundaries) do
		if region.rid == rid then
			matchedRegion = region
			break
		end
	end
	return matchedRegion
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
