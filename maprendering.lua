-- WorldSatNav Main Module
local api = require("api")
local helpers = require("WorldSatNav/helpers")
local constants = require("WorldSatNav/constants")
local settingsModule = require("WorldSatNav/settings")
local eventbus = require("WorldSatNav/eventbus")
local eventtopics = require("WorldSatNav/eventtopics")
local maprendering = {}

local TOPICS = eventtopics.topics

local GetCurrentPosition

local mapLevels = {
	{ level = 0, texture = "zoom-0.png", width = 473, height = 507, zoomfactor = 0, zeroPointX=311,zeroPointY=122,XCordScale=14.59,YCordScale=14.40},
	{ level = 1, texture = "zoom-1.png", width = 948, height = 1017, zoomfactor = 2, zeroPointX=622,zeroPointY=246,XCordScale=29.13,YCordScale=28.85},
	{ level = 2, texture = "zoom-2.png", width = 1897, height = 2023, zoomfactor = 4, zeroPointX=1246,zeroPointY=494,XCordScale=58.27,YCordScale=57.65},
	{ level = 3, texture = "zoom-3.png", width = 3819, height = 4047, zoomfactor = 8, zeroPointX=2515,zeroPointY=989,XCordScale=116.35,YCordScale=115.21}
}

-- Module state
local WorldSatNavState = {
	zoom = 0,
	minZoom = 0,
	maxZoom = 3,
	mapWindowWidth = 473,
	mapWindowHeight = 509,
	UIWindowWidth = 484,
	UIWindowHeight = 522,
	scrollX = 0,
	scrollY = 0,
	lastMouseX = 0,
	lastMouseY = 0,
	isDragging = false,
	userPanned = false,
	iconSize = 15,
	zoomLevel = 0,
	LastRenderConfig = {
		level = nil,
		scrollX = nil,
		scrollY = nil,
		playerIconSextant = nil,
		iconsversion = false,
	},
}

local iconsStore = {}
local iconsStoreIndexCounter = 1
local flashModeTicks = 0

local function SextantEquals(left, right)
	if left == nil or right == nil then
		return left == right
	end
	return left.longitude == right.longitude
		and left.latitude == right.latitude
		and left.deg_long == right.deg_long
		and left.min_long == right.min_long
		and left.sec_long == right.sec_long
		and left.deg_lat == right.deg_lat
		and left.min_lat == right.min_lat
		and left.sec_lat == right.sec_lat
end


local function ApplyIconSize(icon, customIconSize)
	local size = customIconSize or WorldSatNavState.iconSize
	local uiScale = settingsModule.Get("uiDrawScale")
	local zoomScale = 1
	local renderSettings = maprendering.GetMapInfoForZoom(WorldSatNavState.zoomLevel)
	if renderSettings ~= nil then
		zoomScale = 1 + ((renderSettings.zoomfactor or 0) * 0.1)
	end
	local scaledSize = size * uiScale * zoomScale
	if icon.baseSize == size and icon.appliedUiScale == uiScale and icon.appliedZoomScale == zoomScale then
		return
	end
	icon.baseSize = size
	icon.appliedUiScale = uiScale
	icon.appliedZoomScale = zoomScale
	icon.scaledSize = scaledSize
	icon:SetExtent(scaledSize, scaledSize)
	icon.button:SetExtent(scaledSize, scaledSize)
end

local iconIdIndex = 0
local lastClickedIndex = nil

local function SelectActiveMapIcon(icon)
	if icon == nil then
		helpers.DevLog("Cannot update texture for selected ship, icon is nil")
		return
	end
	if icon.indexId == nil then
		helpers.DevLog("Cannot update texture for selected ship, icon indexId is nil")
		return
	end
	lastClickedIndex = icon.indexId
	if icon.sourceType == "Ship" then
		helpers.DevLog("Publishing ship select by sextant event")
		eventbus.TriggerEvent(TOPICS.ships.selectBySextant, icon.sextant)
	else
		helpers.DevLog("Selected icon source type is not Ship")
	end
	helpers.DevLog("Publishing icon click event for sourceType: "..tostring(icon.sourceType))
	eventbus.TriggerEvent(TOPICS.tracking.start, icon.sextant, icon.sourceType, true)
	maprendering.ToggleMap()
end


local function findOrCreateIcon(withTexturePath, customIconSize)
	customIconSize = customIconSize or WorldSatNavState.iconSize
	-- First look for free icons with the same texture
	for index, icon in pairs(iconsStore) do
		if (icon.textureNode == withTexturePath) and (icon.inuse == false) then
			icon.inuse = true
			ApplyIconSize(icon, customIconSize)
			return icon
		end
	end
	-- No free icons with the same texture, look for any free icon
	for index, icon in pairs(iconsStore) do
		if icon ~= maprendering.playerIcon and (icon.inuse == false) then
			icon.inuse = true
			icon.textureNode = withTexturePath
			icon:SetTexture(constants.folderPath.."images/" .. withTexturePath)
			ApplyIconSize(icon, customIconSize)
			return icon
		end
	end
	-- No free icons, create a new one
	if not maprendering.MapUI then
		api.Log:Err("Cannot create icon, MapUI is not initialized")
		return nil
	end
	local icon = maprendering.MapUI:CreateImageDrawable("icon_" .. iconsStoreIndexCounter, "overlay")
	icon.textureNode = withTexturePath
	icon.inuse = true
	icon.sextant = nil
	icon.renderedZoomLevel = nil
	icon.renderedXstate = nil
	icon.renderedYstate = nil
	icon.attachedto = nil
	icon.sourceType = "none"
	icon.indexId = iconIdIndex
	icon:SetTexture(constants.folderPath.."images/" .. withTexturePath)
	icon:Show(false)
	iconsStoreIndexCounter = iconsStoreIndexCounter + 1
    local button = maprendering.MapUI:CreateChildWidget("button", "iconButton_" .. iconIdIndex, 0, true)
	iconIdIndex = iconIdIndex + 1
	button:AddAnchor("TOPLEFT", icon, "TOPLEFT" , 0, 0)
	button:SetExtent(1, 1)
    button:Show(true)
    button:Enable(true)
    if button.SetSounds ~= nil then
        button:SetSounds("my_farm_info")
    end
    button:Raise()
	function button:OnClick()
		if icon.indexId == 0 then
			helpers.DevLog("Player icon clicked, ignoring")
			return
		end
		--maprendering.ToggleMap()
		helpers.DevLog("Icon clicked, sourceType: "..tostring(icon.sourceType)..", indexId: "..tostring(icon.indexId))
		SelectActiveMapIcon(icon)
	end
	button:SetHandler("OnClick", button.OnClick)
	icon.button = button
	iconsStore[iconsStoreIndexCounter] = icon
	ApplyIconSize(icon, customIconSize)
	return icon
