local api = require("api")
local settingsModule = require("WorldSatNav/core/settings")
local helpers = require("WorldSatNav/helpers")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")
local gotoLocation = {}
local GOTO_TARGET_TEXT = ""

local DEFAULT_LABEL = "Destination"
local DEFAULT_HINT = "00°00'00\" (NS), 00°00'00\" (EW)"
local DEFAULT_BUTTON = "Go"
local IMPORT_LABEL = "Import via sharecode"
local IMPORT_HINT = "ShareCode|Here"
local IMPORT_BUTTON = "Add"
local EXPORT_LABEL = "Export demo sharecode"

local gotoLocationWindow = nil
local currentMode = "goto"
local importSubmitCallback = nil

local function ParseGotoTargetText(rawText)
	if rawText == nil then
		return nil
	end

	local text = rawText:match("^%s*(.-)%s*$")
	if text == nil or text == "" then
		return nil
	end

	local normalized = text:upper()
	local pattern = "^(%d+)%s*°%s*(%d+)%s*'%s*(%d+)%s*\"%s*([NS])%s*,%s*(%d+)%s*°%s*(%d+)%s*'%s*(%d+)%s*\"%s*([EW])%s*$"
	local latDeg, latMin, latSec, latDir, longDeg, longMin, longSec, longDir = normalized:match(pattern)
	if latDeg == nil then
		local simplePattern = "^(%d+)%s+(%d+)%s+(%d+)%s+([NS])%s*,?%s*(%d+)%s+(%d+)%s+(%d+)%s+([EW])%s*$"
		latDeg, latMin, latSec, latDir, longDeg, longMin, longSec, longDir = normalized:match(simplePattern)
	end
	if latDeg == nil then
		return nil
	end

    local sextant = {}
    sextant.longitude = longDir
	sextant.latitude = latDir
	sextant.deg_long = tonumber(longDeg)
	sextant.min_long = tonumber(longMin)
	sextant.sec_long = tonumber(longSec)
	sextant.deg_lat =  tonumber(latDeg)
	sextant.min_lat =  tonumber(latMin)
	sextant.sec_lat = tonumber(latSec)
	return sextant
end

local function ResetToGotoMode()
	currentMode = "goto"
	importSubmitCallback = nil
	GOTO_TARGET_TEXT = ""
	if gotoLocationWindow == nil then
		return
	end
	if gotoLocationWindow.textinput ~= nil then
		gotoLocationWindow.textinput:SetText("")
		if gotoLocationWindow.textinput.label ~= nil then
			gotoLocationWindow.textinput.label:SetText(DEFAULT_LABEL)
		end
		if gotoLocationWindow.textinput.CreateGuideText ~= nil then
			gotoLocationWindow.textinput:CreateGuideText("  "..DEFAULT_HINT, ALIGN_LEFT)
		end
	end
	if gotoLocationWindow.submit ~= nil then
		gotoLocationWindow.submit:SetText(DEFAULT_BUTTON)
		gotoLocationWindow.submit:Show(true)
	end
end

local function CLOSE_GOTO_WINDOW()
	if gotoLocationWindow == nil then
		helpers.DevLog("Goto window not initialized yet")
		return
	end
	local inputText = GOTO_TARGET_TEXT
	if gotoLocationWindow.textinput ~= nil and gotoLocationWindow.textinput.GetText ~= nil then
		inputText = gotoLocationWindow.textinput:GetText() or inputText
	end
	GOTO_TARGET_TEXT = inputText or ""
	gotoLocationWindow:Show(false)
	helpers.DevLog("Closing Goto window with text: " .. tostring(GOTO_TARGET_TEXT))
	if currentMode == "import" then
		local callback = importSubmitCallback
		local submittedText = GOTO_TARGET_TEXT
		ResetToGotoMode()
		if submittedText ~= "" and callback ~= nil then
			callback(submittedText)
		end
		return
	end
	if currentMode == "export" then
		ResetToGotoMode()
		return
	end
	if GOTO_TARGET_TEXT ~= "" then
		local sextant = ParseGotoTargetText(GOTO_TARGET_TEXT)
		if sextant ~= nil then
			helpers.DevLog("Parsed GOTO input successfully")
			eventbus.TriggerEvent(eventtopics.topics.tracking.custom, sextant, "Custom goto target", true)
		else
			helpers.DevLog("Failed to parse GOTO input")
		end
	end
end

local function CreateUI(parent, width, height)
    width = width or 500
    height = height or 500
    GOTO_TARGET_TEXT = ""
    local window = api.Interface:CreateEmptyWindow("gotoLocationWindow", parent)
    local gotoWindowHeight = 50 * settingsModule.Get("uiDrawScale")
    local gotoWindowWidth = 260*settingsModule.Get("uiDrawScale")
    window:SetExtent(gotoWindowWidth, gotoWindowHeight)
    window:AddAnchor("TOPLEFT", parent, 0, height)
    window.Background = window:CreateImageDrawable("gotoBackground", "background")
    window:Show(false)
	window.Background:SetExtent(gotoWindowWidth, gotoWindowHeight)
	window.Background:AddAnchor("TOPLEFT", window, "TOPLEFT", 0, 0)
	window.Background:SetTexture(api.baseDir .. "/WorldSatNav/images/mainuibackground3.png")
    window.Background:SetColor(1,1,1,0.9)
	window.Background:Show(true)
		window.textinput = helpers.createTextInput("textinput", window, 10, 0, 175, 20, DEFAULT_HINT, 100, DEFAULT_LABEL, function(text)
		GOTO_TARGET_TEXT = text
		helpers.DevLog("gotoTarget set to " .. tostring(GOTO_TARGET_TEXT))
    end)
    local gobuttonXoffset = (10*settingsModule.Get("uiDrawScale")) + (175 * settingsModule.Get("uiDrawScale"))
    window.submit = helpers.createButton("submitgoto", window, DEFAULT_BUTTON, gobuttonXoffset, 12 * settingsModule.Get("uiDrawScale"))
	return window
