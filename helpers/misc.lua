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

return misc
