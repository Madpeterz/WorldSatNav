---@diagnostic disable: undefined-global
local api = require("api")

local WorldSatNavSettings = {}

local settings = nil
local defaultSettings = {
    TrackingWindowX = 46,
    MainWindowY = 11,
    MainWindowX = 343,
    TrackingWindowY = 300,
    OpenButtonX = 1499,
    OpenButtonY = 716,
    UseTeleportHint = true,
    EnableWorldEvents = true,
    WorldEventsKeptFor = 5, -- in minutes, how long to keep world events in the list
    OpenRealMap = true,
    trackingMode = "guide",
    EnableLocationOutput = false,
    LocationOutputRateLimit = 1000, -- in milliseconds, how often to output player location
    LocationOutputFile = "location.dat",
    showDemoCreatePlus = false,
    EnableAlertDemo = true,
    OpenDemoAddButtonX = 300,
    OpenDemoAddButtonY = 300,
    DrawDemosInNextHour = true,
    OpenDemoWindowX = 500,
    OpenDemoWindowY = 300,
    OpenDemoAlertWindowX = 500,
    OpenDemoAlertWindowY = 300,
}

function  WorldSatNavSettings.Is(key, value)
    return WorldSatNavSettings.Get(key) == value
end

function WorldSatNavSettings.Get(key)
    if(settings == nil) then
        settings = WorldSatNavSettings.LoadSettings()
    end
    if(settings == nil) then -- if for some reason loading settings failed, return default settings
        settings = defaultSettings 
    end
    if(settings[key] == nil) then
        return defaultSettings[key]
    end
    return settings[key]
end

function WorldSatNavSettings.Update(key, value)
    if(settings == nil) then
        settings = WorldSatNavSettings.LoadSettings()
    end
    local oldvalue = settings[key]
    settings[key] = value
    if oldvalue ~= value then 
        api.SaveSettings("WorldSatNav", settings)
    end
end

function WorldSatNavSettings.LoadSettings()
    local settings = api.GetSettings("WorldSatNav")
    -- loop for set default settings if not exists
    local needsSave = false
    for k, v in pairs(defaultSettings) do
        if settings[k] == nil then 
            settings[k] = v 
            needsSave = true
        end
    end
    if needsSave then
        api.SaveSettings("WorldSatNav", settings)
    end
    return settings
end

return WorldSatNavSettings