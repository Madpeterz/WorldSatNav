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
    "Miner's Farmhouse",
    "Recovering Cherry Treehouse",
    "Improved Solar Pavilion Farm Kit",
    "Desserted House",
    "Improved Lunar Pavilion Farm Kit",
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
    local dateValue = dateraw
    local year = firstDefined(dateValue.year, dateValue.years, dateValue.wYear, dateValue.tm_year)
    local month = firstDefined(dateValue.month, dateValue.mon, dateValue.months, dateValue.wMonth, dateValue.tm_mon)
    local day = firstDefined(dateValue.day, dateValue.mday, dateValue.wDay, dateValue.dayOfMonth, dateValue.tm_mday)
    if year ~= nil and year < 100 then
        year = year + 2000
    end
    if month ~= nil and month >= 0 and month <= 11 and dateValue.tm_mon ~= nil then
        month = month + 1
    end
	if year == nil or month == nil or day == nil then
        return "DD-MM-YYYY"
	end

    return formatTwoDigits(day) .. "-" .. formatTwoDigits(month) .. "-" .. tostring(year)
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

function helpers.createLabel(id, parent, text, offsetX, offsetY, fontSize)
    local label = api.Interface:CreateWidget('label', id, parent)
    label:AddAnchor("TOPLEFT", offsetX, offsetY)
    label:SetExtent(255, 30)
    label:SetText(text)
    label.style:SetColor(FONT_COLOR.TITLE[1], FONT_COLOR.TITLE[2],
                         FONT_COLOR.TITLE[3], 1)
    label.style:SetAlign(ALIGN.LEFT)
    label.style:SetFontSize(fontSize or 18)

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
