local api = require("api")
local constants = require("WorldSatNav/core/constants")
local settingsModule = require("WorldSatNav/core/settings")
local log = require("WorldSatNav/helpers/log")

local widgets = {}
local defaultClickSoundKey = "auction_put_up"

local CheckBoxs = {}
widgets.CheckBoxs = CheckBoxs

local function resolveCheckboxTextures(isRadio, customTextureChecked, customTextureUnchecked)
    local radioAddon = "checkbox_"
    if isRadio then
        radioAddon = "radio_"
    end

    local useTextureChecked = constants.folderPath.."images/controls/" .. radioAddon .. "checked.png"
    local useTextureUnchecked = constants.folderPath.."images/controls/" .. radioAddon .. "unchecked.png"

    if type(customTextureChecked) == "string" and customTextureChecked ~= "" then
        useTextureChecked = constants.folderPath.."images/controls/" .. customTextureChecked
    end
    if type(customTextureUnchecked) == "string" and customTextureUnchecked ~= "" then
        useTextureUnchecked = constants.folderPath.."images/controls/" .. customTextureUnchecked
    end

    return useTextureChecked, useTextureUnchecked
end

function widgets.CreateImageButton(id, parent, texturenormal, offsetX, offsetY, sizeX, sizeY, onClickFunction, hasOnHover, onHoverTexture, onHoverTooltip, clickSoundKey)
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    sizeX = sizeX or 25
    sizeY = sizeY or 25
    offsetX = offsetX * settingsModule.Get("uiDrawScale")
    offsetY = offsetY * settingsModule.Get("uiDrawScale")
    sizeX = sizeX * settingsModule.Get("uiDrawScale")
    sizeY = sizeY * settingsModule.Get("uiDrawScale")

    local texturePathNormal = nil
    local texturePathHover = nil
    if texturenormal ~= nil then
        texturePathNormal = constants.folderPath.."images/" .. texturenormal
    end
    if onHoverTexture ~= nil then
        texturePathHover = constants.folderPath.."images/" .. onHoverTexture
    end


    local button = parent:CreateChildWidget("button", id, 0, true)
    local image = nil
    if texturePathNormal ~= nil then
        image = parent:CreateImageDrawable(id .. "_image", "artwork")
        if image == nil then
            log.DevLog("CreateImageButton: Failed to create image drawable for '"..id.."'.")
            return button
        end
        image:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
        image:SetExtent(sizeX, sizeY)
        image:SetTexture(texturePathNormal)
        image:Show(true)
    else
        log.DevLog("CreateImageButton: No texture provided for '"..id.."'.")
    end
    button:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
    button:SetExtent(sizeX, sizeY)
    button:Show(true)
    button:Enable(true)
    if button.SetSounds ~= nil then
        button:SetSounds(clickSoundKey or defaultClickSoundKey)
    end
    button.parent = parent
    button.imageDrawable = image

    if hasOnHover == true then
        function button:HoverStart()
            local mouseX, mouseY = button:GetEffectiveOffset()
            if onHoverTooltip ~= nil then
                api.Interface:SetTooltipOnPos(onHoverTooltip, button, mouseX + button:GetWidth(), mouseY)
            end
            if texturePathHover ~= nil then
                if image ~= nil then
                    image:SetTexture(texturePathHover)
                end
            end
        end

        function button:HoverEnd()
            if onHoverTooltip ~= nil then
                api.Interface:SetTooltipOnPos("", button, 0, 0)
            end
            if texturePathNormal ~= nil then
                if image ~= nil then
                    image:SetTexture(texturePathNormal)
                end
            end
        end
        button:SetHandler("OnEnter", button.HoverStart)
        button:SetHandler("OnLeave", button.HoverEnd)
    end

    if onClickFunction ~= nil then
        function button:OnClick()
            onClickFunction()
        end
        button:SetHandler("OnClick", button.OnClick)
    end
    return button
end

function widgets.SetCheckBoxOverride(id, overrideEnabled)
    if CheckBoxs[id] == nil then
        return
    end
    CheckBoxs[id].override = overrideEnabled
end

