-- Timers: player-made countdowns pinned to where they were created.
-- A single timer fires once and is then kept (greyed out) until deleted. A repeating
-- timer fires, then schedules its next run from the old due time so it never drifts.
local api = require("api")
local helpers = require("WorldSatNav/helpers")
local constants = require("WorldSatNav/core/constants")
local settingsModule = require("WorldSatNav/core/settings")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")
local coordinates = require("WorldSatNav/core/coordinates")
local regionmap = require("WorldSatNav/ui/regionmap")
local countdown = require("WorldSatNav/helpers/countdown")

local TOPICS = eventtopics.topics
local timers = {}

local TIMERS_FILE_PATH = "WorldSatNav/data/timers.dat"
local MODE = "timers"
local TRACK_TYPE = "Timer" -- maprendering maps this tracked type to the timers mode
local KIND_SINGLE = "single"
local KIND_REPEATING = "repeating"
local ICON_SIZE = 10 -- same as taming orbs
local LIST_PAGE_SIZE = 8
-- After an alert, wait this many checks (~1s each) before the next one, so timers
-- that come due together don't replace each other's alert before it can be read.
local ALERT_GAP_CHECKS = 8
-- An alert counts up "time since triggered" for up to 5 minutes (alert window limit);
-- anything older (e.g. fired while offline) shows as text instead.
local COUNT_UP_LIMIT_SECONDS = 4 * 60
-- List text color for finished single timers.
local DONE_TEXT_COLOR = { 0.45, 0.45, 0.45, 1 }

-- id -> { id, name, kind, every, sextant, color, deadline, firedAt }
--   every:    seconds between runs (repeating only)
--   deadline: countdown deadline for the next run
--   firedAt:  timestamp digit string once a single timer has fired (= done)
local timersData = {}
local nextTimerId = 1
local lastColor = nil
local alertHoldChecks = 0

local mainWindow = nil
local form = nil
local formVisible = false
local formRepeating = false
local newTimerButton = nil
local listTimersButton = nil
local listTable = nil
local listVisible = false

local function Info(message)
	api.Log:Info("WorldSatNav: " .. message)
end

local function Trim(text)
	return (tostring(text or ""):match("^%s*(.-)%s*$"))
end

local function IsDone(timer)
	return timer.firedAt ~= nil
end

-- ---------------------------------------------------------------------------
-- Storage
-- ---------------------------------------------------------------------------

local function ValidColor(color)
	color = tonumber(color)
	if color == nil or color < 0 or color >= constants.icons.orbCount then
		return 0
	end
	return math.floor(color)
end

-- Random orb, avoiding the color of the timer made just before it.
local function PickColor()
	local count = constants.icons.orbCount
	local color
	if math.random ~= nil then
		color = math.random(0, count - 1)
	else
		color = nextTimerId % count
	end
	if color == lastColor and count > 1 then
		color = (color + 1) % count
	end
	lastColor = color
	return color
end

local function SaveTimersFile()
	local rows = {}
	for _, timer in pairs(timersData) do
		local anchor, offset = countdown.SerializeDeadline(timer.deadline)
		if anchor ~= nil then
			table.insert(rows, {
				-- Numbers that can grow past 6 digits are text: api.File:Write uses %g.
				id = tostring(timer.id),
				name = timer.name,
				kind = timer.kind,
				every = timer.every and string.format("%d", timer.every) or nil,
				location = timer.sextant,
				color = tostring(timer.color),
				anchor = anchor,
				offset = offset,
				firedAt = timer.firedAt,
			})
		else
			helpers.DevLog("Timer " .. tostring(timer.id) .. " has no usable deadline, not saving it")
		end
	end
	table.sort(rows, function(left, right)
		return tonumber(left.id) < tonumber(right.id)
	end)
	api.File:Write(TIMERS_FILE_PATH, rows)
end