end

local configWindowVisible = false
local currentMapMode = "maps"


function maprendering.ChangeSelectedIcon(sextant, withTexturePath)
	if sextant == nil then
		helpers.DevLog("Cannot change selected icon, sextant is nil")
		return
	end
	for _, icon in pairs(iconsStore) do
		if icon.sextant ~= nil and SextantEquals(icon.sextant, sextant) then
			icon.textureNode = withTexturePath
			icon:SetTexture(constants.folderPath.."images/" .. withTexturePath)
			return
		end
	end
	helpers.DevLog("No icon found for sextant, cannot change selected icon")
end

function maprendering.GetLastSelectedIconSextant()
	if lastClickedIndex == nil then
		helpers.DevLog("No last clicked icon index, cannot get last selected icon sextant")
		return nil, nil
	end
	for _, icon in pairs(iconsStore) do
		if icon.indexId == lastClickedIndex then
			helpers.DevLog("Last selected icon found with indexId: "..tostring(icon.indexId)..", sourceType: "..tostring(icon.sourceType))
			return icon.indexId, icon.sextant
		end
	end
	helpers.DevLog("No icon found for last clicked index: "..tostring(lastClickedIndex))
	return nil, nil
end
function maprendering.DisableIconBySextent(sextent,matchtype)
	if lastClickedIndex == nil then
		return
	end
	for _, icon in pairs(iconsStore) do
		if icon.sourceType == matchtype then
			if icon.sextant ~= nil and SextantEquals(icon.sextant, sextent) then
				icon:Show(false)
				icon.inuse = false
				return
			end
		end
	end
end

local inFlashSelectedMode = false
local selectedFlashIcon = nil
local flashState = false

local function AttachDrawableIcon(icon, sextant, drawTarget)
	if not icon then
		helpers.DevLog("Cannot attach icon, icon is nil")
		return
	end
	if not drawTarget then
		helpers.DevLog("Cannot attach icon, drawTarget is nil")
		return
	end
	if icon and drawTarget then
		icon.inuse = true
		if sextant ~= nil then
			icon.sextant = sextant
		end
		WorldSatNavState.LastRenderConfig.iconsversion = false
		icon.renderedZoomLevel = nil
		icon.renderedXstate = nil
		icon.renderedYstate = nil
		icon.renderedSextant = nil
		icon:RemoveAllAnchors()
		icon:AddAnchor("TOPLEFT", drawTarget, "TOPLEFT", 0, 0)
		icon.attachedto = drawTarget
		icon:Show(true)
	end
end

local function IsValidSextant(sextant)
	sextant = maprendering.NormalizeSextant(sextant)
	if not sextant then
		return false
	end
	return sextant.longitude ~= nil
		and sextant.latitude ~= nil
		and sextant.deg_long ~= nil
		and sextant.min_long ~= nil
		and sextant.sec_long ~= nil
		and sextant.deg_lat ~= nil
		and sextant.min_lat ~= nil
		and sextant.sec_lat ~= nil
end

function maprendering.NormalizeSextant(sextant)
	if sextant == nil then
		return nil
	end
	local normalized = {
		longitude = sextant.longitudeDir or sextant.longitude,
		latitude = sextant.latitudeDir or sextant.latitude,
		deg_long = sextant.longitudeDeg or sextant.deg_long or sextant.degLong,
		min_long = sextant.longitudeMin or sextant.min_long or sextant.minLong,
		sec_long = sextant.longitudeSec or sextant.sec_long or sextant.secLong,
		deg_lat = sextant.latitudeDeg or sextant.deg_lat or sextant.degLat,
		min_lat = sextant.latitudeMin or sextant.min_lat or sextant.minLat,
		sec_lat = sextant.latitudeSec or sextant.sec_lat or sextant.secLat
	}
	if normalized.min_long == nil then normalized.min_long = 0 end
	if normalized.sec_long == nil then normalized.sec_long = 0 end
	if normalized.min_lat == nil then normalized.min_lat = 0 end
	if normalized.sec_lat == nil then normalized.sec_lat = 0 end
	return normalized
end

local function HideIcon(index)
	if iconsStore[index] then
		local iconU = iconsStore[index]
		iconU:Show(false)
		iconU.inuse = false
		iconU.sextant = nil
		iconU.renderedZoomLevel = nil
		iconU.renderedXstate = nil
		iconU.renderedYstate = nil
		iconU:RemoveAllAnchors()
		iconU:AddAnchor("TOPLEFT", maprendering.MapUI, "TOPLEFT", 0, 0)
		iconsStore[index] = iconU
	end
end

local function HideAllIcons()
	for index, _ in pairs(iconsStore) do
		HideIcon(index)
	end
end

function maprendering.CreateIconAttachedToMap(sextant, withTexturePath, sourceType, customIconSize)
	local icon = findOrCreateIcon(withTexturePath, customIconSize)
	if not icon then
		helpers.DevLog("Failed to create or find icon for texture: " .. withTexturePath)
		return nil
	end
	icon.sourceType = sourceType
	AttachDrawableIcon(icon, sextant, maprendering.MapUI.mapImage)
	return icon
end


