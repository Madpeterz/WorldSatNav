local api = require("api")
local constants = require("WorldSatNav/constants")
local settingsModule = require("WorldSatNav/settings")
local coordinates = require("WorldSatNav/coordinates")

local helpers = {}
local defaultClickSoundKey = "auction_put_up"

local CheckBoxs = {}
helpers.CheckBoxs = CheckBoxs

function helpers.SecondsToTime(seconds)
    local hours = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = math.floor(seconds % 60)
    return hours, mins, secs
end

function helpers.distSqToPlayer(info, curCoords)
    if info == nil or curCoords == nil then
        return math.huge
    end
    local lonDir1 = info.longitudeDir or info.longitude
    local latDir1 = info.latitudeDir or info.latitude
    local degLong1 = info.longitudeDeg or info.deg_long or info.degLong
    local minLong1 = info.longitudeMin or info.min_long or info.minLong
    local secLong1 = info.longitudeSec or info.sec_long or info.secLong
    local degLat1 = info.latitudeDeg or info.deg_lat or info.degLat
    local minLat1 = info.latitudeMin or info.min_lat or info.minLat
    local secLat1 = info.latitudeSec or info.sec_lat or info.secLat

    local lonDir2 = curCoords.longitudeDir or curCoords.longitude
    local latDir2 = curCoords.latitudeDir or curCoords.latitude
    local degLong2 = curCoords.longitudeDeg or curCoords.deg_long or curCoords.degLong
    local minLong2 = curCoords.longitudeMin or curCoords.min_long or curCoords.minLong
    local secLong2 = curCoords.longitudeSec or curCoords.sec_long or curCoords.secLong
    local degLat2 = curCoords.latitudeDeg or curCoords.deg_lat or curCoords.degLat
    local minLat2 = curCoords.latitudeMin or curCoords.min_lat or curCoords.minLat
    local secLat2 = curCoords.latitudeSec or curCoords.sec_lat or curCoords.secLat

    if lonDir1 == nil or latDir1 == nil or lonDir2 == nil or latDir2 == nil then
        return math.huge
    end
    if degLong1 == nil or minLong1 == nil or secLong1 == nil or degLat1 == nil or minLat1 == nil or secLat1 == nil then
        return math.huge
    end
    if degLong2 == nil or minLong2 == nil or secLong2 == nil or degLat2 == nil or minLat2 == nil or secLat2 == nil then
        return math.huge
    end

    local lon1 = coordinates.toDecimalDegrees(lonDir1, degLong1 or 0, minLong1 or 0, secLong1 or 0)
    local lat1 = coordinates.toDecimalDegrees(latDir1, degLat1  or 0, minLat1  or 0, secLat1  or 0)
    local lon2 = coordinates.toDecimalDegrees(lonDir2, degLong2 or 0, minLong2 or 0, secLong2 or 0)
    local lat2 = coordinates.toDecimalDegrees(latDir2,  degLat2  or 0, minLat2  or 0, secLat2  or 0)
    return (lon1 - lon2)^2 + (lat1 - lat2)^2
end

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


function helpers.CreateImageButton(id, parent, texturenormal, offsetX, offsetY, sizeX, sizeY, onClickFunction, hasOnHover, onHoverTexture, onHoverTooltip, clickSoundKey)
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
            helpers.DevLog("CreateImageButton: Failed to create image drawable for '"..id.."'.")
            return button
        end
        image:AddAnchor("TOPLEFT", parent, offsetX, offsetY)
        image:SetExtent(sizeX, sizeY)
        image:SetTexture(texturePathNormal)
        image:Show(true)
    else
        helpers.DevLog("CreateImageButton: No texture provided for '"..id.."'.")
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

function helpers.SetCheckBoxOverride(id, overrideEnabled)
    if CheckBoxs[id] == nil then
        return
    end
    CheckBoxs[id].override = overrideEnabled
end

