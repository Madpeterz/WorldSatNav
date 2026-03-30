-- WorldSatNav Coordinate System
-- Handles all coordinate conversions and transformations

local constants = require("WorldSatNav/constants")
local regions = require("WorldSatNav/regions")

local Coordinates = {}

Coordinates.renderingSettings = {
	scaleHX = 0,
	scaleHY = 0,
	centerPointX = 0,
	centerPointY = 0,
}
local renderingSettingsLoaded = false

function Coordinates.ResetRenderingSettings()
	Coordinates.renderingSettings.scaleHX = constants.map.xpointScale + constants.map.tweakScaleX
	Coordinates.renderingSettings.scaleHY = constants.map.ypointScale + constants.map.tweakScaleY
	Coordinates.renderingSettings.centerPointX = constants.map.centerPointX
	Coordinates.renderingSettings.centerPointY = constants.map.centerPointY
	renderingSettingsLoaded = true
end

function Coordinates.UpdateRenderingSettings(centerX, centerY, scaleX, scaleY)
	Coordinates.renderingSettings.scaleHX = scaleX
	Coordinates.renderingSettings.scaleHY = scaleY
	Coordinates.renderingSettings.centerPointX = centerX
	Coordinates.renderingSettings.centerPointY = centerY
end

-- Convert sextant coordinates (deg/min/sec) to pixel coordinates on the map
function Coordinates.getMapDrawPoint(lonDirection, latDirection, lonDegrees, lonMinutes, lonSeconds, latDegrees, latMinutes, latSeconds)
	if renderingSettingsLoaded == false then
		Coordinates.ResetRenderingSettings()
		
	end
	
	local dirX = lonDirection == "W" and -1 or 1
	local dirY = latDirection == "S" and  1 or -1

	local scaleHX = Coordinates.renderingSettings.scaleHX + constants.map.tweakScaleX
	local scaleMX = scaleHX / 100.0
	local scaleSX = scaleMX / 100.0
	local scaleHY = Coordinates.renderingSettings.scaleHY + constants.map.tweakScaleY
	local scaleMY = scaleHY / 100.0
	local scaleSY = scaleMY / 100.0

	local weSecond = lonDegrees * scaleHX + lonMinutes * scaleMX + lonSeconds * scaleSX
	local wePxl = weSecond * dirX
	local nsSecond = latDegrees * scaleHY + latMinutes * scaleMY + latSeconds * scaleSY
	local nsPxl = nsSecond * dirY

	local xPosReal = math.floor(Coordinates.renderingSettings.centerPointX + wePxl + 0.5)
	local yPosReal = math.floor(Coordinates.renderingSettings.centerPointY + nsPxl + 0.5)

	return xPosReal, yPosReal
end

-- Convert sextant coordinates to degrees with scaling for game coordinate system
local coordCoef = 0.00097657363894522145695357130138029

--- Convert latitude sextant coordinates to game world degrees
-- @param direction string "N" or "S"
-- @param degrees number degree component
-- @param minutes number minute component (0-59)
-- @param seconds number second component (0-59)
-- @return number game world Y coordinate in degrees
function Coordinates.latitudeSextantToDegrees(direction, degrees, minutes, seconds)
    return (Coordinates.toDecimalDegrees(direction, degrees, minutes, seconds) + 28) / coordCoef
end

--- Convert longitude sextant coordinates to game world degrees
-- @param direction string "E" or "W"
-- @param degrees number degree component
-- @param minutes number minute component (0-59)
-- @param seconds number second component (0-59)
-- @return number game world X coordinate in degrees
function Coordinates.longitudeSextantToDegrees(direction, degrees, minutes, seconds)
    return (Coordinates.toDecimalDegrees(direction, degrees, minutes, seconds) + 21) / coordCoef
end

-- Get region name from sextant coordinates
function Coordinates.getRegionFromSextant(lonDirection, latDirection, lonDegrees, lonMinutes, lonSeconds, latDegrees, latMinutes, latSeconds)
	local x, y = Coordinates.getMapDrawPoint(lonDirection, latDirection, lonDegrees, lonMinutes, lonSeconds, latDegrees, latMinutes, latSeconds)
	return regions.getRegionFromPixels(x, y)
end

-- Expose the coordinate coefficient so other modules can convert decimal-degree
-- differences directly to game-world meters (distance = degDiff / coordCoef)
Coordinates.coordCoef = coordCoef

-- Convert sextant coordinates to decimal degrees (for distance/bearing calculations)
function Coordinates.toDecimalDegrees(direction, degrees, minutes, seconds)
    local decimal = degrees + (minutes / 60) + (seconds / 3600)
    if direction == "W" or direction == "S" then
        decimal = -decimal
    end
    return decimal
end

function Coordinates.CalculateDistance(SextantA, SextantB)
	if SextantA == nil or SextantB == nil then
		-- "Cannot calculate distance: one or both sextants are nil
		return math.huge
	end
	-- Convert both sextants to decimal degrees
	local lonA = Coordinates.toDecimalDegrees(SextantA.longitudeDir, SextantA.longitudeDeg, SextantA.longitudeMin, SextantA.longitudeSec)
	local latA = Coordinates.toDecimalDegrees(SextantA.latitudeDir, SextantA.latitudeDeg, SextantA.latitudeMin, SextantA.latitudeSec)
	local lonB = Coordinates.toDecimalDegrees(SextantB.longitudeDir, SextantB.longitudeDeg, SextantB.longitudeMin, SextantB.longitudeSec)
	local latB = Coordinates.toDecimalDegrees(SextantB.latitudeDir, SextantB.latitudeDeg, SextantB.latitudeMin, SextantB.latitudeSec)
	-- Calculate the difference in degrees
	local deltaLon = lonB - lonA
	local deltaLat = latB - latA
	-- Convert degree difference to meters using coordCoef
	local distance = math.sqrt(deltaLon * deltaLon + deltaLat * deltaLat) / Coordinates.coordCoef
	return distance
end

return Coordinates