-- Replaces the in-memory timers with the ones saved in timers.dat.
function timers.LoadTimers()
	timersData = {}
	nextTimerId = 1
	local rows = api.File:Read(TIMERS_FILE_PATH)
	if type(rows) ~= "table" then
		helpers.DevLog("No timers file found")
		return
	end
	local loaded = 0
	for _, row in pairs(rows) do
		local id = tonumber(row.id)
		local sextant = coordinates.NormalizeSextant(row.location)
		local deadline = countdown.DeserializeDeadline(row.anchor, row.offset)
		local kind = row.kind == KIND_REPEATING and KIND_REPEATING or KIND_SINGLE
		local every = tonumber(row.every)
		local usable = id ~= nil and sextant ~= nil and deadline ~= nil
			and (kind == KIND_SINGLE or (every ~= nil and every > 0))
		if usable then
			timersData[id] = {
				id = id,
				name = tostring(row.name or "Timer"),
				kind = kind,
				every = kind == KIND_REPEATING and every or nil,
				sextant = sextant,
				color = ValidColor(row.color),
				deadline = deadline,
				firedAt = row.firedAt,
			}
			nextTimerId = math.max(nextTimerId, id + 1)
			loaded = loaded + 1
		else
			helpers.DevLog("Skipping unreadable timer row " .. tostring(row.id))
		end
	end
	helpers.DevLog("Loaded " .. loaded .. " timers")
end

function timers.CreateTimer(name, firstSeconds, everySeconds)
	local sextant = coordinates.NormalizeSextant(api.Map:GetPlayerSextants())
	if type(sextant) ~= "table" then
		Info("Unable to create timer because player coordinates are unavailable.")
		return false
	end
	local deadline = countdown.NewDeadline(firstSeconds)
	if deadline == nil then
		Info("Unable to create timer because the game clock is unavailable.")
		return false
	end
	local id = nextTimerId
	nextTimerId = id + 1
	timersData[id] = {
		id = id,
		name = name,
		kind = everySeconds and KIND_REPEATING or KIND_SINGLE,
		every = everySeconds,
		sextant = sextant,
		color = PickColor(),
		deadline = deadline,
		firedAt = nil,
	}
	SaveTimersFile()
	local message = string.format("Timer '%s' set, triggers in %s", name, helpers.FormatSecondsRemaining(firstSeconds))
	if everySeconds then
		message = message .. ", then every " .. countdown.FormatInterval(everySeconds)
	end
	Info(message)
	return true
end

function timers.RemoveTimer(id)
	if timersData[id] == nil then
		return false
	end
	timersData[id] = nil
	SaveTimersFile()
	return true
end

-- ---------------------------------------------------------------------------
-- Map icons
-- ---------------------------------------------------------------------------

local function TimerTexture(timer)
	if IsDone(timer) then
		return constants.icons.orbDone
	end
	return "icons/taming_" .. timer.color .. ".png"
end

local function ShowModeButtons(visible)
	if newTimerButton ~= nil then
		newTimerButton:Show(visible)
	end
	if listTimersButton ~= nil then
		listTimersButton:Show(visible)
	end
end

-- ---------------------------------------------------------------------------
-- New timer form
-- ---------------------------------------------------------------------------

local DURATION_UNITS = { "days", "hours", "mins" }

-- "Title" label over three small inputs: [  ] days [  ] hours [  ] mins
local function CreateDurationRow(prefix, parent, title, y, fontColor)
	local row = { widgets = {} }
	row.title = helpers.createLabel(prefix .. "Title", parent, title, 60, y, 14, false, fontColor)
	table.insert(row.widgets, row.title)
	local x = 60
	for _, unit in ipairs(DURATION_UNITS) do
		local input = helpers.createTextInput(prefix .. unit, parent, x, y + 22, 50, 29, "0", 3, nil, nil, false, fontColor)
		local unitLabel = helpers.createLabel(prefix .. unit .. "Label", parent, unit, x + 55, y + 27, 14, false, fontColor, 50)
		row[unit] = input
		table.insert(row.widgets, input)
		table.insert(row.widgets, unitLabel)
		x = x + 110
	end
	return row
