local api = require("api")
local constants = require("WorldSatNav/core/constants")

local log = {}

function log.DevLog(message)
    if constants.DEV_MODE then
        api.Log:Info(message)
    end
end

function log.DebugDumpValue(label, value, depth, visited)
	depth = depth or 0
	visited = visited or {}
	local indent = string.rep("  ", depth)
	local valueType = type(value)

	if valueType ~= "table" then
		log.DevLog(indent .. label .. " = " .. tostring(value))
		return
	end

	if visited[value] then
		log.DevLog(indent .. label .. " = <recursive table>")
		return
	end

	visited[value] = true
	log.DevLog(indent .. label .. " = {")
	for key, nestedValue in pairs(value) do
		log.DebugDumpValue(tostring(key), nestedValue, depth + 1, visited)
	end
	log.DevLog(indent .. "}")
end

return log
