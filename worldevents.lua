local api = require("api")
local helpers = require("WorldSatNav/helpers")
local constants = require("WorldSatNav/constants")
local settings = require("WorldSatNav/settings")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")
local regionmap = require("WorldSatNav/regionmap")
local worldevents = {}
local storedEvents = {}

local loadedDemoEvents = false
local triggeredEvents = {
    ["Sunfish"] = {
        ["keyword"] = "swarm of Sunfish",
        ["icon"] = "events/sunfish.png",
        ["type"] = "Fishing",
        ["value"] = "Low/Mid"
    },
    ["Perdita"] = {
        ["keyword"] = "Perdita Statue Torso",
        ["icon"] = "events/perdita.png",
        ["type"] = "Packs",
        ["value"] = "High"
    },
    ["Leviathan"] = {
        ["keyword"] = "Leviathan carcass",
        ["icon"] = "events/leviathan.png",
        ["type"] = "Nation buff",
        ["value"] = "Game breaking"
    },
    ["Warehouse"] = {
        ["keyword"] = "are being unlocked",
        ["icon"] = "events/warehouse.png",
        ["type"] = "Packs",
        ["value"] = "High"
    },
    ["WarehouseRaid"] = {
        ["keyword"] = "Territory Warehouse",
        ["icon"] = "events/warehouse-raid.png",
        ["type"] = "Packs",
        ["value"] = "High"
    },
    ["Crate"] = {
        ["keyword"] = "mysterious crate",
        ["icon"] = "events/crate.png",
        ["type"] = "Packs",
        ["value"] = "Mid"
    },
    ["Delphinad Ghostship"] = {
        ["keyword"] = "has been |cFFF5CB65destroyed",
        ["icon"] = "events/ghostship.png",
        ["type"] = "Packs",
        ["value"] = "Mid"
    }
}

local function LoadDemoEvents()
    if loadedDemoEvents then return end
    if constants.DEV_MODE_LOAD_DEMO_EVENTS == false then
        helpers.DevLog("WorldSatNav: Skipping loading demo events, DEV_MODE_LOAD_DEMO_EVENTS is false")
        return
    end
    if constants.DEV_MODE == false then
        helpers.DevLog("WorldSatNav: DEV_MODE is false, not loading demo events")
        return
    end
    helpers.DevLog("WorldSatNav: Loading demo events")
    local testEvents = {
        ["sunfish"] = 4,
        ["crate"] = 2,
        ["ghost"] = 2,
        ["perdita"] = 1
    }
    for logFile, count in pairs(testEvents) do
        local loop = 1
        while loop <= count do
            local readfile = constants.addonName .. "/data/examples/" .. logFile .. "/" .. loop .. ".log"
            local result = api.File:Read(readfile)
            if result ~= nil then
                helpers.DebugDumpValue("Loaded event data", result)
                worldevents.WorldMessageProcessor("WORLD_MESSAGE", result.message, result.iconKey, result.sextants, result.info)
            else
                helpers.DevLog("WorldSatNav: Failed to load demo event from file: " .. readfile)
            end
            loop = loop + 1
        end
    end
    loadedDemoEvents = true
end

function worldevents.FindCordsInMessage(message)
    local foundcords = string.find(message, "@coordinates")
    if foundcords == nil then
        return false
    end
    return true
end

local function ExpireOldEvents()
    local currentTime = api.Time:GetLocalTime()
    if type(currentTime) ~= "number" then
        helpers.DevLog("WorldSatNav: Unable to expire events, local time is not numeric")
        return
    end
    local expireMinutes = tonumber(settings.Get("WorldEventsKeptFor")) or 5
    local beforeCount = #storedEvents
    local removeEventids = {}
    for i = #storedEvents, 1, -1 do
        local event = storedEvents[i]
        if (currentTime - event.timestamp) > (60 * expireMinutes) then
            table.insert(removeEventids, i)
        end
    end
    for _, id in pairs(removeEventids) do
        table.remove(storedEvents, id)
    end
    local afterCount = #storedEvents
    if beforeCount ~= afterCount then
        helpers.DevLog("WorldSatNav: Expired " .. (beforeCount - afterCount) .. " old events, " .. afterCount .. " remaining")
    end
