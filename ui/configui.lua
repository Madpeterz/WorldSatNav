local helpers = require("WorldSatNav/helpers")
local settingsModule = require("WorldSatNav/core/settings")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")

local configui = {}

local configElements = {}   -- elements always shown/hidden with the whole panel (title, divider)
local tabRegistry = {}      -- tabName -> { checkboxIds = {}, labelWidgets = {} }
local currentTab = "SatNav"
local settingsTitleLabel = nil

local TAB_ORDER = { "SatNav", "Demos", "Events", "Config", "Equip" }
configui.TAB_NAMES = TAB_ORDER -- tab switching is driven by maprendering's mode buttons, see SelectTab/GetActiveTab
for _, tab in ipairs(TAB_ORDER) do
    tabRegistry[tab] = { checkboxIds = {}, labelWidgets = {} }
end

local function RegisterCheckbox(tab, id)
    table.insert(tabRegistry[tab].checkboxIds, id)
end

local function RegisterLabel(tab, widget)
    table.insert(tabRegistry[tab].labelWidgets, widget)
end

local function SetActiveTab(tabName)
    if tabRegistry[tabName] == nil then
        return
    end
    currentTab = tabName
    for tab, reg in pairs(tabRegistry) do
        local visible = (tab == tabName)
        for _, id in ipairs(reg.checkboxIds) do
            helpers.ToggleCheckboxVisable(id, visible)
        end
        for _, widget in ipairs(reg.labelWidgets) do
            widget:Show(visible)
        end
    end
    if settingsTitleLabel ~= nil then
        settingsTitleLabel:SetText("Settings / "..tabName)
    end
end

-- Public API used by maprendering to drive tab switching from the repurposed mode buttons.
function configui.SelectTab(tabName)
    SetActiveTab(tabName)
end

function configui.GetActiveTab()
    return currentTab
end

local function ToggleUIVisibleState(newState)
    for _, element in pairs(configElements) do
        if element and element:IsVisible() ~= newState then
            element:Show(newState)
        end
    end
    if newState == true then
        SetActiveTab(currentTab)
    else
        for tab, reg in pairs(tabRegistry) do
            for _, id in ipairs(reg.checkboxIds) do
                helpers.ToggleCheckboxVisable(id, false)
            end
            for _, widget in ipairs(reg.labelWidgets) do
                widget:Show(false)
            end
        end
    end
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
    elseif checkboxId == "demosSortByTime" then SettingName = "SortDemosByTime"
    elseif checkboxId == "locationOutput" then SettingName = "EnableLocationOutput"
    elseif checkboxId == "locationGuideRegion" then SettingName = "UseTeleportHint"
    elseif checkboxId == "locationOpenRealMap" then SettingName = "OpenRealMap"
    elseif checkboxId == "locationEnableShowOnTracking" then SettingName = "EnableShowOnTracking"
    elseif checkboxId == "locationShowTargetInfoInChat" then SettingName = "ShowTargetInfoInChat"
    elseif checkboxId == "locationAutoGotoNextMap" then SettingName = "AutoGotoNextMap"
    elseif checkboxId == "teleportHintFiltered" then SettingName = "TeleportHintFiltered"
    elseif checkboxId == "eventsTrack" then SettingName = "EnableWorldEvents"
    elseif checkboxId == "eventsAlert" then SettingName = "EnableEventAlerts"
    elseif checkboxId == "DSTOffset" then SettingName = "DSToffset"
    elseif checkboxId == "equipSwapWaterTitle" then SettingName = "SwapToWaterTitle"
    elseif checkboxId == "equipSwapWaterEquipment" then SettingName = "SwapToWaterEquipment"
    elseif checkboxId == "mapsAlwaysShowRegions" then SettingName = "AlwaysShowRegions"
    elseif checkboxId == "mapsColorIconByGrade" then SettingName = "ColorMapIconByGrade"
    elseif checkboxId == "mapsCenterOnPlayerOnModeChange" then SettingName = "CenterOnPlayerOnModeChange"
    elseif checkboxId == "eventsDisableWarehouseRaid" then SettingName = "DisableAlertWarehouseRaid"
    elseif checkboxId == "eventsDisableCrate" then SettingName = "DisableAlertCrate"
    elseif checkboxId == "eventsDisableGhostship" then SettingName = "DisableAlertGhostship"
    elseif checkboxId == "eventsDisableLeviathan" then SettingName = "DisableAlertLeviathan"
    elseif checkboxId == "eventsDisablePerdita" then SettingName = "DisableAlertPerdita"
    elseif checkboxId == "eventsDisableSunfish" then SettingName = "DisableAlertSunfish"
    elseif checkboxId == "targetIconHideMaps" then SettingName = "HideTargetIconMaps"
    elseif checkboxId == "targetIconHideShips" then SettingName = "HideTargetIconShips"
    elseif checkboxId == "targetIconHideEvents" then SettingName = "HideTargetIconEvents"
    elseif checkboxId == "targetIconHideDemos" then SettingName = "HideTargetIconDemos"
    elseif checkboxId == "targetIconHideDawns" then SettingName = "HideTargetIconDawns"
    end
    if SettingName ~= nil then
        settingsModule.Update(SettingName, checkState)
        if checkboxId == "teleportHintFiltered" then
            eventbus.TriggerEvent(eventtopics.topics.dawnsdrop.refresh)
        end
    else
        helpers.DevLog("Unknown checkboxId: "..checkboxId)
    end
