local coordinates = require("WorldSatNav/core/coordinates")

local geo = {}

function geo.distSqToPlayer(info, curCoords)
    if info == nil or curCoords == nil then
        return math.huge
    end
    local lonDir1 = info.longitudeDir or info.longitude
    local latDir1 = info.latitudeDir or info.latitude
    local degLong1 = info.longitudeDeg or info.deg_long or info.degLong
    local minLong1 = info.longitudeMin or info.min_long or info.minLong
    local secLong1 = info.longitudeSec or info.sec_long or info.secLong
    local degLat1 = info.latitudeDeg or info.deg_lat or info.degLat
    local minLat1 = info.latitudeMin or info.min_lat or info.minLat
    local secLat1 = info.latitudeSec or info.sec_lat or info.secLat

    local lonDir2 = curCoords.longitudeDir or curCoords.longitude
    local latDir2 = curCoords.latitudeDir or curCoords.latitude
    local degLong2 = curCoords.longitudeDeg or curCoords.deg_long or curCoords.degLong
    local minLong2 = curCoords.longitudeMin or curCoords.min_long or curCoords.minLong
    local secLong2 = curCoords.longitudeSec or curCoords.sec_long or curCoords.secLong
    local degLat2 = curCoords.latitudeDeg or curCoords.deg_lat or curCoords.degLat
    local minLat2 = curCoords.latitudeMin or curCoords.min_lat or curCoords.minLat
    local secLat2 = curCoords.latitudeSec or curCoords.sec_lat or curCoords.secLat

    if lonDir1 == nil or latDir1 == nil or lonDir2 == nil or latDir2 == nil then
        return math.huge
    end
    if degLong1 == nil or minLong1 == nil or secLong1 == nil or degLat1 == nil or minLat1 == nil or secLat1 == nil then
        return math.huge
    end
    if degLong2 == nil or minLong2 == nil or secLong2 == nil or degLat2 == nil or minLat2 == nil or secLat2 == nil then
        return math.huge
    end

    local lon1 = coordinates.toDecimalDegrees(lonDir1, degLong1 or 0, minLong1 or 0, secLong1 or 0)
    local lat1 = coordinates.toDecimalDegrees(latDir1, degLat1  or 0, minLat1  or 0, secLat1  or 0)
    local lon2 = coordinates.toDecimalDegrees(lonDir2, degLong2 or 0, minLong2 or 0, secLong2 or 0)
    local lat2 = coordinates.toDecimalDegrees(latDir2,  degLat2  or 0, minLat2  or 0, secLat2  or 0)
    return (lon1 - lon2)^2 + (lat1 - lat2)^2
end

function geo.SextantKey(sextant)
	if sextant == nil then
		return "??000000"
	end
	local long = sextant.longitude or "?"
	local lat = sextant.latitude or "?"
	local degLong = sextant.deg_long or "0"
	local minLong = sextant.min_long or "0"
	local secLong = sextant.sec_long or "0"
	local degLat = sextant.deg_lat or "0"
	local minLat = sextant.min_lat or "0"
	local secLat = sextant.sec_lat or "0"
	local returnValue = string.format(
		"%s%s%s%s%s%s%s%s",
		tostring(long),
		tostring(degLong),
		tostring(minLong),
		tostring(secLong),
        tostring(lat),
		tostring(degLat),
		tostring(minLat),
		tostring(secLat)
	)
	return returnValue
end

--- Human readable sextant, e.g. 12°34'56"N 78°09'12"W
function geo.FormatSextant(sextant)
	if sextant == nil then
		return "??"
	end
	return string.format(
		"%d\194\176%02d'%02d\"%s %d\194\176%02d'%02d\"%s",
		sextant.deg_lat or 0, sextant.min_lat or 0, sextant.sec_lat or 0, sextant.latitude or "?",
		sextant.deg_long or 0, sextant.min_long or 0, sextant.sec_long or 0, sextant.longitude or "?"
	)
end

return geo
