---@diagnostic disable: undefined-global
local api = require("api")
local constants = require("WorldSatNav/constants")
local settings = require("WorldSatNav/settings")

local helpers = {}

local CheckBoxs = {}
helpers.CheckBoxs = CheckBoxs

function helpers.DevLog(message)
    if constants.DEV_MODE then
        api.Log:Info(message)
    end
end

helpers.BuildingNames = {
    "Unknown",
    -- 8x8
    "Solar Scarecrow Garden",
    "Lunar Scarecrow Garden",
    "Stellar Scarecrow Garden",
    "Scarecrow Garden",
    "Haranyan Private Smelter",
    "Haranyan Private Sawmill",
    "Haranyan Private Masonry Table",
    "Private Smelter",
    "Private Sawmill",
    "Private Masonry Table",
    -- 16x16
    "Gazebo Farm",
    "Solar Scarecrow Farm",
    "Lunar Scarecrow Farm",
    "Stellar Scarecrow Farm",
    "Scarecrow Farm",
    "Rustic Slate Cottage",
    "Raised Swept-Roof Cottage",
    "Improved Scarecrow Farm",
    -- 24x24 and larger
    "Improved Stellar Pavilion Farm",
    "Improved Solar Pavilion Farm",
    "Improved Lunar Pavilion Farm",
    "Improved Solar Pavilion Farm Kit",
    "Improved Lunar Pavilion Farm Kit",
    "Improved Stellar Pavilion Farm Kit",
    "Miner's Farmhouse",
    "Recovering Cherry Treehouse",
    "Desserted House",
    "Beanstalk House",
    "Rose Quartz Solarium",
    "Rancher's Farmhouse",
    "Harvester's Farmhouse",
    "Advanced Fellowship Plaza",
    "Spired Chateau",
    "Apothecary's Chalet (Terrace)",
    "Tradesman's Manor",
    "Armorer's Townhouse",
    "Thatched Farmhouse",
    "Gazebo Farm",
}

function helpers.GetBuildingNames()
    return helpers.BuildingNames
end


function helpers.CreateSkinnedCheckbox(id, parent, text, offsetX, offsetY, checked, onClickFunction, buttonSizeX, buttonSizeY, radioGroup, renderlayer, showText)
    buttonSizeX = buttonSizeX or 25
    buttonSizeY = buttonSizeY or 25
    renderlayer = renderlayer or "artwork"
    if showText == nil then showText = true end
    -- Create image drawable on parent to show the checkbox
    local overlay = parent:CreateImageDrawable(id.."CheckBoxOverlay", renderlayer)
	overlay:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
    local raidoAddon = ""
    local isRadio = false
    if radioGroup ~= nil then
        raidoAddon = "radio_"
        isRadio = true
    end
	overlay:SetExtent(25, 25)
    if checked then
        overlay:SetTexture(api.baseDir .. "/WorldSatNav/images/" .. raidoAddon .. "checked.png")
    else
        overlay:SetTexture(api.baseDir .. "/WorldSatNav/images/" .. raidoAddon .. "unchecked.png")
    end
    overlay:Show(true)
    
    -- Create invisible button on top for click handling
    local button = parent:CreateChildWidget("button", id.."CheckBoxButton", 0, true)
	button:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
	button:SetExtent(buttonSizeX, buttonSizeY)
    button:Show(true)
    button:Enable(true)
    button:Raise()
    
    local mylabel = nil
    if showText == true then
        mylabel = api.Interface:CreateWidget("label", id.."CheckBoxlabel", parent)
        mylabel:SetExtent(200, 30)
        mylabel:AddAnchor("TOPLEFT", parent, offsetX+30, offsetY)
        mylabel:SetText(text)
        mylabel.style:SetAlign(ALIGN.LEFT)
        mylabel.style:SetFontSize(14)
        mylabel.style:SetColor(0, 0, 0, 1)
        mylabel:Raise()
        mylabel:Show(true)
    end
    
    if onClickFunction ~= nil then
        function button:OnClick()
            local currentChecked = CheckBoxs[id] and CheckBoxs[id].checked or false
            local newChecked = not currentChecked
            local raidoAddon = ""
            if CheckBoxs[id].isRadio then
                if currentChecked == true then
                    helpers.DevLog("WorldSatNav: Radio button '"..id.."' is already checked, ignoring click.")
                    return -- if it's a radio button and already checked, do nothing on click
                end
            end
            if CheckBoxs[id].isRadio then
                raidoAddon = "radio_"
            end
            if newChecked then
                overlay:SetTexture(api.baseDir .. "/WorldSatNav/images/" .. raidoAddon .. "checked.png")
            else
                overlay:SetTexture(api.baseDir .. "/WorldSatNav/images/" .. raidoAddon .. "unchecked.png")
            end
            for cbId, cbData in pairs(CheckBoxs) do
                if cbData.isRadio and cbData.radioGroup == radioGroup and cbId ~= id then
                     helpers.SetCheckboxState(cbId, false)
                end
            end
            CheckBoxs[id].checked = newChecked
            if newChecked ~= currentChecked then
                helpers.DevLog("WorldSatNav: Checkbox '"..id.."' changed to "..tostring(newChecked)..", calling callback.")
                onClickFunction(newChecked)
                return
            end
            helpers.DevLog("WorldSatNav: Checkbox '"..id.."' state unchanged at "..tostring(newChecked)..", callback not called.")
        end
        button:SetHandler("OnClick", button.OnClick)
    end
    
    CheckBoxs[id] = {
        button = button,
        checked = checked,
        label = mylabel,
        overlay = overlay,
        isRadio = isRadio,
        radioGroup = radioGroup
    }
