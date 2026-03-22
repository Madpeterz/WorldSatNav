-- WorldSatNav UI Windows
-- Handles creation of all UI windows and controls

local api = require("api")
local constants = require("WorldSatNav/constants")
local helpers = require("WorldSatNav/helpers")
local ships = require("WorldSatNav/ships")
local settings = require("WorldSatNav/settings")
local coordinates = require("WorldSatNav/coordinates")
local UIWindows = {}

-- Create the GPS tracking window (HUD overlay showing distance/bearing)
function UIWindows.createTRACK_WINDOW(onCloseCallback)
	local TRACK_WINDOW = api.Interface:CreateEmptyWindow("TRACK_WINDOW")
	TRACK_WINDOW:AddAnchor("TOPLEFT", "UIParent", settings.Get("TrackingWindowX"), settings.Get("TrackingWindowY"))
	TRACK_WINDOW.bg = TRACK_WINDOW:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
	TRACK_WINDOW.bg:SetTextureInfo("bg_quest")
	local bg = constants.tracking.backgroundColor
	TRACK_WINDOW.bg:SetColor(bg[1], bg[2], bg[3], bg[4])
	TRACK_WINDOW.bg:AddAnchor("TOPLEFT", TRACK_WINDOW, -100, 0)
	TRACK_WINDOW.bg:AddAnchor("BOTTOMRIGHT", TRACK_WINDOW, 0, 0)
	TRACK_WINDOW:SetExtent(200, 150)
	TRACK_WINDOW:Show(false)

	TRACK_WINDOW.arrow = TRACK_WINDOW:CreateImageDrawable("trackarrow", "overlay")
	TRACK_WINDOW.arrow:SetTexture(api.baseDir .. "/WorldSatNav/images/arrows6/n.png")
	TRACK_WINDOW.arrow:AddAnchor("TOPLEFT", TRACK_WINDOW, -70, 30)
	TRACK_WINDOW.arrow:SetExtent(64, 64)
	TRACK_WINDOW.arrow:Show(true)



	helpers.makeWindowDraggable(TRACK_WINDOW, TRACK_WINDOW, "TrackingWindowX", "TrackingWindowY")

	-- Close button
	TRACK_WINDOW.closeBtn = TRACK_WINDOW:CreateChildWidget("button", "closeBtn", 0, true)
	TRACK_WINDOW.closeBtn:AddAnchor("TOPRIGHT", TRACK_WINDOW, -10, 5)
	api.Interface:ApplyButtonSkin(TRACK_WINDOW.closeBtn, BUTTON_BASIC.WINDOW_SMALL_CLOSE)
	TRACK_WINDOW.closeBtn:Show(true)

	function TRACK_WINDOW.OnClose(button, clicktype)
		TRACK_WINDOW:Show(false)
		if onCloseCallback then
			onCloseCallback()
		end
	end

	TRACK_WINDOW.closeBtn:SetHandler("OnClick", TRACK_WINDOW.OnClose)

	-- Labels
	local trackingLabel = helpers.createLabel('trackingLabel', TRACK_WINDOW, 'Tracking:', 0, 0)
	trackingLabel:RemoveAllAnchors()
	trackingLabel:AddAnchor('TOPLEFT', TRACK_WINDOW, 20, 30)
	ApplyTextColor(trackingLabel, FONT_COLOR.WHITE)

	-- Mark name label
	local markNameLabel = helpers.createLabel('markNameLabel', TRACK_WINDOW, 'undefined point', 0, 0)
	markNameLabel:RemoveAllAnchors()
	markNameLabel:AddAnchor('CENTER', trackingLabel, 0, 20)
	ApplyTextColor(markNameLabel, FONT_COLOR.WHITE)
	TRACK_WINDOW.markNameLabel = markNameLabel

	-- Distance label
	local distanceLabel = helpers.createLabel('distanceLabel', TRACK_WINDOW, '100.3 m', 0, 0)
	distanceLabel:RemoveAllAnchors()
	distanceLabel:AddAnchor('CENTER', markNameLabel, -80, 40)
	ApplyTextColor(distanceLabel, FONT_COLOR.WHITE)
	TRACK_WINDOW.distanceLabel = distanceLabel
	
	return TRACK_WINDOW
