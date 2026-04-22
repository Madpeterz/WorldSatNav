local api = require("api")
local helpers = require("WorldSatNav/helpers")
local constants = require("WorldSatNav/constants")
local settingsModule = require("WorldSatNav/settings")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")

local alertwindow = {}

local alertWindow = nil
local activeAlert = nil

local function createAlertWindow(onCloseCallback, onTrackCallback)
    local window = api.Interface:CreateEmptyWindow("WORLD_MAP_ALERT_WINDOW")
    window:AddAnchor("TOPLEFT", "UIParent", settingsModule.Get("OpenDemoAlertWindowX"), settingsModule.Get("OpenDemoAlertWindowY"))
    window:SetExtent(300, 258)
    window:Show(false)
    window:SetCloseOnEscape(true)

    window.TitleLabelText = helpers.createLabel("TitleLabel", window, "Alert!", 15, 5, 20, true, FONT_COLOR.WHITE)
    window.row1LabelText = helpers.createLabel("alertRow1Label", window, "Region:", 15, 47, 12, false, FONT_COLOR.WHITE)
    window.row2LabelText = helpers.createLabel("alertRow2Label", window, "Owner:", 15, 75, 12, false, FONT_COLOR.WHITE)
    window.row3LabelText = helpers.createLabel("alertRow3Label", window, "Building:", 15, 100, 12, false, FONT_COLOR.WHITE)
    window.countdownLabelText = helpers.createLabel("alertCountdownLabel", window, "Time to start:", 15, 130, 12, false, FONT_COLOR.WHITE)

    window.row1Value = helpers.createLabel("alertRow1Value", window, "Unknown", 55, 47, 12, false, FONT_COLOR.WHITE)
    window.row2Value = helpers.createLabel("alertRow2Value", window, "Unknown", 55, 75, 12, false, FONT_COLOR.WHITE)
    window.row3Value = helpers.createLabel("alertRow3Value", window, "Unknown", 55, 100, 12, false, FONT_COLOR.WHITE)
    window.countdownValue = helpers.createLabel("alertCountdownValue", window, "?", 80, 130, 12, false, FONT_COLOR.WHITE)

    local background = window:CreateImageDrawable("alertbackground", "background")
    background:AddAnchor("TOPLEFT", window, 0, 0)
    background:SetExtent(300, 258)
    background:SetTexture(constants.folderPath.."images/alertbackground2.png")
    window.background = background

    helpers.makeWindowDraggable(window, nil, nil, true, true, "OpenDemoAlertWindowX", "OpenDemoAlertWindowY", false, false)

    local trackButton = helpers.createButton("alertTrackButton", window, "Track", 20, 210)
    trackButton:SetHandler("OnClick", onTrackCallback)
    window.trackButton = trackButton

    window.closeBtn = window:CreateChildWidget("button", "closeBtn", 0, true)
    window.closeBtn:AddAnchor("TOPLEFT", window, 300 - 25, 3)
    api.Interface:ApplyButtonSkin(window.closeBtn, BUTTON_BASIC.WINDOW_SMALL_CLOSE)
    window.closeBtn:Show(true)
    window.closeBtn:SetHandler("OnClick", onCloseCallback)
    window:SetHandler("OnClose", onCloseCallback)
    window:SetHandler("OnCloseByEsc", onCloseCallback)

    return window
end

local function applyAlertRow(index, labelDefault, valueDefault)
    if alertWindow == nil then
        return
    end
    local rows = activeAlert and activeAlert.lines or nil
    local row = (type(rows) == "table" and rows[index]) or nil
    local label = (row and row.label) or labelDefault
    local value = (row and row.value) or valueDefault
    if index == 1 then
        alertWindow.row1LabelText:SetText(label)
        alertWindow.row1Value:SetText(value)
    elseif index == 2 then
        alertWindow.row2LabelText:SetText(label)
        alertWindow.row2Value:SetText(value)
    elseif index == 3 then
        alertWindow.row3LabelText:SetText(label)
        alertWindow.row3Value:SetText(value)
    end
