local api = require("api")
local constants = require("WorldSatNav/core/constants")

-- The addon API has no "play this sound" call. A widget only plays a sound when the
-- engine drives it: a button when clicked, a window when it opens. So an alert plays
-- sounds by re-opening hidden 1x1 windows that each carry one sound key. Two slots
-- opened in the same frame give two stacked sounds.
local sound = {}

local SLOT_COUNT = 2
local slots = {}

local function getSlot(index)
    if slots[index] ~= nil then
        return slots[index]
    end
    local window = api.Interface:CreateEmptyWindow("WorldSatNavSoundSlot" .. index)
    if window == nil then
        return nil
    end
    window:AddAnchor("TOPLEFT", "UIParent", 0, 0)
    window:SetExtent(1, 1)
    window:SetCloseOnEscape(false)
    window:Show(false)
    slots[index] = window
    return window
end

--- Play one sound key on the given slot (1..SLOT_COUNT).
-- The slot is silenced while it is hidden and re-shown, so repeating the same key
-- fires its open sound again and hiding never plays a close sound.
-- @return boolean true when the slot was opened with a key
function sound.Play(slotIndex, key)
    if key == nil or key == "" then
        return false
    end
    if slotIndex < 1 or slotIndex > SLOT_COUNT then
        return false
    end
    local window = getSlot(slotIndex)
    if window == nil or window.SetSounds == nil then
        return false
    end
    window:SetSounds("")
    if window:IsVisible() then
        window:Show(false)
    end
    window:SetSounds(key)
    window:Show(true)
    return true
end

--- Open both slots in the same call so the two sounds overlap.
-- @return boolean, boolean whether each slot was opened
function sound.PlayStacked(keyA, keyB)
    local playedA = sound.Play(1, keyA)
    local playedB = sound.Play(2, keyB)
    return playedA, playedB
end

--- Play the stacked alert sound (constants.alertSounds).
function sound.PlayAlert()
    local keys = constants.alertSounds
    return sound.PlayStacked(keys[1], keys[2])
end

function sound.Release()
    for index, window in pairs(slots) do
        if window.SetSounds ~= nil then
            window:SetSounds("")
        end
        window:Show(false)
        api.Interface:Free(window)
        slots[index] = nil
    end
end

return sound
