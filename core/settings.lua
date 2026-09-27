local api = require("api")
local constants = require("WorldSatNav/core/constants")

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
    RadarWindowX = 400,
    RadarWindowY = 300,
    OpenButtonX = 1499,
    OpenButtonY = 716,
    uiDrawScale = 1.25, -- Scale for UI elements
    showUIbutton = true,

    -- Tracking
    UseTeleportHint = true,
    trackingMode = "Guide",
    RadarEnabled = true,
    OpenRealMap = true,
    EnableShowOnTracking = true,
    ShowTargetInfoInChat = false,
    AutoGotoNextMap = false,
    NextMapMode = 1, -- 1 = nearest in my region only, 2 = nearest anywhere, 3 = my region first then anywhere
    TeleportHintFiltered = true, -- Points of Interest hints only show for the player's faction (West=Nuia, East=Haranya, Shared=both)
    CenterOnPlayerOnModeChange = false, -- re-centers the map view on the player whenever mode changes (Maps/Ships/Events/etc)
    -- Per map mode opt-out for the tracking target ring on the map
    HideTargetIconMaps = false,
    HideTargetIconShips = false,
    HideTargetIconEvents = false,
    HideTargetIconDemos = false,
    HideTargetIconDawns = false,

    EnableLocationOutput = false,
    LocationOutputRateLimit = 1000, -- in milliseconds, how often to output player location
    LocationOutputFile = "location.dat",
    showDemoCreatePlus = false,
    EnableAlertDemo = true,
    SortDemosByTime = true,
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
    DisableAlertWarehouseRaid = false,
    DisableAlertCrate = false,
    DisableAlertGhostship = false,
    DisableAlertLeviathan = false,
    DisableAlertPerdita = false,
    DisableAlertSunfish = false,

    -- Equip
    SwapToWaterTitle = false,
    title_id_swim = 531,
    title_id_normal = 180,
    SwapToWaterEquipment = false,
    equipment_swim = "Eternal Defiance", -- item name in bag
    equipment_normal = "Delphinad Wave Sabatons",

    -- timing
    DSToffset = true, -- offset in hours to apply during daylight saving time

    -- Maps
    AlwaysShowRegions = false, -- when true, treasure map bag region labels show even while the map UI is closed
    ColorMapIconByGrade = false, -- map icons use the grade texture and grow with the map count instead of the marker1-3 textures

    -- Dawnsdrop
    DawnsLastTask = "",
    DawnsLastType = "",
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
    -- Fill in any missing keys with defaults in-memory only. Do NOT persist here:
    -- if the addon failed to load cleanly (e.g. an earlier module errored) and
    -- getSettings returned nil/empty as a result rather than a genuine first run,
    -- eagerly saving here would overwrite the user's real settings file with
    -- defaults. Real values still get written the first time Update() changes
    -- something.
    for k, v in pairs(defaultSettings) do
        if loadedSettings[k] == nil then
            loadedSettings[k] = v
        end
    end
    return loadedSettings
end

return WorldSatNavSettings