end

local function ShowWidgets(widgets, visible)
	for _, widget in ipairs(widgets) do
		if widget ~= nil and widget.Show ~= nil then
			widget:Show(visible)
		end
	end
end

local function ClearDurationRow(row)
	for _, unit in ipairs(DURATION_UNITS) do
		row[unit]:SetText("")
	end
end

local function DurationRowSeconds(row)
	return countdown.DurationFromFields(row.days:GetText(), row.hours:GetText(), row.mins:GetText())
end

local function SetFormVisible(visible)
	if form == nil then
		return
	end
	formVisible = visible
	ShowWidgets(form.widgets, visible)
	helpers.ToggleCheckboxVisable("timerTypeSingle", visible)
	helpers.ToggleCheckboxVisable("timerTypeRepeating", visible)
	ShowWidgets(form.everyRow.widgets, visible and formRepeating)
end

local function SetRepeating(repeating)
	formRepeating = repeating
	if form ~= nil then
		ShowWidgets(form.everyRow.widgets, formVisible and repeating)
	end
end

local function CreateForm(window)
	local fontColor = FONT_COLOR.BLACK
	local scale = settingsModule.Get("uiDrawScale")
	form = { widgets = {} }
	local function add(widget)
		if widget ~= nil then
			table.insert(form.widgets, widget)
		end
		return widget
	end
	add(helpers.createLabel("timerFormTitle", window, "New timer", 60, 15, 18, false, fontColor))
	form.nameInput = add(helpers.createTextInput("timerNameInput", window, 60, 50, 306, 29, "Timer name", 40, "Name", nil, false, fontColor))
	add(form.nameInput.label)
	add(helpers.createLabel("timerTypeLabel", window, "Type", 60, 110, 14, false, fontColor))
	helpers.CreateSkinnedCheckbox("timerTypeSingle", window, "Single", 60, 135, true, function(checked)
		if checked == true then
			SetRepeating(false)
		end
	end, nil, nil, "TimerType", nil, true)
	helpers.CreateSkinnedCheckbox("timerTypeRepeating", window, "Repeating", 180, 135, false, function(checked)
		if checked == true then
			SetRepeating(true)
		end
	end, nil, nil, "TimerType", nil, true)

	local firstRow = CreateDurationRow("timerFirst", window, "Triggers in", 175, fontColor)
	for _, widget in ipairs(firstRow.widgets) do
		add(widget)
	end
	form.firstRow = firstRow
	form.everyRow = CreateDurationRow("timerEvery", window, "Every", 245, fontColor)

	add(helpers.createLabel("timerFormHint", window, "Pinned on the map at your current location.", 60, 315, 12, false, fontColor, 320))
	form.createButton = add(helpers.createButton("timerCreateButton", window, "Create", 60 * scale, 350 * scale))
	form.createButton:SetHandler("OnClick", function()
		timers.CreateClicked()
	end)
	form.cancelButton = add(helpers.createButton("timerCancelButton", window, "Cancel", 170 * scale, 350 * scale))
	form.cancelButton:SetHandler("OnClick", function()
		SetFormVisible(false)
		eventbus.TriggerEvent(TOPICS.UI.requestUIMode, MODE)
	end)
	SetFormVisible(false)
end

local HideList -- defined with the list below

function timers.ShowNewTimerForm()
	if form == nil then
		helpers.DevLog("Timer form not initialized yet")
		return
	end
	HideList()
	eventbus.TriggerEvent(TOPICS.UI.closeGoto)
	eventbus.TriggerEvent(TOPICS.UI.clearItems)
	eventbus.TriggerEvent(TOPICS.UI.EmptyUI)
	ShowModeButtons(false)
	form.nameInput:SetText("")
	ClearDurationRow(form.firstRow)
	ClearDurationRow(form.everyRow)
	helpers.SetCheckboxState("timerTypeSingle", true)
	helpers.SetCheckboxState("timerTypeRepeating", false)
	formRepeating = false
	SetFormVisible(true)