function widgets.CreateSkinnedCheckbox(id, parent, text, offsetX, offsetY, checked, onClickFunction, buttonSizeX, buttonSizeY, radioGroup, renderlayer, showText, customTextureChecked, customTextureUnchecked, clickSoundKey, OffsetTextX, OffsetTextY)
    buttonSizeX = buttonSizeX or 25
    buttonSizeY = buttonSizeY or 25
    renderlayer = renderlayer or "artwork"
    if OffsetTextX == nil then
        OffsetTextX = true
    end
    if OffsetTextY == nil then
        OffsetTextY = false
    end
    buttonSizeX = buttonSizeX * settingsModule.Get("uiDrawScale")
    buttonSizeY = buttonSizeY * settingsModule.Get("uiDrawScale")
    offsetX = offsetX * settingsModule.Get("uiDrawScale")
    offsetY = offsetY * settingsModule.Get("uiDrawScale")


    if showText == nil then showText = true end
    -- Create image drawable on parent to show the checkbox
    local overlay = parent:CreateImageDrawable(id.."CheckBoxOverlay", renderlayer)
	overlay:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
    local isRadio = false
    if radioGroup ~= nil then
        isRadio = true
    end
	overlay:SetExtent(buttonSizeX, buttonSizeY)
    local useTextureChecked, useTextureUnchecked = resolveCheckboxTextures(isRadio, customTextureChecked, customTextureUnchecked)
    if checked then
        overlay:SetTexture(useTextureChecked)
    else
        overlay:SetTexture(useTextureUnchecked)
    end
    overlay:Show(true)

    -- Create invisible button on top for click handling
    local button = parent:CreateChildWidget("button", id.."CheckBoxButton", 0, true)
	button:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
	button:SetExtent(buttonSizeX, buttonSizeY)
    button:Show(true)
    button:Enable(true)
    if button.SetSounds ~= nil then
        button:SetSounds(clickSoundKey or defaultClickSoundKey)
    end
    button:Raise()

    local labelButton = nil

    local mylabel = nil
    if showText == true then
        mylabel = api.Interface:CreateWidget("label", id.."CheckBoxlabel", parent)
        if mylabel == nil then
            log.DevLog("Failed to create label for checkbox with id: " .. id)
            return
        end
        local textOffsetX = 10 * settingsModule.Get("uiDrawScale")
        if OffsetTextX == true then
            textOffsetX = buttonSizeX * settingsModule.Get("uiDrawScale")
        end
        local textOffsetY = 0
        if OffsetTextY == true then
            textOffsetY = buttonSizeY * settingsModule.Get("uiDrawScale")
        end
        mylabel:SetExtent(200, 30)
        mylabel:AddAnchor("TOPLEFT", button, textOffsetX, textOffsetY)
        mylabel:SetText(text)
        mylabel.style:SetAlign(ALIGN.LEFT)
        mylabel.style:SetFontSize(14)
        mylabel.style:SetColor(0, 0, 0, 1)
        local labelWidth = mylabel.GetTextWidth and (mylabel:GetTextWidth() + 4) or mylabel:GetWidth()
        local labelHeight = mylabel.GetTextHeight and (mylabel:GetTextHeight() + 4) or mylabel:GetHeight()
        if type(labelWidth) == "number" and type(labelHeight) == "number" then
            mylabel:SetExtent(labelWidth, labelHeight)
        end
        mylabel:Raise()
        mylabel:Show(true)

        -- Use a transparent proxy button over the label area so clicking text
        -- goes through the button pipeline and triggers button sounds.
        labelButton = parent:CreateChildWidget("button", id.."CheckBoxLabelButton", 0, true)
        if labelButton == nil then
            log.DevLog("Failed to create label button for checkbox with id: " .. id)
            return
        end
        labelButton:AddAnchor("TOPLEFT", button, textOffsetX, textOffsetY)
        if type(labelWidth) == "number" and type(labelHeight) == "number" then
            labelButton:SetExtent(labelWidth, labelHeight)
        else
            labelButton:SetExtent(200, 30)
        end
        labelButton:Show(true)
        labelButton:Enable(true)
        if labelButton.SetSounds ~= nil then
            labelButton:SetSounds(clickSoundKey or defaultClickSoundKey)
        end
        labelButton:Raise()
    end

    if onClickFunction ~= nil then
        function button:OnClick()
            local currentChecked = CheckBoxs[id] and CheckBoxs[id].checked or false
            local overrideEnabled = CheckBoxs[id] and CheckBoxs[id].override or false
            local newChecked = not currentChecked
            if CheckBoxs[id].isRadio then
                if currentChecked == true and overrideEnabled == false then
                    return -- if it's a radio button and already checked, do nothing on click, unless override is enabled
                end
            end
            if currentChecked == true and overrideEnabled == true then
                currentChecked = false -- pretending its unchecked to allow you to reclick a raido button with override enabled
                newChecked = true
            end
            local useTextureChecked, useTextureUnchecked = resolveCheckboxTextures(CheckBoxs[id].isRadio, CheckBoxs[id].customTextureChecked, CheckBoxs[id].customTextureUnchecked)
            if newChecked then
                overlay:SetTexture(useTextureChecked)
            else
                overlay:SetTexture(useTextureUnchecked)
            end
            for cbId, cbData in pairs(CheckBoxs) do
                if cbData.isRadio and cbData.radioGroup == radioGroup and cbId ~= id then
                     widgets.SetCheckboxState(cbId, false)
                end
            end
            CheckBoxs[id].checked = newChecked
            if newChecked ~= currentChecked then
                onClickFunction(newChecked, id)
                return
            end
        end
        button:SetHandler("OnClick", button.OnClick)
        if labelButton ~= nil then
            labelButton:SetHandler("OnClick", button.OnClick)
        end
    end

    CheckBoxs[id] = {
        button = button,
        checked = checked,
        label = mylabel,
        labelButton = labelButton,
        overlay = overlay,
        isRadio = isRadio,
        radioGroup = radioGroup,
        customTextureChecked = customTextureChecked,
        customTextureUnchecked = customTextureUnchecked,
    }
