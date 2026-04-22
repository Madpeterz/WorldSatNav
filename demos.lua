
local api = require("api")
local helpers = require("WorldSatNav/helpers")
local constants = require("WorldSatNav/constants")
local settingsModule = require("WorldSatNav/settings")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")
local regionmap = require("WorldSatNav/regionmap")

local demos = {}
local demosData = {}
local demosFilePath = "WorldSatNav/data/demos.dat"

local demoAddButton = nil
local demoWindow = nil
local demoControlsListMenubutton = nil
local TableListControlForDemos = nil

local function normalizeTimestamp(value)
    local numericValue = tonumber(value)
    if numericValue == nil then
        return nil
    end
    return math.floor(numericValue)
end

local function serializeTimestamp(value)
    local normalizedValue = normalizeTimestamp(value)
    if normalizedValue == nil then
        return nil
    end
    return string.format("%.0f", normalizedValue)
end

function demos.ShowDemoWindow()
	eventbus.TriggerEvent(eventtopics.topics.UI.forcedUIMode, "demos")
end

local function setDemoWindowUIStatue(status)
	if demoWindow == nil then
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	if demoWindow.demo == nil then
		helpers.DevLog("Demo window controls not initialized yet")
		return
	end

	local elements = {}
	local function addElement(element)
		if element ~= nil then
			table.insert(elements, element)
		else
			helpers.DevLog("Attempted to add nil element to demo window UI elements list, skipping")
		end
	end

	addElement(demoWindow.demo.regionnameInput)
	addElement(demoWindow.demo.regionnameInput and demoWindow.demo.regionnameInput.label)
	addElement(demoWindow.demo.ownernameInput)
	addElement(demoWindow.demo.ownernameInput and demoWindow.demo.ownernameInput.label)
	addElement(demoWindow.demo.buildingnameInput)
	addElement(demoWindow.demo.buildingnameInput and demoWindow.demo.buildingnameInput.label)
	addElement(demoWindow.demo.dateinput)
	addElement(demoWindow.demo.dateinput and demoWindow.demo.dateinput.label)
	addElement(demoWindow.demo.timeinput)
	addElement(demoWindow.demo.timeinput and demoWindow.demo.timeinput.label)
	addElement(demoWindow.demo.CreateButton)
	addElement(demoWindow.demo.AutoButton)

	for _, element in ipairs(elements) do
		if element.Show ~= nil then
			element:Show(status)
		end
	end
end

function demos.DemosWindowDisplay(mode)
	if mode ~= "demos" then
		helpers.DevLog("Not showing demo window add, current mode is: " .. tostring(mode))
		return
	end
	if demoWindow == nil then
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	if demoWindow.demo == nil then
		helpers.DevLog("Demo window controls not initialized yet")
		return
	end
	eventbus.TriggerEvent(eventtopics.topics.UI.EmptyUI)
	helpers.DevLog("Setting up demo add window for display")
	demoWindow.demo.regionnameInput.text = ""
	demoWindow.demo.ownernameInput.text = ""
	if demoWindow.demo.buildingnameInput ~= nil then
		helpers.SelectComboBoxByText(demoWindow.demo.buildingnameInput, "Unknown")
	end
	demoWindow.demo.dateinput.text = helpers.getTodayDateText()
	demoWindow.demo.timeinput.text = "HH:MM"
	helpers.DevLog("Showing demo add window UI elements")
	-- update main UI from w/e mode its in to demos add mode
	setDemoWindowUIStatue(true)
	helpers.DevLog("Finished setting up demo add window for display")
end

function demos.HideAllDemoUI()
	if demoWindow == nil then
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	if demoControlsListMenubutton ~= nil and demoControlsListMenubutton:IsVisible() then
		demoControlsListMenubutton:Show(false)
		demoControlsListMenubutton:SetText("List demos")
	end
	if TableListControlForDemos ~= nil then
		TableListControlForDemos.Show(false)
		
	end
	helpers.DevLog("Hiding all demo UI elements")
	setDemoWindowUIStatue(false)
