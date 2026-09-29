--// =========================================================
--// INFINITY CONTROL
--// Performance Optimized
--// =========================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

--// =========================================================
--// CONFIG
--// =========================================================

local CHECK_ITEM_NAME = "Infinity"

local STUN_TOOL_NAME = "stop [bot_move]"
local KILL_TOOL_NAME = "kill [bot_move]"
local SHIELD_TOOL_NAME = "shield [bot_move]"

local TARGET_HEIGHT = 20

local FOLLOW_TIME = 0.25
local HOLD_TIME = 0.1
local AFTER_STUN_FOLLOW_TIME = 0.25

local DEFAULT_SCAN_INTERVAL = 1
local MAX_PLAYERS = 14
local MAX_TARGET_COORDINATE = 50000

--[[
	OPTIONAL SERVER HISTORY LOGGER

	Keep the logger as a separate GitHub file.  After you publish
	ServerHistoryLogger.lua, paste its real raw URL below.  Leaving this as nil
	keeps Infinity Control fully standalone.

	The logger is intentionally not stopped when this UI closes; it owns its own
	ServerLogs/ session and must be stopped explicitly with Logger.Stop().
]]
local SERVER_HISTORY_LOGGER_URL = nil

local function tryStartServerHistoryLogger()
	if type(SERVER_HISTORY_LOGGER_URL) ~= "string"
		or SERVER_HISTORY_LOGGER_URL == "" then
		return
	end

	if type(loadstring) ~= "function" then
		warn("[Infinity Control] loadstring is unavailable; logger was not started.")
		return
	end

	local loaded, loggerOrError = pcall(function()
		local source = game:HttpGet(SERVER_HISTORY_LOGGER_URL)
		local chunk, compileError = loadstring(source)

		if type(chunk) ~= "function" then
			error(compileError or "Logger source could not be compiled.")
		end

		return chunk()
	end)

	if not loaded then
		warn("[Infinity Control] Failed to load Server History Logger:", loggerOrError)
		return
	end

	if type(loggerOrError) ~= "table"
		or type(loggerOrError.Start) ~= "function" then
		warn("[Infinity Control] Loaded logger has no Start() API.")
		return
	end

	local started, startError = pcall(function()
		loggerOrError.Start()
	end)

	if not started then
		warn("[Infinity Control] Failed to start Server History Logger:", startError)
	end
end

tryStartServerHistoryLogger()

--// =========================================================
--// STATE
--// =========================================================

local isRunning = false
local scanInterval = DEFAULT_SCAN_INTERVAL

local previousTargets = {}

local manualQueue = {}
local manualBusy = false
local manualWorkerRunning = false
local autoBusy = false

local playerCards = {}
local playerConnections = {}
local playerCache = {}

local pendingUpdates = {}
local updateQueued = {}

local selectedPlayer = nil

local guiConnections = {}

--// Update flags
local UPDATE_INFO = 1
local UPDATE_SKILLS = 2
local UPDATE_HEALTH = 4
local UPDATE_ALL = UPDATE_INFO + UPDATE_SKILLS + UPDATE_HEALTH

--// =========================================================
--// GUI
--// =========================================================

local oldGui = CoreGui:FindFirstChild("InfinityControl")

if oldGui then
	oldGui:Destroy()
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "InfinityControl"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 500, 1, 0)
MainFrame.Position = UDim2.new(0, 0, 0, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
MainFrame.BackgroundTransparency = 0.12
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 8)
MainCorner.Parent = MainFrame

local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundTransparency = 1
TitleBar.Parent = MainFrame

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Infinity Control"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TitleBar

local CloseButton = Instance.new("TextButton")
CloseButton.Size = UDim2.new(0, 34, 0, 28)
CloseButton.Position = UDim2.new(1, -40, 0, 5)
CloseButton.BackgroundColor3 = Color3.fromRGB(190, 55, 55)
CloseButton.BackgroundTransparency = 0.15
CloseButton.BorderSizePixel = 0
CloseButton.Text = "X"
CloseButton.Font = Enum.Font.GothamBold
CloseButton.TextSize = 14
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.Parent = TitleBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

CloseButton.MouseButton1Click:Connect(function()
	if ScreenGui and ScreenGui.Parent then
		ScreenGui:Destroy()
	end
end)

--// =========================================================
--// DRAG
--// =========================================================

local dragging = false
local dragStart
local startPosition

