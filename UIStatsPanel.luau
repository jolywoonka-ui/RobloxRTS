local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local UIStatsPanel = {}

local THEME = UIStyle.Theme

local function createMetric(parent, titleText, width)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, width, 1, 0)
	frame.BackgroundTransparency = 1
	frame.Parent = parent

	UIStyle.createLabel(frame, titleText, UDim2.new(1, 0, 0, 12), UDim2.new(0, 0, 0, 8), THEME.FontMain, 10, THEME.SubText)
	local value = UIStyle.createLabel(frame, "-", UDim2.new(1, 0, 0, 18), UDim2.new(0, 0, 0, 24), THEME.FontHeader, 18, THEME.Text)
	return value
end

function UIStatsPanel.init(mainScreen, gameFrame)
	local statsContainer = Instance.new("Frame")
	statsContainer.Name = "CommandStats"
	statsContainer.Size = UDim2.new(0, 510, 0, 58)
	statsContainer.Position = UDim2.new(0, 20, 1, -413)
	statsContainer.BorderSizePixel = 0
	statsContainer.Parent = gameFrame
	UIStyle.applyPanel(statsContainer, "background")

	local pad = UIStyle.addPadding(statsContainer, 12, 12, 0, 0)
	pad.PaddingTop = UDim.new(0, 0)
	pad.PaddingBottom = UDim.new(0, 0)

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Padding = UDim.new(0, 16)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Parent = statsContainer

	local creditsText = createMetric(statsContainer, "CREDITS", 110)
	local energyText = createMetric(statsContainer, "ENERGY", 120)
	local incomeText = createMetric(statsContainer, "INCOME", 102)
	local unitsText = createMetric(statsContainer, "UNITS", 102)

	task.spawn(function()
		local statsFolder = player:WaitForChild("Stats", 20)
		local playerStats = player:WaitForChild("PlayerStats", 20)
		if not statsFolder or not playerStats then
			return
		end

		local function update()
			local credits = statsFolder.Credits.Value
			local income = playerStats.Income.Value
			local energy = playerStats.Energy.Value
			local maxEnergy = playerStats.MaxEnergy.Value
			local curUnits = playerStats:FindFirstChild("CurrentUnits") and playerStats.CurrentUnits.Value or 0
			local maxUnits = playerStats:FindFirstChild("UnitLimit") and playerStats.UnitLimit.Value or 0

			creditsText.Text = "$" .. tostring(credits)
			incomeText.Text = "+" .. tostring(income)
			energyText.Text = tostring(energy) .. " / " .. tostring(maxEnergy)
			unitsText.Text = tostring(curUnits) .. " / " .. tostring(maxUnits)

			creditsText.TextColor3 = THEME.Positive
			incomeText.TextColor3 = income > 0 and THEME.Text or THEME.SubText
			energyText.TextColor3 = energy > maxEnergy and THEME.Negative or THEME.Text
			unitsText.TextColor3 = curUnits > maxUnits and THEME.Warning or THEME.Text
		end

		statsFolder.Credits.Changed:Connect(update)
		playerStats.Income.Changed:Connect(update)
		playerStats.Energy.Changed:Connect(update)
		playerStats.MaxEnergy.Changed:Connect(update)
		if playerStats:FindFirstChild("CurrentUnits") then
			playerStats.CurrentUnits.Changed:Connect(update)
		end
		if playerStats:FindFirstChild("UnitLimit") then
			playerStats.UnitLimit.Changed:Connect(update)
		end
		playerStats.ChildAdded:Connect(function(child)
			if child.Name == "CurrentUnits" or child.Name == "UnitLimit" then
				child.Changed:Connect(update)
				update()
			end
		end)
		update()
	end)

	return statsContainer
end

return UIStatsPanel
