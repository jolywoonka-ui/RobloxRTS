local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIBuildMenu = require(ReplicatedStorage.UIBuildMenu)
local UIStatsPanel = require(ReplicatedStorage.UIStatsPanel)
local UIInspector = require(ReplicatedStorage.UIInspector)
local UIMultiSelect = require(ReplicatedStorage.UIMultiSelect)
local UIMouseHandler = require(ReplicatedStorage.UIMouseHandler)
local UIUnitInspector = require(ReplicatedStorage.UIUnitInspector)
local UIStyle = require(ReplicatedStorage.UIStyle)

local THEME = UIStyle.Theme

local MainScreen = Instance.new("ScreenGui")
MainScreen.Name = "RTS_MainUI"
MainScreen.ResetOnSpawn = false
MainScreen.IgnoreGuiInset = true
MainScreen.Parent = playerGui

local GameFrame = Instance.new("Frame", MainScreen)
GameFrame.Name = "GameFrame"
GameFrame.Size = UDim2.new(1, 0, 1, 0)
GameFrame.BackgroundTransparency = 1
GameFrame.Visible = false

local StatsContainer = UIStatsPanel.init(MainScreen, GameFrame)
UIBuildMenu.init(MainScreen, GameFrame, StatsContainer)

UIInspector.init(MainScreen, GameFrame)
UIUnitInspector.init(MainScreen, GameFrame)
local Selection = require(ReplicatedStorage.UnitSelection)
UIMouseHandler.init(UIInspector, UIUnitInspector, UIMultiSelect, Selection)

local function createTopBar(name, parent, size, position)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = position
	frame.BorderSizePixel = 0
	frame.Parent = parent
	UIStyle.applyPanel(frame, "background")
	return frame
end

local LobbyBar = createTopBar("LobbyBar", MainScreen, UDim2.new(0, 390, 0, 40), UDim2.new(0.5, 0, 0, 16))
local GameStatus = ReplicatedStorage:WaitForChild("GameStatus")

local LobbyStatus = Instance.new("TextLabel", LobbyBar)
LobbyStatus.Size = UDim2.new(1, -20, 1, 0)
LobbyStatus.Position = UDim2.new(0, 10, 0, 0)
LobbyStatus.BackgroundTransparency = 1
LobbyStatus.Text = "WAITING FOR PLAYERS"
LobbyStatus.TextColor3 = THEME.Text
LobbyStatus.Font = THEME.FontHeader
LobbyStatus.TextSize = 16
LobbyStatus.TextXAlignment = Enum.TextXAlignment.Center
GameStatus.Changed:Connect(function(v)
	LobbyStatus.Text = string.upper(v)
end)

local TimerFrame = createTopBar("TimerFrame", GameFrame, UDim2.new(0, 210, 0, 40), UDim2.new(0.5, 0, 0, 16))
TimerFrame.Visible = false

local GameTimer = ReplicatedStorage:WaitForChild("GameTimer")
local TimerLabel = Instance.new("TextLabel", TimerFrame)
TimerLabel.Size = UDim2.new(1, -20, 1, 0)
TimerLabel.Position = UDim2.new(0, 10, 0, 0)
TimerLabel.BackgroundTransparency = 1
TimerLabel.Text = "02:00:00"
TimerLabel.TextColor3 = THEME.Text
TimerLabel.Font = THEME.FontHeader
TimerLabel.TextSize = 18
TimerLabel.TextXAlignment = Enum.TextXAlignment.Center
GameTimer.Changed:Connect(function(v)
	TimerLabel.Text = v
end)

local function updateGameState()
	local inGame = player.Team and player.Team.Name ~= "Lobby"
	LobbyBar.Visible = not inGame
	GameFrame.Visible = inGame
	TimerFrame.Visible = inGame
end

player:GetPropertyChangedSignal("Team"):Connect(updateGameState)
updateGameState()