table.insert(guiConnections, TitleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		dragging = true
		dragStart = input.Position
		startPosition = MainFrame.Position
	end
end))

table.insert(guiConnections, TitleBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then

		dragging = false
	end
end))

table.insert(guiConnections, UserInputService.InputChanged:Connect(function(input)
	if not dragging then
		return
	end

	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end

	local delta = input.Position - dragStart

	MainFrame.Position = UDim2.new(
		startPosition.X.Scale,
		startPosition.X.Offset + delta.X,
		startPosition.Y.Scale,
		startPosition.Y.Offset + delta.Y
	)
end))

--// =========================================================
--// CONTROL AREA
--// =========================================================

local ControlFrame = Instance.new("Frame")
ControlFrame.Size = UDim2.new(1, -20, 0, 68)
ControlFrame.Position = UDim2.new(0, 10, 0, 44)
ControlFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
ControlFrame.BackgroundTransparency = 0.2
ControlFrame.BorderSizePixel = 0
ControlFrame.Parent = MainFrame

local ControlCorner = Instance.new("UICorner")
ControlCorner.CornerRadius = UDim.new(0, 7)
ControlCorner.Parent = ControlFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(0, 90, 0, 34)
ToggleButton.Position = UDim2.new(0, 10, 0, 10)
ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
ToggleButton.BorderSizePixel = 0
ToggleButton.Text = "START"
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 13
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Parent = ControlFrame

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

local IntervalLabel = Instance.new("TextLabel")
IntervalLabel.Size = UDim2.new(0, 80, 0, 20)
IntervalLabel.Position = UDim2.new(0, 112, 0, 7)
IntervalLabel.BackgroundTransparency = 1
IntervalLabel.Text = "Interval"
IntervalLabel.Font = Enum.Font.Gotham
IntervalLabel.TextSize = 12
IntervalLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
IntervalLabel.TextXAlignment = Enum.TextXAlignment.Left
IntervalLabel.Parent = ControlFrame

local IntervalBox = Instance.new("TextBox")
IntervalBox.Size = UDim2.new(0, 72, 0, 28)
IntervalBox.Position = UDim2.new(0, 112, 0, 29)
IntervalBox.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
IntervalBox.BorderSizePixel = 0
IntervalBox.Text = tostring(scanInterval)
IntervalBox.Font = Enum.Font.Gotham
IntervalBox.TextSize = 13
IntervalBox.TextColor3 = Color3.fromRGB(255, 255, 255)
IntervalBox.ClearTextOnFocus = false
IntervalBox.Parent = ControlFrame

local IntervalCorner = Instance.new("UICorner")
IntervalCorner.CornerRadius = UDim.new(0, 6)
IntervalCorner.Parent = IntervalBox

local CountLabel = Instance.new("TextLabel")
CountLabel.Size = UDim2.new(0, 100, 0, 20)
CountLabel.Position = UDim2.new(0, 200, 0, 10)
CountLabel.BackgroundTransparency = 1
CountLabel.Text = "Targets: 0"
CountLabel.Font = Enum.Font.Gotham
CountLabel.TextSize = 12
CountLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
CountLabel.TextXAlignment = Enum.TextXAlignment.Left
CountLabel.Parent = ControlFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -320, 0, 20)
StatusLabel.Position = UDim2.new(0, 200, 0, 33)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Ready"
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 11
StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.TextTruncate = Enum.TextTruncate.AtEnd
StatusLabel.Parent = ControlFrame

--// =========================================================
--// ACTION AREA
--// =========================================================

local ActionFrame = Instance.new("Frame")
ActionFrame.Size = UDim2.new(1, -20, 0, 42)
ActionFrame.Position = UDim2.new(0, 10, 0, 120)
ActionFrame.BackgroundTransparency = 1
ActionFrame.Parent = MainFrame

local function createActionButton(text, x)
	local button = Instance.new("TextButton")

	button.Size = UDim2.new(0, 90, 0, 34)
	button.Position = UDim2.new(0, x, 0, 4)

	button.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	button.BackgroundTransparency = 0.08
	button.BorderSizePixel = 0

	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = Color3.fromRGB(255, 255, 255)

	button.Parent = ActionFrame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button

	return button
end

local StunButton = createActionButton("STUN", 0)
local KillButton = createActionButton("KILL", 98)
local ShieldButton = createActionButton("SHIELD", 196)

