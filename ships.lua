
local api = require("api")
local helpers = require("WorldSatNav/helpers")
local constants = require("WorldSatNav/constants")
local Coordinates = require("WorldSatNav/coordinates")
local regionmap = require("WorldSatNav/regionmap")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")
local ships = {}
local shipsData = {}
local shipDataFilePath = "WorldSatNav/data/ships.dat"

local vistitedShips = {}

ships.SelectedShipTexture = constants.folderPath.."images/icons/shipactive.png"
local lastSelectedShipSextant = nil

local function makeLocData(ship)
    local sx = ship.sextant
    local sextantData = {
		sextant = {}
	}
    sextantData.sextant.longitude = sx.longitude
	sextantData.sextant.latitude = sx.latitude
	sextantData.sextant.deg_long =	sx.deg_long
	sextantData.sextant.min_long = sx.min_long
	sextantData.sextant.sec_long = sx.sec_long
	sextantData.sextant.deg_lat =  sx.deg_lat
	sextantData.sextant.min_lat = sx.min_lat
	sextantData.sextant.sec_lat =	sx.sec_lat
	return sextantData;
end

function ships.SelectShipBySextant(sextant)
	if sextant == nil then
		helpers.DevLog("Cannot select ship: sextant is nil")
		return
	end
	if lastSelectedShipSextant ~= nil then
		eventbus.TriggerEvent(eventtopics.topics.icons.clearIcon, lastSelectedShipSextant, "Ship")
	end
	lastSelectedShipSextant = sextant
	helpers.DevLog("Selecting ship with sextant: " .. helpers.SextantKey(sextant))
	eventbus.TriggerEvent(eventtopics.topics.icons.ChangeIcon, sextant, "icons/shipactive.png", "Ship")
	eventbus.TriggerEvent(eventtopics.topics.tracking.custom, sextant, "Ship", false)
end


function ships.GetNextShip()
	if lastSelectedShipSextant == nil then
		api.Log:Info("No ship selected")
		return
	end
	local _, regionName = regionmap.GetRegionForSextant(lastSelectedShipSextant)
	eventbus.TriggerEvent(eventtopics.topics.icons.clearIcon, lastSelectedShipSextant, "Ship")
	local lastVisitedShipKey = helpers.SextantKey(lastSelectedShipSextant)
	vistitedShips[lastVisitedShipKey] = true -- mark the current ship as visited
	helpers.DevLog("Last visited ship marked as visited with key: " .. tostring(lastVisitedShipKey).." in region: "..tostring(regionName))
	local nextShipMap = {}
	for _, ship in pairs(shipsData) do
		local shipKey = helpers.SextantKey(ship.sextant)
		if not vistitedShips[shipKey] then
			local _, shipRegionName = regionmap.GetRegionForSextant(ship.sextant)
			local distance = Coordinates.CalculateDistance(lastSelectedShipSextant, ship.sextant)
			if (shipRegionName == regionName) or (distance < 1250) then
				local shipEntry = {
					ship = ship,
					distance = distance
				}
				table.insert(nextShipMap, shipEntry)
			end
		end
	end
	if #nextShipMap == 0 then
		api.Log:Info("No more unvisited ships found in region " .. tostring(regionName) .. " or nearby please open the map and select next")
		return
	end
	table.sort(nextShipMap, function(a, b) return a.distance < b.distance end)
	local nextShip = nextShipMap[1].ship
	local nextSextant = nextShip.sextant
	ships.SelectShipBySextant(nextSextant)
end

local function loadShipsData()
	if #shipsData > 0 then
		return
	end
	local LoadDataSet = api.File:Read(shipDataFilePath)
	if LoadDataSet == nil then
		helpers.DevLog("failed to load ships data")
		return
	end
	for _, entry in pairs(LoadDataSet) do
		if entry ~= nil then
			local ship = makeLocData(entry)
			table.insert(shipsData, ship)
		end
	end
	if #shipsData == 0 then
		helpers.DevLog("No ships data found in file")
		return
	end
	helpers.DevLog("Loaded " .. #shipsData .. " ships from file")
end

function ships.ResetShipsVisited()
	helpers.DevLog("Resetting visited ships list")
	lastSelectedShipSextant = nil
	vistitedShips = {}
end
function ships.RequestShipsForRender()
	loadShipsData()
	helpers.DevLog("Rendering " .. #shipsData .. " ships on map")
	local LastSelectedSextantKey = nil
	if lastSelectedShipSextant ~= nil then
		LastSelectedSextantKey = helpers.SextantKey(lastSelectedShipSextant)
		helpers.DevLog("[RequestShipsForRender] Last selected ship sextant key: " .. tostring(LastSelectedSextantKey))
	else
		helpers.DevLog("[RequestShipsForRender] No ship currently selected")
	end
	local bulkRenderData = {}
	for _, entry in pairs(shipsData) do
		local shipKey = helpers.SextantKey(entry.sextant)
		if not vistitedShips[shipKey] then
			local thisEntry = {}
			if LastSelectedSextantKey ~= nil and shipKey == LastSelectedSextantKey then
				thisEntry = {
					sextant = entry.sextant,
					texture = "icons/shipactive.png",
					sourceType = "Ship",
					customIconSize = 7,
				}
				table.insert(bulkRenderData, thisEntry)
			else
				thisEntry = {
					sextant = entry.sextant,
					texture = "icons/ship.png",
					sourceType = "Ship",
					customIconSize = 7,
				}
				table.insert(bulkRenderData, thisEntry)
			end
		end
	end
	eventbus.TriggerEvent(eventtopics.topics.icons.BulkDrawIconsAndRedraw, bulkRenderData)
end

function ships.OnLoad()
	eventbus.WatchEvent(eventtopics.topics.render.ships, ships.RequestShipsForRender, "ships")
	eventbus.WatchEvent(eventtopics.topics.ships.selectBySextant, ships.SelectShipBySextant, "ships")
	eventbus.WatchEvent(eventtopics.topics.ships.resetVisited, ships.ResetShipsVisited, "ships")
	eventbus.WatchEvent(eventtopics.topics.tracking.nextShip, ships.GetNextShip, "ships")
end

function ships.OnUnload()
end

return ships;