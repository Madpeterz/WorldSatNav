-- Facade module: aggregates the split-out helpers_*.lua submodules into a
-- single `helpers` table so existing `helpers.X` call sites keep working.
local log = require("WorldSatNav/helpers/log")
local geo = require("WorldSatNav/helpers/geo")
local buildings = require("WorldSatNav/helpers/buildings")
local datetime = require("WorldSatNav/helpers/datetime")
local widgets = require("WorldSatNav/helpers/widgets")
local misc = require("WorldSatNav/helpers/misc")
local sharecode = require("WorldSatNav/helpers/sharecode")

local helpers = {}

for _, submodule in ipairs({log, geo, buildings, datetime, widgets, misc, sharecode}) do
    for key, value in pairs(submodule) do
        helpers[key] = value
    end
end

return helpers
