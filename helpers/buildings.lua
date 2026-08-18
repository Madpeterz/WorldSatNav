local buildings = {}

buildings.BuildingNames = {
    "Unknown",
    -- 8x8
    "Solar Scarecrow Garden",
    "Lunar Scarecrow Garden",
    "Stellar Scarecrow Garden",
    "Scarecrow Garden",
    "Haranyan Private Smelter",
    "Haranyan Private Sawmill",
    "Haranyan Private Masonry Table",
    "Private Smelter",
    "Private Sawmill",
    "Private Masonry Table",
    "Private Leatherwork Table",
    -- 16x16
    "Gazebo Farm",
    "Solar Scarecrow Farm",
    "Lunar Scarecrow Farm",
    "Stellar Scarecrow Farm",
    "Scarecrow Farm",
    "Rustic Slate Cottage",
    "Raised Swept-Roof Cottage",
    "Improved Scarecrow Farm",
    -- 24x24 and larger
    "Improved Stellar Pavilion Farm",
    "Improved Solar Pavilion Farm",
    "Improved Lunar Pavilion Farm",
    "Improved Solar Pavilion Farm Kit",
    "Improved Lunar Pavilion Farm Kit",
    "Improved Stellar Pavilion Farm Kit",
    "Miner's Farmhouse",
    "Recovering Cherry Treehouse",
    "Desserted House",
    "Beanstalk House",
    "Rose Quartz Solarium",
    "Rancher's Farmhouse",
    "Harvester's Farmhouse",
    "Advanced Fellowship Plaza",
    "Spired Chateau",
    "Apothecary's Chalet (Terrace)",
    "Tradesman's Manor",
    "Armorer's Townhouse",
    "Thatched Farmhouse",
    "Gazebo Farm",
}

-- name -> numeric id, derived from BuildingNames order (id 0 = "Unknown")
buildings.BuildingIds = {}
for index, name in ipairs(buildings.BuildingNames) do
    buildings.BuildingIds[name] = index - 1
end

function buildings.GetBuildingNames()
    return buildings.BuildingNames
end

function buildings.GetBuildingId(name)
    return buildings.BuildingIds[name]
end

function buildings.GetBuildingNameById(id)
    id = tonumber(id)
    if id == nil then
        return nil
    end
    return buildings.BuildingNames[id + 1]
end

return buildings