end

local function SaveDemosFile()
	local demosToSave = {}
	local demoCount = 0
	for _, demo in pairs(demosData) do
		local entry = {
			location = demo.sextent,
			ownername = demo.ownername,
			buildingname = demo.buildingname,
			startat = serializeTimestamp(demo.startat),
			regionname = demo.regionname,
		}
		table.insert(demosToSave, entry)
		demoCount = demoCount + 1
	end
	if #demosToSave < demoCount then
		helpers.DevLog("Warning: Number of demos to save does not match number of demos in memory. This should not happen. Not saving to file to prevent potential data loss.")
		return false
	end
	api.File:Write(demosFilePath, demosToSave)
	return true
end

local function createDemoWindowControls(OnAutoButtonClickCallback, OnCreateButtonClickCallback)
	if demoWindow == nil then
		helpers.DevLog("error mapUI has not been created, and I use that for demo windows")
		return nil
	end
	demoWindow.demo = {}
	-- create button
	local createButton = helpers.createButton("CreateDemoButton", demoWindow, "Create", 50*settingsModule.Get("uiDrawScale"), 400*settingsModule.Get("uiDrawScale"))
	createButton:SetHandler("OnClick", OnCreateButtonClickCallback)
	demoWindow.demo.CreateButton = createButton
	-- auto button
	local autoButton = helpers.createButton("AutoDemoButton", demoWindow, "Auto fill", 350*settingsModule.Get("uiDrawScale"), 400*settingsModule.Get("uiDrawScale"))
	autoButton:SetHandler("OnClick", OnAutoButtonClickCallback)
	demoWindow.demo.AutoButton = autoButton
	-- inputs
	local selectedfontcolor = FONT_COLOR.BLACK
	demoWindow.demo.regionnameInput = helpers.createTextInput("regionnameInput", demoWindow, 60, 30, 306, 29, "Region name for demo", 100, "Region", function(text)
		demoWindow.demo.regionnameInput.text = text
	end,false,selectedfontcolor)
	demoWindow.demo.ownernameInput = helpers.createTextInput("ownernameInput", demoWindow, 60, 90, 306, 29, "Owner name for demo", 100, "Owner", function(text)
		demoWindow.demo.ownernameInput.text = text
	end,false,selectedfontcolor)
	demoWindow.demo.buildingnameInput = helpers.CreateComboBox(demoWindow, helpers.GetBuildingNames(), 60, 150,300, 29, false, selectedfontcolor, "Unknown","Building", "buildingnameInput")
	local todaysdate = helpers.getTodayDateText()
	demoWindow.demo.dateinput = helpers.createTextInput("dateinput", demoWindow, 60, 210, 299, 29, todaysdate, 100, "Date", function(text)
		demoWindow.demo.dateinput.text = text
	end,false,selectedfontcolor)
	demoWindow.demo.timeinput = helpers.createTextInput("timeinput", demoWindow, 60, 275, 299, 29, "HH:MM", 100, "Time", function(text)
		demoWindow.demo.timeinput.text = text
	end,false,selectedfontcolor)


