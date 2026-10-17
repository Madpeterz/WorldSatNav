local buildings = {}

buildings.BuildingNames = {
    "Unknown",
    "Solar Scarecrow Garden", -- 8x8
    "Lunar Scarecrow Garden", -- 8x8
    "Stellar Scarecrow Garden", -- 8x8
    "Scarecrow Garden", -- 8x8
    "Haranyan Private Smelter", -- 8x8
    "Haranyan Private Sawmill", -- 8x8
    "Haranyan Private Masonry Table", -- 8x8
    "Private Smelter", -- 8x8
    "Private Sawmill", -- 8x8
    "Private Masonry Table", -- 8x8
    "Private Leatherwork Table", -- 8x8
    "Gazebo Farm", -- 16x16
    "Solar Scarecrow Farm", -- 16x16
    "Lunar Scarecrow Farm", -- 16x16
    "Stellar Scarecrow Farm", -- 16x16
    "Scarecrow Farm", -- 16x16
    "Rustic Slate Cottage", -- 16x16
    "Raised Swept-Roof Cottage", -- 16x16
    "Improved Scarecrow Farm", -- 16x16
    "Improved Stellar Pavilion Farm", -- 24x24
    "Improved Solar Pavilion Farm", -- 24x24
    "Improved Lunar Pavilion Farm", -- 24x24
    "Improved Solar Pavilion Farm Kit", -- 24x24
    "Improved Lunar Pavilion Farm Kit", -- 24x24
    "Improved Stellar Pavilion Farm Kit", -- 24x24
    "Miner's Farmhouse", -- 24x24
    "Recovering Cherry Treehouse", -- 28x28
    "Desserted House", -- 24x24
    "Beanstalk House", -- 48x48
    "Rose Quartz Solarium", -- 24x24
    "Rancher's Farmhouse", -- 24x24
    "Harvester's Farmhouse", -- 24x24
    "Advanced Fellowship Plaza", -- 24x24
    "Spired Chateau", -- 24x24
    "Apothecary's Chalet (Terrace)", -- 24x24
    "Tradesman's Manor", -- 24x24
    "Armorer's Townhouse", -- 24x24
    "Thatched Farmhouse", -- 24x24
    "Gazebo Farm", -- 16x16
    "Tudor Slate Cottage", -- 16x16
    "Freezing Cold Icehouse", -- 24x24
    "Storage Silo", -- 8x8
    "Recovering Aspen Treehouse", -- 28x28
    "Recovering Oak Treehouse", -- 28x28
    "Private Loom", -- 8x8
    "Haranyan Private Leatherwork Table", -- 8x8
    "Raised Rose Cottage", -- 16x16
    "Raised Slate Cottage", -- 16x16
    "Little Witch Pinnacled House", -- 24x24
    "Raised Mushroom House", -- 24x24
    "Tradesman's Townhouse", -- 24x24
    "Swept-Roof Villa", -- 16x16
    "Swept-Roof Chalet", -- 24x24
    "Swept-Roof Manor", -- 28x28
    "Rustic Spring Cottage", -- 16x16
    "Stone Spring Cottage", -- 16x16
    "Tudor Spring Cottage", -- 16x16
    "Stone Slate Cottage", -- 16x16
    "Rustic Rose Cottage", -- 16x16
    "Stone Rose Cottage", -- 16x16
    "Tudor Rose Cottage", -- 16x16
    "Rustic Spring Manor", -- 24x24
    "Stone Spring Manor", -- 24x24
    "Tudor Spring Manor", -- 24x24
    "Rustic Slate Manor", -- 24x24
    "Stone Slate Manor", -- 24x24
    "Tudor Slate Manor", -- 24x24
    "Rustic Rose Manor", -- 24x24
    "Stone Rose Manor", -- 24x24
    "Tudor Rose Manor", -- 24x24
    "Rustic Spring Townhouse", -- 24x24
    "Stone Spring Townhouse", -- 24x24
    "Tudor Spring Townhouse", -- 24x24
    "Rustic Slate Townhouse", -- 24x24
    "Stone Slate Townhouse", -- 24x24
    "Tudor Slate Townhouse", -- 24x24
    "Rustic Rose Townhouse", -- 24x24
    "Stone Rose Townhouse", -- 24x24
    "Tudor Rose Townhouse", -- 24x24
    "Rustic Spring Chalet", -- 24x24
    "Stone Spring Chalet", -- 24x24
    "Tudor Spring Chalet", -- 24x24
    "Rustic Slate Chalet", -- 24x24
    "Stone Slate Chalet", -- 24x24
    "Tudor Slate Chalet", -- 24x24
    "Rustic Rose Chalet", -- 24x24
    "Stone Rose Chalet", -- 24x24
    "Tudor Rose Chalet", -- 24x24
    "Breezy Bungalow", -- 24x24
    "Tidal Bungalow", -- 28x28
    "Oak Treehouse", -- 28x28
    "Cherry Treehouse", -- 28x28
    "Aspen Treehouse", -- 28x28
    "Fellowship Plaza", -- 28x28
    "Mansion", -- 44x44
    "Raised Spring Cottage", -- 16x16
    "Armorer's Manor", -- 24x24
    "Swept-Roof Cottage", -- 16x16
    "Armorer's Chalet (Terrace)", -- 24x24
    "Apothecary's Townhouse", -- 24x24
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