local SelectedLabel = Instance.new("TextLabel")
SelectedLabel.Size = UDim2.new(1, -20, 0, 22)
SelectedLabel.Position = UDim2.new(0, 10, 0, 166)
SelectedLabel.BackgroundTransparency = 1
SelectedLabel.Text = "Selected: None"
SelectedLabel.Font = Enum.Font.Gotham
SelectedLabel.TextSize = 12
SelectedLabel.TextColor3 = Color3.fromRGB(190, 190, 190)
SelectedLabel.TextXAlignment = Enum.TextXAlignment.Left
SelectedLabel.TextTruncate = Enum.TextTruncate.AtEnd
SelectedLabel.Parent = MainFrame

--// =========================================================
--// PLAYER LIST
--// =========================================================

local PlayerList = Instance.new("ScrollingFrame")
PlayerList.Name = "PlayerList"
PlayerList.Size = UDim2.new(1, -20, 1, -200)
PlayerList.Position = UDim2.new(0, 10, 0, 190)
PlayerList.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
PlayerList.BackgroundTransparency = 0.2
PlayerList.BorderSizePixel = 0
PlayerList.ScrollBarThickness = 4
PlayerList.ScrollingDirection = Enum.ScrollingDirection.Y
PlayerList.CanvasSize = UDim2.new(0, 0, 0, 0)
PlayerList.Parent = MainFrame

local PlayerListCorner = Instance.new("UICorner")
PlayerListCorner.CornerRadius = UDim.new(0, 7)
PlayerListCorner.Parent = PlayerList

local Grid = Instance.new("UIGridLayout")
Grid.CellPadding = UDim2.fromOffset(6, 6)
Grid.FillDirection = Enum.FillDirection.Horizontal
Grid.FillDirectionMaxCells = 2
Grid.SortOrder = Enum.SortOrder.LayoutOrder
Grid.Parent = PlayerList

local function updateGrid()
	local width = PlayerList.AbsoluteSize.X
	local height = PlayerList.AbsoluteSize.Y

	local gapX = 6
	local gapY = 6

	local cellWidth = math.floor((width - gapX) / 2)
	local cellHeight = math.floor((height - gapY * 6) / 7)

	if cellWidth < 1 then
		cellWidth = 1
	end

	if cellHeight < 1 then
		cellHeight = 1
	end

	Grid.CellSize = UDim2.fromOffset(cellWidth, cellHeight)

	PlayerList.CanvasSize = UDim2.fromOffset(0, 0)
end

table.insert(guiConnections, PlayerList:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateGrid))

task.defer(updateGrid)

--// =========================================================
--// HELPERS
--// =========================================================

