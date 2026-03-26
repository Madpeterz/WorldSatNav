local settings = require("WorldSatNav/settings")
local api = require("api")
local mapRenderer = require("WorldSatNav/map_renderer")
local constants = require("WorldSatNav/constants")
local helpers = require("WorldSatNav/helpers")

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

-- Utility function to check if a table contains a value
function table.contains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

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
                local testEvents = {
                    ["sunfish"] = 4,
                    ["crate"] = 2,
                    ["ghost"] = 2,
                    ["perdita"] = 1
                }
                for logFile, count in pairs(testEvents) do
                    local loop = 1
                    while loop <= count do
                        local readfile = "WorldSatNav/data/examples/"..logFile.."/"..loop..".log"
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
                        loop = loop + 1
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
            helpers.DevLog("WorldSatNav: Removing old event of type aged out event "..dif.." secs over: '" .. storedEvents[i].type .. "' from " .. storedEvents[i].timestamp)
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

function events.WorldMessageProcessorChat(event, channel, color, status, from, message, unsure1, unsure2, unsure3)
    if(settings.Get("EnableWorldEvents") == false) then
        helpers.DevLog("WorldSatNav: Chat events are disabled in settings, ignoring message")
        return
    end
    local skipChannels = {-4, -3, 6, 14, 7, 9, 5, 10, 4, 0, 1, 3, 2, -2, 11}
    --  Ignored channels
    --  -4= Whisper reply
    --  -3= Whisper
    --  6 = Nation
    --  14 = Faction
    --  7 = Guild
    --  9 = Family
    --  5 = Raid
    --  10  = raid command
    --  4 = Party
    --  0 = local
    -- 1 = shout
    -- 3 = LFG
    -- 2 = Trade
    -- -2 = DAILY_MSG
    -- 11 = Trial
    if table.contains(skipChannels, channel) then
        return -- Ignore specified channels
    end
    if constants.DEV_MODE then
        helpers.DevLog("WorldSatNav: Processing event: " .. event.."")
        api.File:Write(""..event.."="..api.Time:GetLocalTime()..".message.log", {
            channel = channel,
            color = color,
            status = status,
            from = from,
            message = message,
            unsure1 = unsure1,
            unsure2 = unsure2,
            unsure3 = unsure3
        })
    end
end

function events.WorldMessageProcessor(event, message, iconKey, sextants, info)
    if(settings.Get("EnableWorldEvents") == false) then
        helpers.DevLog("WorldSatNav: World events are disabled in settings, ignoring message")
        return
    end
    if event ~= "WORLD_MESSAGE" then
        api.Log:Info("WorldSatNav: Not a world message event, ignoring")
        return
    end
    if constants.DEV_MODE then
        helpers.DevLog("WorldSatNav: Processing event: " .. event.."")
        api.File:Write(""..event.."="..api.Time:GetLocalTime()..".message.log", {
            message = message,
            iconKey = iconKey,
            sextants = sextants,
            info = info
        })
    end
    events.ClearOldEvents()
    local cordsResult = events.FindCordsInMessage(message)
    if cordsResult == false then
        helpers.DevLog("WorldSatNav: No coordinates found in message: " .. message)
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
            helpers.DevLog("WorldSatNav: Detected event '" .. eventType .. "' in message: " .. message)
            table.insert(storedEvents, locData)
            eventMatched = true
            if EnableAutoUpdatesToMap then
                events.RenderEvents()
            end
            break
        end
    end
    if not eventMatched then
        helpers.DevLog("WorldSatNav: No event type matched for message: " .. message)
    end
end

return events