end

function helpers.ToggleCheckboxVisable(id, visable)
    local cb = CheckBoxs[id]
    if cb == nil then
        return
    end
    cb.button:Show(visable)
    cb.button:Enable(visable)
    if(cb.label ~= nil) then
        cb.label:Show(visable)
    end
    cb.overlay:Show(visable)
end

-- Set a checkbox's visual state and internal checked value without firing its callback.
function helpers.SetCheckboxState(id, checked)
    local cb = CheckBoxs[id]
    if cb == nil then return end
    cb.checked = checked
    local raidoAddon = ""
    if cb.isRadio then
        raidoAddon = "radio_"
    end
    if checked then
        cb.overlay:SetTexture(api.baseDir .. "/WorldSatNav/images/" .. raidoAddon .. "checked.png")
    else
        cb.overlay:SetTexture(api.baseDir .. "/WorldSatNav/images/" .. raidoAddon .. "unchecked.png")
    end
end

function helpers.createButton(id, parent, text, x, y)
    local button = api.Interface:CreateWidget('button', id, parent)
    button:SetExtent(55, 26)
    button:AddAnchor("TOPLEFT", parent, x, y)
    button:SetText(text)
    api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
    return button
end

local function formatTwoDigits(value)
    local numericValue = tonumber(value)
    if numericValue == nil then
        return "00"
    end
    if numericValue < 10 then
        return "0" .. tostring(numericValue)
    end
    return tostring(numericValue)
end

local function firstDefined(...)
    local values = {...}
    for _, value in ipairs(values) do
        if value ~= nil then
            return value
        end
    end
    return nil
end

local calibratedTimeState = {
    lastKnownLocalTime = nil,
    lastReturnedTimestamp = nil,
}

function helpers.AdvanceCurrentTimestamp(dt)
    local deltaMsec = tonumber(dt)
    if deltaMsec == nil then
        return
    end

    if calibratedTimeState.lastReturnedTimestamp == nil then
        helpers.GetCurrentTimestamp()
    end

    if calibratedTimeState.lastReturnedTimestamp ~= nil and deltaMsec > 0 then
        calibratedTimeState.lastReturnedTimestamp = calibratedTimeState.lastReturnedTimestamp + (deltaMsec / 1000)
    end
end

