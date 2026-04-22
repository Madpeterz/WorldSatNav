-- WorldSatNav Main Module
local api = require("api")
local maprendering = require("WorldSatNav/maprendering")
local treasuremaps = require("WorldSatNav/treasuremaps")
local demos = require("WorldSatNav/demos")
local ships = require("WorldSatNav/ships")
local events = require("WorldSatNav/worldevents")
local alertwindow = require("WorldSatNav/alertwindow")
local tracking = require("WorldSatNav/tracking")
local gps = require("WorldSatNav/gps")
local gotolocation = require("WorldSatNav/gotolocation")
local helpers = require("WorldSatNav/helpers")
local configui = require("WorldSatNav/configui")
local eventbus = require("WorldSatNav/eventbus")

local WorldSatNav = {
	name = "WorldSatNav",
	author = "Madpeter",
	version = "1.1.0",
	desc = "Im still not sure where to go"
}

-- Addon initialization
local function OnLoad()
	configui.OnLoad()
	tracking.OnLoad()
	alertwindow.OnLoad()
	demos.OnLoad()
	gotolocation.OnLoad()
	treasuremaps.OnLoad()
	ships.OnLoad()
	events.OnLoad()
	eventbus.SetDeferredBudgetPerTick(100)
	-- fire up everything else first then the main UI drawing system
	maprendering.OnLoad()
	-- Register update loop
	api.On("UPDATE", function(dt)
		-- Pump queued events first so chained events are not starved behind update work.
		eventbus.ProcessDeferredEvents()
		helpers.AdvanceCurrentTimestamp(dt)
		maprendering.OnUpdate(dt)
		tracking.onUpdate(dt)
		gps.onUpdate(dt)
		demos.onUpdate(dt)
		alertwindow.onUpdate(dt)
		treasuremaps.onUpdate(dt)
		-- Pump again for events queued by module updates in this same frame.
		eventbus.ProcessDeferredEvents()
	end)
	-- attach events
	function WorldSatNav:EventListener(event, ...)
		if(event == "WORLD_MESSAGE") then 
			events.WorldMessageProcessor(event,unpack(arg))
		end
	end
	if maprendering.MapUI == nil then
		helpers.DevLog("Failed to initialize WorldSatNav: MapUI is nil")
		return
	end
	maprendering.MapUI:SetHandler("OnEvent", WorldSatNav.EventListener)
    maprendering.MapUI:RegisterEvent("WORLD_MESSAGE")
end

-- Addon cleanup
local function OnUnload()
	-- Unregister hooks
	api.On("UPDATE", function() return end)
	-- Unregister events
	if maprendering.MapUI ~= nil then
		maprendering.MapUI:ReleaseHandler("OnEvent")
	end
	-- Clean up modules
	maprendering.OnUnload()
	tracking.OnUnload()
	gotolocation.OnUnload()
	demos.OnUnload()
	alertwindow.OnUnload()
	treasuremaps.OnUnload()
	ships.OnUnload()
	events.OnUnload()
end

WorldSatNav.OnLoad = OnLoad
WorldSatNav.OnUnload = OnUnload

return WorldSatNav