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

function buildings.GetBuildingNames()
    return buildings.BuildingNames
end

return buildings
