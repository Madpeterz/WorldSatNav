local api = require("api")
local settingsModule = require("WorldSatNav/core/settings")
local helpers = require("WorldSatNav/helpers")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")
local constants = require("WorldSatNav/core/constants")
local maprendering = require("WorldSatNav/ui/maprendering")

local dawnsdropTypes = {
    ["Logging"] = {
        "Sequoia",
        "Spruce",
        "Rubber",
        "Larch",
        "Beech",
        "Camphor",
        "Bamboo",
        "Ebony",
        "Oak",
        "Ash",
        "Juniper",
        "Willow",
        "Fir",
        "Cedar",
        "Hornbeam",
        "Pine",
        "Aspen"
    },
    ["Farming"] = {
        "Rice Plant",
        "Millet",
        "Barley",
        "Corn",
        "Potato",
        "Carrot",
        "Garlic",
        "Onion",
        "Cucumber",
        "Tomato",
        "Oats",
        "Wheat",
        "Rye",
        "Peanut",
        "Strawberry",
        "Pumpkin",
        "Quinoa",
        "Bean",
        "Blueberry",
    },
    ["Gathering"] = {
        "Pearl Oyster",
        "Ginkgo Tree",
        "Moringa Tree",
        "Apple Tree",
        "Avocado Tree",
        "Palm Tree",
        "Orange Tree",
        "Olive Tree",
        "Bay Tree",
        "Apricot Tree",
        "Pomegranate Tree",
        "Cherry Tree",
        "Chestnut Tree",
        "Lemon Tree",
        "Fig Tree",
        "Banana Tree",
        "Baobab Tree",
        "Jujube Tree",
        "Cottonwood Tree",
        "Lavender",
        "Narcissus",
        "Azalea",
        "Clover",
        "Rose",
        "Iris",
        "Thistle",
        "Mushroom",
        "Cotton",
        "Rosemary",
        "Cornflower",
        "Lily",
        "Sunflower",
        "Lotus",
        "Mint",
        "Aloe",
        "Cactus",
        "Poppy",
        "Turmeric",
        "Saffron",
        "Chili Pepper",
        "Cultivated Ginseng",
        "Black Pepper",
        "Red Flower",
        "Blue Flower",
    },
    ["Exploration"] = {
        "Old Jar",
        "Old Relic Container",
        "Explorers Bag",
    },
    ["Resources"] = {
        "Mineral Water",
        "Burning Log",
        "Mysterious Crate"
    },
    ["Mining"] = {
        "Iron Vein",
    }
}

local dawnsdrop = {}

local dawnsdropWindow = nil
local TYPE_LABEL = ">"

local DawnsMapMode = "Select"
local DEV_MODE_BUTTON_LABELS = { "Add", "Select", "Ignore" }
local DEV_MODE_BUTTON_IDS = { "dawnsAddModeButton", "dawnsSelectModeButton", "dawnsIgnoreModeButton" }
local devModeButtonsBackground = nil
local markHereButton = nil

local function SetDawnsMapMode(mode)
	DawnsMapMode = mode
end

local function GetTaskNames()
	local names = {}
	for taskName, _ in pairs(dawnsdropTypes) do
		table.insert(names, taskName)
	end
	table.sort(names)
	return names
end

local function PopulateTypeComboBox(task)
	if dawnsdropWindow == nil or dawnsdropWindow.typeCombo == nil then
		return
	end
	local items = dawnsdropTypes[task]
	if items == nil then
		dawnsdropWindow.typeCombo:Show(false)
		return
	end
	dawnsdropWindow.typeCombo.dropdownItem = items
	dawnsdropWindow.typeCombo:Show(true)
	dawnsdropWindow.typeCombo:Select(1)
end

local function GetDataFilePath(task, itemType)
	return "WorldSatNav/data/Dawnsdrop/" .. task .. "/" .. itemType .. ".dat"
end

local function LoadLocations(task, itemType)
	local path = GetDataFilePath(task, itemType)
	return api.File:Read(path) or {}
end