function helpers.GetCurrentTimestamp()
    local localTime = api.Time:GetLocalTime()
    if type(localTime) == "number" then
        if calibratedTimeState.lastKnownLocalTime == nil or localTime > calibratedTimeState.lastKnownLocalTime then
            calibratedTimeState.lastKnownLocalTime = localTime
        end
        if calibratedTimeState.lastReturnedTimestamp == nil or localTime > calibratedTimeState.lastReturnedTimestamp then
            calibratedTimeState.lastReturnedTimestamp = localTime
        end
    end

    return calibratedTimeState.lastReturnedTimestamp or localTime
end

local function extractDateParts(dateValue)
    if type(dateValue) ~= "table" then
        return nil, nil, nil, nil, nil, nil
    end

    local year = firstDefined(dateValue.year, dateValue.years, dateValue.wYear, dateValue.tm_year)
    local month = firstDefined(dateValue.month, dateValue.mon, dateValue.months, dateValue.wMonth, dateValue.tm_mon)
    local day = firstDefined(dateValue.day, dateValue.mday, dateValue.wDay, dateValue.dayOfMonth, dateValue.tm_mday)
    local hour = firstDefined(dateValue.hour, dateValue.hours, dateValue.wHour, dateValue.tm_hour)
    local min = firstDefined(dateValue.min, dateValue.minute, dateValue.minutes, dateValue.wMinute, dateValue.tm_min)
    local sec = firstDefined(dateValue.sec, dateValue.second, dateValue.seconds, dateValue.wSecond, dateValue.tm_sec)

    if year ~= nil and year < 100 then
        year = year + 2000
    end
    if month ~= nil and month >= 0 and month <= 11 and dateValue.tm_mon ~= nil then
        month = month + 1
    end

    return year, month, day, hour, min, sec
end


function helpers.DebugDumpValue(label, value, depth, visited)
	depth = depth or 0
	visited = visited or {}
	local indent = string.rep("  ", depth)
	local valueType = type(value)

	if valueType ~= "table" then
		helpers.DevLog(indent .. label .. " = " .. tostring(value))
		return
	end

	if visited[value] then
		helpers.DevLog(indent .. label .. " = <recursive table>")
		return
	end

	visited[value] = true
	helpers.DevLog(indent .. label .. " = {")
	for key, nestedValue in pairs(value) do
		helpers.DebugDumpValue(tostring(key), nestedValue, depth + 1, visited)
	end
	helpers.DevLog(indent .. "}")
end

function helpers.getTodayDateText()
	local localTime = api.Time:GetLocalTime()
    local dateraw = api.Time:TimeToDate(localTime)
	if dateraw == nil then
        helpers.DevLog("getTodayDateText: Unable to get date table from local time, got: " .. type(dateraw))
        return "DD-MM-YYYY"
	end

    local year, month, day = extractDateParts(dateraw)
	if year == nil or month == nil or day == nil then
        return "DD-MM-YYYY"
	end

    return formatTwoDigits(day) .. "-" .. formatTwoDigits(month) .. "-" .. tostring(year)
end

function helpers.getComboBoxValue(comboBox, defaultValue)
    if comboBox == nil or comboBox.dropdownItem == nil then
        return defaultValue
    end
    local selectedIndex = comboBox:GetSelectedIndex()
    if selectedIndex == nil or selectedIndex < 1 or selectedIndex > #comboBox.dropdownItem then
        return defaultValue
    end
    return comboBox.dropdownItem[selectedIndex]
end

function helpers.SelectComboBoxByText(comboBox, targetText, defaultifNotFound)
  if comboBox == nil or comboBox.dropdownItem == nil or targetText == nil then
    return false
  end

  for index = 1, #comboBox.dropdownItem do
    local itemText = tostring(comboBox.dropdownItem[index])
    if itemText == tostring(targetText) then
      comboBox:Select(index)
      return true
    end
  end

  if defaultifNotFound ~= nil then
    helpers.SelectComboBoxByText(comboBox, defaultifNotFound)
  end
  return false
end

