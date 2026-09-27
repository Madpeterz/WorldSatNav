local api = require("api")
local helpers = require("WorldSatNav/helpers")
local settingsModule = require("WorldSatNav/core/settings")
local eventbus = require("WorldSatNav/core/eventbus")
local eventtopics = require("WorldSatNav/core/eventtopics")

local equip = {}

-- Finds the bag slot holding an item with this exact name, or nil.
-- Each slot read is guarded: a slot that errors (empty/locked) is skipped
-- rather than aborting the scan.
local function findBagSlotByName(name)
	local ok, capacity = pcall(function() return api.Bag:Capacity() end)
	if not ok or type(capacity) ~= "number" then
		return nil
	end
	for index = 1, capacity do
		local okInfo, info = pcall(function() return api.Bag:GetBagItemInfo(1, index) end)
		if okInfo and type(info) == "table" and info.name == name then
			return index
		end
	end
	return nil
end

local function swapTitle(mode)
	local titleId = tonumber(settingsModule.Get("title_id_"..mode))
	if titleId ~= nil then
		api.Player:ChangeAppellation(titleId)
	end
end

local function swapEquipment(mode)
	local itemName = settingsModule.Get("equipment_"..mode)
	if itemName == nil or itemName == "" then
		return
	end
	local slot = findBagSlotByName(itemName)
	if slot ~= nil then
		api.Bag:EquipBagItem(slot, false)
	else
		helpers.DevLog("equip: '"..tostring(itemName).."' not found in bag")
	end
end

-- mode: "swim" or "normal". Applies whichever swaps are enabled in settings.
-- The title and equipment swaps run independently, so a failure in one (e.g.
-- the item is missing from the bag) never stops the other.
function equip.SwapTo(mode)
	if settingsModule.Get("SwapToWaterTitle") then
		local ok, err = pcall(swapTitle, mode)
		if not ok then
			helpers.DevLog("equip: title swap failed: "..tostring(err))
		end
	end
	if settingsModule.Get("SwapToWaterEquipment") then
		local ok, err = pcall(swapEquipment, mode)
		if not ok then
			helpers.DevLog("equip: equipment swap failed: "..tostring(err))
		end
	end
end

local currentState = nil -- "swim" once we have swapped in, nil until then

-- Called on every map mode selection (render.modeSelected). Swaps to the swim gear/title on entering
-- Ships mode and back when leaving it. Repeat calls for the same mode are no-ops.
function equip.OnModeChanged(mode)
	if mode == "ships" and currentState ~= "swim" then
		currentState = "swim"
		equip.SwapTo("swim")
	elseif mode ~= "ships" and currentState == "swim" then
		currentState = nil
		equip.SwapTo("normal")
	end
end

function equip.OnLoad()
	eventbus.WatchEvent(eventtopics.topics.render.modeSelected, equip.OnModeChanged, "equip")
end

return equip
