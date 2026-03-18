-- WorldSatNav Constants
-- Central location for all magic numbers and configuration values

local Constants = {
	-- Map center point and coordinate conversion
	DEV_MODE = false,  -- Set to true to enable dev/debug UI controls and test data

	map = {
		tweakScaleX = 0,
		tweakScaleY = 0,
		centerPointX = 501,
		centerPointY = 30,
		width = 793,
		height = 679,
		xpointScale = 25.5,
		ypointScale = 26.9
	},

	-- Window dimensions and positions
	window = {
		widthPadding = 10,  -- Extra width for main window (929 + 100)
		heightPadding = 50, -- Extra height for main window (557 + 100)
	},
	
	-- Update timing (in milliseconds)
	timing = {
		updateRate = 500,
	},
	
	-- Game-specific constants
	game = {
		portalZoneId = 323,
		portalZoomLevel = 100,
		treasureMapItemName = "Treasure Map with Coordinates",
	},
	
	-- Region colors (R, G, B, Alpha)
	regionColors = {
		["?"] = {171/255, 164/255, 164/255, 0.3},         -- Unknown (grey)
		["Nuia"] = {23/255, 222/255, 20/255, 0.3},        -- Green
		["Haranya"] = {224/255, 26/255, 4/255, 0.3},      -- Red
		["Halcy Glf"] = {4/255, 4/255, 224/255, 0.3},     -- Blue
		["Castaway"] = {73/255, 233/255, 245/255, 0.3},   -- Cyan
		["Arcadian"] = {10/255, 13/255, 13/255, 0.3},     -- Dark grey/black
		["Auroria"] = {238/255, 255/255, 5/255, 0.3},     -- Yellow
	},
	
	-- Overlay text styling
	overlay = {
		fontSize = 10,
		heightOffset = -2,
		height = 14,
	},
	
	-- Tracking window styling
	tracking = {
		backgroundColor = {0, 0, 0, 0.5},
	},
}

return Constants
