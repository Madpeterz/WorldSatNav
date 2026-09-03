local api = require("api")
local settingsModule = require("WorldSatNav/core/settings")
local helpers = require("WorldSatNav/helpers")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")
local constants = require("WorldSatNav/core/constants")
local maprendering = require("WorldSatNav/ui/maprendering")
local regionmap = require("WorldSatNav/ui/regionmap")

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
    },
    ["Points of Interest"] = {
        "Teleports",
    },
}

local dawnsdrop = {}

local dawnsdropWindow = nil
local TYPE_LABEL = ">"

local DawnsMapMode = "Select"
local DEV_MODE_BUTTON_LABELS = { "Add", "Select", "Ignore" }
local DEV_MODE_BUTTON_IDS = { "dawnsAddModeButton", "dawnsSelectModeButton", "dawnsIgnoreModeButton" }
local devModeButtonsBackground = nil
local markHereButton = nil

-- Points of Interest / Teleports: always selectable, but new entries can only be
-- added in DEV_MODE. The side-tag row (west / east / shared) tags newly added markers.
local POI_TASK = "Points of Interest"
local POI_SIDE_BUTTON_LABELS = { "West only", "East only", "Shared" }
local POI_SIDE_BUTTON_IDS = { "dawnsPoiWestButton", "dawnsPoiEastButton", "dawnsPoiSharedButton" }
local POI_SIDE_VALUES = { "west", "east", "shared" }
local DawnsPoiSide = "shared"
local poiSideButtonsBackground = nil
local poiLocationNameInput = nil -- text box on the POI dev row; value stored as entry.locationName
local ShowPoiSideButtons -- forward declaration; assigned below

-- Current text of the POI location-name box, trimmed; nil when empty/unavailable.
local function GetPoiLocationName()
	if poiLocationNameInput == nil or poiLocationNameInput.GetText == nil then
		return nil
	end
	local text = poiLocationNameInput:GetText()
	if type(text) ~= "string" then
		return nil
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return nil
	end
	return text
end

local function SetDawnsMapMode(mode)
	DawnsMapMode = mode
end

local function SetDawnsPoiSide(value)
	DawnsPoiSide = value
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

-- Player factions on each continent. api.Unit:GetFactionName returns one of these
-- quoted names, not "Nuia" / "Haranya".
local FACTION_SIDE = {
	-- Nuia (West)
	["dreamwaker exiles"]  = "west", -- Elves (in-game spelling)
	["dreamwalker exiles"] = "west", -- Elves (alt spelling)
	["queen's crown"]      = "west", -- Nuians
	["andelph"]            = "west", -- Dwarves
	-- Haranya (East)
	["west ishvaran"]      = "east", -- Harani
	["wandering winds"]    = "east", -- Firran
	["repentant shadows"]  = "east", -- Warborn
}

-- Substring fallbacks, in case GetFactionName returns a variant spelling.
local FACTION_SIDE_HINTS = {
	{ "exile", "west" }, { "queen", "west" }, { "andelph", "west" }, { "nuia", "west" },
	{ "ishvaran", "east" }, { "wandering wind", "east" }, { "repentant", "east" }, { "haranya", "east" },
}

-- Maps the player's faction to a POI side key: "west" (Nuia) or "east" (Haranya).
-- Returns nil when the faction is unrecognised (e.g. pirate / player nation) so
-- filtering fails open rather than hiding every hint.
local function GetPlayerSideKey()
	local ok, faction = pcall(function() return api.Unit:GetFactionName("player") end)
	if not ok or type(faction) ~= "string" then
		return nil
	end
	local f = faction:lower()
	local side = FACTION_SIDE[f]
	if side == nil then
		for _, hint in ipairs(FACTION_SIDE_HINTS) do
			if f:find(hint[1], 1, true) then
				side = hint[2]
				break
			end
		end
	end
	helpers.DevLog("POI faction filter: GetFactionName='" .. tostring(faction) .. "' -> side=" .. tostring(side))
	return side
end

-- Returns true when a POI/Teleport entry is reachable by the player, given the
-- faction filter side ("west"/"east"/nil). "shared" entries and untagged legacy
-- entries (treated as "west") follow the same rules as RenderTypeLocations.
local function PoiEntryAllowed(entry, filterSide)
	if filterSide == nil then
		return true
	end
	local entrySide = entry.side or "west"
	return entrySide == "shared" or entrySide == filterSide
end