end

function worldevents.RequestEventsForRender()
    ExpireOldEvents()
    helpers.DevLog("WorldSatNav: Requesting events for render, total stored events: " .. #storedEvents)
    LoadDemoEvents()
    local bulkRenderData = {}
	for _, entry in pairs(storedEvents) do
        local eventInfo = triggeredEvents[entry.eventType]
        local thisEntry = {
        sextant = entry.sextant,
        texture = eventInfo.icon,
        sourceType = "Event",
        customIconSize = 22,
        }
		table.insert(bulkRenderData, thisEntry)
    end
    eventbus.TriggerEvent(eventtopics.topics.icons.BulkDrawIconsAndRedraw, bulkRenderData)
end

function worldevents.WorldMessageProcessor(event, message, iconKey, sextants, info)
    if settings.Get("EnableWorldEvents") == false then
        helpers.DevLog("WorldSatNav: World events are disabled in settings, ignoring message")
        return
    end
    if event ~= "WORLD_MESSAGE" then
        api.Log:Info("WorldSatNav: Not a world message event, ignoring")
        return
    end
    if type(message) ~= "string" or message == "" then
        helpers.DevLog("WorldSatNav: Invalid world message payload, ignoring")
        return
    end
    if type(sextants) ~= "table" or sextants.latitude == nil or sextants.longitude == nil then
        helpers.DevLog("WorldSatNav: Missing sextant data in world message, ignoring")
        return
    end
    helpers.DevLog("WorldSatNav: Processing event: " .. event.."")
    local cordsResult = worldevents.FindCordsInMessage(message)
    if cordsResult == false then
        helpers.DevLog("WorldSatNav: No coordinates found in message: " .. message)
        return
    end
    local sx = {}
    local eventMatched = false
    local matchedEventType = ""
    local matchedEventTypeInfo = nil
    local matchedEventTypeValue = nil
    for eventType, eventTrigger in pairs(triggeredEvents) do
        if string.find(message, eventTrigger.keyword) then
            local sx = {}
            sx.longitude = sextants.longitude
            sx.latitude = sextants.latitude
            sx.deg_long = sextants.deg_long
            sx.min_long = sextants.min_long
            sx.sec_long = sextants.sec_long
            sx.deg_lat =  sextants.deg_lat
            sx.min_lat =  sextants.min_lat
            sx.sec_lat = sextants.sec_lat

            local locData = {
                sextant = sx,
                timestamp = api.Time:GetLocalTime(),
                eventType = eventType
            }
            helpers.DevLog("WorldSatNav: Detected event '" .. eventType .. "' in message: " .. message)
            table.insert(storedEvents, locData)
            eventMatched = true
            matchedEventType = eventType
            matchedEventTypeInfo = eventTrigger.type
            matchedEventTypeValue = eventTrigger.value
            break
        end
    end
    if eventMatched == false then
        helpers.DevLog("WorldSatNav: No event type matched for message: " .. message)
        return
    end
    if settings.Get("EnableEventAlerts") then
        local _, regionName = regionmap.GetRegionForSextant(sextants)
        eventbus.TriggerEvent(eventtopics.topics.alert.show, {
        title = "World event:"..matchedEventType,
        lines = {
            { label = "Region:", value = regionName },
            { label = "Type:", value = matchedEventTypeInfo },
            { label = "Value:", value = matchedEventTypeValue },
        },
        countdownLabel = "Started:",
        countdownSeconds = 0,
        countdownEndText = " ",
        countUpTo5Minutes = true,
        trackText = "Track",
        source = "custom",
        payload = { sextant = sextants },
        })
    end
end

function worldevents.OnLoad()
    eventbus.WatchEvent(eventtopics.topics.render.events, worldevents.RequestEventsForRender, "worldevents")
end

function worldevents.OnUnload()
end

return worldevents;