local function dateTimeToUnixtimeUtcLike(year, month, day, hour, min, sec)
    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    hour = tonumber(hour) or 0
    min = tonumber(min) or 0
    sec = tonumber(sec) or 0

    if year == nil or month == nil or day == nil then
        return nil, "Date is incomplete."
    end

    local components = {year, month, day, hour, min, sec}
    for _, value in ipairs(components) do
        if value % 1 ~= 0 then
            return nil, "Date and time must use whole numbers."
        end
    end

    if month < 1 or month > 12 then
        return nil, "Month must be between 1 and 12."
    end

    local function isLeapYear(value)
        if value % 400 == 0 then
            return true
        end
        if value % 100 == 0 then
            return false
        end
        return value % 4 == 0
    end

    local daysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    local maxDay = daysPerMonth[month]
    if month == 2 and isLeapYear(year) then
        maxDay = 29
    end

    if day < 1 or day > maxDay then
        return nil, "Day is out of range for the selected month."
    end
    if hour < 0 or hour > 23 then
        return nil, "Hour must be between 0 and 23."
    end
    if min < 0 or min > 59 then
        return nil, "Minute must be between 0 and 59."
    end
    if sec < 0 or sec > 59 then
        return nil, "Second must be between 0 and 59."
    end

    local daysSinceEpoch = 0
    if year >= 1970 then
        for currentYear = 1970, year - 1 do
            daysSinceEpoch = daysSinceEpoch + (isLeapYear(currentYear) and 366 or 365)
        end
    else
        for currentYear = 1969, year, -1 do
            daysSinceEpoch = daysSinceEpoch - (isLeapYear(currentYear) and 366 or 365)
        end
    end

    for currentMonth = 1, month - 1 do
        daysSinceEpoch = daysSinceEpoch + daysPerMonth[currentMonth]
        if currentMonth == 2 and isLeapYear(year) then
            daysSinceEpoch = daysSinceEpoch + 1
        end
    end

    daysSinceEpoch = daysSinceEpoch + (day - 1)

    return daysSinceEpoch * 86400 + hour * 3600 + min * 60 + sec
end

local function dateTimeToUnixtime(year, month, day, hour, min, sec)
    local timestamp, errorMessage = dateTimeToUnixtimeUtcLike(year, month, day, hour, min, sec)
    if timestamp == nil then
        return nil, errorMessage
    end

    local currentLocalTime = api.Time:GetLocalTime()
    local currentDateValue = api.Time:TimeToDate(currentLocalTime)
    local currentYear, currentMonth, currentDay, currentHour, currentMin, currentSec = extractDateParts(currentDateValue)

    if currentYear == nil or currentMonth == nil or currentDay == nil then
        return timestamp
    end

    local currentTimestamp = dateTimeToUnixtimeUtcLike(currentYear, currentMonth, currentDay, currentHour or 0, currentMin or 0, currentSec or 0)
    if currentTimestamp == nil then
        return timestamp
    end

    local localOffsetSeconds = currentLocalTime - currentTimestamp
    return timestamp + localOffsetSeconds
end

function helpers.ParseDateTimeToUnixtime(dateText, timeText)
    if type(dateText) ~= "string" or type(timeText) ~= "string" then
        return nil, "Date and time are required."
    end

    local trimmedDate = dateText:match("^%s*(.-)%s*$")
    local trimmedTime = timeText:match("^%s*(.-)%s*$")
    if trimmedDate == "" or trimmedTime == "" then
        return nil, "Date and time are required."
    end

    local year, month, day = trimmedDate:match("^(%d%d%d%d)%D(%d%d?)%D(%d%d?)$")
    if year == nil then
        day, month, year = trimmedDate:match("^(%d%d?)%D(%d%d?)%D(%d%d%d%d)$")
    end
    if year == nil then
        return nil, "Date format must be YYYY-MM-DD or DD-MM-YYYY."
    end

    local hour, min, sec = trimmedTime:match("^(%d%d?):(%d%d?):(%d%d?)$")
    if hour == nil then
        hour, min = trimmedTime:match("^(%d%d?):(%d%d?)$")
        sec = 0
    end
    if hour == nil then
        return nil, "Time format must be HH:MM or HH:MM:SS."
    end

    return dateTimeToUnixtime(year, month, day, hour, min, sec)