local function CopySextant(sextant)
	sextant = maprendering.NormalizeSextant(sextant)
	if sextant == nil then
		return nil
	end
	return {
		longitude = sextant.longitude,
		latitude = sextant.latitude,
		deg_long = sextant.deg_long,
		min_long = sextant.min_long,
		sec_long = sextant.sec_long,
		deg_lat = sextant.deg_lat,
		min_lat = sextant.min_lat,
		sec_lat = sextant.sec_lat
	}
end

local function redrawMapIcons(drawTarget)
	local needsRedraw = false
	local why = "unknown reason"

	if drawTarget == nil then
		helpers.DevLog("Cannot redraw map icons, drawTarget is nil")
		return
	end
	local renderSettings = maprendering.GetMapInfoForZoom(WorldSatNavState.zoomLevel)
	if renderSettings == nil then
		helpers.DevLog("Cannot trigger map redraw, renderSettings for current zoom level is not available")
		return
	end
	if WorldSatNavState.LastRenderConfig == nil then
		WorldSatNavState.LastRenderConfig = {
			level = nil,
			scrollX = nil,
			scrollY = nil,
			playerIconSextant = nil,
			iconsversion = false
		}
		needsRedraw = true
		why = "no last render config"
	end
	local playerSextant = nil
	if maprendering.playerIcon ~= nil then
		if maprendering.playerIcon.sextant ~= nil then
			playerSextant = maprendering.playerIcon.sextant
		end
	end
	if playerSextant ~= nil then
		local playerChanged = not SextantEquals(playerSextant, WorldSatNavState.LastRenderConfig.playerIconSextant)
		if playerChanged then
			needsRedraw = true
			why = "player position changed"
		end
	end

	if WorldSatNavState.LastRenderConfig.iconsversion == false then
		needsRedraw = true
		why = "icons version is false"
	end
	if renderSettings.level ~= WorldSatNavState.LastRenderConfig.level then
		needsRedraw = true
		why = "map zoom changed"
	end
	if WorldSatNavState.scrollX ~= WorldSatNavState.LastRenderConfig.scrollX or WorldSatNavState.scrollY ~= WorldSatNavState.LastRenderConfig.scrollY then
		needsRedraw = true
		why = "map scroll changed"
	end

	if needsRedraw == false then
		return
	end
		
	WorldSatNavState.LastRenderConfig.level = renderSettings.level
	WorldSatNavState.LastRenderConfig.scrollX = WorldSatNavState.scrollX
	WorldSatNavState.LastRenderConfig.scrollY = WorldSatNavState.scrollY
	WorldSatNavState.LastRenderConfig.playerIconSextant = CopySextant(playerSextant)
	WorldSatNavState.LastRenderConfig.iconsversion = true

	local viewWidth = math.floor(renderSettings.width / (renderSettings.zoomfactor + 1))
	local viewHeight = math.floor(renderSettings.height / (renderSettings.zoomfactor + 1))
	local imageWidth = drawTarget:GetWidth()
	local imageHeight = drawTarget:GetHeight()
	if viewWidth <= 0 or viewHeight <= 0 or imageWidth <= 0 or imageHeight <= 0 then
		helpers.DevLog("Cannot redraw icons, invalid view or image size")
		return
	end

	local scaleX = imageWidth / viewWidth
	local scaleY = imageHeight / viewHeight
	for index, icon in pairs(iconsStore) do
		if icon.inuse == true and icon.sextant ~= nil and icon.attachedto == drawTarget then
			ApplyIconSize(icon, icon.baseSize or WorldSatNavState.iconSize)
			local iconScaledSize = icon.scaledSize or (WorldSatNavState.iconSize * settingsModule.Get("uiDrawScale"))
			local halfSize = iconScaledSize / 2
			if icon.renderedZoomLevel == renderSettings.level and icon.renderedXstate == WorldSatNavState.scrollX and icon.renderedYstate == WorldSatNavState.scrollY and SextantEquals(icon.sextant, icon.renderedSextant) then
				
			else
				local mapX, mapY = maprendering.convertSextantToMapCoordinates(icon.sextant, renderSettings)
				if mapX ~= nil and mapY ~= nil then
					local relX = (mapX - WorldSatNavState.scrollX) * scaleX
					local relY = (mapY - WorldSatNavState.scrollY) * scaleY
					local allowedOffscreen = iconScaledSize * 0.05
					local minX = halfSize - allowedOffscreen
					local maxX = imageWidth + allowedOffscreen - halfSize
					local minY = halfSize - allowedOffscreen
					local maxY = imageHeight + allowedOffscreen - halfSize
					local inView = relX >= minX
						and relX <= maxX
						and relY >= minY
						and relY <= maxY
					if not inView then
						icon:Show(false)
						icon.renderedSextant = CopySextant(icon.sextant)
						icon.renderedZoomLevel = renderSettings.level
						icon.renderedXstate = WorldSatNavState.scrollX
						icon.renderedYstate = WorldSatNavState.scrollY
					else
						icon:RemoveAllAnchors()
						icon.renderedZoomLevel = renderSettings.level
						icon.renderedXstate = WorldSatNavState.scrollX
						icon.renderedYstate = WorldSatNavState.scrollY
						icon.renderedSextant = CopySextant(icon.sextant)
						icon:AddAnchor("TOPLEFT", drawTarget, "TOPLEFT", relX - halfSize, relY - halfSize)
						icon:Show(true)
					end
				else
					helpers.DevLog("Failed to convert sextant to map coordinates for icon index " .. index .. ", hiding icon")
					icon:Show(false)
				end
			end
		end
	end
end

function maprendering.FlashModeIcon(sextant, withTexturePath, sourceType, customIconSize)
	if inFlashSelectedMode == true then
		return
	end
	HideAllIcons()
	maprendering.playerIcon.inuse = true
	selectedFlashIcon = maprendering.CreateIconAttachedToMap(sextant, withTexturePath, sourceType, customIconSize)
	flashModeTicks = 0
	flashState = true
	WorldSatNavState.LastRenderConfig.iconsversion = false
	maprendering.TriggerMapRedraw()
	inFlashSelectedMode = true
end

function maprendering.ExitFlashMode()
	if inFlashSelectedMode == false then
		return
	end
	inFlashSelectedMode = false
	maprendering.RequestModeRedraw()