local function RenderTypeLocations(task, itemType)
	local locations = LoadLocations(task, itemType)
	local iconsData = {}
	for _, entry in ipairs(locations) do
		local texture = "icons/marker1.png"
		local iconSize = 5
		if entry.group == 2 then
			texture = "icons/marker2.png"
			iconSize = 8
		elseif entry.group == 3 then
			texture = "icons/marker3.png"
			iconSize = 9
		end
		table.insert(iconsData, {
			sextant = entry.location,
			texture = texture,
			sourceType = "Dawnsdrop " .. task .. " - " .. itemType,
            customIconSize = iconSize,
		})
	end
	eventbus.TriggerEvent(eventtopics.topics.icons.BulkDrawIconsAndRedraw, iconsData)
end

local function OnTaskSelected(task)
	if task == nil then
		return
	end
	settingsModule.Update("DawnsLastTask", task)
	eventbus.TriggerEvent(eventtopics.topics.dawnsdrop.selectTypeChanged, task)
	PopulateTypeComboBox(task)
end

local function OnTypeSelected(itemType)
	if itemType == nil or dawnsdropWindow == nil then
		return
	end
	local task = helpers.getComboBoxValue(dawnsdropWindow.taskCombo)
	settingsModule.Update("DawnsLastType", itemType)
	eventbus.TriggerEvent(eventtopics.topics.dawnsdrop.selectItemChanged, task, itemType)
	if task ~= nil then
		RenderTypeLocations(task, itemType)
	end
end

-- Finds the closest stored location to a click, within a 10px on-screen tolerance.
local function FindClosestLocationIndex(locations, clickedSextant, mapInfo)
	local clickedX, clickedY = maprendering.convertSextantToMapCoordinates(clickedSextant, mapInfo)
	if clickedX == nil or clickedY == nil then
		return nil
	end
	local closestIndex = nil
	local closestDistance = nil
	for index, entry in ipairs(locations) do
		local x, y = maprendering.convertSextantToMapCoordinates(entry.location, mapInfo)
		if x ~= nil and y ~= nil then
			local distance = math.sqrt(((x - clickedX) ^ 2) + ((y - clickedY) ^ 2))
			if closestDistance == nil or distance < closestDistance then
				closestDistance = distance
				closestIndex = index
			end
		end
	end
	if closestIndex == nil or closestDistance > 10 then
		return nil
	end
	return closestIndex
end

-- Clicking an existing location upgrades its marker tier (1 -> 2 -> 3), and
-- clicking it again at tier 3 removes it entirely (next click there starts
-- fresh at tier 1). Clicking empty space adds a new tier-1 location.
local function AddOrUpgradeLocation(task, itemType, clickedSextant)
	local path = GetDataFilePath(task, itemType)
	local locations = LoadLocations(task, itemType)
	local mapInfo = maprendering.GetMapInfoForZoom(maprendering.GetCurrentZoomLevel())
	local closestIndex = FindClosestLocationIndex(locations, clickedSextant, mapInfo)
	if closestIndex ~= nil then
		local entry = locations[closestIndex]
		if entry.group >= 3 then
			table.remove(locations, closestIndex)
			helpers.DevLog("Removed dawnsdrop location at " .. path)
		else
			entry.group = entry.group + 1
			helpers.DevLog("Upgraded dawnsdrop location to group " .. entry.group .. " at " .. path)
		end
	else
		table.insert(locations, { location = clickedSextant, group = 1 })
		helpers.DevLog("Added dawnsdrop location to " .. path)
	end
	api.File:Write(path, locations)
	RenderTypeLocations(task, itemType)
end

local function OnMapClicked(sextant)
	if sextant == nil or dawnsdropWindow == nil then
		return
	end
	if DawnsMapMode ~= "Add" then
		return
	end
	local task = helpers.getComboBoxValue(dawnsdropWindow.taskCombo)
	local itemType = helpers.getComboBoxValue(dawnsdropWindow.typeCombo)
	if task == nil or itemType == nil then
		helpers.DevLog("Cannot modify dawnsdrop location, task or type is not selected")
		return
	end
	AddOrUpgradeLocation(task, itemType, sextant)
end