-- Finds the Teleport POI nearest to targetSextant that sits in the same region as
-- the target. When applyFilter is true, teleports the player's faction cannot use
-- are skipped. Returns { regionName, locationName, name (both joined for display),
-- location = sextant } or nil.
function dawnsdrop.FindNearestTeleport(targetSextant, applyFilter)
	if targetSextant == nil then
		return nil
	end
	local _, targetRegion = regionmap.GetRegionForSextant(targetSextant)
	if targetRegion == nil or targetRegion == "?" then
		return nil
	end

	local filterSide = nil
	if applyFilter then
		filterSide = GetPlayerSideKey()
	end

	local targetRegionLower = targetRegion:lower()
	local locations = LoadLocations(POI_TASK, "Teleports")

	-- Same-region test: trust the entry's stored regionName first (cheap string
	-- compare), and only fall back to deriving the region from the entry's sextant
	-- when regionName is missing or doesn't line up (legacy / mistyped entries).
	local function entryInTargetRegion(entry)
		local rn = entry.regionName
		if rn ~= nil and rn ~= "" and rn:lower() == targetRegionLower then
			return true
		end
		local _, entryRegion = regionmap.GetRegionForSextant(entry.location)
		return entryRegion == targetRegion
	end

	local best, bestDistSq = nil, math.huge
	for _, entry in ipairs(locations) do
		if entry.location ~= nil and PoiEntryAllowed(entry, filterSide) and entryInTargetRegion(entry) then
			local distSq = helpers.distSqToPlayer(entry.location, targetSextant)
			if distSq < bestDistSq then
				best, bestDistSq = entry, distSq
			end
		end
	end

	if best == nil then
		return nil
	end
	local regionName = best.regionName
	local locationName = best.locationName
	local name = locationName
	if regionName ~= nil and regionName ~= "" then
		name = (locationName ~= nil and locationName ~= "")
			and (regionName .. " / " .. locationName)
			or regionName
	end
	return {
		regionName = regionName,
		locationName = locationName,
		name = name,
		location = best.location,
	}
end