end



function maprendering.convertSextantToMapCoordinates(sextant, renderSettings)
	-- sextant coordinate structure with longitude, latitude, deg_long, min_long, sec_long, deg_lat, min_lat, sec_lat
	sextant = maprendering.NormalizeSextant(sextant)
	if not sextant or not renderSettings then
		helpers.DevLog("Cannot convert sextant to map coordinates, sextant or renderSettings is nil")
		return nil, nil
	end

	local long = sextant.longitude
	local lat = sextant.latitude

	local longValue = 0
	local latValue = 0
	if long == nil or lat == nil then
		helpers.DevLog("Invalid sextant data, missing longitude or latitude direction")
		return nil, nil
	end

	local degLong = sextant.deg_long
	local minLong = sextant.min_long
	local secLong = sextant.sec_long
	local degLat = sextant.deg_lat
	local minLat = sextant.min_lat
	local secLat = sextant.sec_lat
	if degLong == nil or minLong == nil or secLong == nil or degLat == nil or minLat == nil or secLat == nil then
		helpers.DevLog("Invalid sextant data, cannot convert to map coordinates")
		return nil, nil
	end
	longValue = degLong + (minLong / 60) + (secLong / 3600)
	latValue = degLat + (minLat / 60) + (secLat / 3600)

	if sextant.longitude == "W" then
		longValue = -longValue
	end
	if sextant.latitude == "N" then
		latValue = -latValue
	end

	local x = renderSettings.zeroPointX + (longValue * renderSettings.XCordScale)
	local y = renderSettings.zeroPointY + (latValue * renderSettings.YCordScale)
	return x, y
end


function maprendering.TriggerMapRedraw()
	if maprendering.MapUI == nil or maprendering.MapUI.mapImage == nil then
		helpers.DevLog("Cannot trigger map redraw, MapUI or mapImage is not initialized")
		return
	end
	if maprendering.playerIcon == nil then
		helpers.DevLog("Player icon is not initialized")
	end
	if maprendering.playerIcon ~= nil then
		local currentPosition = GetCurrentPosition()
		if currentPosition ~= nil then
			maprendering.playerIcon.sextant = currentPosition
		end
	end
	if inFlashSelectedMode == true and selectedFlashIcon ~= nil then
		flashModeTicks = flashModeTicks + 1
		if flashModeTicks == 4 then
			flashModeTicks = 0
			flashState = not flashState
			selectedFlashIcon:Show(flashState)
		end
		return
	else
		redrawMapIcons(maprendering.MapUI.mapImage)
	end
end

local function LoadMapTexture(givenzoomLevel)
	local mapInfo = mapLevels[givenzoomLevel + 1]
	if not mapInfo then
		api.Log:Err("Invalid zoom level: " .. givenzoomLevel)
		return nil, 0, 0, 0, nil
	end
	local texturePath = constants.folderPath.."images/map2/" .. mapInfo.texture
	return texturePath, mapInfo.width, mapInfo.height, mapInfo.zoomfactor, mapInfo
end

local function ApplyMapView()
	if maprendering.MapUI == nil or maprendering.MapUI.mapImage == nil then
		helpers.DevLog("Cannot apply map view, MapUI or mapImage is not initialized")
		return
	end
	local mapInfo = maprendering.GetMapInfoForZoom(WorldSatNavState.zoomLevel)
	local viewWidth = math.floor(mapInfo.width / (mapInfo.zoomfactor + 1))
	local viewHeight = math.floor(mapInfo.height / (mapInfo.zoomfactor + 1))
	local maxX = math.max(0, mapInfo.width - viewWidth)
	local maxY = math.max(0, mapInfo.height - viewHeight)
	WorldSatNavState.scrollX = math.min(math.max(WorldSatNavState.scrollX, 0), maxX)
	WorldSatNavState.scrollY = math.min(math.max(WorldSatNavState.scrollY, 0), maxY)
	maprendering.MapUI.mapImage:SetCoords(math.floor(WorldSatNavState.scrollX), math.floor(WorldSatNavState.scrollY), viewWidth, viewHeight)
	redrawMapIcons(maprendering.MapUI.mapImage)
end

function maprendering.GetMapInfoForZoom(givenzoomLevel)
	return mapLevels[givenzoomLevel + 1]
end

local function GetMouseFocusForZoom(mapImage, givenzoomLevel)
	if not mapImage or not mapImage.GetEffectiveOffset then
		return nil, nil
	end
	local mapInfo = maprendering.GetMapInfoForZoom(givenzoomLevel)
	if not mapInfo then
		return nil, nil
	end
	local mouseX, mouseY = api.Input:GetMousePos()
	local mapX, mapY = mapImage:GetEffectiveOffset()
	local viewWidth = math.floor(mapInfo.width / (mapInfo.zoomfactor + 1))
	local viewHeight = math.floor(mapInfo.height / (mapInfo.zoomfactor + 1))
	local imageWidth = WorldSatNavState.mapWindowWidth
	local imageHeight = WorldSatNavState.mapWindowHeight
	if mapImage.GetWidth then
		local width = mapImage:GetWidth()
		if width and width > 0 then
			imageWidth = width
		end
	end
	if mapImage.GetHeight then
		local height = mapImage:GetHeight()
		if height and height > 0 then
			imageHeight = height
		end
	end
	local relX = mouseX - mapX
	local relY = mouseY - mapY
	if relX < 0 then
		relX = 0
	elseif relX > imageWidth then
		relX = imageWidth
	end
	if relY < 0 then
		relY = 0
	elseif relY > imageHeight then
		relY = imageHeight
	end
	local scaleX = 1
	local scaleY = 1
	if imageWidth > 0 then
		scaleX = viewWidth / imageWidth
	end
	if imageHeight > 0 then
		scaleY = viewHeight / imageHeight
	end
	local mapXPos = WorldSatNavState.scrollX + (relX * scaleX)
	local mapYPos = WorldSatNavState.scrollY + (relY * scaleY)
	return mapXPos / mapInfo.width, mapYPos / mapInfo.height
end

