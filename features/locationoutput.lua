-- Location Output
-- Writes the player's position and the current time to data/<LocationOutputFile> so
-- external tools can follow the player. Kept free of UI requires so it can be tested.

local api = require("api")
local settings = require("WorldSatNav/core/settings")
local datetime = require("WorldSatNav/helpers/datetime")

local locationoutput = {}

local sharedDataLastUpdate = 0
local updateTicker = 0

-- Called every frame with dt in milliseconds; writes at most once per LocationOutputRateLimit.
function locationoutput.Update(dt)
	if settings.Get("EnableLocationOutput") ~= true then
		return
	end
	sharedDataLastUpdate = sharedDataLastUpdate + dt
	if sharedDataLastUpdate < settings.Get("LocationOutputRateLimit") then
		return
	end
	updateTicker = updateTicker + dt
	local writeFile = {
		-- Text, not a number: api.File:Write prints numbers as %g (1.79299e+009), and a
		-- unix-sized number only holds 128s steps in this engine.
		time = datetime.GetCurrentTimestampText(), -- unix seconds
		location = api.Map:GetPlayerSextants(),
		updateTicker = updateTicker
	}
	api.File:Write("WorldSatNav/data/"..settings.Get("LocationOutputFile"), writeFile)
	if updateTicker > 10000 then
		updateTicker = 0 -- reset ticker every 10 seconds to prevent overflow, just a helper so you can see file updates even if time has not changed
	end
	sharedDataLastUpdate = 0
end

return locationoutput