end

function gotoLocation.CloseIfOpen()
    if gotoLocationWindow == nil then
        helpers.DevLog("Goto window not initialized yet")
        return
    end
    if gotoLocationWindow:IsVisible() then
        gotoLocationWindow:Show(false)
    end
    if currentMode ~= "goto" then
        ResetToGotoMode()
    end
end

function gotoLocation.ToggleUI()
    if gotoLocationWindow == nil then
        helpers.DevLog("Goto window not initialized yet")
        return
    end
    if currentMode ~= "goto" then
        ResetToGotoMode()
    end
    if gotoLocationWindow:IsVisible() == true then
        gotoLocationWindow:Show(false)
    else
        gotoLocationWindow:Show(true)
    end
end

-- Opens the goto window repurposed as a sharecode import panel.
-- onSubmit(rawText) is called with the entered text when the Add button is pressed.
function gotoLocation.OpenImportSharecode(onSubmit)
    if gotoLocationWindow == nil then
        helpers.DevLog("Goto window not initialized yet")
        return
    end
    if currentMode == "import" and gotoLocationWindow:IsVisible() then
        CLOSE_GOTO_WINDOW()
        return
    end
    currentMode = "import"
    importSubmitCallback = onSubmit
    GOTO_TARGET_TEXT = ""
    if gotoLocationWindow.textinput ~= nil then
        gotoLocationWindow.textinput:SetText("")
        if gotoLocationWindow.textinput.label ~= nil then
            gotoLocationWindow.textinput.label:SetText(IMPORT_LABEL)
        end
        if gotoLocationWindow.textinput.CreateGuideText ~= nil then
            gotoLocationWindow.textinput:CreateGuideText("  "..IMPORT_HINT, ALIGN_LEFT)
        end
    end
    if gotoLocationWindow.submit ~= nil then
        gotoLocationWindow.submit:SetText(IMPORT_BUTTON)
        gotoLocationWindow.submit:Show(true)
    end
    gotoLocationWindow:Show(true)
end

-- Opens the goto window repurposed as a read-only sharecode export panel.
function gotoLocation.OpenExportSharecode(shareCode)
    if gotoLocationWindow == nil then
        helpers.DevLog("Goto window not initialized yet")
        return
    end
    if currentMode == "export" and gotoLocationWindow:IsVisible() then
        CLOSE_GOTO_WINDOW()
        return
    end
    currentMode = "export"
    importSubmitCallback = nil
    GOTO_TARGET_TEXT = shareCode or ""
    if gotoLocationWindow.textinput ~= nil then
        gotoLocationWindow.textinput:SetText(GOTO_TARGET_TEXT)
        if gotoLocationWindow.textinput.label ~= nil then
            gotoLocationWindow.textinput.label:SetText(EXPORT_LABEL)
        end
    end
    if gotoLocationWindow.submit ~= nil then
        gotoLocationWindow.submit:Show(false)
    end
    gotoLocationWindow:Show(true)
end

local function MainUIReady(MainUI)
	if MainUI == nil then
		helpers.DevLog("MainUIReady event triggered but MainUI is nil")
		return
	end
	local width = MainUI:GetWidth()
	local height = MainUI:GetHeight()
    gotoLocationWindow = CreateUI(MainUI, width, height)
	gotoLocationWindow.submit:SetHandler("OnClick", CLOSE_GOTO_WINDOW)
	gotoLocationWindow:SetHandler("OnClose", CLOSE_GOTO_WINDOW)
	gotoLocationWindow:SetHandler("OnCloseByEsc", CLOSE_GOTO_WINDOW)
end

local function OnModeChanged(mode)
	if currentMode == "goto" or mode == "demos" then
		return
	end
	gotoLocation.CloseIfOpen()
end

function gotoLocation.OnLoad()
	eventbus.WatchEvent(eventtopics.topics.UI.MainUILoaded, MainUIReady, "gotoLocation")
	eventbus.WatchEvent(eventtopics.topics.UI.toggleGoto, gotoLocation.ToggleUI, "gotoLocation")
	eventbus.WatchEvent(eventtopics.topics.UI.closeGoto, gotoLocation.CloseIfOpen, "gotoLocation")
	eventbus.WatchEvent(eventtopics.topics.UI.openImportSharecode, gotoLocation.OpenImportSharecode, "gotoLocation")
	eventbus.WatchEvent(eventtopics.topics.UI.openExportSharecode, gotoLocation.OpenExportSharecode, "gotoLocation")
	eventbus.WatchEvent(eventtopics.topics.render.modeChanged, OnModeChanged, "gotoLocation")
end

function gotoLocation.OnUnload()
	if gotoLocationWindow ~= nil then
		if gotoLocationWindow:IsVisible() then
			gotoLocationWindow:Show(false)
		end
		api.Interface:Free(gotoLocationWindow)
		gotoLocationWindow = nil
	end
end


return gotoLocation