local function GetViewCenterNormalized(zoomLevel)
	local mapInfo = maprendering.GetMapInfoForZoom(zoomLevel)
	if not mapInfo then
		return nil, nil
	end
	local viewWidth = math.floor(mapInfo.width / (mapInfo.zoomfactor + 1))
	local viewHeight = math.floor(mapInfo.height / (mapInfo.zoomfactor + 1))
	local centerX = WorldSatNavState.scrollX + (viewWidth / 2)
	local centerY = WorldSatNavState.scrollY + (viewHeight / 2)
	return centerX / mapInfo.width, centerY / mapInfo.height
end

local function SetMapZoom(givenzoomLevel, mapImage, focusX, focusY)
	local texture, texWidth, texHeight, zoomFactor, mapInfo = LoadMapTexture(givenzoomLevel)
	if not texture then
		api.Log:Err("Failed to load map texture for zoom level: " .. givenzoomLevel)
		return nil
	end
	mapImage:SetTexture(texture)
	WorldSatNavState.zoomLevel = givenzoomLevel
	local viewWidth = math.floor(texWidth / (zoomFactor + 1))
	local viewHeight = math.floor(texHeight / (zoomFactor + 1))
	if focusX ~= nil and focusY ~= nil then
		WorldSatNavState.scrollX = math.floor(focusX - (viewWidth / 2))
		WorldSatNavState.scrollY = math.floor(focusY - (viewHeight / 2))
		WorldSatNavState.userPanned = true
	elseif not WorldSatNavState.userPanned then
		WorldSatNavState.scrollX = math.floor((texWidth - viewWidth) / 2)
		WorldSatNavState.scrollY = math.floor((texHeight - viewHeight) / 2)
	end
	ApplyMapView()
end

local function CreateWorldSatNavWindow()
	local window = api.Interface:CreateEmptyWindow("WorldSatNav")
	window:AddAnchor("TOPLEFT", "UIParent", settingsModule.Get("MainWindowX"), settingsModule.Get("MainWindowY"))
	window.DrawHeight = WorldSatNavState.UIWindowHeight*settingsModule.Get("uiDrawScale")
	window.DrawWidth = WorldSatNavState.UIWindowWidth*settingsModule.Get("uiDrawScale")
	window:SetExtent(window.DrawWidth, window.DrawHeight)
	window:SetCloseOnEscape(true)
	window:SetSounds("world_map")

	local windowBackground = window:CreateImageDrawable("mapimage", "background")
	windowBackground:SetExtent(window.DrawWidth, window.DrawHeight)
	windowBackground:AddAnchor("TOPLEFT", window, "TOPLEFT", 0, 0)
	windowBackground:SetTexture(api.baseDir .. "/WorldSatNav/images/mainuibackground3.png")
	windowBackground:Show(true)
	if windowBackground.Lower then
		windowBackground:Lower()
	end

	local mapBackground = window:CreateColorDrawable(199/255, 184/255, 115/255, 1, "background")
	mapBackground:SetExtent(WorldSatNavState.mapWindowWidth*settingsModule.Get("uiDrawScale"), WorldSatNavState.mapWindowHeight*settingsModule.Get("uiDrawScale"))
	mapBackground:AddAnchor("TOPLEFT", window, "TOPLEFT", 5*settingsModule.Get("uiDrawScale"), 4*settingsModule.Get("uiDrawScale"))
	mapBackground:Show(true)
	if mapBackground.Lower then
		mapBackground:Lower()
	end

	local menuBackground = window:CreateImageDrawable("mapimagemenubackground", "background")
	menuBackground:SetExtent(55*settingsModule.Get("uiDrawScale"),165*settingsModule.Get("uiDrawScale"))
	menuBackground:AddAnchor("TOPLEFT", window, "TOPLEFT", (WorldSatNavState.UIWindowWidth-5)*settingsModule.Get("uiDrawScale"), 125*settingsModule.Get("uiDrawScale"))
	menuBackground:SetTexture(api.baseDir .. "/WorldSatNav/images/mainuibackground3.png")
	menuBackground:Show(true)
	if menuBackground.Lower then
		menuBackground:Lower()
	end

	local mapImage = window:CreateImageDrawable("mapimage", "background")
	mapImage:SetExtent(WorldSatNavState.mapWindowWidth*settingsModule.Get("uiDrawScale"), WorldSatNavState.mapWindowHeight*settingsModule.Get("uiDrawScale"))
	mapImage:AddAnchor("TOPLEFT", window, "TOPLEFT", 5*settingsModule.Get("uiDrawScale"), 4*settingsModule.Get("uiDrawScale"))
	SetMapZoom(WorldSatNavState.zoomLevel, mapImage)
	mapImage:Show(true)

	function window:DragStart()
		if api.Input:IsShiftKeyDown() then
			return
		end
		WorldSatNavState.isDragging = true
		local mouseX, mouseY = api.Input:GetMousePos()
		WorldSatNavState.lastMouseX = mouseX
		WorldSatNavState.lastMouseY = mouseY
	end
	function window:DragStop()
		if api.Input:IsShiftKeyDown() then
			return
		end
		WorldSatNavState.isDragging = false
		WorldSatNavState.userPanned = true
		redrawMapIcons(maprendering.MapUI.mapImage)
	end

	helpers.makeWindowDraggable(window, window.DragStart, window.DragStop, true, true, "MainWindowX", "MainWindowY",true,true)
	function window:OnWheelUp(arg)
		if api.Input:IsControlKeyDown() == false then
			return
		end
		if WorldSatNavState.zoomLevel >= WorldSatNavState.maxZoom then
			return
		end
		local normX, normY = GetMouseFocusForZoom(mapImage, WorldSatNavState.zoomLevel)
		if normX == nil or normY == nil then
			normX, normY = GetViewCenterNormalized(WorldSatNavState.zoomLevel)
		end
		WorldSatNavState.zoomLevel = math.min(WorldSatNavState.zoomLevel + 1, WorldSatNavState.maxZoom)
		local newMapInfo = maprendering.GetMapInfoForZoom(WorldSatNavState.zoomLevel)
		local focusX = normX * newMapInfo.width
		local focusY = normY * newMapInfo.height
		SetMapZoom(WorldSatNavState.zoomLevel, mapImage, focusX, focusY)
		WorldSatNavState.isDragging = false
		local mouseX, mouseY = api.Input:GetMousePos()
		WorldSatNavState.lastMouseX = mouseX
		WorldSatNavState.lastMouseY = mouseY
	end
	window:SetHandler("OnWheelUp", window.OnWheelUp)
	function window:OnWheelDown(arg)
		if api.Input:IsControlKeyDown() == false then
			return
		end
		if WorldSatNavState.zoomLevel <= WorldSatNavState.minZoom then
			return
		end
		local normX, normY = GetMouseFocusForZoom(mapImage, WorldSatNavState.zoomLevel)
		if normX == nil or normY == nil then
			normX, normY = GetViewCenterNormalized(WorldSatNavState.zoomLevel)
		end
		WorldSatNavState.zoomLevel = math.max(WorldSatNavState.zoomLevel - 1, WorldSatNavState.minZoom)
		local newMapInfo = maprendering.GetMapInfoForZoom(WorldSatNavState.zoomLevel)
		local focusX = normX * newMapInfo.width
		local focusY = normY * newMapInfo.height
		SetMapZoom(WorldSatNavState.zoomLevel, mapImage, focusX, focusY)
		WorldSatNavState.isDragging = false
		local mouseX, mouseY = api.Input:GetMousePos()
		WorldSatNavState.lastMouseX = mouseX
		WorldSatNavState.lastMouseY = mouseY
	end
	window:SetHandler("OnWheelDown", window.OnWheelDown)

	function window:OnClose()
		maprendering.ToggleMap()
	end
	window:SetHandler("OnClose", window.OnClose)
	window:SetHandler("OnCloseByEsc", window.OnClose)

	window.closeBtn = window:CreateChildWidget("button", "closeBtn", 0, true)
	window.closeBtn:AddAnchor("TOPLEFT", window, window.DrawWidth - (20*settingsModule.Get("uiDrawScale")), 3*settingsModule.Get("uiDrawScale"))
	api.Interface:ApplyButtonSkin(window.closeBtn, BUTTON_BASIC.WINDOW_SMALL_CLOSE)
	window.closeBtn:Show(true)
	window.closeBtn:SetHandler("OnClick", window.OnClose)

	window.mapImage = mapImage
	window.mapBackground = mapBackground
	return window