end

-- Create the main SatNav window with map display
function UIWindows.createMainWindow(onMapClickCallback, onCloseCallback)


	local mapOffsetX = 15
	local mapOffsetY = 73

	-- Window needs to be sized for the overlay image (819x776)
	local window = api.Interface:CreateEmptyWindow("SatNavWindow", "WorldSat Nav")
	window:AddAnchor("TOPLEFT", "UIParent", settings.Get("MainWindowX"), settings.Get("MainWindowY"))
	window:SetExtent(819, 776)
	window:SetSounds("store")
	window:SetCloseOnEscape(true)
	
	helpers.makeWindowDraggable(window, window, "MainWindowX", "MainWindowY")

	local mapDrawable = window:CreateImageDrawable("yes", "background")
	mapDrawable:AddAnchor("TOPLEFT", window, mapOffsetX, mapOffsetY)
	mapDrawable:SetExtent(constants.map.width, constants.map.height)
	window.mapDrawable = mapDrawable

	-- Create invisible button overlay to capture clicks on the map
	local mapClickBtn = window:CreateChildWidget("button", "mapClickBtn", 0, true)
	mapClickBtn:AddAnchor("TOPLEFT", mapDrawable, 0, 0)
	mapClickBtn:AddAnchor("BOTTOMRIGHT", mapDrawable, 0, 0)
	mapClickBtn:Show(true)
	mapClickBtn:Enable(true)
	mapClickBtn:Raise()
	
	function mapClickBtn:OnClick()
		local mouseX, mouseY = api.Input:GetMousePos()
		
		-- Get button's screen position (which is on the map)
		local btnX, btnY = mapClickBtn:GetEffectiveOffset()
		
		-- If button position works, use it; otherwise try window position
		local baseX, baseY
		if btnX and btnY then
			baseX = btnX
			baseY = btnY
		else
			-- Try window position
			local winX, winY = window:GetEffectiveOffset()
			if winX and winY then
				baseX = winX + mapOffsetX
				baseY = winY + mapOffsetY
			end
		end
		
		if baseX and baseY then
			-- Calculate position relative to map drawable
			local mapX = mouseX - baseX
			local mapY = mouseY - baseY
			
			-- Check if click is within map bounds
			if mapX >= 0 and mapX <= constants.map.width and mapY >= 0 and mapY <= constants.map.height then
				if onMapClickCallback then
					onMapClickCallback(mapX, mapY)
				end
			end
		end
	end
	
	mapClickBtn:SetHandler("OnClick", mapClickBtn.OnClick)
	
	
	local overlay = window:CreateImageDrawable("yes", "overlay")
	overlay:AddAnchor("TOPLEFT", window, 0, 0)
	overlay:SetExtent(819, 776)
	overlay:SetTexture(api.baseDir .. "/WorldSatNav/images/overlay4.png")
	window.overlay = overlay

	if constants.DEV_MODE then
		window.bg = window:CreateNinePartDrawable(TEXTURE_PATH.HUD, "background")
		window.bg:SetTextureInfo("bg_quest")
		local bg = constants.tracking.backgroundColor
		window.bg:SetColor(bg[1], bg[2], bg[3], bg[4])
		window.bg:AddAnchor("TOPLEFT", window, 0, 790)
		window.bg:SetExtent(750, 50)
		window.bg:Show(true)

		window.inputxscale = helpers.createTextInput("inputxscale", window, 15, 790, 150, 26, "0", 100, "X scale", function(text)
			constants.map.tweakScaleX = tonumber(text) or 0
			api.Log:Info("tweakScaleX set to " .. constants.map.tweakScaleX)
			ships.DisplayShips(true)
		end)
		window.inputyscale = helpers.createTextInput("inputyscale", window, 175, 790, 150, 26, "0", 100, "Y scale", function(text)
			constants.map.tweakScaleY = tonumber(text) or 0
			api.Log:Info("tweakScaleY set to " .. constants.map.tweakScaleY)
			ships.DisplayShips(true)
		end)
		window.inputxcenter = helpers.createTextInput("inputxcenter", window, 335, 790, 150, 26, tostring(coordinates.renderingSettings.centerPointX), 100, "X center", function(text)
			coordinates.renderingSettings.centerPointX = tonumber(text) or coordinates.renderingSettings.centerPointX
			api.Log:Info("centerPointX set to " .. coordinates.renderingSettings.centerPointX)
			ships.DisplayShips(true)
		end)
		window.inputycenter = helpers.createTextInput("inputycenter", window, 495, 790, 150, 26, tostring(coordinates.renderingSettings.centerPointY), 100, "Y center", function(text)
			coordinates.renderingSettings.centerPointY = tonumber(text) or coordinates.renderingSettings.centerPointY
			api.Log:Info("centerPointY set to " .. coordinates.renderingSettings.centerPointY)
			ships.DisplayShips(true)
		end)
		window.inputxscale:Raise()
		window.inputyscale:Raise()
		window.inputxcenter:Raise()
		window.inputycenter:Raise()
	end

	local overlayCloseButton = window:CreateChildWidget("button", "overlayCloseButton", 0, true)
	overlayCloseButton:AddAnchor("TOPLEFT", window, 758, 15)
	overlayCloseButton:SetExtent(46, 59)
	overlayCloseButton:Show(true)
	overlayCloseButton:Enable(true)
	
	function overlayCloseButton:OnClick()
		if onCloseCallback then
			onCloseCallback()
		end
	end
	
	overlayCloseButton:SetHandler("OnClick", overlayCloseButton.OnClick)
	return window