function helpers.CreateSkinnedCheckbox(id, parent, text, offsetX, offsetY, checked, onClickFunction, buttonSizeX, buttonSizeY, radioGroup, renderlayer, showText, customTextureChecked, customTextureUnchecked, clickSoundKey, OffsetTextX, OffsetTextY)    
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
            helpers.DevLog("Failed to create label for checkbox with id: " .. id)
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
            helpers.DevLog("Failed to create label button for checkbox with id: " .. id)
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
                     helpers.SetCheckboxState(cbId, false)
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
    if(cb.labelButton ~= nil) then
        cb.labelButton:Show(visable)
        cb.labelButton:Enable(visable)
    end
    cb.overlay:Show(visable)
end

-- Set a checkbox's visual state and internal checked value without firing its callback.
function helpers.SetCheckboxState(id, checked)
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

function helpers.createSkinnedButton(id, parent, text, texture, offsetX, offsetY, buttonSizeX, buttonSizeY, renderlayer, onClickFunction, clickSound, OffsetTextX, OffsetTextY)
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
            helpers.DevLog("Failed to create label for checkbox with id: " .. id)
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

local function unPackTimeStampSource()
    local timeSource = api.Time:GetLocalTime()
    if timeSource == nil then
        helpers.DevLog("WorldSatNav: Unable to get local time for timestamp, got nil")
        return nil
    end
    if type(timeSource) == "number" then
        return timeSource
    end
    local timeSourceC = tonumber(timeSource)
    if type(timeSourceC) == "number" then
        if timeSourceC > 1777395321 then
            return timeSourceC
        end
    end
    helpers.DevLog("WorldSatNav: Unable to parse local time for timestamp, got: " .. tostring(timeSourceC).." as type "..type(timeSource))
    return nil
end

function helpers.GetCurrentTimestamp()
    local localTime = unPackTimeStampSource()
    if localTime ~= nil then
        if calibratedTimeState.lastKnownLocalTime == nil or localTime > calibratedTimeState.lastKnownLocalTime then
            calibratedTimeState.lastKnownLocalTime = localTime
            calibratedTimeState.lastReturnedTimestamp = calibratedTimeState.lastKnownLocalTime
        end
    else
        helpers.DevLog("WorldSatNav: Falling back to previous timestamp due to invalid local time source")
    end
    return calibratedTimeState.lastReturnedTimestamp
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

local function unixToDateTable(timestamp)
    if os ~= nil and type(os.date) == "function" then
        local date = os.date("*t", timestamp)
        if type(date) == "table" then
            return {
                year = date.year,
                month = date.month,
                day = date.day,
                hour = date.hour,
                min = date.min,
                sec = date.sec,
            }
        end
    end

    local seconds = math.floor(timestamp)
    local days = math.floor(seconds / 86400)
    local rem = seconds - (days * 86400)
    local hour = math.floor(rem / 3600)
    rem = rem - (hour * 3600)
    local min = math.floor(rem / 60)
    local sec = rem - (min * 60)

    local function isLeapYear(value)
        if value % 400 == 0 then
            return true
        end
        if value % 100 == 0 then
            return false
        end
        return value % 4 == 0
    end

    local year = 1970
    while true do
        local daysInYear = isLeapYear(year) and 366 or 365
        if days < daysInYear then
            break
        end
        days = days - daysInYear
        year = year + 1
    end

    local daysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    if isLeapYear(year) then
        daysPerMonth[2] = 29
    end

    local month = 1
    while month <= 12 and days >= daysPerMonth[month] do
        days = days - daysPerMonth[month]
        month = month + 1
    end

    local day = days + 1

    return {
        year = year,
        month = month,
        day = day,
        hour = hour,
        min = min,
        sec = sec,
    }
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

