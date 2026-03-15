local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local victoryEvent = ReplicatedStorage:WaitForChild("ShowVictory")

local THEME = UIStyle.Theme

local function createLabel(parent, text, size, position, font, textSize, color, align)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or THEME.Text
	label.Font = font or THEME.FontBody
	label.TextSize = textSize or 14
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

local function createButton(parent, text, size, position, kind)
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.Text = text
	button.Parent = parent
	UIStyle.applyButton(button, kind)
	button.Font = THEME.FontMain
	button.TextSize = 13
	return button
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VictoryScreen"
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screenGui

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 420, 0, 180)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.new(0.5, 0, 0.5, 0)
panel.BorderSizePixel = 0
panel.Parent = screenGui
UIStyle.applyPanel(panel, "background")

createLabel(panel, "ROUND COMPLETE", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 14), THEME.FontMain, 11, THEME.SubText, Enum.TextXAlignment.Center)
local winnersLabel = createLabel(panel, "-", UDim2.new(1, -24, 0, 56), UDim2.new(0, 12, 0, 42), THEME.FontHeader, 26, THEME.Text, Enum.TextXAlignment.Center)
winnersLabel.TextWrapped = true
createLabel(panel, "The next round is preparing now.", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 108), THEME.FontBody, 12, THEME.SubText, Enum.TextXAlignment.Center)

local closeButton = createButton(panel, "DISMISS", UDim2.new(0, 120, 0, 30), UDim2.new(0.5, -60, 1, -42), "secondary")

local function hide()
	screenGui.Enabled = false
end

local function showAnimated()
	screenGui.Enabled = true
	panel.Position = UDim2.new(0.5, 0, 0.5, 10)
	overlay.BackgroundTransparency = 0.62
	TweenService:Create(panel, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
	TweenService:Create(overlay, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.55,
	}):Play()
end

overlay.MouseButton1Click:Connect(hide)
closeButton.MouseButton1Click:Connect(hide)

victoryEvent.OnClientEvent:Connect(function(winnersText)
	showAnimated()
	winnersLabel.Text = tostring(winnersText or "Unknown")
end)
