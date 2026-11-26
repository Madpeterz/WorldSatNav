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

-- Linear map constants for zoom-3.png (the full-size texture). Calibration
-- anchors and the region shapes are both stored in this texture's pixel space.
Coordinates.BASE_RENDER = { zeroPointX = 2513, zeroPointY = 991, XCordScale = 116.44, YCordScale = 115.17, width = 3819, height = 4047 }

-- ---------------------------------------------------------------------------
-- Calibration anchors
-- ---------------------------------------------------------------------------
-- The linear formula (zeroPoint + degrees * scale) drifts in places. An anchor
-- pairs a known in-game sextant with the zoom-3.png pixel it really sits at; the
-- difference from the formula is that anchor's residual. Conversions add a
-- blend of nearby residuals (inverse-distance weighted, fading to zero at
-- ANCHOR_RADIUS), so the result is exact at each anchor, smooth between them,
-- and unchanged anywhere no anchor is in range.

-- Degrees; how far an anchor's correction reaches (~400px on zoom-3.png).
Coordinates.ANCHOR_RADIUS = 3.5
local ANCHOR_EXACT_DISTANCE = 1e-6 -- closer than this counts as standing on the anchor
local INVERSE_ITERATIONS = 6

local anchorCells = {} -- grid cell key -> array of { long, lat, dx, dy }
local anchorCount = 0

local function CellIndex(value)
	return math.floor(value / Coordinates.ANCHOR_RADIUS)
end

local function CellKey(ix, iy)
	return (ix + 1000) * 10000 + (iy + 1000)
end

--- Signed degrees for a sextant: east and south positive.
-- @return number, number longValue, latValue (or nil, nil when the sextant is invalid)
function Coordinates.SextantToValues(sextant)
	sextant = Coordinates.NormalizeSextant(sextant)
	if not sextant then
		return nil, nil
	end
	if sextant.longitude == nil or sextant.latitude == nil then
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
	local longValue = degLong + (minLong / 60) + (secLong / 3600)
	local latValue = degLat + (minLat / 60) + (secLat / 3600)
	if sextant.longitude == "W" then
		longValue = -longValue
	end
	if sextant.latitude == "N" then
		latValue = -latValue
	end
	return longValue, latValue
end