end

function widgets.ToggleCheckboxVisable(id, visable)
    local cb = CheckBoxs[id]
    if cb == nil then
        return
    end
    cb.button:Show(visable)
    cb.button:Enable(visable)
    if(cb.label ~= nil) then
        cb.label:Show(visable)
    end
    if(cb.labelButton ~= nil) then
        cb.labelButton:Show(visable)
        cb.labelButton:Enable(visable)
    end
    cb.overlay:Show(visable)
end

-- Set a checkbox's visual state and internal checked value without firing its callback.
function widgets.SetCheckboxState(id, checked)
    local cb = CheckBoxs[id]
    if cb == nil then return end
    cb.checked = checked
    local useTextureChecked, useTextureUnchecked = resolveCheckboxTextures(cb.isRadio, cb.customTextureChecked, cb.customTextureUnchecked)

    if checked then
        cb.overlay:SetTexture(useTextureChecked)
    else
        cb.overlay:SetTexture(useTextureUnchecked)
    end
end

function widgets.createSkinnedButton(id, parent, text, texture, offsetX, offsetY, buttonSizeX, buttonSizeY, renderlayer, onClickFunction, clickSound, OffsetTextX, OffsetTextY)
    buttonSizeX = buttonSizeX or 25
    buttonSizeY = buttonSizeY or 25
    renderlayer = renderlayer or "artwork"
    if OffsetTextX == nil then
        OffsetTextX = true
    end
    if OffsetTextY == nil then
        OffsetTextY = false
    end
    buttonSizeX = buttonSizeX * settingsModule.Get("uiDrawScale")
    buttonSizeY = buttonSizeY * settingsModule.Get("uiDrawScale")
    offsetX = offsetX * settingsModule.Get("uiDrawScale")
    offsetY = offsetY * settingsModule.Get("uiDrawScale")
    clickSound = clickSound or defaultClickSoundKey

    -- Create image drawable on parent to show the checkbox
    local overlay = parent:CreateImageDrawable(id.."buttonImage", renderlayer)
	overlay:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
    overlay:SetExtent(buttonSizeX, buttonSizeY)
    overlay:SetTexture(constants.folderPath.."images/"..texture)
    overlay:Show(true)
    -- Create invisible button on top for click handling
    local button = parent:CreateChildWidget("button", id.."ButtonClickable", 0, true)
    button:AddAnchor("TOPLEFT", overlay, 0, 0)
    button:SetExtent(buttonSizeX, buttonSizeY)
    button:Show(true)
    button:Enable(true)
    if button.SetSounds ~= nil then
        button:SetSounds(clickSound)
    end
    button.parent = parent
    overlay:Show(true)
    overlay.Button = button
    if onClickFunction ~= nil then
        function button:OnClick()
            onClickFunction()
        end
        button:SetHandler("OnClick", button.OnClick)
    end
    -- create Label on button
    local mylabel = nil
    if text ~= nil and text ~= "" then
        mylabel = api.Interface:CreateWidget("label", id.."CheckBoxlabel", parent)
        if mylabel == nil then
            log.DevLog("Failed to create label for checkbox with id: " .. id)
            return
        end
        local textOffsetX = 10 * settingsModule.Get("uiDrawScale")
        if OffsetTextX == true then
            textOffsetX = buttonSizeX * settingsModule.Get("uiDrawScale")
        end
        local textOffsetY = 0
        if OffsetTextY == true then
            textOffsetY = buttonSizeY * settingsModule.Get("uiDrawScale")
        end
        mylabel:SetExtent(200, 30)
        mylabel:AddAnchor("TOPLEFT", button, textOffsetX, textOffsetY)
        mylabel:SetText(text)
        mylabel.style:SetAlign(ALIGN.LEFT)
        mylabel.style:SetFontSize(14)
        mylabel.style:SetColor(0, 0, 0, 1)
        mylabel:Raise()
        mylabel:Show(true)
    end
    return button
