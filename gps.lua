-- GPS Navigation
-- Handles GPS tracking, distance/bearing calculations, and navigation guidance

local api = require("api")
local coordinates = require("WorldSatNav/coordinates")
local constants = require("WorldSatNav/constants")

local GPS = {}

-- State (must be declared before functions that use them)
local prevPlayerPos = nil
local playerMovementDirection = nil -- Bearing in degrees (0-360)
local lastRelativeDirection = nil -- Track last direction for hysteresis
local pendingDirection = nil -- Candidate direction waiting for confirmation
local pendingDirectionCount = 0 -- How many consecutive times we've seen the candidate
local recentBearings = {} -- Store recent bearings for smoothing

-- Helper function to normalize angle to 0-360 range
local function normalizeAngle(angle)
	while angle < 0 do
		angle = angle + 360
	end
	while angle >= 360 do
		angle = angle - 360
	end
	return angle
end

-- Cross-runtime atan2 compatibility (some Lua runtimes do not provide math.atan2)
local function atan2(y, x)
	if math.atan2 then
		return math.atan2(y, x)
	end

	if x > 0 then
		return math.atan(y / x)
	elseif x < 0 and y >= 0 then
		return math.atan(y / x) + math.pi
	elseif x < 0 and y < 0 then
		return math.atan(y / x) - math.pi
	elseif x == 0 and y > 0 then
		return math.pi / 2
	elseif x == 0 and y < 0 then
		return -math.pi / 2
	else
		return 0
	end
end

-- Convert atan2(eastComp, northComp) result to a normalised 0-360 degree bearing
local function bearingDeg(eastComp, northComp)
	return normalizeAngle(atan2(eastComp, northComp) * (180 / math.pi))
end

-- Convert bearing degrees to a 1-16 compass index (1=N, 2=NNE, 3=NE, ... 16=NNW)
local function bearingToIndex(bearing)
	return math.floor((bearing + 11.25) / 22.5) % 16 + 1
end

-- Extract decimal lon/lat from a sextant position struct
local function sextantToLonLat(pos)
	if pos == nil then
		return nil, nil
	end
	if pos.longitude == nil or pos.latitude == nil then
		return nil, nil
	end
	if pos.deg_long == nil or pos.min_long == nil or pos.sec_long == nil then
		return nil, nil
	end
	if pos.deg_lat == nil or pos.min_lat == nil or pos.sec_lat == nil then
		return nil, nil
	end
	local lon = coordinates.toDecimalDegrees(pos.longitude, pos.deg_long, pos.min_long, pos.sec_long)
	local lat = coordinates.toDecimalDegrees(pos.latitude,  pos.deg_lat,  pos.min_lat,  pos.sec_lat)
	return lon, lat
end

-- Calculate relative direction based on target bearing and movement direction
local function getRelativeDirection(targetBearing, movementBearing)
	if movementBearing == nil then
		return "noidea"
	end
	
	-- Calculate angle difference (-180 to 180)
	-- Positive = target is to the right, negative = target is to the left
	local diff = targetBearing - movementBearing
	diff = normalizeAngle(diff + 180) - 180
	
	-- Each relative direction has a center angle.
	-- Pick the one whose center is closest to diff: that is the direction
	-- the player should turn toward to most efficiently close distance.
	local relDirNames   = {"n",  "nne",  "ne",  "ene", "e",  "ese",  "se",  "sse",  "s",   "ssw",   "sw",   "wsw",  "w",   "wnw",   "nw",   "nnw"}
	local relDirCenters = {  0,   22.5,   45,    67.5,  90,   112.5,  135,   157.5,  180,   -157.5,  -135,   -112.5, -90,   -67.5,   -45,    -22.5}

	local function angleDelta(a, b)
		local d = math.abs(a - b)
		if d > 180 then d = 360 - d end
		return d
	end

	-- Give the currently committed direction a hysteresis bonus to prevent flicker
	-- at zone boundaries. A larger value means more stickiness.
	local hysteresis = 20  -- degrees
	local bestDir = nil
	local bestScore = math.huge
	for i = 1, #relDirNames do
		local score = angleDelta(diff, relDirCenters[i])
		if relDirNames[i] == lastRelativeDirection then
			score = score - hysteresis
		end
		if score < bestScore then
			bestScore = score
			bestDir = relDirNames[i]
		end
	end
	local newDir = bestDir
	
	-- Debounce: require a new direction to appear consecutively before committing.
	-- During debounce, keep showing the last stable committed direction.
	if newDir ~= lastRelativeDirection then
		-- Use a higher count when the diff is small (close to target = noisy bearing).
		local requiredCount = 1
		if math.abs(diff) < 10 then
			requiredCount = 3  -- Very noisy zone near target
		elseif math.abs(diff) < 25 then
			requiredCount = 2
		end

		if newDir == pendingDirection then
			pendingDirectionCount = pendingDirectionCount + 1
			if pendingDirectionCount >= requiredCount then
				lastRelativeDirection = newDir
				pendingDirection = nil
				pendingDirectionCount = 0
			end
		else
			pendingDirection = newDir
			pendingDirectionCount = 1
		end
	else
		-- Confirmed current direction; reset any pending candidate
		pendingDirection = nil
		pendingDirectionCount = 0
	end
	
	-- Return the committed stable direction (lastRelativeDirection), falling
	-- back to newDir only on the very first call before anything is committed.
	return lastRelativeDirection or newDir
