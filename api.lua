---@diagnostic disable: undefined-global, lowercase-global
-- GLOBALS
-- These are all provided in the environment you'll be using.
ADDON = {
    -- Use this to get any of the windows defined in UIC below!
    -- GetContent(UIC)
    GetContent = {},
    -- RegisterContentWidget(UIC, widget)
    RegisterContentWidget = {},
    -- ShowContent(UIC, show (boolean))
    ShowContent = {},
    -- RegisterContentTriggerFunc(UIC, ToggleFunction)
    -- Calls ToggleFunction with true/false when ShowContent is called.
    RegisterContentTriggerFunc = {}
}
UIC = {
    DEV_WINDOW = 0,
    ABILITY_CHANGE = 0,
    CHARACTER_INFO = 0,
    AUTH_MSG_WND = 0,
    BUBBLE_ACTION_BAR = 0,
    BAG = 0,
    DEATH_AND_RESURRECTION_WND = 0,
    OPTION_FRAME = 0,
    SYSTEM_CONFIG_FRAME = 0,
    GAME_EXIT_FRAME = 0,
    SLAVE_EQUIPMENT = 0,
    PLAYER_UNITFRAME = 0,
    TARGET_UNITFRAME = 0,
    RAID_COMMAND_MESSAGE = 0,
    COMBAT_TEXT_FRAME = 0,
    TARGET_OF_TARGET_FRAME = 0,
    WATCH_TARGET_FRAME = 0,
    RAID_MANAGER = 0,
    COMMUNITY_WINDOW = 0,
    ENCHANT_WINDOW = 0
}
BUTTON_BASIC = BUTTON_BASIC
BUTTON_CONTENTS = BUTTON_CONTENTS
CURSOR_PATH = CURSOR_PATH
FONT_COLOR = FONT_COLOR
FONT_SIZE = FONT_SIZE
COMBAT_TEXT_COLOR = COMBAT_TEXT_COLOR
TEXTURE_PATH = TEXTURE_PATH
F_SLOT = F_SLOT
F_UNIT = F_UNIT
SLOT_STYLE = {
  DEFAULT = {},
  BAG_DEFAULT = {},
  SOCKET = {},
  BAG_NOT_ALL_TAB = {},
  BUFF = {},
  EQUIP_ITEM = {},
  PET_ITEM = {},
  SLAVE_EQUIP = {
    FIGUREHEAD = {},
    STAY_SAIL = {},
    SQUARE_SAIL = {},
    FRONT_MAST = {},
    REAR_MAST = {},
    CANNON = {},
    BACKPACK = {},
    BOARD = {},
    HANDLE = {},
    RUDDER = {},
    LAMP = {},
    BELL = {},
    ORGAN = {},
    CARRIED_HARPOON = {},
    HARPOON = {},
    TELESCOPE = {},
    SCUBA = {},
    ENGINE = {},
    DECORATION = {},
    WATERWHEEL = {}
  }
}
STATUSBAR_STYLE = STATUSBAR_STYLE
ALIGN = {
    LEFT = 0,
    RIGHT = 0,
    CENTER = 0,
    TOP = 0,
    BOTTOM = 0,
    BOTTOM_RIGHT = 0,
    BOTTOM_LEFT = 0,
    TOP_LEFT = 0,
    TOP_RIGHT = 0
}

-- chatTabWindow
-- This is a global table that contains the chat windows provided in the game. Window 1 is the default.
---@diagnostic disable-next-line: lowercase-global
chatTabWindow = {}

-- petFrame
-- A global table containing all pet unit frames such as combat pets and mounts.
petFrame = {}

-- combatTextLocale
-- A global table containing the combat text localization strings and font choice.
combatTextLocale = {}

-- Global Functions

-- ConvertColor(color)
-- Takes a single color as a value from 1 to 255, returns as a percentage decimal
ConvertColor = {}

-- ApplyTextColor(widget, color)
-- Applies a color to the widget. Use FONT_COLOR values.
ApplyTextColor = {}

-- ApplyButtonSkin(widget, skin)
-- Applies a skin to a button. Skins are available in BUTTON_BASIC but can also be customized.
ApplyButtonSkin = {}