local function getRoot(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("HumanoidRootPart")
end

local function getHead(character)
	if not character then
		return nil
	end

	return character:FindFirstChild("Head")
end

local function isTargetAlive(player)
	local character = player.Character

	if not character then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return false
	end

	return humanoid.Health > 0
end

local function isTargetPositionSafe(player)
	local character = player.Character
	local root = getRoot(character)

	if not root then
		return false
	end

	local position = root.Position

	return math.abs(position.X) <= MAX_TARGET_COORDINATE
		and math.abs(position.Y) <= MAX_TARGET_COORDINATE
		and math.abs(position.Z) <= MAX_TARGET_COORDINATE
end

local function isTargetSafe(player)
	return player
		and player ~= LocalPlayer
		and player.Parent == Players
		and isTargetAlive(player)
		and isTargetPositionSafe(player)
end

local function hasInfinity(player)
	local character = player.Character

	if character and character:FindFirstChild(CHECK_ITEM_NAME) then
		return true
	end

	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack and backpack:FindFirstChild(CHECK_ITEM_NAME) then
		return true
	end

	return false
end

local function getCustomCharacterName(player)
	local value = player:GetAttribute("CustomCharacterName")

	if value == nil then
		return "None"
	end

	return tostring(value)
end

local function getPlayerTools(player)
	local result = {}

	local backpack = player:FindFirstChildOfClass("Backpack")

	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(result, child.Name)
			end
		end
	end

	local character = player.Character

	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(result, child.Name)
			end
		end
	end

	table.sort(result, function(a, b)
		return a:lower() < b:lower()
	end)

	return result
end

local function setStatus(text)
	if ScreenGui.Parent then
		StatusLabel.Text = text
	end
end

--// =========================================================
--// PLAYER CARD RENDER
--// =========================================================

local function renderSkills(player, tools)
	local card = playerCards[player]
	local cache = playerCache[player]

	if not card or not cache then
		return
	end

	local skillScroll = card:FindFirstChild("SkillScroll")
	local labels = cache.skillLabels

	if not skillScroll then
		return
	end

	for index, toolName in ipairs(tools) do
		local label = labels[index]

		if not label then
			label = Instance.new("TextLabel")

			label.Size = UDim2.new(1, -6, 0, 18)
			label.BackgroundTransparency = 1

			label.Font = Enum.Font.Gotham
			label.TextSize = 10
			label.TextColor3 = Color3.fromRGB(215, 215, 215)

			label.TextXAlignment = Enum.TextXAlignment.Left
			label.TextYAlignment = Enum.TextYAlignment.Center

			label.TextTruncate = Enum.TextTruncate.AtEnd

			label.Parent = skillScroll
			labels[index] = label
		end

		label.Text = "• " .. toolName
		label.Visible = true
	end

	for index = #tools + 1, #labels do
		labels[index].Visible = false
	end

	skillScroll.CanvasSize = UDim2.fromOffset(
		0,
		math.max(#tools * 18, skillScroll.AbsoluteSize.Y)
	)
end

local function updatePlayerCard(player, flags)
	local card = playerCards[player]

	if not card then
		return
	end

	local cache = playerCache[player]

	if not cache then
		cache = {
			skillKey = "",
			skillLabels = {},
			displayName = nil,
			username = nil,
			customName = nil,
			hpText = nil
		}

		playerCache[player] = cache

		flags = UPDATE_ALL
	end

	flags = flags or UPDATE_ALL

	--// Basic info
	if bit32.band(flags, UPDATE_INFO) ~= 0 then
		local displayName = player.DisplayName
		local username = "@" .. player.Name
		local customName = getCustomCharacterName(player)

		if cache.displayName ~= displayName then
			cache.displayName = displayName
			local label = card:FindFirstChild("DisplayName")
			if label then label.Text = displayName end
		end

		if cache.username ~= username then
			cache.username = username
			local label = card:FindFirstChild("Username")
			if label then label.Text = username end
		end

		if cache.customName ~= customName then
			cache.customName = customName
			local label = card:FindFirstChild("CustomName")
			if label then label.Text = "Custom: " .. customName end
		end
	end

	--// Health
	if bit32.band(flags, UPDATE_HEALTH) ~= 0 then
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		local hp = humanoid
			and math.max(0, math.floor(humanoid.Health + 0.5))
			or 0

		local hpText = "HP: " .. hp

		if cache.hpText ~= hpText then
			cache.hpText = hpText
			local label = card:FindFirstChild("HP")
			if label then label.Text = hpText end
		end
	end

	--// Skills
	if bit32.band(flags, UPDATE_SKILLS) ~= 0 then
		local tools = getPlayerTools(player)
		local skillKey = table.concat(tools, "\31")

		if cache.skillKey ~= skillKey then
			cache.skillKey = skillKey
			renderSkills(player, tools)
		end
	end
end

--// =========================================================
--// UPDATE QUEUE
--// =========================================================

local function queuePlayerUpdate(player, flags)
	if not player or player == LocalPlayer then
		return
	end

	if not playerCards[player] then
		return
	end

	pendingUpdates[player] = (pendingUpdates[player] or 0) + flags

	if updateQueued[player] then
		return
	end

	updateQueued[player] = true

	task.defer(function()
		updateQueued[player] = nil

		if not ScreenGui.Parent then
			pendingUpdates[player] = nil
			return
		end

		if not playerCards[player] then
			pendingUpdates[player] = nil
			return
		end

		local updateFlags = pendingUpdates[player]
		pendingUpdates[player] = nil

		updatePlayerCard(player, updateFlags)
	end)
end

--// =========================================================
--// SELECTION
--// =========================================================

local function updateSelectedVisual()
	for player, card in pairs(playerCards) do
		if not card.Parent then
			continue
		end

		local selected = player == selectedPlayer

		if selected then
			card.BackgroundColor3 = Color3.fromRGB(45, 80, 130)
			card.BackgroundTransparency = 0.05
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(100, 170, 255)
				stroke.Transparency = 0
			end
		else
			card.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
			card.BackgroundTransparency = 0.15
			local stroke = card:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = Color3.fromRGB(70, 70, 78)
				stroke.Transparency = 0.45
			end
		end
	end

	if selectedPlayer and selectedPlayer.Parent == Players then
		SelectedLabel.Text = "Selected: " .. selectedPlayer.DisplayName
	else
		SelectedLabel.Text = "Selected: None"
	end
end

local function selectPlayer(player)
	selectedPlayer = player
	updateSelectedVisual()
end

--// =========================================================
--// PLAYER CARD
--// =========================================================

local function createPlayerCard(player)
	local card = Instance.new("Frame")
	card.Name = "PlayerCard"
	card.LayoutOrder = player.UserId
	card.BackgroundColor3 = Color3.fromRGB(32, 32, 38)
	card.BackgroundTransparency = 0.15
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Active = true
	card.Parent = PlayerList

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(70, 70, 78)
	stroke.Transparency = 0.45
	stroke.Parent = card


	local DisplayName = Instance.new("TextLabel")
	DisplayName.Name = "DisplayName"
	DisplayName.Size = UDim2.new(0.48, -8, 0, 22)
	DisplayName.Position = UDim2.new(0, 7, 0, 5)
	DisplayName.BackgroundTransparency = 1
	DisplayName.Font = Enum.Font.GothamBold
	DisplayName.TextSize = 12
	DisplayName.TextColor3 = Color3.fromRGB(255, 255, 255)
	DisplayName.TextXAlignment = Enum.TextXAlignment.Left
	DisplayName.TextTruncate = Enum.TextTruncate.AtEnd
	DisplayName.Parent = card

	local Username = Instance.new("TextLabel")
	Username.Name = "Username"
	Username.Size = UDim2.new(0.48, -8, 0, 18)
	Username.Position = UDim2.new(0, 7, 0, 27)
	Username.BackgroundTransparency = 1
	Username.Font = Enum.Font.Gotham
	Username.TextSize = 10
	Username.TextColor3 = Color3.fromRGB(150, 150, 158)
	Username.TextXAlignment = Enum.TextXAlignment.Left
	Username.TextTruncate = Enum.TextTruncate.AtEnd
	Username.Parent = card

	local CustomName = Instance.new("TextLabel")
	CustomName.Name = "CustomName"
	CustomName.Size = UDim2.new(0.48, -8, 0, 18)
	CustomName.Position = UDim2.new(0, 7, 0, 47)
	CustomName.BackgroundTransparency = 1
	CustomName.Font = Enum.Font.Gotham
	CustomName.TextSize = 9
	CustomName.TextColor3 = Color3.fromRGB(180, 180, 188)
	CustomName.TextXAlignment = Enum.TextXAlignment.Left
	CustomName.TextTruncate = Enum.TextTruncate.AtEnd
	CustomName.Parent = card

	local HP = Instance.new("TextLabel")
	HP.Name = "HP"
	HP.Size = UDim2.new(0.48, -8, 0, 18)
	HP.Position = UDim2.new(0, 7, 1, -24)
	HP.BackgroundTransparency = 1
	HP.Font = Enum.Font.GothamBold
	HP.TextSize = 10
	HP.TextColor3 = Color3.fromRGB(120, 220, 130)
	HP.TextXAlignment = Enum.TextXAlignment.Left
	HP.Parent = card

	local SkillTitle = Instance.new("TextLabel")
	SkillTitle.Size = UDim2.new(0.52, -8, 0, 16)
	SkillTitle.Position = UDim2.new(0.48, 2, 0, 5)
	SkillTitle.BackgroundTransparency = 1
	SkillTitle.Font = Enum.Font.GothamBold
	SkillTitle.TextSize = 10
	SkillTitle.TextColor3 = Color3.fromRGB(200, 200, 210)
	SkillTitle.Text = "技能"
	SkillTitle.TextXAlignment = Enum.TextXAlignment.Left
	SkillTitle.Parent = card

	local SkillScroll = Instance.new("ScrollingFrame")
	SkillScroll.Name = "SkillScroll"
	SkillScroll.Size = UDim2.new(0.52, -8, 1, -27)
	SkillScroll.Position = UDim2.new(0.48, 2, 0, 23)
	SkillScroll.BackgroundTransparency = 1
	SkillScroll.BorderSizePixel = 0
	SkillScroll.ScrollBarThickness = 2
	SkillScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	SkillScroll.ScrollingDirection = Enum.ScrollingDirection.Y
	SkillScroll.Parent = card


	local function bindSelectInput(guiObject)
		guiObject.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				selectPlayer(player)
			end
		end)
	end

	bindSelectInput(card)
	bindSelectInput(DisplayName)
	bindSelectInput(Username)
	bindSelectInput(CustomName)
	bindSelectInput(HP)
	bindSelectInput(SkillTitle)
	bindSelectInput(SkillScroll)

	playerCards[player] = card

	playerCache[player] = {
		skillKey = "",
		skillLabels = {},
		displayName = nil,
		username = nil,
		customName = nil,
		hpText = nil
	}

	return card
end

--// =========================================================
--// CHARACTER CONNECTIONS
--// =========================================================

local function disconnectList(list)
	if not list then
		return
	end

	for _, connection in ipairs(list) do
		if connection then
			connection:Disconnect()
		end
	end

	table.clear(list)
end

local function disconnectPlayer(player)
	local connections = playerConnections[player]

	if connections then
		disconnectList(connections.base)
		disconnectList(connections.character)
		disconnectList(connections.backpack)

		if connections.humanoid then
			connections.humanoid:Disconnect()
			connections.humanoid = nil
		end
	end

	playerConnections[player] = nil

	playerCache[player] = nil
	pendingUpdates[player] = nil
	updateQueued[player] = nil

	if playerCards[player] then
		playerCards[player]:Destroy()
		playerCards[player] = nil
	end
end

local function bindCharacter(player, character)
	local connections = playerConnections[player]

	if not connections then
		return
	end

	disconnectList(connections.character)

	if connections.humanoid then
		connections.humanoid:Disconnect()
		connections.humanoid = nil
	end

	queuePlayerUpdate(player, UPDATE_ALL)

	if not character then
		return
	end

	table.insert(connections.character, character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			queuePlayerUpdate(player, UPDATE_SKILLS)
			return
		end

		if child:IsA("Humanoid") then
			if connections.humanoid then
				connections.humanoid:Disconnect()
			end

			connections.humanoid = child.HealthChanged:Connect(function()
				queuePlayerUpdate(player, UPDATE_HEALTH)
			end)

			queuePlayerUpdate(player, UPDATE_HEALTH)
		end
	end))

	table.insert(connections.character, character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			queuePlayerUpdate(player, UPDATE_SKILLS)
		end
	end))

	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		connections.humanoid = humanoid.HealthChanged:Connect(function()
			queuePlayerUpdate(player, UPDATE_HEALTH)
		end)
	end

	queuePlayerUpdate(player, UPDATE_ALL)