local function CreateUI(parent, width, height)
	local uiScale = settingsModule.Get("uiDrawScale")
	local windowWidth = width
	local windowHeight = 50 * uiScale
	local rowY = 10 * uiScale
	local sideMargin = 10 * uiScale
	local arrowWidth = 20 * uiScale
	local comboHeight = 29 * uiScale
	local comboWidth = (windowWidth - (sideMargin * 2) - arrowWidth) / 2

	local window = api.Interface:CreateEmptyWindow("dawnsdropWindow", parent)
	window:SetExtent(windowWidth, windowHeight)
	window:AddAnchor("TOPLEFT", parent, 0, height)
	window.Background = window:CreateImageDrawable("dawnsdropBackground", "background")
	window.Background:SetExtent(windowWidth, windowHeight)
	window.Background:AddAnchor("TOPLEFT", window, "TOPLEFT", 0, 0)
	window.Background:SetTexture(api.baseDir .. "/WorldSatNav/images/mainuibackground3.png")
	window.Background:SetColor(1, 1, 1, 0.9)
	window.Background:Show(true)
	window:Show(false)

	local taskNames = GetTaskNames()
	window.taskCombo = helpers.CreateComboBox(window, taskNames, sideMargin, rowY, comboWidth, comboHeight, false, FONT_COLOR.BLACK, taskNames[1], nil, "dawnsdropTaskCombo")
	local originalTaskSelect = window.taskCombo.Select
	function window.taskCombo:Select(index)
		originalTaskSelect(self, index)
		OnTaskSelected(helpers.getComboBoxValue(self))
	end

	local arrowX = sideMargin + comboWidth
	window.typeArrow = helpers.createLabel("dawnsdropTypeArrow", window, TYPE_LABEL, arrowX, rowY + (comboHeight / 4), 14, false, FONT_COLOR.BLACK)

	local typeComboX = arrowX + arrowWidth
	window.typeCombo = helpers.CreateComboBox(window, {}, typeComboX, rowY, comboWidth, comboHeight, false, FONT_COLOR.BLACK, nil, nil, "dawnsdropTypeCombo")
	window.typeCombo:Show(false)
	local originalTypeSelect = window.typeCombo.Select
	function window.typeCombo:Select(index)
		originalTypeSelect(self, index)
		OnTypeSelected(helpers.getComboBoxValue(self))
	end

	return window
end