end

-- Creates a checkbox and registers it against the given tab for show/hide on tab switch.
local function CreateTabCheckbox(tab, id, parent, text, x, y, checked, onClick, sizeX, sizeY, radioGroup, renderlayer, showText)
    helpers.CreateSkinnedCheckbox(id, parent, text, x, y, checked, onClick, sizeX, sizeY, radioGroup, renderlayer, showText)
    RegisterCheckbox(tab, id)
end

local function CreateTabLabel(tab, id, parent, text, x, y, fontSize)
    local label = helpers.createLabel(id, parent, text, x, y, fontSize)
    RegisterLabel(tab, label)
    return label
end

-- Thin separator line between setting groups, hidden/shown with the rest of the tab.
local function CreateTabDivider(tab, id, parent, y)
    local div = parent:CreateImageDrawable(id, "background")
    div:SetExtent(370*settingsModule.Get("uiDrawScale"), 1*settingsModule.Get("uiDrawScale"))
    div:AddAnchor("TOPLEFT", parent, "TOPLEFT", 40*settingsModule.Get("uiDrawScale"), y*settingsModule.Get("uiDrawScale"))
    div:SetTexture("bg_quest")
    div:SetColor(1,1,1,0.15)
    div:Show(true)
    if div.Lower then
        div:Lower()
    end
    RegisterLabel(tab, div)
    return div
end

-- Text box bound to a string setting, shown/hidden with the given tab.
local function CreateTabTextInput(tab, id, parent, x, y, width, labelText, setting)
    local input = helpers.createTextInput(id, parent, x, y, width, 29, nil, 60, labelText, function(text)
        settingsModule.Update(setting, text)
    end, false, FONT_COLOR.BLACK)
    input:SetText(settingsModule.Get(setting) or "")
    RegisterLabel(tab, input)
    if input.label ~= nil then
        RegisterLabel(tab, input.label)
    end
    return input
end