end

-- Create the overlay toggle button
function UIWindows.createOverlayButton(onClickCallback)
	local overlayWnd = api.Interface:CreateEmptyWindow("overlayWnd", "UIParent")
	overlayWnd:SetExtent(64, 70)
	overlayWnd:AddAnchor("TOPLEFT", "UIParent", settings.Get("OpenButtonX"), settings.Get("OpenButtonY"))
	overlayWnd.bg = overlayWnd:CreateImageDrawable("bg", "background")
	overlayWnd.bg:SetTexture(api.baseDir .. "/WorldSatNav/images/ui_icon5.png")
	overlayWnd.bg:AddAnchor("TOPLEFT", overlayWnd, 0, 0)
	overlayWnd.bg:SetExtent(64, 70)
	overlayWnd.bg:Show(true)
	overlayWnd:Show(true)
	overlayWnd:Lower()

	-- Drag events for overlay button
	-- Click handler
	local clickBtn = overlayWnd:CreateChildWidget("button", "clickBtn", 0, true)
	clickBtn:AddAnchor("TOPLEFT", overlayWnd, 0, 0)
	clickBtn:AddAnchor("BOTTOMRIGHT", overlayWnd, 0, 0)
	clickBtn:Show(true)
	clickBtn:Enable(true)
	clickBtn:SetSounds("store_drain")


	helpers.makeWindowDraggable(clickBtn, overlayWnd, "OpenButtonX", "OpenButtonY")

	function clickBtn:HoverStart()
		local mouseX, mouseY = overlayWnd:GetEffectiveOffset()
		api.Interface:SetTooltipOnPos("Click to toggle overlay", overlayWnd, mouseX + overlayWnd:GetWidth(), mouseY)
		overlayWnd.bg:SetTexture(api.baseDir .. "/WorldSatNav/images/ui_icon5_hover.png")
	end

	function clickBtn:HoverEnd()
		api.Interface:SetTooltipOnPos("", overlayWnd, 0, 0)
		overlayWnd.bg:SetTexture(api.baseDir .. "/WorldSatNav/images/ui_icon5.png")
	end
	clickBtn:SetHandler("OnEnter", clickBtn.HoverStart)
	clickBtn:SetHandler("OnLeave", clickBtn.HoverEnd)

	function clickBtn:OnClick()
		if onClickCallback then
			onClickCallback()
		end
	end
	
	clickBtn:SetHandler("OnClick", clickBtn.OnClick)

	return overlayWnd
end

return UIWindows
