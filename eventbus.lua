local helpers = require("WorldSatNav/helpers")
local eventtopics = require("WorldSatNav/eventtopics")

local eventbus = {}
local tinsert = table.insert

local watchers = {}
local deferredQueue = {}
local deferredReadIndex = 1
local deferredWriteIndex = 0
local maxDeferredPerTick = 5

local function DispatchEvent(topic, arg1, arg2, arg3, arg4, arg5)
    local topicWatchers = watchers[topic]
    if topicWatchers ~= nil then
        helpers.DevLog("Triggering event topic: " .. topic .. " with " .. #topicWatchers .. " subscribers")
        for i = 1, #topicWatchers do
            local callback = topicWatchers[i]
            callback(arg1, arg2, arg3, arg4, arg5)
        end
    else
        helpers.DevLog("No subscribers for event topic: " .. topic)
    end
end

function eventbus.WatchEvent(topic, callback, sourceFile)
    if eventtopics.HasTopic(topic) == false then
        return false
    end
    if watchers[topic] == nil then
        watchers[topic] = {}
    end
    tinsert(watchers[topic], callback)
    helpers.DevLog("Subscribed to event topic: " .. topic .. " from " .. (sourceFile or "unknown source"))
    return true
end

function eventbus.TriggerEvent(topic, arg1, arg2, arg3, arg4, arg5)
    arg1 = arg1 or nil
    arg2 = arg2 or nil
    arg3 = arg3 or nil
    arg4 = arg4 or nil
    arg5 = arg5 or nil
    if eventtopics.HasTopic(topic) == false then
        return false
    end
    deferredWriteIndex = deferredWriteIndex + 1
    deferredQueue[deferredWriteIndex] = {
        topic = topic,
        arg1 = arg1,
        arg2 = arg2,
        arg3 = arg3,
        arg4 = arg4,
        arg5 = arg5,
    }
    return true
end

function eventbus.TriggerEventImmediate(topic, arg1, arg2, arg3, arg4, arg5)
    if eventtopics.HasTopic(topic) == false then
        return false
    end
    DispatchEvent(topic, arg1, arg2, arg3, arg4, arg5)
    return true
end

function eventbus.ProcessDeferredEvents(maxEvents)
    local budget = maxEvents or maxDeferredPerTick
    if budget < 1 then
        return 0
    end

    local processed = 0
    while deferredReadIndex <= deferredWriteIndex and processed < budget do
        local evt = deferredQueue[deferredReadIndex]
        deferredQueue[deferredReadIndex] = nil
        deferredReadIndex = deferredReadIndex + 1
        if evt ~= nil then
            processed = processed + 1
            DispatchEvent(evt.topic, evt.arg1, evt.arg2, evt.arg3, evt.arg4, evt.arg5)
        end
    end

    if deferredReadIndex > deferredWriteIndex then
        deferredQueue = {}
        deferredReadIndex = 1
        deferredWriteIndex = 0
    elseif deferredReadIndex > 128 then
        local remaining = {}
        local remainingCount = 0
        for i = deferredReadIndex, deferredWriteIndex do
            remainingCount = remainingCount + 1
            remaining[remainingCount] = deferredQueue[i]
        end
        deferredQueue = remaining
        deferredReadIndex = 1
        deferredWriteIndex = remainingCount
    end

    return processed
end

function eventbus.SetDeferredBudgetPerTick(maxEvents)
    if type(maxEvents) ~= "number" then
        return false
    end
    if maxEvents < 1 then
        return false
    end
    maxDeferredPerTick = math.floor(maxEvents)
    return true
end

return eventbus