local eventtopics = {
	topics = {
		tracking = {
			start = "tracking.start",
			stop = "tracking.stop",
			nextMap = "tracking.nextMap",
			nextShip = "tracking.nextShip",
			custom = "tracking.custom",
		},
		demo = {
			triggerAlert = "demo.triggerAlert",
			openAddWindow = "demo.openAddWindow",
			listDemos = "demo.listDemos",
		},
		alert = {
			show = "alert.show",
			hide = "alert.hide",
			track = "alert.track",
		},
		UI = {
			open = "ui.open",
			close = "ui.close",
			MainUILoaded = "ui.mainui.loaded",
			toggleGoto = "ui.toggleGoto",
			closeGoto = "ui.closeGoto",
			clearItems = "ui.clearItems",
			EmptyUI = "ui.empty",
			ReloadUI = "ui.reload",
			forcedUIMode = "ui.forcedMode",
			forcedUIModeReady = "ui.forcedModeReady",
			requestUIMode = "ui.requestMode",
		},
		icons = {
			drawIcon = "icons.drawIcon",
			clearIcon = "icons.clearIcon",
			ChangeIcon = "icons.changeIcon",
			BulkDrawIconsAndRedraw = "icons.bulkDrawIconsAndRedraw",
		},
		ships = {
			selectBySextant = "ships.selectBySextant",
			resetVisited = "ships.resetVisited",
		},
		render = {
			redrawMap = "render.redrawMap",
			modeChanged = "render.modeChanged",
			maps = "render.maps",
			ships = "render.ships",
			demos = "render.demos",
			events = "render.events",
			config = "render.config",
			demoadd = "render.demoadd",
			clearUiState = "render.clearUiState",
		},
	}
}

local topicSet = nil

local function rebuildTopicSet()
	topicSet = {}
	for _, topics in pairs(eventtopics.topics) do
		for _, value in pairs(topics) do
			topicSet[value] = true
		end
	end
end

rebuildTopicSet()

function eventtopics.HasTopic(topic)
	if topic == nil then
		return false
	end
	local set = topicSet
	if set == nil then
		return false
	end
	return set[topic] == true
end

return eventtopics
