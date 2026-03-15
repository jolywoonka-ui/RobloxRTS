local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local victoryEvent = ReplicatedStorage:WaitForChild("ShowVictoryStats")

local THEME = UIStyle.Theme

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "VictoryStatsScreen"
screenGui.Enabled = false
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = playerGui

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.5
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Parent = screenGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 760, 0, 420)
mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui
UIStyle.applyPanel(mainFrame, "background")

UIStyle.createLabel(mainFrame, "MATCH REPORT", UDim2.new(1, -120, 0, 20), UDim2.new(0, 14, 0, 14), THEME.FontHeader, 22, THEME.Text)
UIStyle.createLabel(mainFrame, "Simple round summary for you and the lobby leaders.", UDim2.new(1, -120, 0, 14), UDim2.new(0, 14, 0, 40), THEME.FontMain, 12, THEME.Text)
local closeButton = UIStyle.createButton(mainFrame, "CLOSE", UDim2.new(0, 80, 0, 28), UDim2.new(1, -94, 0, 14), "secondary")
UIStyle.createDivider(mainFrame, 64, 1)

local winnersLabel = UIStyle.createLabel(mainFrame, "-", UDim2.new(1, -28, 0, 26), UDim2.new(0, 14, 0, 78), THEME.FontHeader, 24, THEME.Text)

local personalFrame = Instance.new("Frame")
personalFrame.Size = UDim2.new(0.5, -18, 1, -142)
personalFrame.Position = UDim2.new(0, 14, 0, 122)
personalFrame.BackgroundTransparency = 1
personalFrame.Parent = mainFrame
local personalLayout = Instance.new("UIListLayout")
personalLayout.Padding = UDim.new(0, 8)
personalLayout.Parent = personalFrame

local globalFrame = Instance.new("Frame")
globalFrame.Size = UDim2.new(0.5, -18, 1, -142)
globalFrame.Position = UDim2.new(0.5, 4, 0, 122)
globalFrame.BackgroundTransparency = 1
globalFrame.Parent = mainFrame
local globalLayout = Instance.new("UIListLayout")
globalLayout.Padding = UDim.new(0, 8)
globalLayout.Parent = globalFrame

local function clearRows(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function createMetricRow(parent, titleText, valueText)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 52)
	row.BorderSizePixel = 0
	row.Parent = parent
	UIStyle.applyPanel(row, "panel")
	UIStyle.createLabel(row, string.upper(titleText), UDim2.new(0.55, -8, 1, 0), UDim2.new(0, 8, 0, 0), THEME.FontMain, 11, THEME.SubText)
	UIStyle.createLabel(row, tostring(valueText), UDim2.new(0.45, -8, 1, 0), UDim2.new(0.55, 0, 0, 0), THEME.FontHeader, 18, THEME.Text, Enum.TextXAlignment.Right)
end

local function createLeaderRow(parent, titleText, playerName, valueText)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 60)
	row.BorderSizePixel = 0
	row.Parent = parent
	UIStyle.applyPanel(row, "panel")
	UIStyle.createLabel(row, string.upper(titleText), UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 6), THEME.FontMain, 11, THEME.SubText)
	UIStyle.createLabel(row, tostring(playerName), UDim2.new(0.62, -8, 0, 18), UDim2.new(0, 8, 0, 26), THEME.FontHeader, 16, THEME.Text)
	UIStyle.createLabel(row, tostring(valueText), UDim2.new(0.38, -8, 0, 18), UDim2.new(0.62, 0, 0, 26), THEME.FontBody, 12, THEME.SubText, Enum.TextXAlignment.Right)
end

local function getGlobalEntry(globalMost, key)
	local entry = globalMost and globalMost[key]
	if not entry then
		return "-", 0
	end
	return tostring(entry.player or "-"), tonumber(entry.value or 0) or 0
end

local function findPersonalStats(data)
	local list = data and data.personalStats
	if not list then
		return nil
	end
	for _, pdata in ipairs(list) do
		if pdata.name == player.Name then
			return pdata
		end
	end
	return nil
end

local function hide()
	screenGui.Enabled = false
end

local function showAnimated()
	screenGui.Enabled = true
	mainFrame.Position = UDim2.new(0.5, 0, 0.5, 10)
	overlay.BackgroundTransparency = 0.58
	TweenService:Create(mainFrame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
	TweenService:Create(overlay, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.5,
	}):Play()
end

closeButton.MouseButton1Click:Connect(hide)
overlay.MouseButton1Click:Connect(hide)

victoryEvent.OnClientEvent:Connect(function(data)
	showAnimated()

	local winners = (data and data.winners) and tostring(data.winners) or "Unknown"
	winnersLabel.Text = "Winner: " .. winners

	clearRows(personalFrame)
	clearRows(globalFrame)

	UIStyle.createLabel(personalFrame, "YOUR REPORT", UDim2.new(1, 0, 0, 16), UDim2.new(), THEME.FontMain, 11, THEME.SubText)
	UIStyle.createLabel(globalFrame, "ROUND LEADERS", UDim2.new(1, 0, 0, 16), UDim2.new(), THEME.FontMain, 11, THEME.SubText)

	local mine = findPersonalStats(data)
	createMetricRow(personalFrame, "Money Spent", mine and (mine.moneySpent or 0) or 0)
	createMetricRow(personalFrame, "Units Recruited", mine and (mine.unitsRecruited or 0) or 0)
	createMetricRow(personalFrame, "Damage Dealt", mine and (mine.damageDealt or 0) or 0)

	local topSpenderName, topSpenderValue = getGlobalEntry(data and data.globalMost, "moneySpent")
	local topRecruitName, topRecruitValue = getGlobalEntry(data and data.globalMost, "unitsRecruited")
	local topDamageName, topDamageValue = getGlobalEntry(data and data.globalMost, "damageDealt")

	createLeaderRow(globalFrame, "Top Spender", topSpenderName, "$" .. tostring(topSpenderValue))
	createLeaderRow(globalFrame, "Top Recruiter", topRecruitName, tostring(topRecruitValue) .. " units")
	createLeaderRow(globalFrame, "Top Damage", topDamageName, tostring(topDamageValue))
end)
