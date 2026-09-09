local constants = require("WorldSatNav/core/constants")

local misc = {}

--- Iterate over all treasure map items currently in the player's bag.
-- Calls callback(slotIndex, btn, info) for each slot that contains a treasure map.
-- @param callback function called with (slotIndex, btn, info) for each matching slot
function misc.iterateTreasureMaps(callback)
    local bagFrame = ADDON:GetContent(UIC.BAG)
    if not bagFrame or not bagFrame.slots or not bagFrame.slots.btns then
        return
    end
    for slotIndex, btn in pairs(bagFrame.slots.btns) do
        local info = btn:GetInfo()
        if info and info.name == constants.game.treasureMapItemName then
            callback(slotIndex, btn, info)
        end
    end
end

--- Wrap fn so it only runs once `intervalMs` of accumulated dt has passed.
-- The returned function takes (dt, ...) and forwards every arg to fn when it
-- fires. The accumulator resets to 0 on fire, matching the hand-rolled throttles
-- these replace (no carry-over of the overshoot).
-- @param intervalMs number minimum milliseconds between calls to fn
-- @param fn function the work to throttle
-- @return function drop-in onUpdate handler
function misc.throttle(intervalMs, fn)
    local elapsed = 0
    return function(dt, ...)
        elapsed = elapsed + (dt or 0)
        if elapsed < intervalMs then
            return
        end
        elapsed = 0
        return fn(dt, ...)
    end
end

return misc