-- X2Util, a utility library in the game's client.
X2Util = {
    GetMyMoneyString = {},
    -- Takes x,y,z and returns screenX, screenY and distance
    -- Negative distance means the coordinate is off screen
    ConvertWorldToScreen = {}
}
-- X2Chat, a library containing multiple functions to handle chat messages.
X2Chat = {
    -- ExpressEmotion(emotion)
    ExpressEmotion = {},
    -- DispatchChatMessage(channel, message)
    DispatchChatMessage = {},

}

-- X2Hotkey, a helper library for hotkeys.
X2Hotkey = {
    
}

-- X2NameTag, a helper library for in-game nametags
X2NameTag = {

}

-- CreateItemIconButton(id, parent)
CreateItemIconButton = {}

-- ParseCombatMessage(combatEvent, ...)
ParseCombatMessage = {}

-- GetTextureInfo(path, key)
GetTextureInfo = {}

-- Money Window Helper
W_MONEY = {
    -- CreateMoneyEditsWindow(id, parent, titleText)
    CreateMoneyEditsWindow = {},
    -- CreateTwoLineMoneyWindow(id, parent)
    CreateTwoLineMoneyWindow = {},
    -- CreateDefaultMoneyWindow(id, parent, width, height)
    CreateDefaultMoneyWindow = {},
    -- CreateTitleMoneyWindow(id, parent, titleText, direction, layoutType)
    CreateTitleMoneyWindow = {},
}
-- Control Widget Helper
W_CTRL = {
    -- CreateComboBox(parent)
    CreateComboBox = {},
    -- CreateEdit(id, parent)
    CreateEdit = {},
    -- CreditMultiLineEdit(id, parent)
    CreditMultiLineEdit = {},
    -- CreateLabel(id, parent)
    CreateLabel = {},
    -- CreateList(id, parent) 
    CreateList = {},
    -- CreateListCtrl(id, parent)
    CreateListCtrl = {},
    -- CreatePageControl(id, parent, style)
    CreatePageControl = {},
    -- CreatePageScrollListCtrl(id, parent)
    CreatePageScrollListCtrl = {},
    -- CreateScroll(id, parent)
    CreateScroll = {},
    -- CreateScrollListBox(id, parent, bgType)
    CreateScrollListBox = {},
    -- CreateScrollListCtrl(id, parent, index)
    CreateScrollListCtrl = {},
}
-- Unit Widget Helper
W_UNIT = {
    -- CreateBuffWindow(id, parent, maxCount, isBuff, isRaidMember)
    CreateBuffWindow = {},
    -- CreateLevelLabel(id, parent, useLevelTexture)
    CreateLevelLabel = {},
}
-- Bar Widget Helper
W_BAR = {
    --CreateCastingBar(id, parent, unit)
    CreateCastingBar = {},
    --CreateDoubleGauge(id, parent)
    CreateDoubleGauge = {},
    --CreateExpBar(id, parent)
    CreateExpBar = {},
    --CreateLaborPowerBar(id, parent)
    CreateLaborPowerBar = {},
    --CreateHpBar(id, parent)
    CreateHpBar = {},
    --CreateSkillBar(id, parent)
    CreateSkillBar = {},
    --CreateStatusBarOfUnitFrame(id, parent, barType)
    CreateStatusBarOfUnitFrame = {},
    --CreateStatusBarOfRaidFrame(id, parent, barType)
    CreateStatusBarOfRaidFrame = {},
    --CreateStatusBar(id, parent, style)
    CreateStatusBar = {},
}
-- Icon Widget Helper
W_ICON = {
    -- CreateDestroyIcon(widget, layer)
    CreateDestroyIcon = {},
    -- CreatePackIcon(widget, layer)
    CreatePackIcon = {},
    -- CreateLifeTimeIcon(widget, layer)
    CreateLifeTimeIcon = {},
    -- CreateLookIcon(widget, layer)
    CreateLookIcon = {},
    -- CreateLockIcon(widget, layer)
    CreateLockIcon = {},
    -- CreateDyeingIcon(widget, layer)
    CreateDyeingIcon = {},
    -- CreateStack(widget)
    CreateStack = {},
    -- CreateLimitLevel(widget)
    CreateLimitLevel = {},
    -- CreateOverlayStateImg(widget, layer)
    CreateOverlayStateImg = {},
    -- CreateOpenPaperItemIcon(widget, layer)
    CreateOpenPaperItemIcon = {},
    -- CreatePartyIconWidget(widget)
    CreatePartyIconWidget = {},
    -- CreateLootIconWidget(widget)
    CreateLootIconWidget = {},
    -- CreateGuideIconWidget(widget)
    CreateGuideIconWidget = {},
    -- CreateItemIconImage(id, parent)
    CreateItemIconImage = {},
    -- CreateAchievementGradeIcon(widget)
    CreateAchievementGradeIcon = {},
    -- CreateQuestGradeMarker(parent)
    CreateQuestGradeMarker = {},
    -- DrawRoundDingbat(widget)
    DrawRoundDingbat = {},
    -- DrawMoneyIcon(parent, arg)
    DrawMoneyIcon = {},
    -- DrawSkillFlameIcon(widget, layer)
    DrawSkillFlameIcon = {},
    -- DrawItemSideEffectBackground(widget)
    DrawItemSideEffectBackground = {},
    -- CreateArrowIcon(widget, layer)
    CreateArrowIcon = {},
    -- DrawMinusDingbat(money_window_widget)
    DrawMinusDingbat = {},
    -- CreateLeaderMark(id, parent)
    CreateLeaderMark = {}
}
-- Character Equipment Slots
EQUIP_SLOT = {
    HEAD = 0,
    NECK = 0,
    CHEST = 0,
    WAIST = 0,
    LEGS = 0,
    HANDS = 0,
    FEET = 0,
    ARMS = 0,
    BACK = 0,
    EAR_1 = 0,
    EAR_2 = 0,
    FINGER_1 = 0,
    FINGER_2 = 0,
    UNDERSHIRT = 0,
    UNDERPANTS = 0,
    MAINHAND = 0,
    OFFHAND = 0,
    RANGED = 0,
    MUSICAL = 0,
    BACKPACK = 0,
    COSPLAY = 0,
}