local function RenderTypeLocations(task, itemType)
	local locations = LoadLocations(task, itemType)
	local iconsData = {}

	-- Points of Interest can be limited to the player's faction:
	-- West = Nuia, East = Haranya, Shared = both. nil filter = show all.
	local poiSideFilter = nil
	if task == POI_TASK and settingsModule.Get("TeleportHintFiltered") ~= false then
		poiSideFilter = GetPlayerSideKey()
	end
	if task == POI_TASK then
		helpers.DevLog("RenderTypeLocations POI: setting="
			.. tostring(settingsModule.Get("TeleportHintFiltered"))
			.. " poiSideFilter=" .. tostring(poiSideFilter)
			.. " entries=" .. tostring(#locations))
	end

	for _, entry in ipairs(locations) do
		local entrySide = entry.side or "west" -- untagged legacy entries treated as west
		local hidden = task == POI_TASK and poiSideFilter ~= nil
			and entrySide ~= "shared" and entrySide ~= poiSideFilter
		if not hidden then
			local texture = "icons/marker1.png"
			local iconSize = 5
			if task == POI_TASK then
				-- Points of Interest markers use per-side object icons, not group tiers.
				iconSize = 8
				local objType = entrySide
				if objType ~= "east" and objType ~= "shared" then
					objType = "west" -- west / untagged
				end
				texture = "icons/tp_orb_" .. objType .. ".png"
			elseif entry.group == 2 then
				texture = "icons/marker2.png"
				iconSize = 8
			elseif entry.group == 3 then
				texture = "icons/marker3.png"
				iconSize = 9
			end
			table.insert(iconsData, {
				sextant = entry.location,
				texture = texture,
				sourceType = itemType,
	            customIconSize = iconSize,
			})
		end
	end
	eventbus.TriggerEvent(eventtopics.topics.icons.BulkDrawIconsAndRedraw, iconsData)
end

-- Re-render the icons for whatever task/type is currently selected. Used when an
-- external change (e.g. the "Teleport hint filtered" setting) affects visibility.
local function RerenderCurrentSelection()
	if dawnsdropWindow == nil or not dawnsdropWindow:IsVisible() then
		return
	end
	local task = helpers.getComboBoxValue(dawnsdropWindow.taskCombo)
	local itemType = helpers.getComboBoxValue(dawnsdropWindow.typeCombo)
	if task ~= nil and itemType ~= nil then
		RenderTypeLocations(task, itemType)
	end
end

local function OnTaskSelected(task)
	if task == nil then
		return
	end
	settingsModule.Update("DawnsLastTask", task)
	eventbus.TriggerEvent(eventtopics.topics.dawnsdrop.selectTypeChanged, task)
	PopulateTypeComboBox(task)
	if ShowPoiSideButtons ~= nil and dawnsdropWindow ~= nil and dawnsdropWindow:IsVisible() then
		ShowPoiSideButtons(true)
	end
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
-- Points of Interest have no tiers: clicking an existing one removes it outright.
-- When alwaysAdd is true (e.g. "Mark here"), always insert a fresh tier-1
-- location and never merge into or upgrade a nearby one.
local function AddOrUpgradeLocation(task, itemType, clickedSextant, alwaysAdd)
	local path = GetDataFilePath(task, itemType)
	local locations = LoadLocations(task, itemType)
	local mapInfo = maprendering.GetMapInfoForZoom(maprendering.GetCurrentZoomLevel())
	local closestIndex = nil
	if not alwaysAdd then
		closestIndex = FindClosestLocationIndex(locations, clickedSextant, mapInfo)
	end
	if closestIndex ~= nil then
		local entry = locations[closestIndex]
		if task == POI_TASK or entry.group >= 3 then
			-- Points of Interest have no tier steps: clicking an existing one removes it.
			table.remove(locations, closestIndex)
			helpers.DevLog("Removed dawnsdrop location at " .. path)
		else
			entry.group = entry.group + 1
			helpers.DevLog("Upgraded dawnsdrop location to group " .. entry.group .. " at " .. path)
		end
	else
		local entry = { location = clickedSextant, group = 1 }
		if task == POI_TASK then
			entry.side = DawnsPoiSide
			entry.locationName = GetPoiLocationName()
			local _, regionName = regionmap.GetRegionForSextant(clickedSextant)
			if regionName ~= nil and regionName ~= "?" then
				entry.regionName = regionName
			end
		end
		table.insert(locations, entry)
		helpers.DevLog("Added dawnsdrop location to " .. path
			.. (entry.side ~= nil and (" [" .. entry.side .. "]") or "")
			.. (entry.locationName ~= nil and (" '" .. entry.locationName .. "'") or ""))
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
		AddOrUpgradeLocation(task, itemType, playerSextant, true)
	end)
	markHereButton:Show(false)

	-- Second dev row: side tag + location-name box for Points of Interest markers.
	-- Only shown when DEV_MODE is on and the POI task is selected (see ShowPoiSideButtons).
	local poiRowY = y - 28
	local poiNameX = margin + (#POI_SIDE_BUTTON_LABELS * spacing)
	local poiNameWidth = 200
	local poiRowWidth = poiNameX + poiNameWidth + 10

	poiSideButtonsBackground = mapUI:CreateImageDrawable("dawnsdropPoiSideBackground", "background")
	poiSideButtonsBackground:SetExtent(poiRowWidth * uiScale, 26 * uiScale)
	poiSideButtonsBackground:AddAnchor("TOPLEFT", mapUI, "TOPLEFT", (margin - 5) * uiScale, (poiRowY - 3) * uiScale)
	poiSideButtonsBackground:SetTexture(api.baseDir .. "/WorldSatNav/images/mainuibackground3.png")
	poiSideButtonsBackground:SetColor(1, 1, 1, 0.9)
	poiSideButtonsBackground:Show(false)

	for index, label in ipairs(POI_SIDE_BUTTON_LABELS) do
		local id = POI_SIDE_BUTTON_IDS[index]
		local value = POI_SIDE_VALUES[index]
		local x = margin + ((index - 1) * spacing)
		helpers.CreateSkinnedCheckbox(id, mapUI, label, x, poiRowY, value == DawnsPoiSide, function()
			SetDawnsPoiSide(value)
		end, nil, nil, "DawnsPoiSide", nil, true)
		helpers.ToggleCheckboxVisable(id, false)
	end

	poiLocationNameInput = helpers.createTextInput("dawnsPoiLocationNameInput", mapUI, poiNameX, poiRowY,
		poiNameWidth, 22, "Location name", 60, nil, nil, false, FONT_COLOR.BLACK)
	if poiLocationNameInput ~= nil then
		poiLocationNameInput:Show(false)
	end
end

local function IsPoiTaskSelected()
	if dawnsdropWindow == nil or dawnsdropWindow.taskCombo == nil then
		return false
	end
	return helpers.getComboBoxValue(dawnsdropWindow.taskCombo) == POI_TASK
end

-- Assigns the forward-declared upvalue so callers defined earlier (OnTaskSelected)
-- can reach it.
ShowPoiSideButtons = function(visible)
	if visible and (constants.DEV_MODE ~= true or not IsPoiTaskSelected()) then
		visible = false
	end
	for _, id in ipairs(POI_SIDE_BUTTON_IDS) do
		helpers.ToggleCheckboxVisable(id, visible)
	end
	if poiSideButtonsBackground ~= nil then
		poiSideButtonsBackground:Show(visible)
	end
	if poiLocationNameInput ~= nil then
		poiLocationNameInput:Show(visible)
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
	if markHereButton ~= nil then
		markHereButton:Show(visible)
		markHereButton:Enable(visible)
	end
	ShowPoiSideButtons(visible)
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
	for index, id in ipairs(POI_SIDE_BUTTON_IDS) do
		helpers.SetCheckboxState(id, POI_SIDE_VALUES[index] == DawnsPoiSide)
	end
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
	eventbus.WatchEvent(eventtopics.topics.dawnsdrop.refresh, RerenderCurrentSelection, "dawnsdrop")
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