end

local function connectPlayer(player)
	if player == LocalPlayer or playerCards[player] then
		return
	end

	createPlayerCard(player)

	local connections = {
		base = {},
		character = {},
		backpack = {},
		humanoid = nil
	}

	playerConnections[player] = connections

	local function bindBackpack(backpack)
		if not backpack then
			return
		end

		disconnectList(connections.backpack)

		table.insert(connections.backpack, backpack.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				queuePlayerUpdate(player, UPDATE_SKILLS)
			end
		end))

		table.insert(connections.backpack, backpack.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				queuePlayerUpdate(player, UPDATE_SKILLS)
			end
		end))

		queuePlayerUpdate(player, UPDATE_SKILLS)
	end

	table.insert(connections.base, player.CharacterAdded:Connect(function(character)
		bindCharacter(player, character)
	end))

	table.insert(connections.base, player.CharacterRemoving:Connect(function()
		if connections.humanoid then
			connections.humanoid:Disconnect()
			connections.humanoid = nil
		end
		disconnectList(connections.character)
		queuePlayerUpdate(player, UPDATE_ALL)
	end))

	table.insert(connections.base, player:GetPropertyChangedSignal("DisplayName"):Connect(function()
		queuePlayerUpdate(player, UPDATE_INFO)
	end))

	table.insert(connections.base, player:GetAttributeChangedSignal("CustomCharacterName"):Connect(function()
		queuePlayerUpdate(player, UPDATE_INFO)
	end))

	table.insert(connections.base, player.ChildAdded:Connect(function(child)
		if child:IsA("Backpack") then
			bindBackpack(child)
		end
	end))

	table.insert(connections.base, player.ChildRemoved:Connect(function(child)
		if child:IsA("Backpack") then
			disconnectList(connections.backpack)
			queuePlayerUpdate(player, UPDATE_SKILLS)
		end
	end))

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		bindBackpack(backpack)
	end

	if player.Character then
		bindCharacter(player, player.Character)
	else
		queuePlayerUpdate(player, UPDATE_ALL)
	end

	queuePlayerUpdate(player, UPDATE_ALL)