ADDON_API = {
    File = {},
    Unit = {},
    Team = {},
    Log = {},
    Interface = {},
    Cursor = {},
    Input = {},
    Time = {},
    Player = {},
    Bag = {},
    Ability = {},
    Item = {},
    Skill = {},
    Store = {},
    Bank = {},
    Equipment = {},
    SiegeWeapon = {},
    ItemEnchant = {},
    Map = {},
    Quest = {},
    Zone = {},
    -- This is the 'addons' directory at runtime
    baseDir = "",
    rootWindow = {},
    timers = {}
}

-- ======
-- Logging
-- ======

--[[ 
    Logs a message to chat in YELLOW
    @param message (string) The message to log
    @returns (nil)
]]
function ADDON_API.Log:Info(message)
end

--[[ 
    Logs a message to chat in RED
    @param message (string) The message to log
    @returns (nil)
]]
function ADDON_API.Log:Err(message)
end

-- ======
-- File Handling
-- ======

--[[ 
    Serializes a table and writes it to the desired path.
    Paths are relative to the addons folder
    @param path (string) The file path
    @param tbl (table) The table to serialize
    @returns (nil)
]]
function ADDON_API.File:Write(path, tbl)
end

--[[ 
    Reads the file located at path and deserializes it into a table.
    Paths are relative to the addons folder
    @param path (string) The file path
    @returns (table) The deserialized table
]]
function ADDON_API.File:Read(path)
end

--[[ 
    Get the settings for the desired addonId
    @param addonId (string) The name of the addon folder. For example, `example_addon`
    @returns (table) The settings table
]]
function ADDON_API.GetSettings(addonId)
end

--[[ 
    Saves all addon settings. Do not call too often.
    @returns (nil)
]]
function ADDON_API.SaveSettings()
end

-- ======
-- Interface
-- ======

--[[ 
    Creates a standard looking window. If size is not specified, it will default to 680x615
    Tabs can be used to define tabs on the window by default.
    @param id (string) The window ID
    @param title (string) The window title
    @param x (number) X position
    @param y (number) Y position
    @param tabs (table) Tabs configuration
    @returns (table) The created window
]]
function ADDON_API.Interface:CreateWindow(id, title, x, y, tabs)
end

--[[ 
    Creates an empty window, that does not render anything.
    Particularly useful to draw things on the HUD
    @param id (string) The window ID
    @returns (table) The created window
]]
function ADDON_API.Interface:CreateEmptyWindow(id)
end

--[[ 
    Creates a Widget bound to parent.
    Types: button, label, window, slot, checkbutton, window, textbox, message, gametooltip
    @param type (string) The widget type
    @param id (string) The widget ID
    @param parent (table) The parent widget
    @returns (table) The created widget
]]
function ADDON_API.Interface:CreateWidget(type, id, parent)
end

