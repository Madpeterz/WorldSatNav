local settings = require("WorldSatNav/settings")
local api = require("api")
local mapRenderer = require("WorldSatNav/map_renderer")
local constants = require("WorldSatNav/constants")

local events = {}

local storedEvents = {}

local triggeredEvents = {
    ["Sunfish"] = {
        ["keyword"] = "swarm of Sunfish",
        ["icon"] = "events/sunfish.png"
    },
    ["Perdita"] = {
        ["keyword"] = "Perdita Statue Torso",
        ["icon"] = "events/perdita.png"
    },
    ["Leviathan"] = {
        ["keyword"] = "Leviathan carcass",
        ["icon"] = "events/leviathan.png"
    },
    ["Warehouse"] = {
        ["keyword"] = "are being unlocked",
        ["icon"] = "events/warehouse.png"
    },
    ["WarehouseRaid"] = {
        ["keyword"] = "Territory Warehouse",
        ["icon"] = "events/warehouse-raid.png"
    },
    ["Crate"] = {
        ["keyword"] = "mysterious crate",
        ["icon"] = "events/crate.png"
    },
    ["Delphinad Ghostship"] = {
        ["keyword"] = "has been |cFFF5CB65destroyed",
        ["icon"] = "events/ghostship.png"
    }
}
local EnableAutoUpdatesToMap = false
local InEventsMode = false

function events.SetAutoUpdates(enabled)
    EnableAutoUpdatesToMap = enabled
end

function events.getEventData()
    return storedEvents
end

function events.InEventsMode()
    return InEventsMode
end

function events.SetEventsMode(enabled)
    InEventsMode = enabled
end

function events.RenderEvents()
    events.ClearOldEvents()
    mapRenderer.hideDots()
    mapRenderer.renderPlayerMarker()
    for _, eventData in pairs(storedEvents) do
        local eventInfo = triggeredEvents[eventData.type]
        if eventInfo ~= nil then
            mapRenderer.renderDot(eventData, 1, eventInfo.icon, 30, 30)
        end
    end
end

function events.DisplayEvents(Enable)
    events.SetAutoUpdates(Enable)
    events.SetEventsMode(Enable)
    if Enable then
        events.RenderEvents()
        if constants.DEV_MODE then
            if #storedEvents == 0 then
                api.Log:Info("WorldSatNav: Displaying test events on map.")
                local testEvents = {"sunfish","crate","ghost1","ghost2"}
                for _, logFile in pairs(testEvents) do
                    local readfile = "WorldSatNav/data/" .. logFile .. ".log"
                    local ok, result = pcall(function()
                        return api.File:Read(readfile)
                    end)
                    if not ok then
                        api.Log:Info("WorldSatNav: Error reading test event log: " .. readfile .. " | " .. tostring(result))
                    elseif result ~= nil then
                        local ok2, err = pcall(function()
                            events.WorldMessageProcessor("WORLD_MESSAGE", result.message, result.iconKey, result.sextants, result.info)
                        end)
                        if not ok2 then
                            api.Log:Info("WorldSatNav: Error processing test event log: " .. readfile .. " | " .. tostring(err))
                        end
                    else
                        api.Log:Info("WorldSatNav: Failed to read test event log (nil result): " .. readfile)
                    end
                end
            end
        end
    end
end


function events.ClearOldEvents()
    local currentTime = api.Time:GetLocalTime()
    local keptForSeconds = settings.Get("WorldEventsKeptFor") * 60
    for i = #storedEvents, 1, -1 do
        local dif = currentTime - storedEvents[i].timestamp
        if dif > keptForSeconds then
            if constants.DEV_MODE then
                api.Log:Info("WorldSatNav: Removing old event of type aged out event "..dif.." secs over: '" .. storedEvents[i].type .. "' from " .. storedEvents[i].timestamp)
            end
            table.remove(storedEvents, i)
        end
    end
end

function events.FindCordsInMessage(message)
    local foundcords = string.find(message, "@coordinates")
    if foundcords == nil then
        return false
    end
    return true
end

function events.WorldMessageProcessor(event, message, iconKey, sextants, info)
    if constants.DEV_MODE then
        api.Log:Info("WorldSatNav: Processing message: " .. message.. " writing to "..api.Time:GetLocalTime()..".message.log")
        api.File:Write(""..api.Time:GetLocalTime()..".message.log", {message = message, iconKey = iconKey, sextants = sextants, info = info})
    end
    if(settings.Get("EnableWorldEvents") == false) then
        if constants.DEV_MODE then
            api.Log:Info("WorldSatNav: World events are disabled in settings, ignoring message")
        end
        return
    end
    if event ~= "WORLD_MESSAGE" then
        api.Log:Info("WorldSatNav: Not a world message event, ignoring")
        return
    end
    events.ClearOldEvents()
    local cordsResult = events.FindCordsInMessage(message)
    if cordsResult == false then
        if constants.DEV_MODE then
            api.Log:Info("WorldSatNav: No coordinates found in message: " .. message)
        end
        return
    end
    local eventMatched = false
    for eventType, eventTrigger in pairs(triggeredEvents) do
        if string.find(message, eventTrigger.keyword) then
            local sx = sextants
            local locData = {
                longitudeDir = sx.longitude,
                longitudeDeg = sx.deg_long,
                longitudeMin = sx.min_long,
                longitudeSec = sx.sec_long,
                latitudeDir = sx.latitude,
                latitudeDeg = sx.deg_lat,
                latitudeMin = sx.min_lat,
                latitudeSec = sx.sec_lat,
                isevent = true,
                type = eventType,
                timestamp = api.Time:GetLocalTime()
            }
            if constants.DEV_MODE then
                api.Log:Info("WorldSatNav: Detected event '" .. eventType .. "' in message: " .. message)
            end
            table.insert(storedEvents, locData)
            eventMatched = true
            if EnableAutoUpdatesToMap then
                events.RenderEvents()
            end
            break
        end
    end
    if not eventMatched and constants.DEV_MODE then
        api.Log:Info("WorldSatNav: No event type matched for message: " .. message)
    end
end

return events