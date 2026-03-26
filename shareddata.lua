local api = require("api")
local settings = require("WorldSatNav/settings")

local shareddata = {}

local sharedDataLastUpdate = 0

function shareddata.onUpdate(dt)
	-- Throttled updates (run every 750ms)
	sharedDataLastUpdate = sharedDataLastUpdate + dt
	if sharedDataLastUpdate < settings.Get("LocationOutputRateLimit") then
		return
	end
	
	local writeFile = {
		time = api.Time:GetLocalTime(),
		location = api.Map:GetPlayerSextants()
	}
	api.File:Write("WorldSatNav/Data/"..settings.Get("LocationOutputFile"), writeFile)
	sharedDataLastUpdate = 0
end

return shareddata