--[[ 
    Creates a status bar
    @param name (string) The name of the status bar
    @param parent (table) The parent widget
    @param type (string) The type of the status bar
    @returns (table) The created status bar
]]
function ADDON_API.Interface:CreateStatusBar(name, parent, type)
end

--[[ 
    Creates a Combo Box (like the grade selector in the equipment folio)
    Use the dropdownItem member to set the contents
    @param window (table) The parent window
    @returns (table) The created combo box
]]
function ADDON_API.Interface:CreateComboBox(window)
end

--[[ 
    Applies a skin to a button 
    Possible values are BUTTON_BASIC.{DEFAULT, RESET, BASIC} and more
    @param btn (table) The button widget
    @param skin (string) The skin to apply
    @returns (nil)
]]
function ADDON_API.Interface:ApplyButtonSkin(btn, skin)
end

--[[ 
    Sets tooltip at coordinates
    @param text (string) The tooltip text
    @param target (table) The target widget
    @param posX (number) X position
    @param posY (number) Y position
    @returns (nil)
]]
function ADDON_API.Interface:SetTooltipOnPos(text, target, posX, posY)
end

--[[ 
    Frees the specified window's reference, removing it from the UI
    Useful for cleaning up windows in the OnUnload function of addons
    @param wnd (table) The window to free
    @returns (nil)
]]
function ADDON_API.Interface:Free(wnd)
end

--[[ 
    Gets the screen width
    @returns (number) The screen width
]]
function ADDON_API.Interface:GetScreenWidth()
end

--[[ 
    Gets the screen height
    @returns (number) The screen height
]]
function ADDON_API.Interface:GetScreenHeight()
end

--[[ 
    Gets the UI scale
    @returns (number) The UI scale
]]
function ADDON_API.Interface:GetUIScale()
end

-- ======
-- Unit
-- ======

--[[
    Note: The "unit" parameter or identifier in the below functions can be: 
    - player
    - target
    - targettarget
    - team1 through team50
    - playerpet1 or playerpet2
]]


--[[ 
    Returns a unit's (player, npc, pet..) name by its ID
    @param id (number) The unit ID
    @returns (string) The unit name
]]
function ADDON_API.Unit:GetUnitNameById(id)
end

--[[ 
    Returns a unit's information by its ID
    @param id (number) The unit ID
    @returns (table) The unit information
]]
function ADDON_API.Unit:GetUnitInfoById(id)
end

--[[ 
    Get the screen coordinates of the desired unit. This can be used to overlay UI elements and "track" units.
    @param unit (string) The unit identifier
    @returns (number, number) The screen X and Y coordinates
]]
function ADDON_API.Unit:GetUnitScreenPosition(unit)
end

--[[ 
    Returns the distance between the desired unit and the player, in meters
    @param unit (string) The unit identifier
    @returns (number) The distance in meters
]]
function ADDON_API.Unit:UnitDistance(unit)
end

--[[ 
    Returns the unit ID for the desired unit. The ID can then be passed to GetUnitNameById and GetUnitInfoById
    @param unit (string) The unit identifier
    @returns (number) The unit ID
]]
function ADDON_API.Unit:GetUnitId(unit)
end

--[[ 
    Returns the number of buffs a unit has
    @param unit (string) The unit identifier
    @returns (number) The number of buffs
]]
function ADDON_API.Unit:UnitBuffCount(unit)
end

--[[ 
    Returns the buff at index for a unit. Nil if no buff is found
    @param unit (string) The unit identifier
    @param index (number) The buff index
    @returns (table) The buff information
]]
function ADDON_API.Unit:UnitBuff(unit, index)
end

--[[ 
    Returns the unit world coordinates of the desired unit as x,y,z
    @param unit (string) The unit identifier
    @returns (number, number, number) The world X, Y, Z coordinates
]]
function ADDON_API.Unit:UnitWorldPosition(unit)
end

--[[ 
    Returns the number of debuffs a unit has
    @param unit (string) The unit identifier
    @returns (number) The number of debuffs
]]
function ADDON_API.Unit:UnitDeBuffCount(unit)
end

--[[ 
    Returns the debuff at index for a unit. Nil if no debuff is found
    @param unit (string) The unit identifier
    @param index (number) The debuff index
    @returns (table) The debuff information
]]
function ADDON_API.Unit:UnitDeBuff(unit, index)
end