end

local function applyAlertData(data)
    if alertWindow == nil then
        return
    end
    alertWindow.TitleLabelText:SetText(data.title or "Alert!")
    applyAlertRow(1, "Region:", "Unknown")
    applyAlertRow(2, "Owner:", "Unknown")
    applyAlertRow(3, "Building:", "Unknown")

    local countdownLabel = data.countdownLabel or "Time to start:"
    alertWindow.countdownLabelText:SetText(countdownLabel)

    local remaining = tonumber(data.countdownSeconds)
    alertWindow.timeRemaining = remaining
    alertWindow.IsCountingUp = data.countUpTo5Minutes or false
    if remaining == nil then
        alertWindow.countdownValue:SetText(data.countdownText or "?")
    else
        local minutes = math.floor(remaining / 60)
        local seconds = math.floor(remaining % 60)
        alertWindow.countdownValue:SetText(string.format("%02d:%02d", minutes, seconds))
    end

    local trackText = data.trackText or "Track"
    alertWindow.trackButton:SetText(trackText)
    if data.enableTrack == false then
        alertWindow.trackButton:Show(false)
    else
        alertWindow.trackButton:Show(true)
    end
end

function alertwindow.ShowAlert(data)
    if alertWindow == nil then
        helpers.DevLog("Alert window not initialized yet")
        return
    end
    if type(data) ~= "table" then
        helpers.DevLog("Alert data must be a table")
        return
    end
    activeAlert = data
    applyAlertData(data)
    alertWindow:Show(true)
end

function alertwindow.HideAlert()
    if alertWindow ~= nil and alertWindow:IsVisible() then
        alertWindow:Show(false)
    end
    activeAlert = nil
end

local function handleTrackClick()
    if activeAlert == nil then
        return
    end
    eventbus.TriggerEvent(eventtopics.topics.tracking.start, activeAlert.payload.sextant, activeAlert.title, true)
    alertwindow.HideAlert()
end

function alertwindow.onUpdate(dt)
    if alertWindow == nil or alertWindow:IsVisible() == false then
        return
    end
    if alertWindow.timeRemaining == nil then
        return
    end
    local deltaSeconds = tonumber(dt) and (dt / 1000) or 0
    if alertWindow.IsCountingUp == true then
        local countUp = alertWindow.timeRemaining + deltaSeconds
        alertWindow.timeRemaining = countUp
        local minutes = math.floor(countUp / 60)
        local seconds = math.floor(countUp % 60)
        if minutes >= 5 then
            alertwindow.HideAlert()
        else
            alertWindow.countdownValue:SetText(string.format("%02d:%02d", minutes, seconds))
        end
    else
        local countdown = alertWindow.timeRemaining - deltaSeconds
        alertWindow.timeRemaining = countdown
        local endText = (activeAlert and activeAlert.countdownEndText) or "Starting soon!"
        if countdown <= 0 then
            alertWindow.countdownValue:SetText(endText)
        else
            local minutes = math.floor(countdown / 60)
            local seconds = math.floor(countdown % 60)
            alertWindow.countdownValue:SetText(string.format("%02d:%02d", minutes, seconds))
        end
    end
end

function alertwindow.MainUIReady()
    alertWindow = createAlertWindow(alertwindow.HideAlert, handleTrackClick)
end

function alertwindow.OnLoad()
    eventbus.WatchEvent(eventtopics.topics.UI.MainUILoaded, alertwindow.MainUIReady, "alertwindow")
    eventbus.WatchEvent(eventtopics.topics.alert.show, alertwindow.ShowAlert, "alertwindow")
    eventbus.WatchEvent(eventtopics.topics.alert.hide, alertwindow.HideAlert, "alertwindow")
end

function alertwindow.OnUnload()
    if alertWindow ~= nil then
        if alertWindow:IsVisible() then
            alertWindow:Show(false)
        end
        api.Interface:Free(alertWindow)
        alertWindow = nil
    end
    activeAlert = nil
end

return alertwindow
