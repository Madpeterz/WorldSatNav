local helpers = require("WorldSatNav/helpers")
local settingsModule = require("WorldSatNav/settings")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")

local configui = {}

local configElements = {}

function ToggleUIVisibleState(newState)
    for _, element in pairs(configElements) do
        if element and element:IsVisible() ~= newState then
            element:Show(newState)
        end
    end
    helpers.ToggleCheckboxVisable("trackingModeGuide", newState)
    helpers.ToggleCheckboxVisable("trackingModeCompass", newState)
    helpers.ToggleCheckboxVisable("demosShowNextHour", newState)
    helpers.ToggleCheckboxVisable("demosEnableAddUI", newState)
    helpers.ToggleCheckboxVisable("demosEnableAlerts", newState)
    helpers.ToggleCheckboxVisable("locationOutput", newState)
    helpers.ToggleCheckboxVisable("locationGuideRegion", newState)
    helpers.ToggleCheckboxVisable("locationOpenRealMap", newState)
    helpers.ToggleCheckboxVisable("eventsTrack", newState)
    helpers.ToggleCheckboxVisable("eventsKeep5", newState)
    helpers.ToggleCheckboxVisable("eventsKeep10", newState)
    helpers.ToggleCheckboxVisable("eventsKeep15", newState)
    helpers.ToggleCheckboxVisable("eventsAlert", newState)
    helpers.ToggleCheckboxVisable("DSTOffset", newState)
end
function configui.ShowConfigUI()
    ToggleUIVisibleState(true)
end
function configui.HideConfigUI()
    ToggleUIVisibleState(false)
end

local function CheckBoxUpdate(checkState, checkboxId)
    local SettingName = nil
    if checkboxId == "demosShowNextHour" then SettingName = "DrawDemosInNextHour"
    elseif checkboxId == "demosEnableAddUI" then SettingName = "showDemoCreatePlus"
    elseif checkboxId == "demosEnableAlerts" then SettingName = "EnableAlertDemo"
    elseif checkboxId == "locationOutput" then SettingName = "EnableLocationOutput"
    elseif checkboxId == "locationGuideRegion" then SettingName = "UseTeleportHint"
    elseif checkboxId == "locationOpenRealMap" then SettingName = "OpenRealMap"
    elseif checkboxId == "eventsTrack" then SettingName = "EnableWorldEvents"
    elseif checkboxId == "eventsAlert" then SettingName = "EnableEventAlerts"
    elseif checkboxId == "DSTOffset" then SettingName = "DSToffset"
    end
    if SettingName ~= nil then
        settingsModule.Update(SettingName, checkState)
    else
        helpers.DevLog("Unknown checkboxId: "..checkboxId)
    end
end