--[[ 
    Gets the health of a unit
    @param unit (string) The unit identifier
    @returns (number) The current health
]]
function ADDON_API.Unit:UnitHealth(unit)
end

--[[ 
    Gets the maximum health of a unit
    @param unit (string) The unit identifier
    @returns (number) The maximum health
]]
function ADDON_API.Unit:UnitMaxHealth(unit)
end

--[[ 
    Gets the mana of a unit
    @param unit (string) The unit identifier
    @returns (number) The current mana
]]
function ADDON_API.Unit:UnitMana(unit)
end

--[[ 
    Gets the maximum mana of a unit
    @param unit (string) The unit identifier
    @returns (number) The maximum mana
]]
function ADDON_API.Unit:UnitMaxMana(unit)
end

--[[ 
    Gets information about a unit
    @param unit (string) The unit identifier
    @returns (table) The unit information
]]
function ADDON_API.Unit:UnitInfo(unit)
end

--[[ 
    Gets modifier information about a unit
    @param unit (string) The unit identifier
    @returns (table) The modifier information
]]
function ADDON_API.Unit:UnitModifierInfo(unit)
end

--[[ 
    Gets the class of a unit
    @param unit (string) The unit identifier
    @returns (string) The unit class
]]
function ADDON_API.Unit:UnitClass(unit)
end

--[[ 
    Gets the gear score of a unit
    @param unit (string) The unit identifier
    @returns (number) The gear score
]]
function ADDON_API.Unit:UnitGearScore(unit)
end

--[[ 
    Gets the team authority of a unit
    @param unit (string) The unit identifier
    @returns (number) The team authority
]]
function ADDON_API.Unit:UnitTeamAuthority(unit)
end

--[[ 
    Checks if a unit is a team member
    @param unit (string) The unit identifier
    @returns (boolean) True if the unit is a team member, false otherwise
]]
function ADDON_API.Unit:UnitIsTeamMember(unit)
end

--[[ 
    Checks if a unit is currently flagged.
    @param unit (string) The unit identifier
    @returns (boolean) True if the unit is flagged for forced PvP, false otherwise
]]
function ADDON_API.Unit:UnitIsForceAttack(unit)
end

--[[ 
    Gets the faction name of a unit
    @param unit (string) The unit identifier
    @returns (string) The faction name
]]
function ADDON_API.Unit:GetFactionName(unit)
end

--[[ 
    Gets the screen name tag offset of a unit
    @param unit (string) The unit identifier
    @returns (number) The offset
]]
function ADDON_API.Unit:GetUnitScreenNameTagOffset(unit)
end

--[[ 
    Gets high ability (Abyssal Charges) resource information
    @returns (table) The resource information
]]
function ADDON_API.Unit:GetHighAbilityRscInfo()
end

--[[ 
    Checks if a unit is offline
    @param unit (string) The unit identifier
    @returns (boolean) True if the unit is offline, false otherwise
]]
function ADDON_API.Unit:UnitIsOffline(unit)
end

--[[ 
    Gets the overhead marker unit ID
    @param markerIndex (number) The marker index, any nubmer between 1 and 12
    @returns (number) The unit ID
]]
function ADDON_API.Unit:GetOverHeadMarkerUnitId(markerIndex)
end

-- ======
-- Team
-- ======

--[[ 
    Invites the desired player to raid/party
    If party is true and the player is not in party/raid, a party will be created. Otherwise, a raid
    @param name (string) The player name
    @param party (boolean) True for party, false for raid
    @returns (nil)
]]
function ADDON_API.Team:InviteToTeam(name, party)
end

--[[ 
    Sets the player's role within the party
    0 = Blue
    @param role (number) The role ID
    @returns (nil)
]]
function ADDON_API.Team:SetRole(role)
end

--[[ 
    Checks if the team is a party
    @returns (boolean) True if the team is a party, false otherwise
]]
function ADDON_API.Team:IsPartyTeam()
end

--[[ 
    Checks if the team is a raid
    @returns (boolean) True if the team is a raid, false otherwise
]]
function ADDON_API.Team:IsPartyRaid()
end

--[[ 
    Gets the member index by name
    @param playerName (string) The player name
    @returns (number) The member index
]]
function ADDON_API.Team:GetMemberIndexByName(playerName)
end

--[[ 
    Gets the team distributor name
    @returns (string) The distributor name
]]
function ADDON_API.Team:GetTeamDistributorName()
end

