---@diagnostic disable: undefined-global
local api = require("api")
local constants = require("WorldSatNav/constants")
local settings = require("WorldSatNav/settings")

local helpers = {}

local CheckBoxs = {}
helpers.CheckBoxs = CheckBoxs



function helpers.CreateSkinnedCheckbox(id, parent, text, offsetX, offsetY, checked, onClickFunction, buttonSizeX, buttonSizeY, radioGroup)
    buttonSizeX = buttonSizeX or 25
    buttonSizeY = buttonSizeY or 25
    -- Create image drawable on parent to show the checkbox
    local overlay = parent:CreateImageDrawable(id.."CheckBoxOverlay", "artwork")
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
    
    local mylabel = api.Interface:CreateWidget("label", id.."CheckBoxlabel", parent)
    mylabel:SetExtent(200, 30)
    mylabel:AddAnchor("TOPLEFT", parent, offsetX+30, offsetY)
    mylabel:SetText(text)
    mylabel.style:SetAlign(ALIGN.LEFT)
    mylabel.style:SetFontSize(14)
    mylabel.style:SetColor(0, 0, 0, 1)
    mylabel:Show(true)
    
    if onClickFunction ~= nil then
        function button:OnClick()
            local currentChecked = CheckBoxs[id] and CheckBoxs[id].checked or false
            local newChecked = not currentChecked
            local raidoAddon = ""
            if CheckBoxs[id].isRadio then
                if currentChecked == true then
                    if constants.DEV_MODE then
                        api.Log:Info("WorldSatNav: Radio button '"..id.."' is already checked, ignoring click.")
                    end
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
                if constants.DEV_MODE then
                    api.Log:Info("WorldSatNav: Checkbox '"..id.."' changed to "..tostring(newChecked)..", calling callback.")
                end
                onClickFunction(newChecked)
                return
            end
            if constants.DEV_MODE then
                api.Log:Info("WorldSatNav: Checkbox '"..id.."' state unchanged at "..tostring(newChecked)..", callback not called.")
            end
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
    cb.label:Show(visable)
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
function helpers.createTextInput(id, parent, offsetX, offsetY, width, height, placeholder, maxLength, labelText, onTextChanged)
    width     = width     or 200
    height    = height    or 26
    maxLength = maxLength or 100
    offsetX   = offsetX   or 0
    offsetY   = offsetY   or 0

    local labelWidget = nil
    local inputOffsetY = offsetY
    if labelText then
        labelWidget = helpers.createLabel(id .. "_label", parent, labelText, offsetX, offsetY, 14)
        inputOffsetY = offsetY + 20
    end

    local editBox = W_CTRL.CreateEdit(id .. "_edit", parent)
    editBox:SetExtent(width, height)
    editBox:RemoveAllAnchors()
    editBox:AddAnchor("TOPLEFT", parent, offsetX, inputOffsetY)
    editBox:SetMaxTextLength(maxLength)
    editBox:SetCursorColor(0.8, 0.8, 0.8, 1)
    editBox:UseSelectAllWhenFocused(true)
    editBox:Show(true)

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