end

--// =========================================================
--// TOOL FUNCTIONS
--// =========================================================

local function useTool(toolName)
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")

	if not humanoid then
		return false
	end

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")

	if not backpack then
		return false
	end

	local tool = backpack:FindFirstChild(toolName)

	if not tool or not tool:IsA("Tool") then
		return false
	end

	humanoid:EquipTool(tool)

	task.wait(HOLD_TIME)

	humanoid:UnequipTools()

	return true
end

local function getToolName(action)
	if action == "Stun" then
		return STUN_TOOL_NAME
	end

	if action == "Kill" then
		return KILL_TOOL_NAME
	end

	if action == "Shield" then
		return SHIELD_TOOL_NAME
	end

	return nil
end

--// =========================================================
--// FOLLOW
--// =========================================================

local function followTarget(target, duration, owner)
	if not isTargetSafe(target) then
		return false
	end

	local startTime = os.clock()

	while os.clock() - startTime < duration do
		if not isTargetSafe(target) then
			return false
		end

		if owner == "auto" and manualBusy then
			return false
		end

		local localCharacter = LocalPlayer.Character
		local localRoot = getRoot(localCharacter)

		local targetCharacter = target.Character
		local targetHead = getHead(targetCharacter)

		if not localRoot or not targetHead then
			return false
		end

		local targetPosition = targetHead.Position + Vector3.new(0, TARGET_HEIGHT, 0)

		localRoot.CFrame = CFrame.new(targetPosition)

		RunService.Heartbeat:Wait()
	end

	return true