--[[ 
    Gets the team player index
    @returns (number) The player index
]]
function ADDON_API.Team:GetTeamPlayerIndex()
end

--[[ 
    Gets the role of a team member
    @param memberIndex (number) The member index
    @returns (number) The role ID
]]
function ADDON_API.Team:GetRole(memberIndex)
end

-- ======
-- Bag
-- ======

--[[ 
    Equips the item at the bag slot specified
    @param bagSlot (number) The bag slot index
    @param isAux (boolean) True for auxiliary slot, false otherwise
    @returns (nil)
]]
function ADDON_API.Bag:EquipBagItem(bagSlot, isAux)
end

--[[ 
    Get item information at the index, in the bag specified. 1 = Inventory 
    @param bagType (number) The bag type
    @param index (number) The item index
    @returns (table) The item information
]]
function ADDON_API.Bag:GetBagItemInfo(bagType, index)
end

--[[ 
    Counts the items in the bag
    @returns (number) The item count
]]
function ADDON_API.Bag:CountItems()
end

--[[ 
    Gets the bag capacity
    @returns (number) The bag capacity
]]
function ADDON_API.Bag:Capacity()
end

--[[ 
    Counts the items in the bag by item type
    @param type (number) The item type
    @returns (number) The item count
]]
function ADDON_API.Bag:CountBagItemByItemType(type)
end

--[[ 
    Gets the amount of gold in the player's bag.
    @returns (number) The currency amount
]]
function ADDON_API.Bag:GetCurrency()
end

-- ======
-- Cursor
-- ======

--[[ 
    Clears the cursor
    @returns (nil)
]]
function ADDON_API.Cursor:ClearCursor()
end

--[[ 
    Sets the cursor image
    @param image (string) The image path
    @param x (number) X position
    @param y (number) Y position
    @returns (nil)
]]
function ADDON_API.Cursor:SetCursorImage(image, x, y)
end

--[[ 
    Gets the picked bag item index from the cursor
    @returns (number) The bag item index
]]
function ADDON_API.Cursor:GetCursorPickedBagItemIndex()
end

--[[ 
    Gets the picked bag item amount from the cursor
    @returns (number) The bag item amount
]]
function ADDON_API.Cursor:GetCursorPickedBagItemAmount()
end

--[[ 
    Gets the item information that is currently on the cursor
    @returns (table) The cursor information
]]
function ADDON_API.Cursor:GetCursorInfo()
end

-- ======
-- Time
-- ======

--[[ 
    Returns milliseconds since the game's UI scripts have started running
    @returns (number) The milliseconds since the game started
]]
function ADDON_API.Time:GetUiMsec()
end

--[[ 
    Gets the local time of the player's computer
    @returns (table) The local time
]]
function ADDON_API.Time:GetLocalTime()
end

--[[ 
    The amount of time until a date period
    @param localTime (table) The local time
    @param period (number) The period time
    @returns (table) The time difference between the local time and the period
]]
function ADDON_API.Time:PeriodTimeToDate(localTime, period)
end

--[[ 
    Converts an epoch timestamp to a date
    @param epochTimestamp (number) The epoch timestamp
    @returns (table) The date
]]
function ADDON_API.Time:TimeToDate(epochTimestamp)
end

--[[ 
    Gets the game time
    @returns (table) The in-game time
]]
function ADDON_API.Time:GetGameTime()
end

-- ======
-- Quest
-- ======

--[[ 
    Checks if a quest is completed
    @param questTypeId (number) The quest type ID
    @returns (boolean) True if the quest is completed, false otherwise
]]
function ADDON_API.Quest:IsCompleted(questTypeId)
end

--[[ 
    Gets the active quest title
    @param questTypeId (number) The quest type ID
    @returns (string) The quest title
]]
function ADDON_API.Quest:GetActiveQuestTitle(questTypeId)
end

--[[ 
    Gets the main title of the quest context
    @param questTypeId (number) The quest type ID
    @returns (string) The main title
]]
function ADDON_API.Quest:GetQuestContextMainTitle(questTypeId)
end

--[[ 
    Gets the body of the quest context
    @param questTypeId (number) The quest type ID
    @returns (string) The body text
]]
function ADDON_API.Quest:GetQuestContextBody(questTypeId)
end

-- ======
-- Input
-- ======

