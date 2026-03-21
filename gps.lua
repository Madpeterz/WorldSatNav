-- WorldSatNav GPS Navigation
-- Handles GPS tracking, distance/bearing calculations, and navigation guidance

local api = require("api")
local coordinates = require("WorldSatNav/coordinates")

local GPS = {}

-- State (must be declared before functions that use them)
local gpsNavTo = nil
local gpsNavToName = ""
local gpsNavSextant = nil
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

-- Convert atan2(eastComp, northComp) result to a normalised 0-360 degree bearing
local function bearingDeg(eastComp, northComp)
	return normalizeAngle(math.atan2(eastComp, northComp) * (180 / math.pi))
end

-- Convert bearing degrees to a 1-12 compass index (1=N, 2=NNE, ... 12=NNW)
local function bearingToIndex(bearing)
	return math.floor((bearing + 15) / 30) % 12 + 1
end

-- Extract decimal lon/lat from a sextant position struct
local function sextantToLonLat(pos)
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
	local relDirNames   = {"n",  "nne", "ene", "e",  "ese", "sse", "s",   "ssw",  "wsw",  "w",   "wnw",  "nnw"}
	local relDirCenters = {  0,   30,    60,    90,   120,   150,   180,   -150,   -120,   -90,   -60,    -30}

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
local function getGPSGuideText(playerCord, targetCord)
	-- playerCord and targetCord have: longitude, deg_long, min_long, sec_long, latitude, deg_lat, min_lat, sec_lat
	
	local playerLon, playerLat = sextantToLonLat(playerCord)
	local targetLon, targetLat = sextantToLonLat(targetCord)
	
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
	local directions = {"n", "nne", "ene", "e", "ese", "sse", "s", "ssw", "wsw", "w", "wnw", "nnw"}
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
	local distance = math.sqrt(lonDiff * lonDiff + latDiff * latDiff) / coordinates.coordCoef * (3.2 / 3.6)
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

-- Public API

--- Set GPS target location from treasure map item data
-- @param itemData table treasure map item info with coordinate fields
-- @param name string optional display name for the target
function GPS.setTarget(itemData, name)
	gpsNavTo = itemData
	gpsNavToName = name or ""
	
	-- Initialize player position for movement tracking
	prevPlayerPos = api.Map:GetPlayerSextants()
	
	if itemData then
		gpsNavSextant = {
			longitude = itemData.longitudeDir,
			deg_long = itemData.longitudeDeg or 0,
			min_long = itemData.longitudeMin or 0,
			sec_long = itemData.longitudeSec or 0,
			latitude = itemData.latitudeDir,
			deg_lat = itemData.latitudeDeg or 0,
			min_lat = itemData.latitudeMin or 0,
			sec_lat = itemData.latitudeSec or 0,
		}
	else
		gpsNavSextant = nil
	end
end

--- Clear the current GPS target and stop navigation
function GPS.clearTarget()
	gpsNavTo = nil
	gpsNavToName = ""
	gpsNavSextant = nil
	prevPlayerPos = nil
	playerMovementDirection = nil
	lastRelativeDirection = nil
	pendingDirection = nil
	pendingDirectionCount = 0
	recentBearings = {}
end

--- Check if a GPS target is currently set
-- @return boolean true if a target is set
function GPS.hasTarget()
	return gpsNavTo ~= nil
end

--- Get the display name of the current GPS target
-- @return string target name or empty string if no target
function GPS.getTargetName()
	return gpsNavToName
end

--- Get the raw item data for the current GPS target
-- @return table item data or nil if no target
function GPS.getTarget()
	return gpsNavTo
end

--- Get the sextant coordinates of the current GPS target
-- @return table sextant coordinate structure or nil if no target
function GPS.getTargetSextant()
	return gpsNavSextant
end

--- Update player movement direction (should be called regularly)
function GPS.updateMovementTracking()
	if gpsNavSextant == nil then
		return
	end
	
	local curCoords = api.Map:GetPlayerSextants()
	updateMovementDirection(curCoords)
end

--- Get formatted navigation text showing direction and distance to target
-- @return string compassDir  compass direction ("n","ne","e","se","s","sw","w","nw","here")
-- @return number distance     distance to target in distanceScale units
-- @return string distanceScale unit label ("m", "km", or "Mm")
-- @return number bearing      absolute bearing in degrees (0-360) to the target
-- @return string relativeDir  direction relative to player movement (same octant names, or "noidea")
function GPS.getNavigationText()
	if gpsNavSextant == nil then
		return ""
	end
	
	local curCoords = api.Map:GetPlayerSextants()
	
	return getGPSGuideText(curCoords, gpsNavSextant)
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
	local directions = {"N", "NNE", "ENE", "E", "ESE", "SSE", "S", "SSW", "WSW", "W", "WNW", "NNW"}
	return directions[bearingToIndex(playerMovementDirection)]
end

--- Get relative direction to target based on movement direction
-- @return string relative direction ("ahead", "left", "behind-right", etc.) or nil
function GPS.GetRelativeDirectionToTarget()
	if gpsNavSextant == nil or playerMovementDirection == nil then
		return nil
	end
	
	local curCoords = api.Map:GetPlayerSextants()
	local _, _, _, bearing, relativeDir = getGPSGuideText(curCoords, gpsNavSextant)
	
	return relativeDir
end

--- Get the current player position as sextant coordinates
-- @return table sextant coordinate structure with longitude, latitude, deg_long, min_long, sec_long, deg_lat, min_lat, sec_lat
function GPS.GetCurrentPosition()
	return api.Map:GetPlayerSextants()
end

return GPS