function configui.CreateConfigUI(MapUIWindow)
    if MapUIWindow == nil then
        helpers.DevLog("MapUIWindow is nil, cannot create config UI")
        return
    end
    local settingsText = helpers.createLabel("settingsLabel", MapUIWindow, "Settings", 25, 10, 25)
    table.insert(configElements, settingsText)
    -- tracking mode [Guide, Compass]

    local trackingModeLabel = helpers.createLabel("trackingModeLabel", MapUIWindow, "Tracking Mode:", 40, 40, 12)
    table.insert(configElements, trackingModeLabel)
    helpers.CreateSkinnedCheckbox(
        "trackingModeGuide",
        MapUIWindow,
        "Guide",
        40,
        60,
        settingsModule.Is("trackingMode","Guide"),
        function(checked)
            if checked == true then settingsModule.Update("trackingMode", "Guide") end
        end,
        nil,
        nil,
        "TrackingMode",
        nil,
        true
    )
    helpers.CreateSkinnedCheckbox("trackingModeCompass", MapUIWindow, "Compass", 125, 60, settingsModule.Is("trackingMode","Compass"), 
    function(checked)
        if checked == true then settingsModule.Update("trackingMode", "Compass") end
    end, nil, nil, "TrackingMode", nil, true)
    -- Demos [Show only in the next hour, Enable UI For demo add, Enable alerts]
    helpers.CreateSkinnedCheckbox("demosShowNextHour", MapUIWindow, "Show only in the next hour", 40, 105, settingsModule.Is("DrawDemosInNextHour", true), CheckBoxUpdate)
    helpers.CreateSkinnedCheckbox("demosEnableAddUI", MapUIWindow, "Enable + for add", 40, 135, settingsModule.Is("showDemoCreatePlus", true), CheckBoxUpdate)
    helpers.CreateSkinnedCheckbox("demosEnableAlerts", MapUIWindow, "Enable alerts", 40, 165, settingsModule.Is("EnableAlertDemo", true), CheckBoxUpdate)
    local demosLabel = helpers.createLabel("demosLabel", MapUIWindow, "Demos:", 40, 85, 12)
    table.insert(configElements, demosLabel)
    -- Location [Output, Guide region name, Open real map] 
    helpers.CreateSkinnedCheckbox("locationOutput", MapUIWindow, "Output location to file", 40, 245, settingsModule.Is("EnableLocationOutput", true), CheckBoxUpdate)
    helpers.CreateSkinnedCheckbox("locationGuideRegion", MapUIWindow, "Tracking use region name", 250, 245, settingsModule.Is("UseTeleportHint", true), CheckBoxUpdate)
    helpers.CreateSkinnedCheckbox("locationOpenRealMap", MapUIWindow, "Open real map on click", 40, 275, settingsModule.Is("OpenRealMap", true), CheckBoxUpdate)
    local locationLabel = helpers.createLabel("locationLabel", MapUIWindow, "Location:", 40, 220, 12)
    table.insert(configElements, locationLabel)
    -- Events [Track events, Keep Events for [5min, 10min, 15mins], alert for events]
    helpers.CreateSkinnedCheckbox("eventsTrack", MapUIWindow, "Track events", 250, 60, settingsModule.Is("EnableWorldEvents", true), CheckBoxUpdate)

    local eventsLabel = helpers.createLabel("eventsLabel", MapUIWindow, "Events:", 250, 40, 12)
    table.insert(configElements, eventsLabel)
    helpers.CreateSkinnedCheckbox("eventsAlert", MapUIWindow, "Enable alerts for events", 250, 30+60, settingsModule.Is("EnableEventAlerts", true), CheckBoxUpdate)

    local KeepEventsLabel = helpers.createLabel("KeepEventsLabel", MapUIWindow, "Keep events for [X] mins", 250, 115, 9)
    table.insert(configElements, KeepEventsLabel)
    
    helpers.CreateSkinnedCheckbox("eventsKeep5", MapUIWindow, "5", 250, 135, settingsModule.Is("WorldEventsKeptFor",5), 
    function(checked)
                    settingsModule.Update("WorldEventsKeptFor", 5)
                end, nil, nil, "eventsKeep", nil, true)
    helpers.CreateSkinnedCheckbox("eventsKeep10", MapUIWindow, "10", 300, 135, settingsModule.Is("WorldEventsKeptFor",10), 
    function(checked)
                    settingsModule.Update("WorldEventsKeptFor", 10)
                end, nil, nil, "eventsKeep", nil, true)
    helpers.CreateSkinnedCheckbox("eventsKeep15", MapUIWindow, "15", 350, 135, settingsModule.Is("WorldEventsKeptFor",15), 
    function(checked)
                    settingsModule.Update("WorldEventsKeptFor", 15)
                end, nil, nil, "eventsKeep", nil, true)

    local settingPanelDiv = MapUIWindow:CreateImageDrawable("settingPanelDiv", "background")
	settingPanelDiv:SetExtent(3*settingsModule.Get("uiDrawScale"),175*settingsModule.Get("uiDrawScale"))
	settingPanelDiv:AddAnchor("TOPLEFT", MapUIWindow, "TOPLEFT", 225*settingsModule.Get("uiDrawScale"), 40*settingsModule.Get("uiDrawScale"))
	settingPanelDiv:SetTexture("bg_quest")
    settingPanelDiv:SetColor(0,0,0,0.5)
	settingPanelDiv:Show(true)
	if settingPanelDiv.Lower then
		settingPanelDiv:Lower()
	end
    table.insert(configElements, settingPanelDiv)
    local settingPanelDiv2 = MapUIWindow:CreateImageDrawable("settingPanelDiv", "background")
	settingPanelDiv2:SetExtent(400*settingsModule.Get("uiDrawScale"),3*settingsModule.Get("uiDrawScale"))
	settingPanelDiv2:AddAnchor("TOPLEFT", MapUIWindow, "TOPLEFT", 40*settingsModule.Get("uiDrawScale"), 325*settingsModule.Get("uiDrawScale"))
	settingPanelDiv2:SetTexture("bg_quest")
    settingPanelDiv2:SetColor(0,0,0,0.5)
	settingPanelDiv2:Show(true)
	if settingPanelDiv2.Lower then
		settingPanelDiv2:Lower()
	end
    table.insert(configElements, settingPanelDiv2)

    local timeLabel = helpers.createLabel("timeLabel", MapUIWindow, "Time:", 40, 265*settingsModule.Get("uiDrawScale"), 12)
    table.insert(configElements, timeLabel)
    helpers.CreateSkinnedCheckbox("DSTOffset", MapUIWindow, "DST +1 hour", 40, 285*settingsModule.Get("uiDrawScale"), settingsModule.Is("DSToffset", 1), CheckBoxUpdate)

    
    configui.HideConfigUI()
end


function configui.OnLoad()
    eventbus.WatchEvent(eventtopics.topics.UI.MainUILoaded, configui.CreateConfigUI, "configui")
    eventbus.WatchEvent(eventtopics.topics.render.modeChanged, configui.HideConfigUI, "configui")
    eventbus.WatchEvent(eventtopics.topics.UI.close, configui.HideConfigUI, "configui")
    eventbus.WatchEvent(eventtopics.topics.UI.open, configui.HideConfigUI, "configui")
    eventbus.WatchEvent(eventtopics.topics.render.config, configui.ShowConfigUI, "configui")
end

function configui.OnUnload()
end

return configui