end

-- Update player movement direction from position changes
local function updateMovementDirection(newPos)
	if newPos == nil then
		return
	end
	if prevPlayerPos == nil then
		prevPlayerPos = newPos
		return
	end
	
	-- Calculate position differences
	local prevLon, prevLat = sextantToLonLat(prevPlayerPos)
	local newLon,  newLat  = sextantToLonLat(newPos)
	
	local lonDiff = newLon - prevLon
	local latDiff = newLat - prevLat
	
	-- Very small threshold - any detectable movement
	local movementThreshold = 0.00001
	local absLonDiff = math.abs(lonDiff)
	local absLatDiff = math.abs(latDiff)

	-- Detect teleportation: a jump this large cannot be normal movement.
	-- Reset state instead of injecting a nonsense bearing into the smoothing buffer.
	local teleportThreshold = 0.1  -- ~10 km in decimal degrees
	if absLonDiff > teleportThreshold or absLatDiff > teleportThreshold then
		prevPlayerPos = newPos
		recentBearings = {}
		playerMovementDirection = nil
		return
	end

	if absLonDiff > movementThreshold or absLatDiff > movementThreshold then
		-- Calculate bearing of movement
		local bearing = bearingDeg(lonDiff, latDiff)

		-- Add to recent bearings for smoothing
		table.insert(recentBearings, bearing)
		if #recentBearings > 5 then
			table.remove(recentBearings, 1) -- Keep only last 5 samples
		end
		
		-- Average the recent bearings for smoother direction
		-- Handle circular averaging (account for 0/360 wraparound)
		local sinSum, cosSum = 0, 0
		for _, b in ipairs(recentBearings) do
			local rad = b * (math.pi / 180)
			sinSum = sinSum + math.sin(rad)
			cosSum = cosSum + math.cos(rad)
		end
		playerMovementDirection = bearingDeg(sinSum, cosSum)

		prevPlayerPos = newPos
	end
	-- If no significant movement, keep previous direction
end

