-- WorldSatNav Coordinate System
-- Handles all coordinate conversions and transformations

local constants = require("WorldSatNav/core/constants")
local log = require("WorldSatNav/helpers/log")

local Coordinates = {}

--- Convert a sextant using engine-native field names (longitudeDir, longitudeDeg, ...)
-- or camelCase names to the short longitude/deg_long/... form used throughout the addon.
-- target: optional table to write into instead of allocating a new one (used by
-- maprendering's GetCurrentPosition scratch buffer to avoid a table allocation every poll).
function Coordinates.NormalizeSextant(sextant, target)
	if sextant == nil then
		return nil
	end
	local normalized = target or {}
	normalized.longitude = sextant.longitudeDir or sextant.longitude
	normalized.latitude = sextant.latitudeDir or sextant.latitude
	normalized.deg_long = sextant.longitudeDeg or sextant.deg_long or sextant.degLong
	normalized.min_long = sextant.longitudeMin or sextant.min_long or sextant.minLong
	normalized.sec_long = sextant.longitudeSec or sextant.sec_long or sextant.secLong
	normalized.deg_lat = sextant.latitudeDeg or sextant.deg_lat or sextant.degLat
	normalized.min_lat = sextant.latitudeMin or sextant.min_lat or sextant.minLat
	normalized.sec_lat = sextant.latitudeSec or sextant.sec_lat or sextant.secLat
	if normalized.min_long == nil then normalized.min_long = 0 end
	if normalized.sec_long == nil then normalized.sec_long = 0 end
	if normalized.min_lat == nil then normalized.min_lat = 0 end
	if normalized.sec_lat == nil then normalized.sec_lat = 0 end
	return normalized
end

--- Convert a sextant to pixel coordinates on a map texture.
-- @param renderSettings table one of maprendering's mapLevels entries
-- @return number, number x, y (or nil, nil when the sextant is invalid)
function Coordinates.SextantToMapCoordinates(sextant, renderSettings)
	sextant = Coordinates.NormalizeSextant(sextant)
	if not sextant or not renderSettings then
		log.DevLog("Cannot convert sextant to map coordinates, sextant or renderSettings is nil")
		return nil, nil
	end

	local long = sextant.longitude
	local lat = sextant.latitude

	local longValue = 0
	local latValue = 0
	if long == nil or lat == nil then
		log.DevLog("Invalid sextant data, missing longitude or latitude direction")
		return nil, nil
	end

	local degLong = sextant.deg_long
	local minLong = sextant.min_long
	local secLong = sextant.sec_long
	local degLat = sextant.deg_lat
	local minLat = sextant.min_lat
	local secLat = sextant.sec_lat
	if degLong == nil or minLong == nil or secLong == nil or degLat == nil or minLat == nil or secLat == nil then
		log.DevLog("Invalid sextant data, cannot convert to map coordinates")
		return nil, nil
	end
	longValue = degLong + (minLong / 60) + (secLong / 3600)
	latValue = degLat + (minLat / 60) + (secLat / 3600)

	if sextant.longitude == "W" then
		longValue = -longValue
	end
	if sextant.latitude == "N" then
		latValue = -latValue
	end

	local x = renderSettings.zeroPointX + (longValue * renderSettings.XCordScale)
	local y = renderSettings.zeroPointY + (latValue * renderSettings.YCordScale)
	return x, y
end

--- Convert latitude sextant coordinates to game world degrees
-- @param direction string "N" or "S"
-- @param degrees number degree component
-- @param minutes number minute component (0-59)
-- @param seconds number second component (0-59)
-- @return number game world Y coordinate in degrees
function Coordinates.latitudeSextantToDegrees(direction, degrees, minutes, seconds)
	if constants.coordCoef == nil then
		return 0
	end
    return (Coordinates.toDecimalDegrees(direction, degrees, minutes, seconds) + 28) / constants.coordCoef
end

--- Convert longitude sextant coordinates to game world degrees
-- @param direction string "E" or "W"
-- @param degrees number degree component
-- @param minutes number minute component (0-59)
-- @param seconds number second component (0-59)
-- @return number game world X coordinate in degrees
function Coordinates.longitudeSextantToDegrees(direction, degrees, minutes, seconds)
	if constants.coordCoef == nil then
		return 0
	end
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
