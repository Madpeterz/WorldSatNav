-- helpers/sound.lua: the hidden-window sound slots used for alert sounds.
return function(t, env)
    -- Fake window that records every SetSounds / Show call in order.
    local function newWindow(log, name)
        local window = { visible = false }
        function window:AddAnchor() end
        function window:SetExtent() end
        function window:SetCloseOnEscape() end
        function window:IsVisible() return self.visible end
        function window:SetSounds(key) table.insert(log, name .. ":sounds=" .. tostring(key)) end
        function window:Show(state)
            self.visible = state
            table.insert(log, name .. ":show=" .. tostring(state))
        end
        return window
    end

    local function load(stored)
        local api = env.reset({ now = 1700000000, settings = stored })
        local log = {}
        api.Interface = {
            CreateEmptyWindow = function(_, name)
                return newWindow(log, name)
            end,
            Free = function(_, window)
                table.insert(log, "free")
            end,
        }
        return env.require("helpers/sound"), log
    end

    local function indexOf(list, value)
        for index, item in ipairs(list) do
            if item == value then
                return index
            end
        end
        return nil
    end

    t.test("Play opens a slot window carrying the key", function()
        local sound, log = load()
        t.truthy(sound.Play(1, "store"))
        t.eq(log[#log], "WorldSatNavSoundSlot1:show=true")
        t.truthy(indexOf(log, "WorldSatNavSoundSlot1:sounds=store"))
    end)

    t.test("Play ignores empty keys and unknown slots", function()
        local sound, log = load()
        t.falsy(sound.Play(1, ""))
        t.falsy(sound.Play(1, nil))
        t.falsy(sound.Play(3, "store"))
        t.eq(#log, 0)
    end)

    t.test("replaying a slot hides it silently before re-opening", function()
        local sound, log = load()
        sound.Play(1, "store")
        local before = #log
        sound.Play(1, "store")
        local second = {}
        for i = before + 1, #log do
            table.insert(second, log[i])
        end
        t.eq(table.concat(second, " | "), table.concat({
            "WorldSatNavSoundSlot1:sounds=",
            "WorldSatNavSoundSlot1:show=false",
            "WorldSatNavSoundSlot1:sounds=store",
            "WorldSatNavSoundSlot1:show=true",
        }, " | "))
    end)

    t.test("PlayStacked opens two different slots", function()
        local sound, log = load()
        local a, b = sound.PlayStacked("store", "loot")
        t.truthy(a)
        t.truthy(b)
        t.truthy(indexOf(log, "WorldSatNavSoundSlot1:sounds=store"))
        t.truthy(indexOf(log, "WorldSatNavSoundSlot2:sounds=loot"))
    end)

    t.test("PlayStacked with one key plays just that slot", function()
        local sound, log = load()
        local a, b = sound.PlayStacked("store", "")
        t.truthy(a)
        t.falsy(b)
        t.isnil(indexOf(log, "WorldSatNavSoundSlot2:show=true"))
    end)

    t.test("alert sound is ranking stacked with skill_book", function()
        local sound, log = load()
        local constants = env.require("core/constants")
        t.eq(constants.alertSounds[1], "ranking")
        t.eq(constants.alertSounds[2], "skill_book")
        sound.PlayAlert()
        t.truthy(indexOf(log, "WorldSatNavSoundSlot1:sounds=ranking"))
        t.truthy(indexOf(log, "WorldSatNavSoundSlot2:sounds=skill_book"))
        t.eq(log[#log], "WorldSatNavSoundSlot2:show=true")
    end)

    t.test("Release frees every slot that was created", function()
        local sound, log = load()
        sound.PlayStacked("store", "loot")
        sound.Release()
        local frees = 0
        for _, line in ipairs(log) do
            if line == "free" then
                frees = frees + 1
            end
        end
        t.eq(frees, 2)
    end)
end
