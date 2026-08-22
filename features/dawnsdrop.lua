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
local devModeButtonsBackground = nil

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

local MIGRATION_ARC_MINUTE_IN_DEGREES = 7 / 60
local MIGRATION_GROUP_MIN_SIZE = 2 -- a legacy cluster bigger than this (3+) earns an upgraded tier

local function SextantToDecimalDegrees(sextant)
	local longValue = sextant.deg_long + (sextant.min_long / 60) + (sextant.sec_long / 3600)
	if sextant.longitude == "W" then
		longValue = -longValue
	end
	local latValue = sextant.deg_lat + (sextant.min_lat / 60) + (sextant.sec_lat / 3600)
	if sextant.latitude == "N" then
		latValue = -latValue
	end
	return longValue, latValue
end

-- Chain-clusters locations (accepts either bare legacy sextants or {location=..}
-- entries) within arcMinuteInDegrees of each other, then tags every real
-- location in a cluster with the tier its cluster size earns, instead of
-- collapsing the cluster down to a centroid.
local function RegroupLocationsByDistance(entries, arcMinuteInDegrees)
	local points = {}
	for _, entry in pairs(entries) do
		local sextant = entry.location or entry
		local long, lat = SextantToDecimalDegrees(sextant)
		table.insert(points, { long = long, lat = lat, sextant = sextant })
	end

	local assigned = {}
	local clusters = {}
	for i = 1, #points do
		if not assigned[i] then
			assigned[i] = true
			local cluster = { i }
			local queue = { i }
			while #queue > 0 do
				local currentIndex = table.remove(queue)
				local current = points[currentIndex]
				for j = 1, #points do
					if not assigned[j] then
						local other = points[j]
						local dLong = current.long - other.long
						local dLat = current.lat - other.lat
						local distance = math.sqrt((dLong * dLong) + (dLat * dLat))
						if distance <= arcMinuteInDegrees then
							assigned[j] = true
							table.insert(cluster, j)
							table.insert(queue, j)
						end
					end
				end
			end
			table.insert(clusters, cluster)
		end
	end

	local regrouped = {}
	for _, cluster in ipairs(clusters) do
		local group = 1
		if #cluster > MIGRATION_GROUP_MIN_SIZE then
			group = (#cluster >= 4) and 3 or 2
		end
		for _, index in ipairs(cluster) do
			table.insert(regrouped, { location = points[index].sextant, group = group })
		end
	end
	return regrouped
end

-- One-time conversion for files saved before locations carried a group tier.
local function MigrateLegacyLocations(legacyLocations)
	return RegroupLocationsByDistance(legacyLocations, MIGRATION_ARC_MINUTE_IN_DEGREES)
end

-- Reads the stored locations, migrating (and re-saving) legacy plain-sextant
-- files the first time they're encountered.
local function LoadLocations(task, itemType)
	local path = GetDataFilePath(task, itemType)
	local locations = api.File:Read(path) or {}
	if locations[1] ~= nil and locations[1].location == nil then
		helpers.DevLog("Migrating legacy dawnsdrop data at " .. path)
		locations = MigrateLegacyLocations(locations)
		api.File:Write(path, locations)
	end
	return locations
end

-- One-off: re-cluster Mining/Iron Vein at 10 arc minutes to thin out the icons
-- further than the 7' default gave. Guarded so it only ever runs once.
local function RegroupIronVeinOnce()
	if settingsModule.Get("DawnsIronVeinRegroupedAt10") == true then
		return
	end
	local task, itemType = "Mining", "Iron Vein"
	local locations = LoadLocations(task, itemType)
	locations = RegroupLocationsByDistance(locations, 10 / 60)
	api.File:Write(GetDataFilePath(task, itemType), locations)
	settingsModule.Update("DawnsIronVeinRegroupedAt10", true)
	helpers.DevLog("Re-grouped Mining/Iron Vein locations at 10 arc minutes")
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

-- Clicking an existing location upgrades its marker tier (1 -> 2 -> 3 -> 1);
-- clicking empty space adds a new tier-1 location.
local function AddOrUpgradeLocation(task, itemType, clickedSextant)
	local path = GetDataFilePath(task, itemType)
	local locations = LoadLocations(task, itemType)
	local mapInfo = maprendering.GetMapInfoForZoom(maprendering.GetCurrentZoomLevel())
	local closestIndex = FindClosestLocationIndex(locations, clickedSextant, mapInfo)
	if closestIndex ~= nil then
		local entry = locations[closestIndex]
		entry.group = (entry.group >= 3) and 1 or (entry.group + 1)
		helpers.DevLog("Upgraded dawnsdrop location to group " .. entry.group .. " at " .. path)
	else
		table.insert(locations, { location = clickedSextant, group = 1 })
		helpers.DevLog("Added dawnsdrop location to " .. path)
	end
	api.File:Write(path, locations)
	RenderTypeLocations(task, itemType)
end

local function RemoveClosestLocation(task, itemType, clickedSextant)
	local path = GetDataFilePath(task, itemType)
	local locations = LoadLocations(task, itemType)
	local mapInfo = maprendering.GetMapInfoForZoom(maprendering.GetCurrentZoomLevel())
	local closestIndex = FindClosestLocationIndex(locations, clickedSextant, mapInfo)
	if closestIndex == nil then
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
		AddOrUpgradeLocation(task, itemType, sextant)
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
	local uiScale = settingsModule.Get("uiDrawScale")
	local margin = 5
	local spacing = 115
	local y = -30
	local rowWidth = margin + (#DEV_MODE_BUTTON_LABELS * spacing) + 20

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
	if dawnsdropWindow.taskCombo ~= nil and savedTask ~= nil then
		helpers.SelectComboBoxByText(dawnsdropWindow.taskCombo, savedTask, taskNames[1])
	end
	local savedType = settingsModule.Get("DawnsLastType")
	if dawnsdropWindow.typeCombo ~= nil and savedType ~= nil and savedType ~= "" then
		helpers.SelectComboBoxByText(dawnsdropWindow.typeCombo, savedType)
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
	RegroupIronVeinOnce()
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