function helpers.FormatTimestampToDateTime(timestamp)
    local numericTimestamp = tonumber(timestamp)
    helpers.DevLog("FormatTimestampToDateTime called with timestamp: " .. (numericTimestamp and string.format("%.0f", numericTimestamp) or tostring(timestamp)))
    if type(numericTimestamp) ~= "number" then
        return "Invalid Timestamp"
    end
    numericTimestamp = math.floor(numericTimestamp + 0.5)
    local dateTable = api.Time:TimeToDate(numericTimestamp)
    if dateTable == nil then
        dateTable = api.Time:TimeToDate(numericTimestamp * 1000)
    end
    if dateTable == nil then
        dateTable = api.Time:TimeToDate(numericTimestamp / 1000)
    end
    if dateTable == nil then
        local fallbackTimestamp = numericTimestamp
        if fallbackTimestamp > 100000000000 then
            fallbackTimestamp = math.floor((fallbackTimestamp / 1000) + 0.5)
        end
        dateTable = unixToDateTable(fallbackTimestamp)
    end
    if dateTable == nil then
        helpers.DevLog("FormatTimestampToDateTime: TimeToDate failed for " .. tostring(numericTimestamp))
        return "Invalid Date"
    end
    local year, month, day, hour, min, sec = extractDateParts(dateTable)
    if year == nil or month == nil or day == nil or hour == nil or min == nil or sec == nil then
        return "Invalid Date"
    end
    return string.format("%04d-%02d-%02d %02d:%02d:%02d", year, month, day, hour, min, sec)
end

function helpers.TimeRemaining(futureTimestamp, multilineOutput)
    multilineOutput = multilineOutput or false
    local currentTimestamp = helpers.GetCurrentTimestamp()
    local remainingSeconds = futureTimestamp - currentTimestamp
    if remainingSeconds <= 0 then
        return "Now/Passed"
    end
    remainingSeconds = math.floor(remainingSeconds + 0.5)
    local hours, mins, secs = helpers.SecondsToTime(remainingSeconds)
    if hours > 0 then
        if multilineOutput then
            return string.format("%d hours\n\r%d mins & %d secs", hours, mins, secs)
        end
        return string.format("%d hours, %d mins & %d secs", hours, mins, secs)
    end
    if mins > 0 then
        return string.format("%d mins & %d secs", mins, secs)
    end
    return string.format("%d secs", secs)
end

function helpers.getTodayDateText()
    local dateraw = api.Time:TimeToDate(api.Time:GetLocalTime())
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
        return nil, "Hour must be between 0 and 23. given value was: " .. tostring(hour)
    end
    if min < 0 or min > 59 then
        return nil, "Minute must be between 0 and 59. given value was: " .. tostring(min)
    end
    if sec < 0 or sec > 59 then
        return nil, "Second must be between 0 and 59. given value was: " .. tostring(sec)
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

local function adjustDateByDays(year, month, day, deltaDays)
    local function isLeapYear(value)
        if value % 400 == 0 then
            return true
        end
        if value % 100 == 0 then
            return false
        end
        return value % 4 == 0
    end

    local function daysInMonth(y, m)
        local daysPerMonth = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
        if m == 2 and isLeapYear(y) then
            return 29
        end
        return daysPerMonth[m]
    end

    year = tonumber(year)
    month = tonumber(month)
    day = tonumber(day)
    deltaDays = tonumber(deltaDays) or 0

    while deltaDays ~= 0 do
        if deltaDays > 0 then
            local dim = daysInMonth(year, month)
            if day < dim then
                day = day + 1
                deltaDays = deltaDays - 1
            else
                day = 1
                month = month + 1
                if month > 12 then
                    month = 1
                    year = year + 1
                end
                deltaDays = deltaDays - 1
            end
        else
            if day > 1 then
                day = day - 1
                deltaDays = deltaDays + 1
            else
                month = month - 1
                if month < 1 then
                    month = 12
                    year = year - 1
                end
                day = daysInMonth(year, month)
                deltaDays = deltaDays + 1
            end
        end
    end

    return year, month, day
end

