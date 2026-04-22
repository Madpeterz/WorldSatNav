-- WorldSatNav Coordinate System
-- Handles all coordinate conversions and transformations

local constants = require("WorldSatNav/constants")

local Coordinates = {}

--- Convert latitude sextant coordinates to game world degrees
-- @param direction string "N" or "S"
-- @param degrees number degree component
-- @param minutes number minute component (0-59)
-- @param seconds number second component (0-59)
-- @return number game world Y coordinate in degrees
function Coordinates.latitudeSextantToDegrees(direction, degrees, minutes, seconds)
    return (Coordinates.toDecimalDegrees(direction, degrees, minutes, seconds) + 28) / constants.coordCoef
end

--- Convert longitude sextant coordinates to game world degrees
-- @param direction string "E" or "W"
-- @param degrees number degree component
-- @param minutes number minute component (0-59)
-- @param seconds number second component (0-59)
-- @return number game world X coordinate in degrees
function Coordinates.longitudeSextantToDegrees(direction, degrees, minutes, seconds)
    return (Coordinates.toDecimalDegrees(direction, degrees, minutes, seconds) + 21) / constants.coordCoef
end

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
	local function unpackSextant(sextant)
		local longitude = sextant.longitude
		local latitude = sextant.latitude
		local degLong = sextant.deg_long or 0
		local minLong = sextant.min_long or 0
		local secLong = sextant.sec_long or 0
		local degLat = sextant.deg_lat or 0
		local minLat = sextant.min_lat or 0
		local secLat = sextant.sec_lat or 0
		return longitude, latitude, degLong, minLong, secLong, degLat, minLat, secLat
	end
	local lonDirA, latDirA, degLongA, minLongA, secLongA, degLatA, minLatA, secLatA = unpackSextant(SextantA)
	local lonDirB, latDirB, degLongB, minLongB, secLongB, degLatB, minLatB, secLatB = unpackSextant(SextantB)
	if lonDirA == nil or latDirA == nil or lonDirB == nil or latDirB == nil then
		return math.huge
	end
	-- Convert both sextants to decimal degrees
	local lonA = Coordinates.toDecimalDegrees(lonDirA, degLongA, minLongA, secLongA)
	local latA = Coordinates.toDecimalDegrees(latDirA, degLatA, minLatA, secLatA)
	local lonB = Coordinates.toDecimalDegrees(lonDirB, degLongB, minLongB, secLongB)
	local latB = Coordinates.toDecimalDegrees(latDirB, degLatB, minLatB, secLatB)
	-- Calculate the difference in degrees
	local deltaLon = lonB - lonA
	local deltaLat = latB - latA
	-- Convert degree difference to meters using coordCoef
	local distance = math.sqrt(deltaLon * deltaLon + deltaLat * deltaLat) / constants.coordCoef
	return distance
end

return Coordinates