end

local function applyWidgetFontColor(widget, fontcolor)
    if widget == nil or fontcolor == nil then
        return
    end
    ApplyTextColor(widget, fontcolor)
    if widget.style ~= nil and widget.style.SetColor ~= nil then
        local alpha = fontcolor[4] or 1
        widget.style:SetColor(fontcolor[1], fontcolor[2], fontcolor[3], alpha)
    end
end

local function applyComboBoxFontColor(comboBox, fontcolor)
    if comboBox == nil or fontcolor == nil then
        return
    end

    applyWidgetFontColor(comboBox, fontcolor)
    applyWidgetFontColor(comboBox.textButton, fontcolor)
    applyWidgetFontColor(comboBox.label, fontcolor)
    applyWidgetFontColor(comboBox.selectedText, fontcolor)
    applyWidgetFontColor(comboBox.editbox, fontcolor)
    applyWidgetFontColor(comboBox.editBox, fontcolor)
    applyWidgetFontColor(comboBox.text, fontcolor)
end

function helpers.CreateComboBox(parent, items, x, y, width, height, transparent, fontcolor, currentitem)
	local cb = api.Interface:CreateComboBox(parent)
    fontcolor = fontcolor or FONT_COLOR.WHITE
    transparent = transparent or false
    currentitem = currentitem or nil
    if transparent == true then
        if cb.bg ~= nil then
            cb.bg:SetColor(1, 1, 1, 0)
        end
        if cb.SetInset ~= nil then
            cb:SetInset(0, 0, 0, 0)
        end
    end
    cb.limitItemCount = 10
    cb.unselectedText = currentitem or (items and items[1]) or ""
    applyComboBoxFontColor(cb, fontcolor)

	if width and height then
		cb:SetExtent(width, height)
	end
	if x and y then
		cb:AddAnchor("TOPLEFT", parent, x, y)
	end
	if items then
		cb.dropdownItem = items
	end
    if cb.Select ~= nil then
        local originalSelect = cb.Select
        function cb:Select(index)
            originalSelect(self, index)
            applyComboBoxFontColor(self, fontcolor)
        end
    end
    if currentitem then
        helpers.SelectComboBoxByText(cb, currentitem)
    end
    applyComboBoxFontColor(cb, fontcolor)
    cb:Show(true)
	return cb
end


-- Creates a single-line text input field with an optional label and placeholder.
-- Parameters:
--   id             : unique widget id
--   parent         : parent widget
--   offsetX/Y      : position relative to parent
--   width          : width of the input box (default 200)
--   height         : height of the input box (default 26)
--   placeholder    : guide/placeholder text shown when empty (optional)
--   maxLength      : max characters allowed (default 100)
--   labelText      : label shown above the input (optional, nil = no label)
--   onTextChanged  : callback(text) fired when text changes (optional)
-- Returns the editBox widget (editBox.label is set if a label was created)
function helpers.createTextInput(id, parent, offsetX, offsetY, width, height, placeholder, maxLength, labelText, onTextChanged, transparent, fontcolor)
    width     = width     or 200
    height    = height    or 26
    maxLength = maxLength or 100
    offsetX   = offsetX   or 0
    offsetY   = offsetY   or 0
    transparent = transparent or false
    fontcolor = fontcolor or FONT_COLOR.BLUE

    local labelWidget = nil
    local inputOffsetY = offsetY
    if labelText then
        labelWidget = helpers.createLabel(id .. "_label", parent, labelText, offsetX, offsetY, 14)
        inputOffsetY = offsetY + 20
    end

    local editBox = W_CTRL.CreateEdit(id .. "_edit", parent)
    ApplyTextColor(editBox, fontcolor)
    editBox:SetExtent(width, height)
    editBox:RemoveAllAnchors()
    editBox:AddAnchor("TOPLEFT", parent, offsetX, inputOffsetY)
    editBox:SetMaxTextLength(maxLength)
    editBox:SetCursorColor({0, 0, 0, 1})
    editBox:UseSelectAllWhenFocused(false)
    editBox:Show(true)
    
    if transparent then
        editBox:SetExtent(width, height)
        if editBox.bg ~= nil then
            editBox.bg:SetColor(1, 1, 1, 0)
        end
        if editBox.SetInset ~= nil then
            editBox:SetInset(0, 0, 0, 0)
        end
    end

    if placeholder then
        editBox:CreateGuideText(placeholder, ALIGN_LEFT)
    end

    if onTextChanged then
        function editBox:OnTextChanged()
            onTextChanged(self:GetText())
        end
        editBox:SetHandler("OnTextChanged", editBox.OnTextChanged)
    end

    editBox.label = labelWidget
    return editBox