local function dateTimeToUnixtime(year, month, day, hour, min, sec)
    local timestamp, errorMessage = dateTimeToUnixtimeUtcLike(year, month, day, hour, min, sec)
    if timestamp == nil then
        return nil, errorMessage
    end
    return timestamp
end

local function dateTimeToLocalUnixtime(year, month, day, hour, min, sec)
    if os ~= nil and type(os.time) == "function" then
        local timestamp = os.time({
            year = year,
            month = month,
            day = day,
            hour = hour or 0,
            min = min or 0,
            sec = sec or 0,
        })
        if timestamp ~= nil then
            return timestamp
        end
    end

    local timestamp, errorMessage = dateTimeToUnixtimeUtcLike(year, month, day, hour, min, sec)
    if timestamp == nil then
        return nil, errorMessage
    end

    local now = helpers.GetCurrentTimestamp()
    if type(now) ~= "number" then
        return timestamp
    end

    local nowDate = api.Time:TimeToDate(now)
    local nowYear, nowMonth, nowDay, nowHour, nowMin, nowSec = extractDateParts(nowDate)
    if nowYear == nil or nowMonth == nil or nowDay == nil or nowHour == nil or nowMin == nil or nowSec == nil then
        return timestamp
    end

    local utcLikeNow = dateTimeToUnixtimeUtcLike(nowYear, nowMonth, nowDay, nowHour, nowMin, nowSec)
    if utcLikeNow == nil then
        return timestamp
    end

    return timestamp + (now - utcLikeNow)
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
    if settingsModule.Get("DSToffset") == true then
         hour = hour - 1
    end

    if hour < 0 or hour > 23 then
        local dayShift = math.floor(hour / 24)
        hour = hour - (dayShift * 24)
        year, month, day = adjustDateByDays(year, month, day, dayShift)
    end

    return dateTimeToLocalUnixtime(year, month, day, hour, min, sec)
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

function helpers.CreateComboBox(parent, items, x, y, width, height, transparent, fontcolor, currentitem, labelText, id)
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
        labelWidget = helpers.createLabel(labelId, parent, labelText, x, y, 14, transparent, fontcolor)
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
        helpers.SelectComboBoxByText(cb, currentitem)
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
        labelWidget = helpers.createLabel(id .. "_label", parent, labelText, offsetX, offsetY, 14, transparent, fontcolor)
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
    editBox:SetCursorColor({0, 0, 0, 1})
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

function helpers.createLabel(id, parent, text, offsetX, offsetY, fontSize, transparent, fontcolor, width, height)
    local label = api.Interface:CreateWidget('label', id, parent)
    if label == nil then
        helpers.DevLog("Failed to create label with id: " .. id)
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