end
local function CreateDemoAddUI(onClickCallback)
	local overlayWnd = api.Interface:CreateEmptyWindow("overlayDemoPlus", "UIParent")
	overlayWnd:SetExtent(35*settingsModule.Get("uiDrawScale"), 40*settingsModule.Get("uiDrawScale"))
	overlayWnd:AddAnchor("TOPLEFT", "UIParent", settingsModule.Get("OpenDemoAddButtonX"), settingsModule.Get("OpenDemoAddButtonY"))
	overlayWnd.bg = overlayWnd:CreateImageDrawable("bg", "background")
	overlayWnd.bg:SetTexture(constants.folderPath.."images/ui/demo_add.png")
	overlayWnd.bg:AddAnchor("TOPLEFT", overlayWnd, "TOPLEFT", 0, 0)
	overlayWnd.bg:SetExtent(35*settingsModule.Get("uiDrawScale"), 40*settingsModule.Get("uiDrawScale"))
	overlayWnd.bg:Show(true)
	overlayWnd:Show(settingsModule.Get("showDemoCreatePlus"))
	overlayWnd:Lower()

	-- Drag events for overlay button
	-- Click handler
	local clickBtn = overlayWnd:CreateChildWidget("button", "clickBtn", 0, true)
	clickBtn:AddAnchor("TOPLEFT", overlayWnd, "TOPLEFT", 0, 0)
	clickBtn:AddAnchor("BOTTOMRIGHT", overlayWnd, "BOTTOMRIGHT", 0, 0)
	clickBtn:Show(true)
	clickBtn:Enable(true)
	clickBtn:SetSounds("store_drain")
	clickBtn.parent = overlayWnd

	helpers.makeWindowDraggable(clickBtn, nil, nil, true, true, "OpenDemoAddButtonX" , "OpenDemoAddButtonY", false, true)

	function clickBtn:HoverStart()
		local mouseX, mouseY = overlayWnd:GetEffectiveOffset()
		api.Interface:SetTooltipOnPos("Show demo add", overlayWnd, mouseX + overlayWnd:GetWidth(), mouseY + (overlayWnd:GetHeight()*2))
		overlayWnd.bg:SetTexture(constants.folderPath.."images/ui/demo_add_hover.png")
	end

	function clickBtn:HoverEnd()
		api.Interface:SetTooltipOnPos("", overlayWnd, 0, 0)
		overlayWnd.bg:SetTexture(constants.folderPath.."images/ui/demo_add.png")
	end
	clickBtn:SetHandler("OnEnter", clickBtn.HoverStart)
	clickBtn:SetHandler("OnLeave", clickBtn.HoverEnd)

	function clickBtn:OnClick()
		if onClickCallback then
			onClickCallback()
		end
	end
	
	clickBtn:SetHandler("OnClick", clickBtn.OnClick)

	return overlayWnd
end