end

function helpers.createLabel(id, parent, text, offsetX, offsetY, fontSize, transparent, fontcolor, width, height)
    local label = api.Interface:CreateWidget('label', id, parent)
    label:AddAnchor("TOPLEFT", offsetX, offsetY)
    label:SetExtent(width or 255, height or 30)
    label:SetText(text)
    label.style:SetColor(FONT_COLOR.TITLE[1], FONT_COLOR.TITLE[2],
                         FONT_COLOR.TITLE[3], 1)
    label.style:SetAlign(ALIGN.LEFT)
    label.style:SetFontSize(fontSize or 18)
    if transparent then
        if label.bg ~= nil then
            label.bg:SetColor(1, 1, 1, 0)
        end
        if label.SetInset ~= nil then
            label:SetInset(0, 0, 0, 0)
        end
    end
    if fontcolor then
        label.style:SetColor(fontcolor[1], fontcolor[2], fontcolor[3], fontcolor[4] or 1)
    end
    label:Show(true)
    return label
end



--- Iterate over all treasure map items currently in the player's bag.
-- Calls callback(slotIndex, btn, info) for each slot that contains a treasure map.
-- @param callback function called with (slotIndex, btn, info) for each matching slot
function helpers.iterateTreasureMaps(callback)
    local bagFrame = ADDON:GetContent(UIC.BAG)
    if not bagFrame or not bagFrame.slots or not bagFrame.slots.btns then
        return
    end
    for slotIndex, btn in pairs(bagFrame.slots.btns) do
        local info = btn:GetInfo()
        if info and info.name == constants.game.treasureMapItemName then
            callback(slotIndex, btn, info)
        end
    end
end

--- Attach shift-drag move behaviour to a widget.
-- OnDragStart requires Shift to be held, moves movedWidget, and saves the final
-- position to settings under settingsKeyX / settingsKeyY.
-- @param dragTarget  widget that receives drag events
-- @param movedWidget widget that actually moves (may equal dragTarget)
-- @param settingsKeyX string settings key for the X position
-- @param settingsKeyY string settings key for the Y position
function helpers.makeWindowDraggable(dragTarget, movedWidget, settingsKeyX, settingsKeyY)
    function dragTarget:OnDragStart()
        if api.Input:IsShiftKeyDown() == false then
            return
        end
        movedWidget:StartMoving()
        api.Cursor:ClearCursor()
        api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
    end

    function dragTarget:OnDragStop()
        movedWidget:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        local x, y = movedWidget:GetEffectiveOffset()
        settings.Update(settingsKeyX, x)
        settings.Update(settingsKeyY, y)
    end

    dragTarget:SetHandler("OnDragStart", dragTarget.OnDragStart)
    dragTarget:SetHandler("OnDragStop", dragTarget.OnDragStop)
    if dragTarget.RegisterForDrag ~= nil then
        dragTarget:RegisterForDrag("LeftButton")
    end
    if dragTarget.EnableDrag ~= nil then
        dragTarget:EnableDrag(true)
    end
end

return helpers