--[[ 
    Checks if the Shift key is pressed
    @returns (boolean) True if the Shift key is pressed, false otherwise
]]
function ADDON_API.Input:IsShiftKeyDown()
end

--[[ 
    Checks if the Control key is pressed
    @returns (boolean) True if the Control key is pressed, false otherwise
]]
function ADDON_API.Input:IsControlKeyDown()
end

--[[ 
    Checks if the Alt key is pressed
    @returns (boolean) True if the Alt key is pressed, false otherwise
]]
function ADDON_API.Input:IsAltKeyDown()
end

--[[ 
    Gets the mouse position
    @returns (number, number) The X and Y coordinates of the mouse
]]
function ADDON_API.Input:GetMousePos()
end

-- ======
-- Player
-- ======

--[[ 
    Changes the player's title
    @param type (number) The ID of the title to set
    @returns (nil|true) True if the title was changed, nil otherwise
]]
function ADDON_API.Player:ChangeAppellation(type)
end

--[[ 
    Gets the currently showing player title
    @returns (string) The title
]]
function ADDON_API.Player:GetShowingAppellation()
end

--[[ 
    Gets the player's game points
    @returns (number) The game points
]]
function ADDON_API.Player:GetGamePoints()
end

--[[ 
    Gets the player's crime information
    @returns (table) The crime information
]]
function ADDON_API.Player:GetCrimeInfo()
end

-- ======
-- Events & Timers
-- ======

--[[ 
    Binds callback to the desired event
    Current events:
    - UPDATE (dt) - Called every frame, with dt = time in msec since last frame
    - CHAT_MESSAGE
    - TEAM_MEMBERS_CHANGED
    - UI_RELOADED
    - UPDATE_PING_INFO - Called when the map ping is moved
    @param event (string) The event name
    @param callback (function) The callback function
    @returns (nil)
]]
function ADDON_API.On(event, callback)
end

--[[ 
    Registers a callback to be executed in a certain duration (in msec)
    If you need to call this often, consider using On("UPDATE") instead
    @param msec (number) The duration in milliseconds
    @param callback (function) The callback function
    @param ... (any) Additional arguments
    @returns (nil)
]]
function ADDON_API:DoIn(msec, callback, ...)
end

--[[ 
    Emits an event. We recommend using event names like "ADDON_MY_EVENT" so that other addons don't get tripped.
    @param event (string) The event name
    @param ... (any) Additional arguments
    @returns (nil)
]]
function ADDON_API:Emit(event, ...)
end

-- ======
-- Ability
-- ======

--[[ 
    Gets the tooltip for a buff
    @param buffId (number) The buff ID
    @param itemLevel (number) The item level
    @returns (string) The tooltip text
]]
function ADDON_API.Ability:GetBuffTooltip(buffId, itemLevel)
end

--[[ 
    Gets the ability from the view
    @param index (number) The view index
    @returns (table) The ability information
]]
function ADDON_API.Ability:GetAbilityFromView(index)
end

--[[ 
    Checks if an ability is active
    @param ability (table) The ability information
    @returns (boolean) True if the ability is active, false otherwise
]]
function ADDON_API.Ability:IsActiveAbility(ability)
end

--[[ 
    Gets the skillset name by ID
    @param skillsetId (number) The skillset ID
    @returns (string) The skillset name
]]
function ADDON_API.Ability:GetSkillsetNameById(skillsetId)
end

--[[ 
    Gets the unit class name
    @param unit (string) The unit identifier
    @returns (string) The class name
]]
function ADDON_API.Ability:GetUnitClassName(unit)
end

--[[ 
    Gets the class name from skillset IDs
    @param skillset1 (number) The first skillset ID
    @param skillset2 (number) The second skillset ID
    @param skillset3 (number) The third skillset ID
    @returns (string) The class name
]]
function ADDON_API.Ability:GetClassNameFromSkillsetIds(skillset1, skillset2, skillset3)
end

-- ======
-- Item
-- ======

--[[ 
    Gets item information by its type
    @param itemId (number) The item ID
    @returns (table) The item information
]]
function ADDON_API.Item:GetItemInfoByType(itemId)
end

-- ======
-- Skill
-- ======

--[[ 
    Gets the tooltip for a skill
    @param skillId (number) The skill ID
    @returns (string) The tooltip text
]]
function ADDON_API.Skill:GetSkillTooltip(skillId)
end

-- ======
-- Store
-- ======