end

--- Get the current player position as sextant coordinates
-- @return table sextant coordinate structure with longitude, latitude, deg_long, min_long, sec_long, deg_lat, min_lat, sec_lat
GetCurrentPosition = function()
	return maprendering.NormalizeSextant(api.Map:GetPlayerSextants())
end

local lastupdate = 0


function maprendering.GetCurrentMode()
	return currentMapMode
end


local function UpdateMapMode(mode)
	helpers.SetCheckBoxOverride("mapsModeButton", false)
	helpers.SetCheckBoxOverride("shipsModeButton", false)
	helpers.SetCheckBoxOverride("eventsModeButton", false)
	helpers.SetCheckBoxOverride("demosModeButton", false)
	maprendering.ReloadUIItems()
	maprendering.ClearUIState()
	currentMapMode = mode
    if not maprendering.MapUI or not maprendering.MapUI.mapImage then
        return
    end
    if not maprendering.MapUI:IsVisible() then
		helpers.DevLog("Not triggering update for map mode change because map is not visible")
        return
    end
	if configWindowVisible == true then
		helpers.DevLog("Not triggering update for map mode change because config window is visible")
		return
	end
	HideAllIcons()
	eventbus.TriggerEvent(TOPICS.render.clearUiState)
	maprendering.playerIcon.inuse = true
	maprendering.playerIcon.sextant = GetCurrentPosition()
	maprendering.playerIcon.sourceType = "player"
	maprendering.playerIcon.textureNode = "icons/player.png"
	maprendering.playerIcon:SetTexture(constants.folderPath.."images/icons/player.png")
	AttachDrawableIcon(maprendering.playerIcon, maprendering.playerIcon.sextant, maprendering.MapUI.mapImage)
	if not IsValidSextant(maprendering.playerIcon.sextant) then
		maprendering.playerIcon:Show(false)
	end
	WorldSatNavState.LastRenderConfig.iconsversion = false
	eventbus.TriggerEvent(TOPICS.render.modeChanged, mode)
	if mode == "maps" then
		helpers.DevLog("Publishing maps render event due to map mode change")
		eventbus.TriggerEvent(TOPICS.render.maps)
	elseif mode == "ships" then
		eventbus.TriggerEvent(TOPICS.render.ships)
	elseif mode == "events" then
		eventbus.TriggerEvent(TOPICS.render.events)
	elseif mode == "demos" then
		eventbus.TriggerEvent(TOPICS.render.demos)
	else
		helpers.DevLog("Unknown map mode: " .. tostring(mode))
	end
	maprendering.TriggerMapRedraw()
end

function maprendering.RequestModeRedraw()
	UpdateMapMode(currentMapMode)
end

function maprendering.OnUpdate(dt)
    lastupdate = lastupdate + dt
    if lastupdate < (constants.timing.updateRate/4) then
        return
    end
    lastupdate = 0
    if not maprendering.MapUI or not maprendering.MapUI.mapImage then
        return
    end
    if not maprendering.MapUI:IsVisible() then
        return
    end
	if not maprendering.MapUI.mapImage:IsVisible() then
		return
	end
    local mapInfo = maprendering.GetMapInfoForZoom(WorldSatNavState.zoomLevel)
    if WorldSatNavState.isDragging then
        local mouseX, mouseY = api.Input:GetMousePos()
        local dx = mouseX - WorldSatNavState.lastMouseX
        local dy = mouseY - WorldSatNavState.lastMouseY
        if dx ~= 0 or dy ~= 0 then
            
            local scrollFactor = mapInfo.zoomfactor + 1
            dx = dx * (scrollFactor/4)
            dy = dy * (scrollFactor/4)
            WorldSatNavState.scrollX = WorldSatNavState.scrollX - dx
            WorldSatNavState.scrollY = WorldSatNavState.scrollY + dy
            ApplyMapView()
            WorldSatNavState.lastMouseX = mouseX
            WorldSatNavState.lastMouseY = mouseY
        end
    end
	maprendering.TriggerMapRedraw()