local function CreateDevModeButtons(mapUI)
	local uiScale = settingsModule.Get("uiDrawScale")
	local margin = 5
	local spacing = 115
	local y = -30
	local markHereX = margin + (#DEV_MODE_BUTTON_LABELS * spacing)
	local rowWidth = markHereX + 65

	devModeButtonsBackground = mapUI:CreateImageDrawable("dawnsdropDevModeBackground", "background")
	devModeButtonsBackground:SetExtent(rowWidth * uiScale, 26 * uiScale)
	devModeButtonsBackground:AddAnchor("TOPLEFT", mapUI, "TOPLEFT", (margin - 5) * uiScale, (y - 3) * uiScale)
	devModeButtonsBackground:SetTexture(api.baseDir .. "/WorldSatNav/images/mainuibackground3.png")
	devModeButtonsBackground:SetColor(1, 1, 1, 0.9)
	devModeButtonsBackground:Show(false)

	for index, label in ipairs(DEV_MODE_BUTTON_LABELS) do
		local id = DEV_MODE_BUTTON_IDS[index]
		local x = margin + ((index - 1) * spacing)
		helpers.CreateSkinnedCheckbox(id, mapUI, label, x, y, label == DawnsMapMode, function()
			SetDawnsMapMode(label)
			if dawnsdropWindow ~= nil then
				local task = helpers.getComboBoxValue(dawnsdropWindow.taskCombo)
				local itemType = helpers.getComboBoxValue(dawnsdropWindow.typeCombo)
				if task ~= nil and itemType ~= nil then
					RenderTypeLocations(task, itemType)
				end
			end
		end, nil, nil, "DawnsMapMode", nil, true)
		helpers.ToggleCheckboxVisable(id, false)
	end

	-- createButton doesn't scale its offsets internally (unlike CreateSkinnedCheckbox), so pre-scale here to line up with the row above.
	markHereButton = helpers.createButton("dawnsMarkHereButton", mapUI, "Mark here", markHereX * uiScale, y * uiScale)
	markHereButton:Raise()
	markHereButton:SetHandler("OnClick", function()
		local task = dawnsdropWindow ~= nil and helpers.getComboBoxValue(dawnsdropWindow.taskCombo) or nil
		local itemType = dawnsdropWindow ~= nil and helpers.getComboBoxValue(dawnsdropWindow.typeCombo) or nil
		if task == nil or itemType == nil then
			helpers.DevLog("Cannot mark location, task or type is not selected")
			return
		end
		local playerSextant = maprendering.GetPlayerPosition()
		if playerSextant == nil then
			helpers.DevLog("Cannot mark location, player position unavailable")
			return
		end
		AddOrUpgradeLocation(task, itemType, playerSextant)
	end)
	markHereButton:Show(false)
end

local function ShowDevModeButtons(visible)
	if visible and constants.DEV_MODE ~= true then
		visible = false
	end
	for _, id in ipairs(DEV_MODE_BUTTON_IDS) do
		helpers.ToggleCheckboxVisable(id, visible)
	end
	if devModeButtonsBackground ~= nil then
		devModeButtonsBackground:Show(visible)
	end
	if markHereButton ~= nil then
		markHereButton:Show(visible)
		markHereButton:Enable(visible)
	end
end

local function MainUIReady(MainUI)
	if MainUI == nil then
		helpers.DevLog("MainUIReady event triggered but MainUI is nil")
		return
	end
	local width = MainUI:GetWidth()
	local height = MainUI:GetHeight()
	dawnsdropWindow = CreateUI(MainUI, width, height)
	CreateDevModeButtons(MainUI)
end

function dawnsdrop.RequestDawnsDropForRender()
	if dawnsdropWindow == nil then
		helpers.DevLog("Dawnsdrop window not initialized yet")
		return
	end
	local taskNames = GetTaskNames()
	local savedTask = settingsModule.Get("DawnsLastTask")
	if savedTask == nil or savedTask == "" or dawnsdropTypes[savedTask] == nil then
		savedTask = taskNames[1]
	end
	-- Cache the saved type before selecting the task: selecting a task
	-- repopulates and auto-selects the type combo, which overwrites
	-- DawnsLastType with that default before we get a chance to restore it.
	local savedType = settingsModule.Get("DawnsLastType")
	if dawnsdropWindow.taskCombo ~= nil and savedTask ~= nil then
		helpers.SelectComboBoxByText(dawnsdropWindow.taskCombo, savedTask, taskNames[1])
	end
	if dawnsdropWindow.typeCombo ~= nil and savedType ~= nil and savedType ~= "" then
		helpers.SelectComboBoxByText(dawnsdropWindow.typeCombo, savedType)
	end
	dawnsdropWindow:Show(true)
	SetDawnsMapMode("Select")
	helpers.SetCheckboxState("dawnsSelectModeButton", true)
	helpers.SetCheckboxState("dawnsAddModeButton", false)
	helpers.SetCheckboxState("dawnsIgnoreModeButton", false)
	ShowDevModeButtons(true)
end

function dawnsdrop.HideUI()
	ShowDevModeButtons(false)
	if dawnsdropWindow == nil then
		return
	end
	dawnsdropWindow:Show(false)
end

function dawnsdrop.GetDawnsMapMode()
	return DawnsMapMode
end

local function OnDevModeChanged(devModeEnabled)
	if dawnsdropWindow == nil or not dawnsdropWindow:IsVisible() then
		return
	end
	ShowDevModeButtons(devModeEnabled == true)
end

function dawnsdrop.OnLoad()
	eventbus.WatchEvent(eventtopics.topics.UI.MainUILoaded, MainUIReady, "dawnsdrop")
	eventbus.WatchEvent(eventtopics.topics.dev.modeChanged, OnDevModeChanged, "dawnsdrop")
	eventbus.WatchEvent(eventtopics.topics.render.modeChanged, dawnsdrop.HideUI, "dawnsdrop")
	eventbus.WatchEvent(eventtopics.topics.UI.close, dawnsdrop.HideUI, "dawnsdrop")
	eventbus.WatchEvent(eventtopics.topics.render.config, dawnsdrop.HideUI, "dawnsdrop")
	eventbus.WatchEvent(eventtopics.topics.render.dawnsdrop, dawnsdrop.RequestDawnsDropForRender, "dawnsdrop")
	eventbus.WatchEvent(eventtopics.topics.dawnsdrop.mapClick, OnMapClicked, "dawnsdrop")
	maprendering.RegisterDawnsMapModeProvider(dawnsdrop.GetDawnsMapMode)
end

function dawnsdrop.OnUnload()
	if dawnsdropWindow ~= nil then
		if dawnsdropWindow:IsVisible() then
			dawnsdropWindow:Show(false)
		end
		api.Interface:Free(dawnsdropWindow)
		dawnsdropWindow = nil
	end
end

return dawnsdrop