end

function widgets.createButton(id, parent, text, x, y)
    local button = api.Interface:CreateWidget('button', id, parent)
    button:SetExtent(55, 26)
    button:AddAnchor("TOPLEFT", parent, x, y)
    button:SetText(text)
    api.Interface:ApplyButtonSkin(button, BUTTON_BASIC.DEFAULT)
    button:Enable(true)
    return button
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

function widgets.getComboBoxValue(comboBox, defaultValue)
    if comboBox == nil or comboBox.dropdownItem == nil then
        return defaultValue
    end
    local selectedIndex = comboBox:GetSelectedIndex()
    if selectedIndex == nil or selectedIndex < 1 or selectedIndex > #comboBox.dropdownItem then
        return defaultValue
    end
    return comboBox.dropdownItem[selectedIndex]
end

function widgets.SelectComboBoxByText(comboBox, targetText, defaultifNotFound)
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
    return widgets.SelectComboBoxByText(comboBox, defaultifNotFound)
  end
  return false
end

function widgets.CreateComboBox(parent, items, x, y, width, height, transparent, fontcolor, currentitem, labelText, id)
    labelText = labelText or nil
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
    local labelWidget = nil
    if labelText then
        local labelId = (id or "comboBox") .. "_label"
        labelWidget = widgets.createLabel(labelId, parent, labelText, x, y, 14, transparent, fontcolor)
        -- Keep the combo box below the label to avoid overlap.
    end
    cb.limitItemCount = 10
    cb.unselectedText = currentitem or (items and items[1]) or ""
    applyComboBoxFontColor(cb, fontcolor)

	if width and height then
		cb:SetExtent(width, height)
	end
	if x and y then
        if labelWidget then
            -- Anchor to the label if it exists, otherwise anchor to the parent.
            cb:AddAnchor("TOPLEFT", labelWidget, 0, 30)
        else
		    cb:AddAnchor("TOPLEFT", parent, x, y)
        end
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
        widgets.SelectComboBoxByText(cb, currentitem)
    end
    applyComboBoxFontColor(cb, fontcolor)
    cb:Show(true)
    cb.label= labelWidget
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
function widgets.createTextInput(id, parent, offsetX, offsetY, width, height, placeholder, maxLength, labelText, onTextChanged, transparent, fontcolor)
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
        labelWidget = widgets.createLabel(id .. "_label", parent, labelText, offsetX, offsetY, 14, transparent, fontcolor)
        inputOffsetY = offsetY + 20
    end

    local uiScale = settingsModule.Get("uiDrawScale") or 1
    local scaledWidth = width * uiScale
    local scaledHeight = height * uiScale
    local scaledOffsetX = offsetX * uiScale
    local scaledInputOffsetY = inputOffsetY * uiScale
    local textLeftInset = math.floor(6 * uiScale)

    local editBox = W_CTRL.CreateEdit(id .. "_edit", parent)
    ApplyTextColor(editBox, fontcolor)
    editBox:SetExtent(scaledWidth, scaledHeight)
    editBox:RemoveAllAnchors()
    editBox:AddAnchor("TOPLEFT", parent, scaledOffsetX, scaledInputOffsetY)
    editBox:SetMaxTextLength(maxLength)
    editBox:SetCursorColor(0, 0, 0, 1)
    if editBox.SetInset ~= nil then
        editBox:SetInset(textLeftInset, 0, 0, 0)
    end
    editBox:UseSelectAllWhenFocused(false)
    editBox:Show(true)

    if transparent then
        editBox:SetExtent(scaledWidth, scaledHeight)
        if editBox.bg ~= nil then
            editBox.bg:SetColor(1, 1, 1, 0)
        end
        if editBox.SetInset ~= nil then
            editBox:SetInset(textLeftInset, 0, 0, 0)
        end
    end

    if placeholder then
        placeholder = "  "..placeholder -- add some padding to the placeholder text
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