--[[ 
    Returns the Seller % on packs. Usually 80%, it futureproofs your addon if it changes.
    @returns (number) The seller share ratio
]]
function ADDON_API.Store:GetSellerShareRatio()
end

--[[ 
    Gets the specialty ratio
    @returns (number) The specialty ratio
]]
function ADDON_API.Store:GetSpecialtyRatio()
end

--[[ 
    Gets the production zone groups
    @returns (table) The production zone groups
]]
function ADDON_API.Store:GetProductionZoneGroups()
end

--[[ 
    Gets the sellable zone groups starting from a zone ID
    @param startZoneId (number) The starting zone ID
    @returns (table) The sellable zone groups
]]
function ADDON_API.Store:GetSellableZoneGroups(startZoneId)
end

--[[ 
    Gets the specialty ratio between two zones
    @param startZoneId (number) The starting zone ID
    @param finishZoneId (number) The finishing zone ID
    @returns (number) The specialty ratio
]]
function ADDON_API.Store:GetSpecialtyRatioBetween(startZoneId, finishZoneId)
end

-- ======
-- Bank
-- ======

--[[ 
    Counts the items in the bank
    @returns (number) The item count
]]
function ADDON_API.Bank:CountItems()
end

--[[ 
    Gets the bank's item capacity
    @returns (number) The bank capacity
]]
function ADDON_API.Bank:Capacity()
end

--[[ 
    Gets the amount of gold in the player's bank.
    @returns (number) The currency amount
]]
function ADDON_API.Bank:GetCurrency()
end

--[[ 
    Gets the link text for a slot in the bank
    @param inventorySlotId (number) The bank slot ID
    @returns (string) The link text
]]
function ADDON_API.Bank:GetLinkText(inventorySlotId)
end

-- ======
-- Equipment
-- ======

--[[ 
    Gets the tooltip information for an equipped item
    @param slotIdx (number) The slot index
    @returns (table) The tooltip information
]]
function ADDON_API.Equipment:GetEquippedItemTooltipInfo(slotIdx)
end

--[[ 
    Gets the tooltip text for an equipped item
    @param unit (string) The unit identifier
    @param slotIdx (number) The slot index
    @returns (string) The tooltip text
]]
function ADDON_API.Equipment:GetEquippedItemTooltipText(unit, slotIdx)
end

--[[ 
    Gets the equipped skillset lunagems for a unit
    @param unit (string) The unit identifier
    @returns (table) The lunagems information
]]
function ADDON_API.Equipment:GetEquippedSkillsetLunagems(unit)
end

-- ======
-- SiegeWeapon
-- ======

--[[ 
    Gets the siege weapon speed
    @returns (number) The speed
]]
function ADDON_API.SiegeWeapon:GetSiegeWeaponSpeed()
end

--[[ 
    Gets the siege weapon's turn speed
    @returns (number) The turn speed
]]
function ADDON_API.SiegeWeapon:GetSiegeWeaponTurnSpeed()
end

-- ======
-- ItemEnchant
-- ======

--[[ 
    Gets the ratio information for item enchantment
    @returns (table) The ratio information
]]
function ADDON_API.ItemEnchant:GetRatioInfos()
end

--[[ 
    Gets the enchant item information
    @returns (table) The enchant item information
]]
function ADDON_API.ItemEnchant:GetEnchantItemInfo()
end

--[[ 
    Gets the support item information
    @returns (table) The support item information
]]
function ADDON_API.ItemEnchant:GetSupportItemInfo()
end

--[[ 
    Gets the target item information
    @returns (table) The target item information
]]
function ADDON_API.ItemEnchant:GetTargetItemInfo()
end

-- ======
-- Map
-- ======

--[[ 
    Toggles the map with a portal
    @param portal_zone_id (number) The portal zone ID
    @param x (number) X position
    @param y (number) Y position
    @param z (number) Z position
    @returns (nil)
]]
function ADDON_API.Map:ToggleMapWithPortal(portal_zone_id, x, y, z)
end

--[[ 
    Gets the player's coordinates in sextant format
    @returns (table) The sextants information
]]
function ADDON_API.Map:GetPlayerSextants()
end

-- ======
-- Zone
-- ======

--[[ 
    Gets the zone state information by zone ID
    @param zoneId (number) The zone ID
    @returns (table) The zone state information
]]
function ADDON_API.Zone:GetZoneStateInfoByZoneId(zoneId)
end