-- Calculate GPS guidance text showing direction and distance
local function getGPSGuideText(targetSextant)
	-- targetSextant has: longitude, deg_long, min_long, sec_long, latitude, deg_lat, min_lat, sec_lat
	-- 	longitude, latitude
	if targetSextant == nil then
		return "noidea", 0, "m", 0, nil
	end

	local playerSextant = api.Map:GetPlayerSextants()
	local playerLon, playerLat = sextantToLonLat(playerSextant)
	local targetLon, targetLat = sextantToLonLat(targetSextant)
	if playerLon == nil or playerLat == nil or targetLon == nil or targetLat == nil then
		return "noidea", 0, "m", 0, nil
	end
	
	-- Calculate differences
	local lonDiff = targetLon - playerLon
	local latDiff = targetLat - playerLat
	
	-- Apply deadzone (10 seconds = 10/3600 degrees ≈ 0.00278)
	local deadzone = 10 / 3600
	if math.abs(lonDiff) < deadzone and math.abs(latDiff) < deadzone then
		return "here", 0, "m", 0, nil
	end
	
	-- Calculate bearing (0-360 degrees, where 0 is North)
	-- atan2 is numerically stable at all distances
	local absLon = math.abs(lonDiff)
	local absLat = math.abs(latDiff)
	
	-- Threshold for ignoring directions (5 seconds = 5/3600 degrees)
	local directionThreshold = 5 / 3600
	local showLatDirection = absLat > directionThreshold
	local showLonDirection = absLon > directionThreshold
	
	-- atan2 is numerically stable at all distances, unlike the ratio formula
	local bearing = bearingDeg(lonDiff, latDiff)

	-- Convert bearing to compass direction
	local directions = {"n", "nne", "ne", "ene", "e", "ese", "se", "sse", "s", "ssw", "sw", "wsw", "w", "wnw", "nw", "nnw"}
	local compassDir = directions[bearingToIndex(bearing)]
	
	-- Filter out directions that don't exceed threshold, or show only dominant direction
	if not showLatDirection and not showLonDirection then
		compassDir = "noidea"
	elseif not showLatDirection then
		-- Only show E/W
		compassDir = lonDiff > 0 and "e" or "w"
	elseif not showLonDirection then
		-- Only show N/S
		compassDir = latDiff > 0 and "n" or "s"
	else
		-- Both directions exceed threshold; use the 16-direction compass bearing
	end
	
	-- Calculate distance in game-world meters using the game's own coordinate coefficient.
	-- coordCoef ≈ 1/1024 maps sextant decimal-degrees to game units (meters).
	-- An empirical correction factor of 3.2/3.6 ≈ 0.8889 brings readings in line with observed distances.
	local coordCoef = constants.coordCoef or (1 / 1024)
	local distance = math.sqrt(lonDiff * lonDiff + latDiff * latDiff) / coordCoef * (3.2 / 3.6)
	local distanceScale = "m"
	local scales = {"km", "Mm"}
	for _, scale in ipairs(scales) do
		if distance > 999 then
			distance = distance / 1000
			distanceScale = scale
		end
	end

	local relativeDir = getRelativeDirection(bearing, playerMovementDirection)
	return compassDir, distance, distanceScale, bearing, relativeDir
end

--- Update player movement direction (should be called regularly)
function GPS.updateMovementTracking()
	updateMovementDirection(api.Map:GetPlayerSextants())
end

--- Get formatted navigation text showing direction and distance to target
-- @return string compassDir  compass direction ("n","ne","e","se","s","sw","w","nw","here")
-- @return number distance     distance to target in distanceScale units
-- @return string distanceScale unit label ("m", "km", or "Mm")
-- @return number bearing      absolute bearing in degrees (0-360) to the target
-- @return string relativeDir  direction relative to player movement (same octant names, or "noidea")
function GPS.getNavigationText(targetSextant)
	local ok, compassDir, distance, distanceScale, bearing, relativeDir = pcall(getGPSGuideText, targetSextant)
	if not ok then
		return "noidea", 0, "m", 0, "noidea"
	end
	return compassDir, distance, distanceScale, bearing, relativeDir
end

--- Get the player's current movement direction in degrees (0-360, North = 0)
-- @return number bearing in degrees or nil if not enough movement data
function GPS.GetPlayerMovementDirection()
	return playerMovementDirection
end

--- Get the player's movement direction as a compass string
-- @return string compass direction ("N", "NE", "E", etc.) or nil
function GPS.GetPlayerMovementDirectionString()
	if playerMovementDirection == nil then
		return nil
	end
	local directions = {"N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"}
	return directions[bearingToIndex(playerMovementDirection)]
end

--- Get relative direction to target based on movement direction
-- @return string relative direction ("ahead", "left", "behind-right", etc.) or nil
function GPS.GetRelativeDirectionToTarget(targetSextant)
	if targetSextant == nil or playerMovementDirection == nil then
		return nil
	end
	
	local _, _, _, bearing, relativeDir = getGPSGuideText(targetSextant)
	
	return relativeDir
end

local lastUpdate = 0
function GPS.onUpdate(dt)
	lastUpdate = lastUpdate + dt
	if lastUpdate < (constants.timing.updateRate/4) then
		return
	end
    lastUpdate = 0
	GPS.updateMovementTracking()
end

return GPS