end

function timers.CreateClicked()
	if form == nil then
		return
	end
	local name = Trim(form.nameInput:GetText())
	if name == "" then
		Info("Timer needs a name.")
		return
	end
	local firstSeconds, firstError = DurationRowSeconds(form.firstRow)
	if firstSeconds == nil then
		Info("Timer 'Triggers in' " .. tostring(firstError) .. ".")
		return
	end
	local everySeconds = nil
	if formRepeating then
		local everyError
		everySeconds, everyError = DurationRowSeconds(form.everyRow)
		if everySeconds == nil then
			Info("Timer 'Every' " .. tostring(everyError) .. ".")
			return
		end
	end
	if not timers.CreateTimer(name, firstSeconds, everySeconds) then
		return
	end
	SetFormVisible(false)
	eventbus.TriggerEvent(TOPICS.UI.requestUIMode, MODE)
end

-- ---------------------------------------------------------------------------
-- List
-- ---------------------------------------------------------------------------

-- Active timers soonest first, then finished ones oldest first.
local function SortedTimers()
	local entries = {}
	for _, timer in pairs(timersData) do
		table.insert(entries, { timer = timer, left = countdown.SecondsLeft(timer.deadline) })
	end
	table.sort(entries, function(left, right)
		local leftDone, rightDone = IsDone(left.timer), IsDone(right.timer)
		if leftDone ~= rightDone then
			return rightDone
		end
		if not leftDone and left.left ~= nil and right.left ~= nil and left.left ~= right.left then
			return left.left < right.left
		end
		return left.timer.id < right.timer.id
	end)
	return entries
end

local function StatusText(timer, secondsLeft)
	local nowText = helpers.GetCurrentTimestampText()
	if IsDone(timer) then
		local firedText = helpers.FormatUserClockShortAt(timer.firedAt, 0)
		return firedText and ("Done\n" .. firedText) or "Done"
	end
	local text = helpers.FormatSecondsRemaining(secondsLeft)
	local at = secondsLeft and nowText and helpers.FormatUserClockShortAt(nowText, math.max(0, secondsLeft))
	if at ~= nil then
		text = text .. "\n" .. at
	end
	return text
end

local function TypeText(timer)
	if timer.kind == KIND_REPEATING then
		return "Every\n" .. countdown.FormatInterval(timer.every)
	end
	return "Single"
end