function widgets.createLabel(id, parent, text, offsetX, offsetY, fontSize, transparent, fontcolor, width, height)
    local label = api.Interface:CreateWidget('label', id, parent)
    if label == nil then
        log.DevLog("Failed to create label with id: " .. id)
        return nil
    end
    offsetX = offsetX or 0
    offsetY = offsetY or 0
    offsetX = offsetX * settingsModule.Get("uiDrawScale")
    offsetY = offsetY * settingsModule.Get("uiDrawScale")
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

function widgets.CreateListTable(parent, offsetX, offsetY, Headers)
    local listTable = {}
    listTable.parent = parent
    listTable.LabelsPool = {}
    listTable.ButtonsPool = {}
    listTable.colConfigs = {}
    listTable.colSizes = {}
    listTable.LabelsInUse = {}
    listTable.ButtonsInUse = {}
    listTable._LabelCounter = 0
    listTable._ButtonCounter = 0
    listTable._IsVisible = true
    listTable._OffsetX = offsetX or 0
    listTable._OffsetY = offsetY or 0
    listTable._Headers = Headers or {}
    listTable._PageNumber = 0
    listTable._ItemsPerPage = 0
    listTable.IsVisible = function() return listTable._IsVisible end
    listTable.setColSize = function(col, size)
        listTable.colSizes[col] = size
    end
    listTable.SetPageControl = function(PageNumber, ItemsPerPage)
        listTable._PageNumber = PageNumber or 0
        listTable._ItemsPerPage = ItemsPerPage or 0
    end
    listTable.ConfigCol = function(col, isButtonA, OnClickCallback)
        OnClickCallback = OnClickCallback or nil
        isButtonA = isButtonA or false
        local colConfig = {
            isButton = isButtonA,
            OnClickCallback = OnClickCallback,
        }
        listTable.colConfigs[col] = colConfig
    end
    listTable.GetLabelFromPool = function()
        local label = nil
        if #listTable.LabelsPool > 0 then
            label = table.remove(listTable.LabelsPool, 1)
        end
        if label == nil then
            listTable._LabelCounter = listTable._LabelCounter + 1
            label = widgets.createLabel("listTableLabel"..tostring(listTable._LabelCounter), listTable.parent, "", 0, 0, 14)
        end
        return label
    end
    listTable.GetButtonFromPool = function()
        local button = nil
        if #listTable.ButtonsPool > 0 then
            button = table.remove(listTable.ButtonsPool, 1)
        end
        if button == nil then
            listTable._ButtonCounter = listTable._ButtonCounter + 1
            button = widgets.createButton("listTableButton"..tostring(listTable._ButtonCounter), listTable.parent, "", 0, 0)
        end

        return button
    end
    listTable.Show = function(status)
        status = status or false
        log.DevLog("setting "..#listTable.LabelsInUse.." labels and "..#listTable.ButtonsInUse.." buttons to visible="..tostring(status))
        for _, lbl in pairs(listTable.LabelsInUse) do
            lbl:Show(status)
        end
        for _, btn in pairs(listTable.ButtonsInUse) do
            btn:Show(status)
        end
        listTable._IsVisible = status
    end
    listTable.Update = function(data)
        listTable.ClearPage()
        local currentX = listTable._OffsetX
        local currentY = listTable._OffsetY
        for index, header in pairs(listTable._Headers) do
            log.DevLog("Creating header label for column " .. tostring(index) .. ": " .. tostring(header))
            local label = listTable.GetLabelFromPool()
            if label == nil then
                log.DevLog("Failed to get label from pool for header: " .. tostring(header))
                return
            end
            label:SetText(header)
            label:RemoveAllAnchors()
            label:AddAnchor("TOPLEFT", listTable.parent, currentX, currentY)
            table.insert(listTable.LabelsInUse, label)
            currentX = currentX + (listTable.colSizes[index] or 150)
            log.DevLog("done with header " .. tostring(index))
        end
        currentY = currentY + 30
        local entrysAdded = 0
        local skipToIndex = listTable._PageNumber * listTable._ItemsPerPage
        local totalPages = 0
        if listTable._ItemsPerPage > 0 then
            totalPages = math.ceil(#data / listTable._ItemsPerPage)
        end

        for rowindex, entry in pairs(data) do
            if rowindex >= skipToIndex then
                currentX = listTable._OffsetX
                for columnIndex, cell in pairs(entry) do
                    local localcolConfig = listTable.colConfigs[columnIndex]
                    if localcolConfig ~= nil and localcolConfig.isButton == true then
                        local button = listTable.GetButtonFromPool()
                        if button == nil then
                            log.DevLog("Failed to get button from pool for cell: " .. tostring(cell))
                            return
                        end
                        button:SetExtent((listTable.colSizes[columnIndex] or 150) - 10, 30)
                        button:SetText(tostring(cell))
                        button:RemoveAllAnchors()
                        button:AddAnchor("TOPLEFT", listTable.parent, currentX, currentY+10)
                        if localcolConfig.OnClickCallback ~= nil then
                            function button:OnClick()
                                localcolConfig.OnClickCallback(rowindex, columnIndex)
                            end
                            button:SetHandler("OnClick", button.OnClick)
                        end
                        table.insert(listTable.ButtonsInUse, button)
                    else
                        local cellText = tostring(cell)
                        if string.find(cellText, "\n", 1, true) then
                            local lineOffsetY = 0
                            for line in string.gmatch(cellText, "[^\r\n]+") do
                                local label = listTable.GetLabelFromPool()
                                if label == nil then
                                    log.DevLog("Failed to get label from pool for cell line: " .. tostring(line))
                                    return
                                end
                                label:SetText(tostring(line))
                                label:RemoveAllAnchors()
                                label:AddAnchor("TOPLEFT", listTable.parent, currentX, currentY + lineOffsetY)
                                table.insert(listTable.LabelsInUse, label)
                                lineOffsetY = lineOffsetY + 20
                            end
                        else
                            local label = listTable.GetLabelFromPool()
                            if label == nil then
                                log.DevLog("Failed to get label from pool for cell: " .. tostring(cellText))
                                return
                            end
                            label:SetText(cellText)
                            label:RemoveAllAnchors()
                            label:AddAnchor("TOPLEFT", listTable.parent, currentX, currentY)
                            table.insert(listTable.LabelsInUse, label)
                        end
                    end
                    currentX = currentX + (listTable.colSizes[columnIndex] or 150)
                end
                currentY = currentY + 63
                entrysAdded = entrysAdded + 1
                if listTable._ItemsPerPage > 0 and entrysAdded >= listTable._ItemsPerPage then
                    break
                end
            end
        end
        if totalPages > 0 then
            local centering = 50
            local BackButton = listTable.GetButtonFromPool()
            if BackButton == nil then
                log.DevLog("Failed to get button from pool for back button")
                return
            end
            BackButton:SetExtent(100, 30)
            BackButton:SetText("Back a page")
            BackButton:RemoveAllAnchors()
            BackButton:AddAnchor("TOPLEFT", listTable.parent, 20, currentY+10)
            function BackButton:OnClick()
                if listTable._PageNumber > 0 then
                    listTable.SetPageControl(listTable._PageNumber - 1, listTable._ItemsPerPage)
                    listTable.Update(data)
                end
            end
            BackButton:SetHandler("OnClick", BackButton.OnClick)
            BackButton:Enable(listTable._PageNumber > 0)
            table.insert(listTable.ButtonsInUse, BackButton)
            local PageIndicator = listTable.GetLabelFromPool()
            if PageIndicator == nil then
                log.DevLog("Failed to get label from pool for page indicator")
                return
            end
            PageIndicator:SetText("Page "..tostring(listTable._PageNumber + 1).." of "..tostring(totalPages))
            PageIndicator:RemoveAllAnchors()
            PageIndicator:AddAnchor("TOPLEFT", listTable.parent, listTable._OffsetX + 160 + centering, currentY + 10)
            table.insert(listTable.LabelsInUse, PageIndicator)
            local NextButton = listTable.GetButtonFromPool()
            if NextButton == nil then
                log.DevLog("Failed to get button from pool for next button")
                return
            end
            NextButton:SetExtent(100, 30)
            NextButton:SetText("Next page")
            NextButton:RemoveAllAnchors()
            NextButton:AddAnchor("TOPRIGHT", listTable.parent, -20, currentY+10)
            function NextButton:OnClick()
                if listTable._PageNumber < totalPages - 1 then
                    listTable.SetPageControl(listTable._PageNumber + 1, listTable._ItemsPerPage)
                    listTable.Update(data)
                end
            end
            NextButton:SetHandler("OnClick", NextButton.OnClick)
            NextButton:Enable(listTable._PageNumber < totalPages - 1)
            table.insert(listTable.ButtonsInUse, NextButton)
        end
        listTable.Show(true)
    end
    listTable.ClearPage = function()
        for _, lbl in pairs(listTable.LabelsInUse) do
            lbl:Show(false)
            table.insert(listTable.LabelsPool, lbl)
        end
        listTable.LabelsInUse = {}
        for _, btn in pairs(listTable.ButtonsInUse) do
            btn:Show(false)
            table.insert(listTable.ButtonsPool, btn)
        end
        listTable.ButtonsInUse = {}
    end
    return listTable

end

function widgets.makeWindowDraggable(dragTarget, OnStartCallback, OnEndCallback, MoveEnableWithShift, SavePosition, SavePositionXKey, SavePositionYKey, DisableParentBinding, DisableBlockDragIfNotShift)
    DisableParentBinding = DisableParentBinding or false
    DisableBlockDragIfNotShift = DisableBlockDragIfNotShift or false

    if dragTarget.RegisterForDrag == nil and dragTarget.EnableDrag == nil then
        log.DevLog("makeWindowDraggable: Drag target does not support dragging")
		return
    end

    local moveTarget = dragTarget
    if dragTarget.parent ~= nil and DisableParentBinding == false then
        moveTarget = dragTarget.parent
    end

    if moveTarget.StartMoving == nil or moveTarget.StopMovingOrSizing == nil then
        log.DevLog("makeWindowDraggable: Drag target does not support movement")
        return
    end

	function dragTarget:OnDragStart()
        local moveEnabled = true
        if MoveEnableWithShift then
            moveEnabled = api.Input:IsShiftKeyDown()
        end
		if moveEnabled == false and DisableBlockDragIfNotShift == false then
           	return
		end
        if moveEnabled == true then
            moveTarget:StartMoving()
            api.Cursor:ClearCursor()
            api.Cursor:SetCursorImage(CURSOR_PATH.MOVE, 0, 0)
        end
		if OnStartCallback ~= nil then
			OnStartCallback()
		end
    end

    function dragTarget:OnDragStop()
		moveTarget:StopMovingOrSizing()
        api.Cursor:ClearCursor()
        if SavePosition then
			local x, y = moveTarget:GetEffectiveOffset()
            if SavePositionXKey then
                settingsModule.Update(SavePositionXKey, x)
            end
            if SavePositionYKey then
                settingsModule.Update(SavePositionYKey, y)
            end
        end
		if OnEndCallback ~= nil then
			local x, y = moveTarget:GetEffectiveOffset()
			OnEndCallback(x, y)
		end
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

return widgets