end


local function FocusOnMe()
	if not maprendering.MapUI or not maprendering.MapUI.mapImage then
		helpers.DevLog("Cannot focus on player, MapUI or mapImage is not initialized")
		return
	end
	local currentPosition = GetCurrentPosition()
	if currentPosition == nil then
		helpers.DevLog("Cannot focus on player, current position is nil")
		return
	end
	local mapInfo = maprendering.GetMapInfoForZoom(WorldSatNavState.zoomLevel)
	if mapInfo == nil then
		helpers.DevLog("Cannot focus on player, map info for current zoom level is not available")
		return
	end
	local focusX, focusY = maprendering.convertSextantToMapCoordinates(currentPosition, mapInfo)
	if focusX == nil or focusY == nil then
		helpers.DevLog("Cannot focus on player, failed to convert sextant to map coordinates")
		return
	end
	SetMapZoom(WorldSatNavState.zoomLevel, maprendering.MapUI.mapImage, focusX, focusY)
end

local cleanup = {}
local function CreateUiElements()
    maprendering.MapUI = CreateWorldSatNavWindow()
	if maprendering.MapUI == nil then
		helpers.DevLog("Failed to create MapUI")
		return
	end
	maprendering.MapUI:Show(false)

	maprendering.playerIcon = findOrCreateIcon("icons/player.png")
	if not maprendering.playerIcon then
		helpers.DevLog("Failed to create player icon")
		return
	end
	maprendering.playerIcon.sourceType = "player"
	maprendering.playerIcon.textureNode = "icons/player.png"
	maprendering.playerIcon:SetTexture(constants.folderPath.."images/icons/player.png")
	maprendering.playerIcon.sextant = GetCurrentPosition()
	AttachDrawableIcon(maprendering.playerIcon, maprendering.playerIcon.sextant, maprendering.MapUI.mapImage)
	if not IsValidSextant(maprendering.playerIcon.sextant) then
		maprendering.playerIcon:Show(false)
	end
	redrawMapIcons(maprendering.MapUI.mapImage)

	helpers.CreateSkinnedCheckbox("mapsModeButton", maprendering.MapUI, "Maps", 470, 128, true, function()
		UpdateMapMode("maps")
	end, 62, 25, "DisplayMode", "artwork", true, "button_active.png", "button_ready.png", "mail",false)
	helpers.CreateSkinnedCheckbox("shipsModeButton", maprendering.MapUI, "Ships", 470, 128+25, false, function()
		eventbus.TriggerEvent(TOPICS.ships.resetVisited)
		UpdateMapMode("ships")
	end, 62, 25, "DisplayMode", "artwork", true, "button_active.png", "button_ready.png", "mail",false)
	helpers.CreateSkinnedCheckbox("eventsModeButton", maprendering.MapUI, "Events", 470, 128+50, false, function()
		UpdateMapMode("events")
	end, 62, 25, "DisplayMode", "artwork", true, "button_active.png", "button_ready.png", "mail",false)
	helpers.CreateSkinnedCheckbox("demosModeButton", maprendering.MapUI, "Demos", 470, 128+75, false, function()
		UpdateMapMode("demos")
	end, 62, 25, "DisplayMode", "artwork", true, "button_active.png", "button_ready.png", "mail",false)

	--helpers.createSkinnedButton("gotoLocation", maprendering.MapUI, "Goto ->", "controls/button_ready.png", 400, 450, 55, 25, nil, nil, nil, false)
	helpers.CreateImageButton("gotoLocation", maprendering.MapUI, "ui/goto.png", 478, 128+130, 25, 25, function()
		eventbus.TriggerEvent(TOPICS.UI.toggleGoto)
	end, true, nil, "Location input", "item_enchant")
	helpers.CreateImageButton("settingsButton", maprendering.MapUI, "ui/settings.png", 478, 128+100, 25, 25, function()
		if configWindowVisible then
			maprendering.ReloadUIItems()
			configWindowVisible = false
			UpdateMapMode(currentMapMode)
		else
			HideAllIcons()
			eventbus.TriggerEvent(TOPICS.render.config)
			maprendering.UnloadUIItems()
			configWindowVisible = true
		end
	end, true, nil, "Settings", "item_enchant")
	helpers.CreateImageButton("myPosButton", maprendering.MapUI, "ui/mypos.png", 483+25, 128+100, 25, 25,FocusOnMe,true,nil,"My location","item_enchant")
	local openX, openY = tonumber(settingsModule.Get("OpenButtonX")), tonumber(settingsModule.Get("OpenButtonY"))
	local screenWidth, screenHeight = api.Interface:GetScreenWidth(), api.Interface:GetScreenHeight()
	if openX == nil or openY == nil then
		openX = 50
		openY = 50
	end
	if screenWidth ~= nil and screenHeight ~= nil and screenWidth > 0 and screenHeight > 0 then
		openX = math.max(0, math.min(openX, screenWidth - 50))
		openY = math.max(0, math.min(openY, screenHeight - 50))
	end

	local windowUIbUTTON = api.Interface:CreateEmptyWindow("WorldSatNav")
	windowUIbUTTON:AddAnchor("TOPLEFT", "UIParent", openX, openY)
	windowUIbUTTON:SetExtent(50*settingsModule.Get("uiDrawScale"),50*settingsModule.Get("uiDrawScale"))
	windowUIbUTTON:SetCloseOnEscape(false)
	windowUIbUTTON:Show(true)
	local mainUIButton = helpers.CreateImageButton("MainUIButton", windowUIbUTTON, "icons/main_ui.png", 0, 0, 50, 50, maprendering.ToggleMap, true, "icons/main_ui_hover.png", "Open satnav","portal")
	helpers.makeWindowDraggable(mainUIButton, nil, nil, true, true, "OpenButtonX", "OpenButtonY")
	
	table.insert(cleanup, mainUIButton.parent)
	table.insert(cleanup, maprendering.MapUI)