--- Replace the calibration anchors.
-- @param anchors array of { px = number, py = number, sextant = table } where
--   px/py are pixels on zoom-3.png; entries with a bad sextant or pixel are skipped.
-- @return number how many anchors were accepted
function Coordinates.SetAnchors(anchors)
	anchorCells = {}
	anchorCount = 0
	if type(anchors) ~= "table" then
		return 0
	end
	local base = Coordinates.BASE_RENDER
	for _, anchor in ipairs(anchors) do
		local px = tonumber(anchor.px)
		local py = tonumber(anchor.py)
		local longValue, latValue = Coordinates.SextantToValues(anchor.sextant)
		if px ~= nil and py ~= nil and longValue ~= nil then
			local entry = {
				long = longValue,
				lat = latValue,
				dx = px - (base.zeroPointX + (longValue * base.XCordScale)),
				dy = py - (base.zeroPointY + (latValue * base.YCordScale)),
			}
			local key = CellKey(CellIndex(longValue), CellIndex(latValue))
			local cell = anchorCells[key]
			if cell == nil then
				cell = {}
				anchorCells[key] = cell
			end
			cell[#cell + 1] = entry
			anchorCount = anchorCount + 1
		end
	end
	return anchorCount
end

function Coordinates.GetAnchorCount()
	return anchorCount
end

--- Pixel correction (in zoom-3.png pixels) for a position given in signed degrees.
-- @return number, number dx, dy (0, 0 when no anchor is in range)
function Coordinates.AnchorCorrection(longValue, latValue)
	if anchorCount == 0 then
		return 0, 0
	end
	local radius = Coordinates.ANCHOR_RADIUS
	local ix = CellIndex(longValue)
	local iy = CellIndex(latValue)
	local sumW, sumX, sumY = 0, 0, 0
	local exactCount, exactX, exactY = 0, 0, 0
	for cx = ix - 1, ix + 1 do
		for cy = iy - 1, iy + 1 do
			local cell = anchorCells[CellKey(cx, cy)]
			if cell ~= nil then
				for i = 1, #cell do
					local anchor = cell[i]
					local dLong = longValue - anchor.long
					local dLat = latValue - anchor.lat
					local distance = math.sqrt((dLong * dLong) + (dLat * dLat))
					if distance < ANCHOR_EXACT_DISTANCE then
						exactCount = exactCount + 1
						exactX = exactX + anchor.dx
						exactY = exactY + anchor.dy
					elseif distance < radius then
						-- Modified Shepard weight: 1/d^2 near the anchor, 0 at the radius.
						local w = (radius - distance) / (radius * distance)
						w = w * w
						sumW = sumW + w
						sumX = sumX + (w * anchor.dx)
						sumY = sumY + (w * anchor.dy)
					end
				end
			end
		end
	end
	if exactCount > 0 then
		return exactX / exactCount, exactY / exactCount
	end
	if sumW == 0 then
		return 0, 0
	end
	-- A "no correction" weight equal to a lone anchor's at half the radius, so
	-- a single anchor fades out smoothly instead of stepping to 0 at the edge.
	local zeroWeight = 1 / (radius * radius)
	local total = sumW + zeroWeight
	return sumX / total, sumY / total
end

--- Signed degrees to pixel coordinates on a map texture, anchor corrected.
function Coordinates.ValuesToMapCoordinates(longValue, latValue, renderSettings)
	local x = renderSettings.zeroPointX + (longValue * renderSettings.XCordScale)
	local y = renderSettings.zeroPointY + (latValue * renderSettings.YCordScale)
	if anchorCount > 0 then
		local base = Coordinates.BASE_RENDER
		local dx, dy = Coordinates.AnchorCorrection(longValue, latValue)
		x = x + (dx * renderSettings.XCordScale / base.XCordScale)
		y = y + (dy * renderSettings.YCordScale / base.YCordScale)
	end
	return x, y
end

--- Pixel coordinates on a map texture to signed degrees, undoing the anchor
-- correction (fixed-point iteration; residuals change slowly, so it settles fast).
function Coordinates.MapCoordinatesToValues(x, y, renderSettings)
	local linearLong = (x - renderSettings.zeroPointX) / renderSettings.XCordScale
	local linearLat = (y - renderSettings.zeroPointY) / renderSettings.YCordScale
	if anchorCount == 0 then
		return linearLong, linearLat
	end
	local base = Coordinates.BASE_RENDER
	local longValue, latValue = linearLong, linearLat
	for _ = 1, INVERSE_ITERATIONS do
		local dx, dy = Coordinates.AnchorCorrection(longValue, latValue)
		longValue = linearLong - (dx / base.XCordScale)
		latValue = linearLat - (dy / base.YCordScale)
	end
	return longValue, latValue
end

--- Pixel on any zoom level's texture to the matching zoom-3.png pixel, through
-- the two levels' linear constants (no anchor correction). An anchor captured
-- this way lands back on the clicked pixel at the zoom it was clicked on.
function Coordinates.ToBasePixels(x, y, renderSettings)
	local base = Coordinates.BASE_RENDER
	local linearLong = (x - renderSettings.zeroPointX) / renderSettings.XCordScale
	local linearLat = (y - renderSettings.zeroPointY) / renderSettings.YCordScale
	return base.zeroPointX + (linearLong * base.XCordScale), base.zeroPointY + (linearLat * base.YCordScale)
end

--- Convert a sextant to pixel coordinates on a map texture.
-- @param renderSettings table one of maprendering's mapLevels entries
-- @return number, number x, y (or nil, nil when the sextant is invalid)
function Coordinates.SextantToMapCoordinates(sextant, renderSettings)
	if not sextant or not renderSettings then
		log.DevLog("Cannot convert sextant to map coordinates, sextant or renderSettings is nil")
		return nil, nil
	end
	local longValue, latValue = Coordinates.SextantToValues(sextant)
	if longValue == nil then
		return nil, nil
	end
	return Coordinates.ValuesToMapCoordinates(longValue, latValue, renderSettings)
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