-- keepPage: stay on the current page (clamped) instead of jumping to the first.
function timers.RedrawList(keepPage)
	if listTable == nil then
		return
	end
	local rowData = {}
	local rowKeys = {}
	for _, entry in ipairs(SortedTimers()) do
		local textColor = IsDone(entry.timer) and DONE_TEXT_COLOR or nil
		table.insert(rowData, {
			"»",
			{ text = entry.timer.name, color = textColor },
			{ text = TypeText(entry.timer), color = textColor },
			{ text = StatusText(entry.timer, entry.left), color = textColor },
			"×",
		})
		table.insert(rowKeys, entry.timer.id)
	end
	local page = 0
	if keepPage then
		local lastPage = math.max(0, math.ceil(#rowData / LIST_PAGE_SIZE) - 1)
		page = math.min(listTable._PageNumber or 0, lastPage)
	end
	listTable.rowKeys = rowKeys
	listTable.SetPageControl(page, LIST_PAGE_SIZE)
	listTable.Update(rowData)
end

local function TimerForRow(row)
	if listTable == nil or type(listTable.rowKeys) ~= "table" then
		return nil
	end
	local id = listTable.rowKeys[tonumber(row) or 0]
	return id and timersData[id] or nil
end

local function ListGotoClicked(row)
	local timer = TimerForRow(row)
	if timer == nil then
		return
	end
	eventbus.TriggerEvent(TOPICS.UI.requestUIMode, MODE)
	eventbus.TriggerEvent(TOPICS.tracking.start, timer.sextant, TRACK_TYPE, true, timer.name)
end

local function ListRemoveClicked(row)
	local timer = TimerForRow(row)
	if timer == nil then
		return
	end
	timers.RemoveTimer(timer.id)
	Info("Timer '" .. timer.name .. "' deleted.")
	timers.RedrawList(true)
end

HideList = function()
	listVisible = false
	if listTable ~= nil then
		listTable.Show(false)
	end
	if listTimersButton ~= nil then
		listTimersButton:SetText("List timers")
	end
end

local function ShowList()
	SetFormVisible(false)
	eventbus.TriggerEvent(TOPICS.UI.closeGoto)
	eventbus.TriggerEvent(TOPICS.UI.clearItems)
	eventbus.TriggerEvent(TOPICS.UI.EmptyUI)
	if listTable == nil then
		listTable = helpers.CreateListTable(mainWindow, 30, 30, { "Goto", "Name", "Type", "Next in", "Del" })
		listTable.ConfigCol(1, true, ListGotoClicked)
		listTable.ConfigCol(5, true, ListRemoveClicked)
		listTable.setColSize(1, 60)
		listTable.setColSize(2, 170)
		listTable.setColSize(3, 105)
		listTable.setColSize(4, 160)
		listTable.setColSize(5, 60)
	end
	listVisible = true
	listTimersButton:SetText("Hide list")
	timers.RedrawList(false)
end

local function ListButtonClicked()
	if listVisible then
		HideList()
		eventbus.TriggerEvent(TOPICS.UI.requestUIMode, MODE)
	else
		ShowList()
	end
end

-- ---------------------------------------------------------------------------
-- Mode lifecycle
-- ---------------------------------------------------------------------------

function timers.HideAllTimerUI()
	SetFormVisible(false)
	HideList()
	ShowModeButtons(false)
end

function timers.RequestTimersForRender()
	timers.HideAllTimerUI()
	local showDone = settingsModule.Is("ShowDoneTimers", true)
	local icons = {}
	for _, timer in pairs(timersData) do
		if showDone or not IsDone(timer) then
			table.insert(icons, {
				sextant = timer.sextant,
				texture = TimerTexture(timer),
				sourceType = TRACK_TYPE,
				customIconSize = ICON_SIZE,
				label = timer.name,
			})
		end
	end
	ShowModeButtons(true)
	eventbus.TriggerEvent(TOPICS.icons.BulkDrawIconsAndRedraw, icons)
end

-- Something changed (a timer fired): refresh whatever timers view is showing, but never
-- tear down the form while the player is typing in it.
local function RefreshViews()
	if listVisible then
		timers.RedrawList(true)
		return
	end
	if formVisible then
		return
	end
	if mainWindow ~= nil and mainWindow:IsVisible() then
		eventbus.TriggerEvent(TOPICS.render.redrawMap, MODE)
	end
end

-- ---------------------------------------------------------------------------
-- Triggering
-- ---------------------------------------------------------------------------

local function FireTimer(timer, secondsLeft)
	local overdue = math.max(0, -secondsLeft)
	local typeText = "Single"
	local nextText = "Done"
	local nextLeft = nil
	local nextDeadline = nil
	if timer.kind == KIND_REPEATING then
		nextLeft = countdown.NextRepeatSecondsLeft(secondsLeft, timer.every)
		nextDeadline = nextLeft and countdown.NewDeadline(nextLeft)
	end
	if nextDeadline ~= nil then
		timer.deadline = nextDeadline
		typeText = "Every " .. countdown.FormatInterval(timer.every)
		nextText = helpers.FormatSecondsRemaining(nextLeft)
	else
		-- Single timer (or a repeating one that can't be rescheduled): done.
		timer.firedAt = helpers.GetCurrentTimestampText() or "unknown"
	end
	helpers.DevLog("Timer '" .. timer.name .. "' fired, overdue by " .. tostring(overdue) .. "s")

	local _, regionName = regionmap.GetRegionForSextant(timer.sextant)
	local alertData = {
		title = "Timer: " .. timer.name,
		lines = {
			{ label = "Region:", value = regionName or "Unknown" },
			{ label = "Type:", value = typeText },
			{ label = "Next:", value = nextText },
		},
		countdownLabel = "Triggered:",
		trackText = "Track",
		source = "timer",
		payload = {
			sextant = timer.sextant,
			trackType = TRACK_TYPE,
		},
	}
	if overdue <= COUNT_UP_LIMIT_SECONDS then
		alertData.countdownSeconds = overdue
		alertData.countUpTo5Minutes = true
	else
		alertData.countdownText = helpers.FormatSecondsRemaining(overdue) .. " ago"
	end
	eventbus.TriggerEvent(TOPICS.alert.show, alertData)
end

-- Fires the most overdue timer, at most one per ALERT_GAP_CHECKS checks.
local function CheckTimers()
	if alertHoldChecks > 0 then
		alertHoldChecks = alertHoldChecks - 1
		return
	end
	local dueTimer, dueLeft = nil, nil
	for _, timer in pairs(timersData) do
		if not IsDone(timer) then
			local left = countdown.SecondsLeft(timer.deadline)
			if left ~= nil and left <= 0 and (dueLeft == nil or left < dueLeft) then
				dueTimer, dueLeft = timer, left
			end
		end
	end
	if dueTimer == nil then
		return
	end
	FireTimer(dueTimer, dueLeft)
	SaveTimersFile()
	alertHoldChecks = ALERT_GAP_CHECKS
	RefreshViews()
end

local throttledCheck = helpers.throttle(constants.timing.timerPoll, CheckTimers)
-- Keeps the list's "Next in" column current while it is open.
local throttledListRefresh = helpers.throttle(constants.timing.timerPoll * 10, function()
	if listVisible then
		timers.RedrawList(true)
	end
end)

function timers.onUpdate(dt)
	throttledCheck(dt)
	throttledListRefresh(dt)
end

-- ---------------------------------------------------------------------------
-- Load / unload
-- ---------------------------------------------------------------------------

function timers.MainUIReady(window)
	mainWindow = window
	timers.LoadTimers()
	CreateForm(window)

	newTimerButton = helpers.createButton("TimerNewButton", window, "New timer", 10, window:GetHeight() - 35)
	newTimerButton:RemoveAllAnchors()
	newTimerButton:AddAnchor("BOTTOMLEFT", window, 10, -10)
	newTimerButton:SetHandler("OnClick", timers.ShowNewTimerForm)

	listTimersButton = helpers.createButton("TimerListButton", window, "List timers", window:GetWidth() - 85, window:GetHeight() - 35)
	listTimersButton:RemoveAllAnchors()
	listTimersButton:AddAnchor("BOTTOMRIGHT", window, -10, -10)
	listTimersButton:SetHandler("OnClick", ListButtonClicked)

	ShowModeButtons(false)
end

function timers.OnLoad()
	eventbus.WatchEvent(TOPICS.UI.MainUILoaded, timers.MainUIReady, "timers")
	eventbus.WatchEvent(TOPICS.render.modeChanged, timers.HideAllTimerUI, "timers")
	eventbus.WatchEvent(TOPICS.render.config, timers.HideAllTimerUI, "timers")
	eventbus.WatchEvent(TOPICS.UI.close, timers.HideAllTimerUI, "timers")
	eventbus.WatchEvent(TOPICS.UI.open, timers.HideAllTimerUI, "timers")
	eventbus.WatchEvent(TOPICS.render.timers, timers.RequestTimersForRender, "timers")
end

function timers.OnUnload()
	timers.HideAllTimerUI()
	timersData = {}
	form = nil
	listTable = nil
	newTimerButton = nil
	listTimersButton = nil
	mainWindow = nil
end

return timers