end

function maprendering.ClearUIState()
	HideAllIcons()
	eventbus.TriggerEvent(TOPICS.render.clearUiState)
	configWindowVisible = false
end

function maprendering.ToggleMap()
	eventbus.TriggerEvent(TOPICS.UI.closeGoto)
	if maprendering.MapUI:IsVisible() then
		maprendering.MapUI:Show(false)
		eventbus.TriggerEvent(TOPICS.UI.close)
	else
		maprendering.MapUI:Show(true)
		eventbus.TriggerEvent(TOPICS.UI.open)
		if currentMapMode == nil then
			currentMapMode = "maps"
		end
		UpdateMapMode(currentMapMode) -- Ensure the correct mode is displayed when opening display again
	end
end

local isUIUnloaded = false
function maprendering.UnloadUIItems()
	if isUIUnloaded == true then
		return
	end
	HideAllIcons()
	maprendering.MapUI.mapImage:Show(false)
	maprendering.MapUI.mapBackground:Show(false)
	isUIUnloaded = true
end

function maprendering.ReloadUIItems()
	if isUIUnloaded == false then
		return
	end
	maprendering.MapUI.mapImage:Show(true)
	maprendering.MapUI.mapBackground:Show(true)
	isUIUnloaded = false
end

local function BulkDrawIcons(iconsData)
	maprendering.ClearUIState()
	maprendering.ReloadUIItems()
	if maprendering.playerIcon ~= nil and maprendering.MapUI ~= nil and maprendering.MapUI.mapImage ~= nil then
		maprendering.playerIcon.inuse = true
		maprendering.playerIcon.sourceType = "player"
		maprendering.playerIcon.textureNode = "icons/player.png"
		maprendering.playerIcon:SetTexture(constants.folderPath.."images/icons/player.png")
		maprendering.playerIcon.sextant = GetCurrentPosition()
		AttachDrawableIcon(maprendering.playerIcon, maprendering.playerIcon.sextant, maprendering.MapUI.mapImage)
		if not IsValidSextant(maprendering.playerIcon.sextant) then
			maprendering.playerIcon:Show(false)
		end
	end
	iconsData = iconsData or {}
	helpers.DevLog("Received request to bulk draw icons, count: " .. tostring(#iconsData))
	for _, iconData in pairs(iconsData) do
		maprendering.CreateIconAttachedToMap(iconData.sextant, iconData.texture, iconData.sourceType, iconData.customIconSize)
	end
	-- Do not request a full mode redraw here: that path clears icons and republishes render events.
	WorldSatNavState.LastRenderConfig.iconsversion = false
	maprendering.TriggerMapRedraw()
	helpers.DevLog("Bulk drew " .. tostring(#iconsData) .. " icons and triggered map redraw")
end

function maprendering.ForceSelectUIMode(mode)
	if mode ~= "maps" and mode ~= "ships" and mode ~= "events" and mode ~= "demos" then
		helpers.DevLog("Invalid map mode: " .. tostring(mode))
		return
	end
	eventbus.TriggerEvent(TOPICS.UI.close)
	maprendering.MapUI:Show(true)
	currentMapMode = mode
	WorldSatNavState.LastRenderConfig.iconsversion = false -- Force icons to redraw with the new mode
	helpers.SetCheckboxState("mapsModeButton", mode == "maps")
	helpers.SetCheckboxState("shipsModeButton", mode == "ships")
	helpers.SetCheckboxState("eventsModeButton", mode == "events")
	helpers.SetCheckboxState("demosModeButton", mode == "demos")
	helpers.SetCheckBoxOverride("mapsModeButton", true)
	helpers.SetCheckBoxOverride("shipsModeButton", true)
	helpers.SetCheckBoxOverride("eventsModeButton", true)
	helpers.SetCheckBoxOverride("demosModeButton", true)
	eventbus.TriggerEvent(TOPICS.UI.forcedUIModeReady, mode)
end
-- Addon initialization
function maprendering.OnLoad()
	eventbus.WatchEvent(TOPICS.icons.drawIcon, maprendering.CreateIconAttachedToMap, "maprendering")
	eventbus.WatchEvent(TOPICS.icons.ChangeIcon, maprendering.ChangeSelectedIcon, "maprendering")
	eventbus.WatchEvent(TOPICS.icons.clearIcon, maprendering.DisableIconBySextent, "maprendering")
	eventbus.WatchEvent(TOPICS.render.redrawMap, maprendering.RequestModeRedraw, "maprendering")
	eventbus.WatchEvent(TOPICS.icons.BulkDrawIconsAndRedraw, BulkDrawIcons, "maprendering")
	eventbus.WatchEvent(TOPICS.UI.clearItems, maprendering.ClearUIState, "maprendering")
	eventbus.WatchEvent(TOPICS.UI.EmptyUI, maprendering.UnloadUIItems, "maprendering")
	eventbus.WatchEvent(TOPICS.UI.ReloadUI, maprendering.ReloadUIItems, "maprendering")
	eventbus.WatchEvent(TOPICS.UI.forcedUIMode, maprendering.ForceSelectUIMode, "maprendering")
	eventbus.WatchEvent(TOPICS.UI.requestUIMode, UpdateMapMode, "maprendering")
	CreateUiElements()
	local newMapInfo = maprendering.GetMapInfoForZoom(0)
	local focusX = newMapInfo.width / 2
	local focusY = newMapInfo.height / 2
	SetMapZoom(WorldSatNavState.zoomLevel, maprendering.MapUI.mapImage, focusX, focusY)
	eventbus.TriggerEvent(TOPICS.UI.MainUILoaded, maprendering.MapUI)
end

function maprendering.OnUnload()
	for _, obj in pairs(cleanup) do
		if obj ~= nil and obj.Show ~= nil then
			obj:Show(false)
		end
		api.Interface:Free(obj)
		obj = nil
	end
	cleanup = nil
end

return maprendering