end

--// =========================================================
--// AUTO PROCESS
--// =========================================================

local function processTarget(target)
	if not isTargetSafe(target) then
		return false
	end

	if not followTarget(target, FOLLOW_TIME, "auto") then
		return false
	end

	if manualBusy then
		return false
	end

	if not isTargetSafe(target) then
		return false
	end

	useTool(STUN_TOOL_NAME)

	if manualBusy then
		return false
	end

	followTarget(target, AFTER_STUN_FOLLOW_TIME, "auto")

	return true
end

local function processTargets(targets)
	if autoBusy then
		return
	end

	autoBusy = true

	local localCharacter = LocalPlayer.Character
	local root = getRoot(localCharacter)

	local originalCFrame = root and root.CFrame

	for _, target in ipairs(targets) do
		if manualBusy then
			break
		end

		processTarget(target)
	end

	root = getRoot(LocalPlayer.Character)

	if root and originalCFrame then
		root.CFrame = originalCFrame
	end

	autoBusy = false
end

local function scanTargets()
	local targets = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and hasInfinity(player) then
			table.insert(targets, player)
		end
	end

	table.sort(targets, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)

	return targets
end

local function updateTargetLogs(targets)
	local current = {}

	for _, player in ipairs(targets) do
		current[player.UserId] = true

		if not previousTargets[player.UserId] then
			print("[Infinity] New target:", player.Name, player.UserId)
		end
	end

	previousTargets = current

	CountLabel.Text = "Targets: " .. tostring(#targets)
end

--// =========================================================
--// MANUAL ACTION
--// =========================================================

local function processManualAction(target, action)
	if not isTargetSafe(target) then
		return
	end

	local root = getRoot(LocalPlayer.Character)
	local originalCFrame = root and root.CFrame

	if not followTarget(target, FOLLOW_TIME, "manual") then
		return
	end

	if not isTargetSafe(target) then
		root = getRoot(LocalPlayer.Character)

		if root and originalCFrame then
			root.CFrame = originalCFrame
		end

		return
	end

	local toolName = getToolName(action)

	if toolName then
		useTool(toolName)
	end

	followTarget(target, AFTER_STUN_FOLLOW_TIME, "manual")

	root = getRoot(LocalPlayer.Character)

	if root and originalCFrame then
		root.CFrame = originalCFrame
	end
end

local function runManualQueue()
	if manualWorkerRunning then
		return
	end

	manualWorkerRunning = true
	manualBusy = true

	while #manualQueue > 0 do
		local request = table.remove(manualQueue, 1)

		if request and request.target and request.action then
			processManualAction(request.target, request.action)
		end
	end

	manualBusy = false
	manualWorkerRunning = false
end

local function enqueueManualAction(target, action)
	if not target or target == LocalPlayer then
		return
	end

	table.insert(manualQueue, {
		target = target,
		action = action
	})

	if not manualWorkerRunning then
		task.spawn(runManualQueue)
	end
end

local function handleAction(action)
	if not selectedPlayer then
		setStatus("No player selected")
		return
	end

	if selectedPlayer.Parent ~= Players then
		selectedPlayer = nil
		updateSelectedVisual()
		setStatus("Selected player is gone")
		return
	end

	enqueueManualAction(selectedPlayer, action)

	setStatus(action .. " queued: " .. selectedPlayer.Name)
end

--// =========================================================
--// BUTTONS
--// =========================================================

StunButton.MouseButton1Click:Connect(function()
	handleAction("Stun")
end)

KillButton.MouseButton1Click:Connect(function()
	handleAction("Kill")
end)

ShieldButton.MouseButton1Click:Connect(function()
	handleAction("Shield")
end)

--// =========================================================
--// TOGGLE
--// =========================================================

ToggleButton.MouseButton1Click:Connect(function()
	isRunning = not isRunning

	if isRunning then
		ToggleButton.Text = "STOP"
		ToggleButton.BackgroundColor3 = Color3.fromRGB(150, 65, 65)

		setStatus("Auto scanning...")
	else
		ToggleButton.Text = "START"
		ToggleButton.BackgroundColor3 = Color3.fromRGB(70, 70, 80)

		previousTargets = {}
		CountLabel.Text = "Targets: 0"

		setStatus("Stopped")
	end
end)

--// =========================================================
--// INTERVAL
--// =========================================================

IntervalBox.FocusLost:Connect(function()
	local value = tonumber(IntervalBox.Text)

	if value and value > 0 then
		scanInterval = value
		IntervalBox.Text = tostring(value)

		setStatus("Interval: " .. tostring(value))
	else
		IntervalBox.Text = tostring(scanInterval)
	end
end)

--// =========================================================
--// PLAYER SETUP
--// =========================================================

local function refreshPlayerOrder()
	local players = {}

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(players, player)
		end
	end

	table.sort(players, function(a, b)
		return a.Name:lower() < b.Name:lower()
	end)

	for index, player in ipairs(players) do
		local card = playerCards[player]

		if card then
			card.Visible = index <= MAX_PLAYERS
			card.LayoutOrder = index
		end
	end
end

local existingPlayers = {}

for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		table.insert(existingPlayers, player)
	end
end

for _, player in ipairs(existingPlayers) do
	connectPlayer(player)
end

refreshPlayerOrder()

table.insert(guiConnections, Players.PlayerAdded:Connect(function(player)
	if player == LocalPlayer then
		return
	end

	connectPlayer(player)
	refreshPlayerOrder()
end))

table.insert(guiConnections, Players.PlayerRemoving:Connect(function(player)
	previousTargets[player.UserId] = nil

	if selectedPlayer == player then
		selectedPlayer = nil
	end

	disconnectPlayer(player)
	refreshPlayerOrder()
	updateSelectedVisual()
end))

--// =========================================================
--// AUTO LOOP
--// =========================================================

task.spawn(function()
	while ScreenGui.Parent do
		if isRunning then
			local targets = scanTargets()

			updateTargetLogs(targets)

			if #targets > 0 and not autoBusy and not manualBusy then
				processTargets(targets)
			end
		end

		task.wait(scanInterval)
	end
end)

--// =========================================================
--// CLEANUP
--// =========================================================

local cleanedUp = false

local function cleanup()
	if cleanedUp then
		return
	end

	cleanedUp = true
	isRunning = false

	manualQueue = {}
	manualBusy = false
	manualWorkerRunning = false
	autoBusy = false

	for _, connection in ipairs(guiConnections) do
		if connection then
			connection:Disconnect()
		end
	end

	table.clear(guiConnections)

	local playersToDisconnect = {}

	for player in pairs(playerConnections) do
		table.insert(playersToDisconnect, player)
	end

	for _, player in ipairs(playersToDisconnect) do
		disconnectPlayer(player)
	end

	table.clear(playerCards)
	table.clear(playerConnections)
	table.clear(playerCache)
	table.clear(pendingUpdates)
	table.clear(updateQueued)
	table.clear(previousTargets)

	selectedPlayer = nil
end

-- Destroying also runs when a newly executed copy removes the older GUI.
-- That prevents the old control script from leaving live event connections.
ScreenGui.Destroying:Connect(cleanup)

--// =========================================================
--// INITIAL
--// =========================================================

updateGrid()
updateSelectedVisual()
setStatus("Ready")

print("[Infinity Control] Optimized version loaded")