function helpers.CreateListTable(parent, offsetX, offsetY, Headers)
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
            label = helpers.createLabel("listTableLabel"..tostring(listTable._LabelCounter), listTable.parent, "", 0, 0, 14)
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
            button = helpers.createButton("listTableButton"..tostring(listTable._ButtonCounter), listTable.parent, "", 0, 0)
        end

        return button
    end
    listTable.Show = function(status)
        status = status or false
        helpers.DevLog("setting "..#listTable.LabelsInUse.." labels and "..#listTable.ButtonsInUse.." buttons to visible="..tostring(status))
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
            helpers.DevLog("Creating header label for column " .. tostring(index) .. ": " .. tostring(header))
            local label = listTable.GetLabelFromPool()
            if label == nil then
                helpers.DevLog("Failed to get label from pool for header: " .. tostring(header))
                return
            end
            label:SetText(header)
            label:RemoveAllAnchors()
            label:AddAnchor("TOPLEFT", listTable.parent, currentX, currentY)
            table.insert(listTable.LabelsInUse, label)
            currentX = currentX + (listTable.colSizes[index] or 150)
            helpers.DevLog("done with header " .. tostring(index))
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
                            helpers.DevLog("Failed to get button from pool for cell: " .. tostring(cell))
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
                                    helpers.DevLog("Failed to get label from pool for cell line: " .. tostring(line))
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
                                helpers.DevLog("Failed to get label from pool for cell: " .. tostring(cellText))
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
                helpers.DevLog("Failed to get button from pool for back button")
                return
            end
            BackButton:SetExtent(100, 30)
            BackButton:SetText("Back a page")
            BackButton:RemoveAllAnchors()
            BackButton:AddAnchor("TOPLEFT", listTable.parent, listTable._OffsetX+centering, currentY+10)
            function BackButton:OnClick()
                if listTable._PageNumber > 0 then
                    listTable.SetPageControl(listTable._PageNumber - 1, listTable._ItemsPerPage)
                    listTable.Update(data)
                end
            end
            BackButton:SetHandler("OnClick", BackButton.OnClick)
            table.insert(listTable.ButtonsInUse, BackButton)
            local PageIndicator = listTable.GetLabelFromPool()
            if PageIndicator == nil then
                helpers.DevLog("Failed to get label from pool for page indicator")
                return
            end
            PageIndicator:SetText("Page "..tostring(listTable._PageNumber + 1).." of "..tostring(totalPages))
            PageIndicator:RemoveAllAnchors()
            PageIndicator:AddAnchor("TOPLEFT", listTable.parent, listTable._OffsetX + 160 + centering, currentY + 10)
            table.insert(listTable.LabelsInUse, PageIndicator)
            local NextButton = listTable.GetButtonFromPool()
            if NextButton == nil then
                helpers.DevLog("Failed to get button from pool for next button")
                return
            end
            NextButton:SetExtent(100, 30)
            NextButton:SetText("Next page")
            NextButton:RemoveAllAnchors()
            NextButton:AddAnchor("TOPLEFT", listTable.parent, listTable._OffsetX + 320 + centering, currentY+10)
            function NextButton:OnClick()
                if listTable._PageNumber < totalPages - 1 then
                    listTable.SetPageControl(listTable._PageNumber + 1, listTable._ItemsPerPage)
                    listTable.Update(data)
                end
            end
            NextButton:SetHandler("OnClick", NextButton.OnClick)
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

function helpers.makeWindowDraggable(dragTarget, OnStartCallback, OnEndCallback, MoveEnableWithShift, SavePosition, SavePositionXKey, SavePositionYKey, DisableParentBinding, DisableBlockDragIfNotShift)
    DisableParentBinding = DisableParentBinding or false
    DisableBlockDragIfNotShift = DisableBlockDragIfNotShift or false

    if dragTarget.RegisterForDrag == nil and dragTarget.EnableDrag == nil then
        helpers.DevLog("makeWindowDraggable: Drag target does not support dragging")
		return
    end

    local moveTarget = dragTarget
    if dragTarget.parent ~= nil and DisableParentBinding == false then
        moveTarget = dragTarget.parent
    end

    if moveTarget.StartMoving == nil or moveTarget.StopMovingOrSizing == nil then
        helpers.DevLog("makeWindowDraggable: Drag target does not support movement")
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


function helpers.SextantKey(sextant)
	if sextant == nil then
		return "??000000"
	end
	local long = sextant.longitude or "?"
	local lat = sextant.latitude or "?"
	local degLong = sextant.deg_long or "0"
	local minLong = sextant.min_long or "0"
	local secLong = sextant.sec_long or "0"
	local degLat = sextant.deg_lat or "0"
	local minLat = sextant.min_lat or "0"
	local secLat = sextant.sec_lat or "0"
	local returnValue = string.format(
		"%s%s%s%s%s%s%s%s",
		tostring(long),
		tostring(degLong),
		tostring(minLong),
		tostring(secLong),
        tostring(lat),
		tostring(degLat),
		tostring(minLat),
		tostring(secLat)
	)
	return returnValue
end
return helpers
