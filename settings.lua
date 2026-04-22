local api = require("api")
local constants = require("WorldSatNav/constants")

local WorldSatNavSettings = {}
local addonName = constants.addonName
local getSettings = api.GetSettings
local saveSettings = api.SaveSettings

local settings = nil
local defaultSettings = {
    -- drawing
    MainWindowY = 11,
    MainWindowX = 343,
    TrackingWindowX = 46,
    TrackingWindowY = 300,
    OpenButtonX = 1499,
    OpenButtonY = 716,
    uiDrawScale = 1.25, -- Scale for UI elements

    -- Tracking
    UseTeleportHint = true,
    trackingMode = "Guide",
    OpenRealMap = true,
    
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
    
    -- Events
    EnableEventAlerts = true,
    EnableWorldEvents = true,
    WorldEventsKeptFor = 5, -- in minutes, how long to keep world events in the list

    -- timing
    DSToffset = true, -- offset in hours to apply during daylight saving time
}

local function DevLog(message)
    if constants.DEV_MODE then
        api.Log:Info(message)
    end
end

local function EnsureSettingsLoaded()
    if settings == nil then
        settings = WorldSatNavSettings.LoadSettings()
        if settings == nil then
            settings = defaultSettings
        end
    end
    return settings
end

function  WorldSatNavSettings.Is(key, value)
    return WorldSatNavSettings.Get(key) == value
end

function WorldSatNavSettings.KeyExists(key)
    if key == nil then
        DevLog("setting key "..tostring(key).." does not exist")
        return false
    end
    return defaultSettings[key] ~= nil
end

function WorldSatNavSettings.Get(key)
    if not WorldSatNavSettings.KeyExists(key) then
        return nil
    end
    local loadedSettings = EnsureSettingsLoaded()
    if loadedSettings[key] == nil then
        return defaultSettings[key]
    end
    return loadedSettings[key]
end

function WorldSatNavSettings.Update(key, value)
    if not WorldSatNavSettings.KeyExists(key) then
        return false
    end
    local loadedSettings = EnsureSettingsLoaded()

    local oldvalue = loadedSettings[key]
    loadedSettings[key] = value
    if oldvalue ~= value then 
        DevLog("Setting updated: "..key.." = "..tostring(value))
        saveSettings(addonName, loadedSettings)
    end
    return true
end

function WorldSatNavSettings.LoadSettings()
    local loadedSettings = getSettings(addonName)
    if loadedSettings == nil then
        loadedSettings = {}
    end
    -- loop for set default settings if not exists
    local needsSave = false
    for k, v in pairs(defaultSettings) do
        if loadedSettings[k] == nil then 
            loadedSettings[k] = v 
            needsSave = true
        end
    end
    if needsSave then
        saveSettings(addonName, loadedSettings)
        DevLog("Settings file created with default settings")
    end
    return loadedSettings
end

return WorldSatNavSettings