local function DEMO_EXPIRE()
	local currentTime = tonumber(helpers.GetCurrentTimestamp())
	if currentTime == nil then
		helpers.DevLog("Skipping demo expiry: current time is not numeric")
		return
	end
	currentTime = currentTime + (60 * 30)
	local expiredDemos = {}
	for sextantKey, demo in pairs(demosData) do
		local expireTime = tonumber(demo.expiretime)
		if expireTime ~= nil and expireTime < currentTime then
			table.insert(expiredDemos, sextantKey)
		end
	end
	if #expiredDemos == 0 then
		return
	end
	helpers.DevLog("Expiring " .. #expiredDemos .. " demos")
	for _, sextantKey in pairs(expiredDemos) do
		demosData[sextantKey] = nil
	end
	SaveDemosFile()
end

local function DEMO_TRIGGER_ALERT()
	local currentTime = tonumber(helpers.GetCurrentTimestamp())
	if currentTime == nil then
		helpers.DevLog("Skipping demo alert trigger: current time is not numeric")
		return
	end
	local selectedKey = nil
	local fiveMinsTime = currentTime + 300
	for sextantKey, demo in pairs(demosData) do
		if demo.alertTriggered == false and demo.startat ~= nil and demo.startat <= fiveMinsTime then
			selectedKey = sextantKey
			break
		end
	end
	if selectedKey == nil then
		return
	end
	helpers.DevLog("Triggering alert for demo at sextant: " .. tostring(demosData[selectedKey].sextent) .. " starting at: " .. tostring(demosData[selectedKey].startat))
	demosData[selectedKey].alertTriggered = true
	local alertData = {
		title = "Demo Alert!",
		lines = {
			{ label = "Region:", value = demosData[selectedKey].regionname or "Unknown" },
			{ label = "Owner:", value = demosData[selectedKey].ownername or "Unknown" },
			{ label = "Building:", value = demosData[selectedKey].buildingname or "Unknown" },
		},
		countdownLabel = "Time to start:",
		countdownSeconds = demosData[selectedKey].startat - currentTime,
		countdownEndText = "Starting soon!",
		trackText = "Track",
		source = "demo",
		countUpTo5Minutes = false,
		payload = {
			sextant = demosData[selectedKey].sextent,
		},
	}
	eventbus.TriggerEvent(eventtopics.topics.alert.show, alertData)

end

local function loadDemosData()
	local demosDataFromFile = api.File:Read(demosFilePath)
	if demosDataFromFile == nil then
		helpers.DevLog("No demos data file found")
		return
	end
	local newDemoscount = 0
	for _, demo in pairs(demosDataFromFile) do
		local sextentKey = helpers.SextantKey(demo.location)
		local startAt = tonumber(demo.startat)
		local isNew = demosData[sextentKey] == nil
		demosData[sextentKey] = {
			sextent = demo.location,
			ownername = demo.ownername,
			buildingname = demo.buildingname,
			regionname = demo.regionname,
			startat = startAt,
			expiretime = startAt and (startAt + constants.timing.demoExpireTime + 30) or nil,
			alertTriggered = false,
		}
		if isNew then
			newDemoscount = newDemoscount + 1
		end
	end
	helpers.DevLog("Loaded " .. newDemoscount .. " demos from file new total count: " .. #demosData)
	DEMO_EXPIRE()
end

function demos.RequestDemosForRender()
	demos.HideAllDemoUI()
	loadDemosData()
	helpers.DevLog("Rendering " .. #demosData .. " demos on map")
	local bulkRenderData = {}
	for _, entry in pairs(demosData) do
		local skipThis = false
		if settingsModule.Get("DrawDemosInNextHour") == true then
			local currentTime = tonumber(helpers.GetCurrentTimestamp())
			if type(currentTime) ~= "number" then
				helpers.DevLog("Current time is not numeric, skipping demo alert time check for this entry and rendering it")
			elseif entry.startat == nil then
				helpers.DevLog("Demo entry start time is nil, skipping demo alert time check for this entry and rendering it")
			elseif entry.startat > (currentTime + 3600) then
				skipThis = true
			end
		end
		if skipThis == false then
			local thisEntry = {
				sextant = entry.sextent,
				texture = "icons/demo.png",
				sourceType = "Demo",
				customIconSize = 15,
			}
			table.insert(bulkRenderData, thisEntry)
		end
	end
	if demoControlsListMenubutton ~= nil then
		demoControlsListMenubutton:Show(true)
	end
	eventbus.TriggerEvent(eventtopics.topics.icons.BulkDrawIconsAndRedraw, bulkRenderData)
end

local function DEMO_AUTOHIDE_PLUS()
	if demoAddButton == nil then 
		helpers.DevLog("Demo add button not initialized yet")
		return
	end
	if demoWindow == nil then 
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	if settingsModule.Get("showDemoCreatePlus") == false then
		if demoAddButton:IsVisible() then
			demoAddButton:Show(false)
		end
		return
	end
	local unitid = api.Unit:GetUnitId("target")
	if unitid == nil then
		if demoAddButton:IsVisible() then
			demoAddButton:Show(false)
		end
		return
	end
	local targetdetails = api.Unit:GetUnitInfoById(unitid)
	if targetdetails.type ~= "housing" then
		if demoAddButton:IsVisible() then
			demoAddButton:Show(false)
		end
		return
	end
	local targetdetails = api.Unit:GetUnitInfoById(unitid)
	if targetdetails.type ~= "housing" then
		if demoAddButton:IsVisible() then
			demoAddButton:Show(false)
		end
		return
	end
	if not demoAddButton:IsVisible() then
		demoAddButton:Show(true)
	end
end

local lastUpdate = 0
local lastUpdateLongRunning = 0
function demos.onUpdate(dt)
	lastUpdate = lastUpdate + dt
	lastUpdateLongRunning = lastUpdateLongRunning + dt
	if lastUpdate < (constants.timing.updateRate*2) then
		return
	end
    lastUpdate = 0
	DEMO_AUTOHIDE_PLUS()
	if lastUpdateLongRunning < (constants.timing.updateRate*30) then
		return
	end
	lastUpdateLongRunning = 0
	DEMO_EXPIRE()
	DEMO_TRIGGER_ALERT()
end

function demos.AutoFillClicked()
	if demoWindow == nil then 
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	local unitid = api.Unit:GetUnitId("target")
	if unitid == nil then
		helpers.DevLog("DEMO_WINDOW_AUTO: No target selected")
		return
	end
	local targetpos = api.Map:GetPlayerSextants()
	if targetpos == nil then
		helpers.DevLog("DEMO_WINDOW_AUTO: Could not get player position")
		return
	end
	local targetdetails = api.Unit:GetUnitInfoById(unitid)
	if targetdetails.type ~= "housing" then
		helpers.DevLog("DEMO_WINDOW_AUTO: Target is not a housing unit")
		return
	end
	
	local ownername = targetdetails.owner_name or "Unknown"
	local buildingname = targetdetails.name or "Unknown"
	local _, regionname = regionmap.GetRegionForSextant(targetpos)
	regionname = regionname or "Unknown"
	demoWindow.demo.regionnameInput:SetText(regionname)
	demoWindow.demo.ownernameInput:SetText(ownername)
	helpers.SelectComboBoxByText(demoWindow.demo.buildingnameInput, buildingname, "Unknown")
	api.Log:Info(string.format("Auto-filled demo info - Region: %s, Owner: %s, Building: %s", regionname, ownername, buildingname))
end

function demos.CreateDemo(regionname, ownername, buildingname, dateText, timeText, timestamp)
    local playerSextants = api.Map:GetPlayerSextants()
    if type(playerSextants) ~= "table" then
        api.Log:Info("WorldSatNav: Unable to create demo because player coordinates are unavailable.")
        return false
    end

    local demoTimestamp = timestamp
    if demoTimestamp == nil then
        demoTimestamp = helpers.ParseDateTimeToUnixtime(dateText, timeText)
    end
    demoTimestamp = normalizeTimestamp(demoTimestamp)
    if type(demoTimestamp) ~= "number" then
        api.Log:Info("WorldSatNav: Unable to create demo because the date/time could not be converted.")
        return false
    end
	local newDemo = {
		sextent = playerSextants,
		ownername = ownername,
		buildingname = buildingname,
		startat = demoTimestamp,
		regionname = regionname,
		expiretime = demoTimestamp and (demoTimestamp + constants.timing.demoExpireTime + 30) or nil,
		alertTriggered = false,
    }
	local sextantKey = helpers.SextantKey(playerSextants)
	demosData[sextantKey] = newDemo
	if SaveDemosFile() == false then
		api.Log:Info("WorldSatNav: Failed to save demo data to file after creating a new demo.")
		return false
	end
    helpers.DevLog(string.format("Created demo '%s' for '%s' in region '%s' at %d", tostring(buildingname), tostring(ownername), tostring(regionname), demoTimestamp))
    return true
end

function demos.CreateDemoClicked()
	if demoWindow == nil then 
		helpers.DevLog("Demo window not initialized yet")
		return
	end
	helpers.DevLog("Creating demo with input data")
	local regionname = demoWindow.demo.regionnameInput:GetText() or "Unknown"
	local ownername = demoWindow.demo.ownernameInput:GetText() or "Unknown"
	local buildingname = helpers.getComboBoxValue(demoWindow.demo.buildingnameInput, "Unknown")
	local date = demoWindow.demo.dateinput:GetText() or "Unknown"
	local time = demoWindow.demo.timeinput:GetText() or "Unknown"
	if buildingname == "Unknown" then
		api.Log:Info("WorldSatNav: Invalid building input for demo creation")
		return
	end
	if ownername == "Unknown" then
		api.Log:Info("WorldSatNav: Invalid owner input for demo creation")
		return
	end
	if regionname == "Unknown" then
		api.Log:Info("WorldSatNav: Invalid region input for demo creation")
		return
	end
	if date == "Unknown" then
		api.Log:Info("WorldSatNav: Invalid date input for demo creation")
		return
	end
	if time == "Unknown" then
		api.Log:Info("WorldSatNav: Invalid time input for demo creation")
		return
	end
	local timestamp, parseError = helpers.ParseDateTimeToUnixtime(date, time)
	if timestamp == nil then
		api.Log:Info("WorldSatNav: " .. tostring(parseError))
		return
	end
	local timeleft = timestamp - helpers.GetCurrentTimestamp()
	local hours, mins, secs = helpers.SecondsToTime(timeleft)
	api.Log:Info(string.format("WorldSatNav: Creating demo - Region: %s, Owner: %s, Building: %s, Date: %s, Time: %s, Time left: %02d:%02d:%02d", regionname, ownername, buildingname, date, time, hours, mins, secs))
	if not demos.CreateDemo(regionname, ownername, buildingname, date, time, timestamp) then
		api.Log:Info("WorldSatNav: Failed to create demo entry.")
		return
	end
	eventbus.TriggerEvent(eventtopics.topics.UI.requestUIMode, "demos")
end

local function handleAlertTrack(alertData)
	if type(alertData) ~= "table" then
		return
	end
	if alertData.source ~= "demo" then
		return
	end
	local payload = alertData.payload
	local targetSextant = payload and payload.sextant or nil
	if targetSextant == nil then
		helpers.DevLog("No sextant payload provided for demo alert tracking")
		return
	end
	eventbus.TriggerEvent(eventtopics.topics.tracking.start, targetSextant, "Demo", true)
end

local function getDemoByRow(row)
	if TableListControlForDemos == nil then
		helpers.DevLog("TableListControlForDemos is nil, cannot get demo by row")
		return nil
	end
	local index = tonumber(row)
	if index == nil then
		return nil
	end
	local rowKeys = TableListControlForDemos.rowKeys
	if type(rowKeys) == "table" then
		local demoKey = rowKeys[index]
		if demoKey ~= nil then
			return demosData[demoKey]
		end
		return nil
	end
	local currentIndex = 0
	for _, demo in pairs(demosData) do
		currentIndex = currentIndex + 1
		if currentIndex == index then
			return demo
		end
	end
	return nil
end

function demos.ListMenuGotoClicked(row,col)
	helpers.DevLog("Goto clicked for row: " .. tostring(row) .. " col: " .. tostring(col))
	if TableListControlForDemos == nil then
		helpers.DevLog("TableListControlForDemos is nil, cannot hide demo list UI")
		return
	end
	local demo = getDemoByRow(row)
	if demo == nil then
		helpers.DevLog("Could not find demo for row: " .. tostring(row))
		return
	end
	eventbus.TriggerEvent(eventtopics.topics.UI.requestUIMode, "demos")
	eventbus.TriggerEvent(eventtopics.topics.tracking.start, demo.sextent, "Demo", true)
	helpers.DevLog("Started tracking demo at sextant: " .. tostring(demo.sextent))
end

function demos.ListMenuRemoveClicked(row,col)
	helpers.DevLog("Remove clicked for row: " .. tostring(row) .. " col: " .. tostring(col))
	if TableListControlForDemos == nil then
		helpers.DevLog("TableListControlForDemos is nil, cannot hide demo list UI")
		return
	end
	local demo = getDemoByRow(row)
	if demo == nil then
		helpers.DevLog("Could not find demo for row: " .. tostring(row))
		return
	end
	TableListControlForDemos.Show(false)
	demosData[helpers.SextantKey(demo.sextent)] = nil
	SaveDemosFile()
	helpers.DevLog("Removed demo at sextant: " .. tostring(demo.sextent))
	demos.RedrawDemosList()
end

function demos.RedrawDemosList()
	if TableListControlForDemos == nil then
		helpers.DevLog("TableListControlForDemos is nil, cannot redraw demo list UI")
		return
	end
	local rowData = {}
	local rowKeys = {}
	for sextantKey, demosDataEntry in pairs(demosData) do
		local thisRow = {
			"->",
			string.format("%s\n in %s", demosDataEntry.buildingname or "Unknown",demosDataEntry.regionname or "Unknown"),
			demosDataEntry.startat and helpers.TimeRemaining(demosDataEntry.startat, true) or "Unknown",
			"[X]",
		}
		table.insert(rowData, thisRow)
		table.insert(rowKeys, sextantKey)
	end
	TableListControlForDemos.rowKeys = rowKeys
	TableListControlForDemos.SetPageControl(0,8)
	TableListControlForDemos.Update(rowData)
	helpers.DevLog("WorldSatNav: Demo list UI SetData attempted")
end

function demos.MainUIReady(MainUIWindow)
	demoWindow = MainUIWindow
	helpers.DevLog("Demos module loaded")
	loadDemosData()
    demoAddButton = CreateDemoAddUI(demos.ShowDemoWindow)
	createDemoWindowControls(demos.AutoFillClicked, demos.CreateDemoClicked)
	demoControlsListMenubutton = helpers.createButton("DemoControlListShow",MainUIWindow,"List demos", MainUIWindow:GetWidth() - 85, MainUIWindow:GetHeight() - 35)
	demoControlsListMenubutton:Show(false)
	demoControlsListMenubutton:SetHandler("OnClick", function(button)
		button = button or demoControlsListMenubutton
		if button:GetText() == "List demos" then
			button:SetText("Hide list")
			eventbus.TriggerEvent(eventtopics.topics.UI.clearItems)
			eventbus.TriggerEvent(eventtopics.topics.UI.EmptyUI)
			helpers.DevLog("WorldSatNav: Demo list click handler running")
			if TableListControlForDemos == nil then
				TableListControlForDemos = helpers.CreateListTable(MainUIWindow, 30, 30, {"Goto", "Info", "Status", "Remove"})
				TableListControlForDemos.ConfigCol(1, true, demos.ListMenuGotoClicked) -- set goto as a button
				TableListControlForDemos.ConfigCol(4, true, demos.ListMenuRemoveClicked) -- set remove as a button
				TableListControlForDemos.setColSize(1, 75)
				TableListControlForDemos.setColSize(2, 225)
				TableListControlForDemos.setColSize(3, 150)
				TableListControlForDemos.setColSize(4, 100)
			end
			demos.RedrawDemosList()
		else
			button:SetText("List demos")
			if TableListControlForDemos ~= nil then
				TableListControlForDemos.Show(false)
			end
			eventbus.TriggerEvent(eventtopics.topics.UI.requestUIMode, "demos")
		end
	end)
end

function demos.OnLoad()
	eventbus.WatchEvent(eventtopics.topics.UI.MainUILoaded, demos.MainUIReady, "demos")
	eventbus.WatchEvent(eventtopics.topics.render.modeChanged, demos.HideAllDemoUI, "demos")
	eventbus.WatchEvent(eventtopics.topics.UI.close, demos.HideAllDemoUI, "demos")
	eventbus.WatchEvent(eventtopics.topics.UI.open, demos.HideAllDemoUI, "demos")
	eventbus.WatchEvent(eventtopics.topics.render.demos, demos.RequestDemosForRender, "demos")
	eventbus.WatchEvent(eventtopics.topics.render.config, demos.HideAllDemoUI, "demos")
	eventbus.WatchEvent(eventtopics.topics.UI.forcedUIModeReady, demos.DemosWindowDisplay, "demos")
	eventbus.WatchEvent(eventtopics.topics.alert.track, handleAlertTrack, "demos")
end

function demos.OnUnload()
	if demoAddButton ~= nil then
		if demoAddButton:IsVisible() then
			demoAddButton:Show(false)
		end
		api.Interface:Free(demoAddButton)
		demoAddButton = nil
	end
end

return demos;