function configui.CreateConfigUI(MapUIWindow)
    if MapUIWindow == nil then
        helpers.DevLog("MapUIWindow is nil, cannot create config UI")
        return
    end
    local settingsText = helpers.createLabel("settingsLabel", MapUIWindow, "Settings / "..currentTab, 25, 10, 25, false, nil, 350)
    table.insert(configElements, settingsText)
    settingsTitleLabel = settingsText

    local titleDiv = MapUIWindow:CreateImageDrawable("settingPanelDiv", "background")
    titleDiv:SetExtent(400*settingsModule.Get("uiDrawScale"),3*settingsModule.Get("uiDrawScale"))
    titleDiv:AddAnchor("TOPLEFT", MapUIWindow, "TOPLEFT", 25*settingsModule.Get("uiDrawScale"), 40*settingsModule.Get("uiDrawScale"))
    titleDiv:SetTexture("bg_quest")
    titleDiv:SetColor(0,0,0,0.5)
    titleDiv:Show(true)
    if titleDiv.Lower then
        titleDiv:Lower()
    end
    table.insert(configElements, titleDiv)

    local col1, col2 = 40, 290

    -- Maps tab (maps + tracking settings)
    CreateTabLabel("SatNav", "nextMapModeLabel", MapUIWindow, "Next button behaviour:", 40, 65, 12)
    CreateTabCheckbox("SatNav", "nextMapModeRegionOnly", MapUIWindow, "[A] Nearest (in region)", 40, 89, settingsModule.Is("NextMapMode", 1),
        function(checked) if checked == true then settingsModule.Update("NextMapMode", 1) end end, nil, nil, "nextMapMode", nil, true)
    CreateTabCheckbox("SatNav", "nextMapModeAnywhere", MapUIWindow, "[B] Nearest", 210, 89, settingsModule.Is("NextMapMode", 2),
        function(checked) if checked == true then settingsModule.Update("NextMapMode", 2) end end, nil, nil, "nextMapMode", nil, true)
    CreateTabCheckbox("SatNav", "nextMapModeRegionThenAnywhere", MapUIWindow, "[C] A then B", 320, 89, settingsModule.Is("NextMapMode", 3),
        function(checked) if checked == true then settingsModule.Update("NextMapMode", 3) end end, nil, nil, "nextMapMode", nil, true)

    CreateTabLabel("SatNav", "trackingModeLabel", MapUIWindow, "Display type:", 40, 119, 12)
    CreateTabCheckbox("SatNav", "trackingModeGuide", MapUIWindow, "Guide", 40, 143, settingsModule.Is("RadarEnabled", false) and settingsModule.Is("trackingMode","Guide"),
        function(checked)
            if checked == true then
                eventbus.TriggerEvent(eventtopics.topics.radar.setEnabled, false)
                settingsModule.Update("trackingMode", "Guide")
            end
        end, nil, nil, "TrackingDisplayType", nil, true)
    CreateTabCheckbox("SatNav", "trackingModeCompass", MapUIWindow, "Compass", 150, 143, settingsModule.Is("RadarEnabled", false) and settingsModule.Is("trackingMode","Compass"),
        function(checked)
            if checked == true then
                eventbus.TriggerEvent(eventtopics.topics.radar.setEnabled, false)
                settingsModule.Update("trackingMode", "Compass")
            end
        end, nil, nil, "TrackingDisplayType", nil, true)
    CreateTabCheckbox("SatNav", "radarEnabled", MapUIWindow, "Radar", 260, 143, settingsModule.Is("RadarEnabled", true),
        function(checked)
            if checked == true then
                eventbus.TriggerEvent(eventtopics.topics.radar.setEnabled, true)
            end
        end, nil, nil, "TrackingDisplayType", nil, true)

    CreateTabDivider("SatNav", "satNavDiv1", MapUIWindow, 171)

    CreateTabCheckbox("SatNav", "mapsAlwaysShowRegions", MapUIWindow, "Keep map region label on inventory", col1, 183, settingsModule.Is("AlwaysShowRegions", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "locationAutoGotoNextMap", MapUIWindow, "Auto goto next map", col2, 183, settingsModule.Is("AutoGotoNextMap", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "locationOpenRealMap", MapUIWindow, "Open real map on tracking start", col1, 209, settingsModule.Is("OpenRealMap", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "locationEnableShowOnTracking", MapUIWindow, "Use \"Show\" button", col2, 209, settingsModule.Is("EnableShowOnTracking", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "locationGuideRegion", MapUIWindow, "Use teleport hints when tracking", col1, 235, settingsModule.Is("UseTeleportHint", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "locationShowTargetInfoInChat", MapUIWindow, "Target info in chat", col2, 235, settingsModule.Is("ShowTargetInfoInChat", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "teleportHintFiltered", MapUIWindow, "Filter teleport locations by faction", col1, 261, settingsModule.Is("TeleportHintFiltered", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "mapsColorIconByGrade", MapUIWindow, "Color icon for grade", col2, 261, settingsModule.Is("ColorMapIconByGrade", true), CheckBoxUpdate)

    CreateTabDivider("SatNav", "satNavDiv2", MapUIWindow, 289)

    CreateTabLabel("SatNav", "targetIconHideLabel", MapUIWindow, "Hide target icon on:", 40, 301, 9)
    CreateTabCheckbox("SatNav", "targetIconHideMaps", MapUIWindow, "Maps", col1, 323, settingsModule.Is("HideTargetIconMaps", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "targetIconHideShips", MapUIWindow, "Ships", col2, 323, settingsModule.Is("HideTargetIconShips", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "targetIconHideEvents", MapUIWindow, "Events", col1, 349, settingsModule.Is("HideTargetIconEvents", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "targetIconHideDemos", MapUIWindow, "Demos", col2, 349, settingsModule.Is("HideTargetIconDemos", true), CheckBoxUpdate)
    CreateTabCheckbox("SatNav", "targetIconHideDawns", MapUIWindow, "Dawns", col1, 375, settingsModule.Is("HideTargetIconDawns", true), CheckBoxUpdate)

    -- Demos tab
    CreateTabCheckbox("Demos", "demosShowNextHour", MapUIWindow, "Show only in the next hour", col1, 65, settingsModule.Is("DrawDemosInNextHour", true), CheckBoxUpdate)
    CreateTabCheckbox("Demos", "demosEnableAddUI", MapUIWindow, "Show Add button", col2, 65, settingsModule.Is("showDemoCreatePlus", true), CheckBoxUpdate)

    CreateTabDivider("Demos", "demosDiv1", MapUIWindow, 92)

    CreateTabCheckbox("Demos", "demosSortByTime", MapUIWindow, "Sort by time remaining", col1, 104, settingsModule.Is("SortDemosByTime", true), CheckBoxUpdate)
    CreateTabCheckbox("Demos", "demosEnableAlerts", MapUIWindow, "Enable alerts for demos", col2, 104, settingsModule.Is("EnableAlertDemo", true), CheckBoxUpdate)

    -- Events tab
    CreateTabLabel("Events", "KeepEventsLabel", MapUIWindow, "Keep events for [X] mins:", 40, 65, 9)
    CreateTabCheckbox("Events", "eventsKeep5", MapUIWindow, "5", 40, 87, settingsModule.Is("WorldEventsKeptFor",5),
        function(checked) if checked == true then settingsModule.Update("WorldEventsKeptFor", 5) end end, nil, nil, "eventsKeep", nil, true)
    CreateTabCheckbox("Events", "eventsKeep10", MapUIWindow, "10", 100, 87, settingsModule.Is("WorldEventsKeptFor",10),
        function(checked) if checked == true then settingsModule.Update("WorldEventsKeptFor", 10) end end, nil, nil, "eventsKeep", nil, true)
    CreateTabCheckbox("Events", "eventsKeep15", MapUIWindow, "15", 160, 87, settingsModule.Is("WorldEventsKeptFor",15),
        function(checked) if checked == true then settingsModule.Update("WorldEventsKeptFor", 15) end end, nil, nil, "eventsKeep", nil, true)

    CreateTabDivider("Events", "eventsDiv1", MapUIWindow, 115)

    CreateTabCheckbox("Events", "eventsTrack", MapUIWindow, "Enable world events", col1, 127, settingsModule.Is("EnableWorldEvents", true), CheckBoxUpdate)
    CreateTabCheckbox("Events", "eventsAlert", MapUIWindow, "Show alerts for events", col2, 127, settingsModule.Is("EnableEventAlerts", true), CheckBoxUpdate)
    CreateTabLabel("Events", "disableAlertsLabel", MapUIWindow, "Disable alerts for:", 40, 155, 9)
    CreateTabCheckbox("Events", "eventsDisableWarehouseRaid", MapUIWindow, "Warehouse opening & Raid", col1, 177, settingsModule.Is("DisableAlertWarehouseRaid", true), CheckBoxUpdate)
    CreateTabCheckbox("Events", "eventsDisableCrate", MapUIWindow, "Crates", col2, 177, settingsModule.Is("DisableAlertCrate", true), CheckBoxUpdate)
    CreateTabCheckbox("Events", "eventsDisableGhostship", MapUIWindow, "Delphinad Ghostship", col1, 203, settingsModule.Is("DisableAlertGhostship", true), CheckBoxUpdate)
    CreateTabCheckbox("Events", "eventsDisableLeviathan", MapUIWindow, "Leviathan", col2, 203, settingsModule.Is("DisableAlertLeviathan", true), CheckBoxUpdate)
    CreateTabCheckbox("Events", "eventsDisablePerdita", MapUIWindow, "Perdita", col1, 229, settingsModule.Is("DisableAlertPerdita", true), CheckBoxUpdate)
    CreateTabCheckbox("Events", "eventsDisableSunfish", MapUIWindow, "Sunfish", col2, 229, settingsModule.Is("DisableAlertSunfish", true), CheckBoxUpdate)

    -- Config tab
    CreateTabCheckbox("Config", "locationOutput", MapUIWindow, "Output location to file", 40, 65, settingsModule.Is("EnableLocationOutput", true), CheckBoxUpdate)
    CreateTabCheckbox("Config", "mapsCenterOnPlayerOnModeChange", MapUIWindow, "Center on player on mode change", 40, 91, settingsModule.Is("CenterOnPlayerOnModeChange", true), CheckBoxUpdate)

    CreateTabDivider("Config", "configDiv1", MapUIWindow, 118)

    CreateTabLabel("Config", "timeLabel", MapUIWindow, "Time:", 40, 130, 12)
    CreateTabCheckbox("Config", "DSTOffset", MapUIWindow, "DST +1 hour", 40, 154, settingsModule.Is("DSToffset", true), CheckBoxUpdate)

    -- Equip tab (title IDs live in settings: title_id_swim / title_id_normal)
    CreateTabCheckbox("Equip", "equipSwapWaterTitle", MapUIWindow, "Swap to water title", col1, 65, settingsModule.Is("SwapToWaterTitle", true), CheckBoxUpdate)

    CreateTabDivider("Equip", "equipDiv1", MapUIWindow, 96)

    CreateTabCheckbox("Equip", "equipSwapWaterEquipment", MapUIWindow, "Swap to water equipment", col1, 108, settingsModule.Is("SwapToWaterEquipment", true), CheckBoxUpdate)
    CreateTabTextInput("Equip", "equipmentSwimInput", MapUIWindow, col1, 138, 160, "Water equipment:", "equipment_swim")
    CreateTabTextInput("Equip", "equipmentNormalInput", MapUIWindow, 205, 138, 160, "Normal equipment:", "equipment_normal")

    SetActiveTab(currentTab)
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
