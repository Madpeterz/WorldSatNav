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
local DEV_MODE_BUTTON_LABELS = { "Add", "Remove", "Select", "Ignore" }
local DEV_MODE_BUTTON_IDS = { "dawnsAddModeButton", "dawnsRemoveModeButton", "dawnsSelectModeButton", "dawnsIgnoreModeButton" }

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

local function RenderTypeLocations(task, itemType)
	local locations = api.File:Read(GetDataFilePath(task, itemType)) or {}
	local iconsData = {}
	for _, sextant in pairs(locations) do
		table.insert(iconsData, {
			sextant = sextant,
			texture = "icons/marker1.png",
			sourceType = "Dawnsdrop " .. task .. " - " .. itemType,
		})
	end
	eventbus.TriggerEvent(eventtopics.topics.icons.BulkDrawIconsAndRedraw, iconsData)
end

local function OnTaskSelected(task)
	if task == nil then
		return
	end
	eventbus.TriggerEvent(eventtopics.topics.dawnsdrop.selectTypeChanged, task)
	PopulateTypeComboBox(task)
end

local function OnTypeSelected(itemType)
	if itemType == nil or dawnsdropWindow == nil then
		return
	end
	local task = helpers.getComboBoxValue(dawnsdropWindow.taskCombo)
	eventbus.TriggerEvent(eventtopics.topics.dawnsdrop.selectItemChanged, task, itemType)
	if task ~= nil then
		RenderTypeLocations(task, itemType)
	end
end

local function AddLocationToFile(task, itemType, sextant)
	local path = GetDataFilePath(task, itemType)
	local locations = api.File:Read(path) or {}
	table.insert(locations, sextant)
	api.File:Write(path, locations)
	helpers.DevLog("Added dawnsdrop location to " .. path)
	RenderTypeLocations(task, itemType)
end

local function RemoveClosestLocation(task, itemType, clickedSextant)
	local path = GetDataFilePath(task, itemType)
	local locations = api.File:Read(path) or {}
	local mapInfo = maprendering.GetMapInfoForZoom(maprendering.GetCurrentZoomLevel())
	local clickedX, clickedY = maprendering.convertSextantToMapCoordinates(clickedSextant, mapInfo)
	if clickedX == nil or clickedY == nil then
		helpers.DevLog("Cannot remove dawnsdrop location, failed to convert clicked sextant to map coordinates")
		return
	end
	local closestIndex = nil
	local closestDistance = nil
	for index, sextant in pairs(locations) do
		local x, y = maprendering.convertSextantToMapCoordinates(sextant, mapInfo)
		if x ~= nil and y ~= nil then
			local distance = math.sqrt(((x - clickedX) ^ 2) + ((y - clickedY) ^ 2))
			if closestDistance == nil or distance < closestDistance then
				closestDistance = distance
				closestIndex = index
			end
		end
	end
	if closestIndex == nil or closestDistance > 10 then
		helpers.DevLog("No dawnsdrop location within range to remove")
		return
	end
	table.remove(locations, closestIndex)
	api.File:Write(path, locations)
	helpers.DevLog("Removed dawnsdrop location from " .. path)
	RenderTypeLocations(task, itemType)
end

local function OnMapClicked(sextant)
	if sextant == nil or dawnsdropWindow == nil then
		return
	end
	if DawnsMapMode ~= "Add" and DawnsMapMode ~= "Remove" then
		return
	end
	local task = helpers.getComboBoxValue(dawnsdropWindow.taskCombo)
	local itemType = helpers.getComboBoxValue(dawnsdropWindow.typeCombo)
	if task == nil or itemType == nil then
		helpers.DevLog("Cannot modify dawnsdrop location, task or type is not selected")
		return
	end
	if DawnsMapMode == "Add" then
		AddLocationToFile(task, itemType, sextant)
	elseif DawnsMapMode == "Remove" then
		RemoveClosestLocation(task, itemType, sextant)
	end
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
	if constants.DEV_MODE ~= true then
		return
	end
	local margin = 5
	local spacing = 115
	local y = 4
	for index, label in ipairs(DEV_MODE_BUTTON_LABELS) do
		local id = DEV_MODE_BUTTON_IDS[index]
		local x = margin + ((index - 1) * spacing)
		helpers.CreateSkinnedCheckbox(id, mapUI, label, x, y, label == DawnsMapMode, function()
			SetDawnsMapMode(label)
		end, nil, nil, "DawnsMapMode", nil, true)
		helpers.ToggleCheckboxVisable(id, false)
	end
end

local function ShowDevModeButtons(visible)
	if constants.DEV_MODE ~= true then
		return
	end
	for _, id in ipairs(DEV_MODE_BUTTON_IDS) do
		helpers.ToggleCheckboxVisable(id, visible)
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
	if dawnsdropWindow.taskCombo ~= nil and taskNames[1] ~= nil then
		helpers.SelectComboBoxByText(dawnsdropWindow.taskCombo, taskNames[1])
	end
	dawnsdropWindow:Show(true)
	SetDawnsMapMode("Select")
	helpers.SetCheckboxState("dawnsSelectModeButton", true)
	helpers.SetCheckboxState("dawnsAddModeButton", false)
	helpers.SetCheckboxState("dawnsRemoveModeButton", false)
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

function dawnsdrop.OnLoad()
	eventbus.WatchEvent(eventtopics.topics.UI.MainUILoaded, MainUIReady, "dawnsdrop")
	eventbus.WatchEvent(eventtopics.topics.render.modeChanged, dawnsdrop.HideUI, "dawnsdrop")
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
