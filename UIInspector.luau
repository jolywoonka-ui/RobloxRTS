-- UIInspector (ModuleScript, ReplicatedStorage)
-- Split orchestrator: layout, rendering, selection, and training responsibilities are delegated to dedicated modules.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local UnitEvent = ReplicatedStorage:WaitForChild("UnitEvent")
local SellEvent = ReplicatedStorage:WaitForChild("SellEvent")
local UpgradeEvent = ReplicatedStorage:WaitForChild("UpgradeEvent") or error("UpgradeEvent missing")
local MissileSiloEvent = ReplicatedStorage:WaitForChild("MissileSiloEvent")
local HeadquartersControlEvent = ReplicatedStorage:WaitForChild("HeadquartersControlEvent")
local ResearchEvent = ReplicatedStorage:WaitForChild("ResearchEvent")
local UnitsFolder = ReplicatedStorage:WaitForChild("Units")
local UIMultiSelect = require(ReplicatedStorage:WaitForChild("UIMultiSelect"))

local Layout = require(ReplicatedStorage:WaitForChild("UIInspector.Layout"))
local Rendering = require(ReplicatedStorage:WaitForChild("UIInspector.Rendering"))
local Selection = require(ReplicatedStorage:WaitForChild("UIInspector.Selection"))
local Training = require(ReplicatedStorage:WaitForChild("UIInspector.Training"))
local Targeting = require(ReplicatedStorage:WaitForChild("UIInspectorTargeting"))
local SuperWeapons = require(ReplicatedStorage:WaitForChild("UIInspectorSuperWeapons"))
local Production = require(ReplicatedStorage:WaitForChild("UIInspectorProduction"))
local Panels = require(ReplicatedStorage:WaitForChild("UIInspectorPanels"))

local UIInspector = {}

local THEME = UIStyle.Theme

local CONSTANTS = {
	TRAIN_POS_WITH_QUEUE = UDim2.new(0, 10, 0, 210),
	TRAIN_SIZE_WITH_QUEUE = UDim2.new(1, -20, 1, -370),
	TRAIN_POS_INFO = UDim2.new(0, 10, 0, 135),
	TRAIN_SIZE_INFO = UDim2.new(1, -20, 1, -295),
	INSPECTOR_SIZE_FULL = UDim2.new(0, 345, 0, 575),
	INSPECTOR_POS_FULL = UDim2.new(1, -365, 1, -595),
	INSPECTOR_SIZE_COMPACT = UDim2.new(0, 345, 0, 220),
	INSPECTOR_POS_COMPACT = UDim2.new(1, -365, 1, -240),
}

local ui = nil
local selectedBuilding = nil
local inspectorConnections = {}
local humanoidConn = nil
local selectionVisuals = nil

local sellActionTargets = {}
local upgradeActionTargets = {}
local getSellActionRefundTotal

local function queueRenderHelpers()
	return {
		theme = THEME,
		addCorner = Layout.addCorner,
		addStroke = Layout.addStroke,
		createText = Layout.createText,
		renderUnitViewport = Rendering.renderUnitViewport,
	}
end

local function disconnectInspectorSignals()
	if humanoidConn then
		humanoidConn:Disconnect()
		humanoidConn = nil
	end
	for _, conn in ipairs(inspectorConnections) do
		conn:Disconnect()
	end
	inspectorConnections = {}
end

local function resetInspectorLayout()
	if not ui then
		return
	end
	local productionGradient = ui.InspectorFrame:FindFirstChild("ProductionShellGradient")
	if productionGradient then
		productionGradient:Destroy()
	end
	ui.InspectorFrame.Size = CONSTANTS.INSPECTOR_SIZE_FULL
	ui.InspectorFrame.Position = CONSTANTS.INSPECTOR_POS_FULL
	ui.InspectorFrame.BackgroundColor3 = THEME.Background
	ui.InspectorFrame.BackgroundTransparency = 0
	ui.TrainFrame.Visible = true
	ui.TrainFrame.Position = CONSTANTS.TRAIN_POS_WITH_QUEUE
	ui.TrainFrame.Size = CONSTANTS.TRAIN_SIZE_WITH_QUEUE
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	ui.TrainFrame.ScrollBarImageColor3 = THEME.Stroke
	ui.TrainFrame.ScrollBarThickness = 5
	ui.TrainFrame.ScrollingEnabled = true
	ui.QueueLabel.Visible = true
	ui.QueueLabel.Text = "TRAINING QUEUE"
	ui.QueueLabel.TextColor3 = THEME.SubText
	ui.QueueScroll.Visible = true
	ui.QueueScroll.Position = UDim2.new(0, 10, 0, 143)
	ui.QueueScroll.Size = UDim2.new(1, -20, 0, 60)
	ui.InspTitle.Position = UDim2.new(0, 10, 0, 5)
	ui.InspTitle.Size = UDim2.new(1, -20, 0, 40)
	ui.InspTitle.TextXAlignment = Enum.TextXAlignment.Center
	ui.InspTitle.TextSize = 22
	ui.InspTitle.Visible = true
	ui.HPContainer.Position = UDim2.new(0, 20, 0, 50)
	ui.HPContainer.Size = UDim2.new(1, -40, 0, 20)
	ui.HPContainer.BackgroundColor3 = THEME.Inset
	ui.HPContainer.Visible = true
	local inspectorStroke = ui.InspectorFrame:FindFirstChildWhichIsA("UIStroke")
	if inspectorStroke then
		inspectorStroke.Color = THEME.Stroke
		inspectorStroke.Thickness = 2
		inspectorStroke.Transparency = 0
	end
	local hpStroke = ui.HPContainer:FindFirstChildWhichIsA("UIStroke")
	if hpStroke then
		hpStroke.Color = THEME.Stroke
		hpStroke.Thickness = 1
	end
	ui.RelationshipLabel.Visible = false
	ui.GarrisonLabel.Visible = false
	ui.SpecialStatusLabel.Visible = false
	ui.ActionBtn.Visible = false
	ui.ActionBtn.Size = UDim2.new(1, -40, 0, 40)
	ui.ActionBtn.Position = UDim2.new(0, 20, 1, -45)
	ui.ActionBtn.Text = "SPECIAL ACTION"
	ui.SellBtn.Size = UDim2.new(1, -40, 0, 40)
	ui.SellBtn.Position = UDim2.new(0, 20, 1, -145)
	ui.SellBtn.BackgroundColor3 = THEME.Negative
	ui.SellBtn.TextColor3 = THEME.Text
	ui.UpgradeBtn.Size = UDim2.new(1, -40, 0, 40)
	ui.UpgradeBtn.Position = UDim2.new(0, 20, 1, -95)
	ui.UpgradeBtn.BackgroundColor3 = THEME.Accent
	ui.UpgradeBtn.TextColor3 = THEME.Text
end

local function clearTrainFrameContent()
	for _, child in ipairs(ui.TrainFrame:GetChildren()) do
		if child:IsA("GuiObject") and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

local function collectOwnedSelectedBuildings()
	local targets = {}
	local seen = {}
	for _, b in ipairs(UIMultiSelect.getSelected()) do
		if b and b.Parent and b:GetAttribute("Owner") == player.Name and not seen[b] then
			seen[b] = true
			table.insert(targets, b)
		end
	end
	return targets
end

local function getBuildingTypeName(building)
	if not building then
		return "BUILDING"
	end
	return tostring(building:GetAttribute("Type") or building.Name or "BUILDING")
end

local function summarizeSelectedBuildings(buildings)
	local summary = {
		Count = #buildings,
		SameType = true,
		TypeName = nil,
		CountsByType = {},
	}

	if #buildings == 0 then
		return summary
	end

	local firstType = getBuildingTypeName(buildings[1])
	summary.TypeName = firstType

	for _, building in ipairs(buildings) do
		local buildingType = getBuildingTypeName(building)
		summary.CountsByType[buildingType] = (summary.CountsByType[buildingType] or 0) + 1
		if buildingType ~= firstType then
			summary.SameType = false
		end
	end

	return summary
end

local function refreshSelectedQueueUI()
	if not ui or not selectedBuilding then
		return
	end
	local bType = selectedBuilding:GetAttribute("Type")
	if bType == "MissileSilo" then
		return
	end
	if bType == "Headquarters" or bType == "HeadquartersL2" then
		return
	end
	if bType == "ResearchCenter" then
		return
	end
	Training.refreshQueueUI(ui.QueueScroll, selectedBuilding, queueRenderHelpers())
end

local function applyHPBinding(model)
	local hum = model:FindFirstChild("Humanoid")
	if not hum then
		return
	end

	local function update()
		local maxHealth = hum.MaxHealth > 0 and hum.MaxHealth or 1
		local p = math.clamp(hum.Health / maxHealth, 0, 1)
		ui.HPBarFill.Size = UDim2.new(p, 0, 1, 0)
		ui.HPBarFill.BackgroundColor3 = p < 0.3 and THEME.Red or (p < 0.6 and Color3.fromRGB(255, 200, 50) or THEME.Green)
	end

	humanoidConn = hum.HealthChanged:Connect(update)
	update()
end

local function getOwnerPlayer(ownerName)
	if not ownerName or ownerName == "" then
		return nil
	end
	return Players:FindFirstChild(ownerName)
end

local function getOwnedWorldCounts(ownerName)
	local buildingCount = 0
	local unitCount = 0

	local currentMap = workspace:FindFirstChild("CurrentMap")
	local buildingContainer = currentMap and currentMap:FindFirstChild("PlayerBuildings")
	local armyContainer = currentMap and currentMap:FindFirstChild("Army")

	if buildingContainer then
		for _, inst in ipairs(buildingContainer:GetDescendants()) do
			if inst:IsA("Model") and inst:GetAttribute("Type") and inst:GetAttribute("Owner") == ownerName then
				buildingCount += 1
			end
		end
	end

	if armyContainer then
		for _, inst in ipairs(armyContainer:GetChildren()) do
			if inst:GetAttribute("IsUnit") and inst:GetAttribute("Owner") == ownerName then
				unitCount += 1
			end
		end
	end

	return buildingCount, unitCount, buildingContainer, armyContainer
end

local function isResearchUnlocked(researchId)
	if not researchId then
		return true
	end
	return player:GetAttribute("Research_" .. tostring(researchId)) == true
end

local function getResearchDisplayName(researchId)
	local researchData = Config.Research[researchId]
	return tostring(researchData and researchData.DisplayName or researchId or "RESEARCH")
end

local function formatClockDuration(seconds)
	seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	if minutes > 0 then
		return string.format("%dm %02ds", minutes, remainder)
	end
	return string.format("%ds", remainder)
end

local function renderHeadquartersPanel(model, bData)
	local MODE_DEFS = {
		Close = {Label = "CLOSE DEFENSE", Range = 6, Damage = 20},
		Balanced = {Label = "BALANCED", Range = 8, Damage = 15},
		Long = {Label = "LONG REACH", Range = 10, Damage = 10},
	}

	local function formatDuration(seconds)
		seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
		local minutes = math.floor(seconds / 60)
		local remainder = seconds % 60
		if minutes > 0 then
			return string.format("%dm %02ds", minutes, remainder)
		end
		return string.format("%ds", remainder)
	end

	local function getModeStats(modeName)
		local modeDef = MODE_DEFS[modeName] or MODE_DEFS.Balanced
		return modeDef.Damage, modeDef.Range, modeDef
	end

	ui.InspectorFrame.Size = UDim2.new(0, 620, 0, 690)
	ui.InspectorFrame.Position = UDim2.new(1, -640, 1, -710)
	ui.InspectorFrame.BackgroundTransparency = 1
	local inspectorStroke = ui.InspectorFrame:FindFirstChildWhichIsA("UIStroke")
	if inspectorStroke then
		inspectorStroke.Transparency = 1
	end
	ui.InspTitle.Visible = false
	ui.HPContainer.Visible = false
	ui.QueueLabel.Visible = false
	ui.QueueScroll.Visible = false
	Training.hideQueueError()
	ui.TrainFrame.Position = UDim2.new(0, 8, 0, 8)
	ui.TrainFrame.Size = UDim2.new(1, -16, 1, -16)
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	ui.TrainFrame.ScrollBarThickness = 0
	ui.TrainFrame.ScrollingEnabled = false
	ui.SellBtn.Visible = true
	ui.SellBtn.Size = UDim2.new(0.5, -14, 0, 48)
	ui.SellBtn.Position = UDim2.new(0, 22, 1, -72)
	ui.SellBtn.BackgroundColor3 = Color3.fromRGB(130, 65, 65)
	ui.SellBtn.Text = "SURRENDER"
	ui.UpgradeBtn.Size = UDim2.new(0.5, -14, 0, 48)
	ui.UpgradeBtn.Position = UDim2.new(0.5, -8, 1, -72)
	ui.UpgradeBtn.BackgroundColor3 = Color3.fromRGB(188, 158, 99)
	ui.UpgradeBtn.TextColor3 = Color3.fromRGB(20, 18, 14)
	ui.UpgradeBtn.Visible = Training.canUpgradeBuilding(model)

	local ownerName = model:GetAttribute("Owner")
	local ownerPlayer = getOwnerPlayer(ownerName)
	local playerStats = ownerPlayer and ownerPlayer:FindFirstChild("PlayerStats")
	local teamColor = ownerPlayer and ownerPlayer:GetAttribute("TeamColor")
	if typeof(teamColor) ~= "Color3" then
		teamColor = Color3.fromRGB(168, 142, 95)
	end
	local heroColor = teamColor:Lerp(Color3.fromRGB(28, 26, 24), 0.58)
	local heroStrokeColor = teamColor:Lerp(Color3.fromRGB(255, 246, 222), 0.45)
	local heroAccentColor = teamColor:Lerp(Color3.fromRGB(255, 247, 214), 0.35)

	local content = Instance.new("Frame")
	content.Name = "HQContent"
	content.Size = UDim2.new(1, -8, 0, 674)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = ui.TrainFrame
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, 674)

	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, 0, 0, 656)
	shell.BackgroundColor3 = Color3.fromRGB(24, 24, 29)
	shell.BorderSizePixel = 0
	shell.Parent = content
	Layout.addCorner(shell, UDim.new(0, 16))
	Layout.addStroke(shell, 1, heroStrokeColor:Lerp(Color3.fromRGB(100, 92, 84), 0.55))

	local hero = Instance.new("Frame")
	hero.Size = UDim2.new(1, -24, 0, 120)
	hero.Position = UDim2.new(0, 12, 0, 12)
	hero.BackgroundColor3 = heroColor
	hero.BorderSizePixel = 0
	hero.Parent = shell
	Layout.addCorner(hero, UDim.new(0, 14))
	Layout.addStroke(hero, 1, heroStrokeColor)

	local overline = Layout.createText(hero, "COLONY COMMAND", UDim2.new(1, -18, 0, 18), UDim2.new(0, 12, 0, 10), Enum.Font.GothamBold, heroAccentColor, Enum.TextXAlignment.Left, THEME)
	overline.TextSize = 11

	local heading = Layout.createText(hero, string.upper(model.Name), UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 28), Enum.Font.GothamBlack, THEME.Text, Enum.TextXAlignment.Left, THEME)
	heading.TextSize = 25

local headline = Layout.createText(hero, "Command your colony, deploy builders, and tune defensive reach.", UDim2.new(1, -24, 0, 26), UDim2.new(0, 12, 0, 58), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	headline.TextSize = 12
	headline.TextWrapped = true

	local healthLabel = Layout.createText(hero, "STRUCTURAL INTEGRITY", UDim2.new(1, -24, 0, 14), UDim2.new(0, 12, 0, 84), Enum.Font.GothamBold, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	healthLabel.TextSize = 11

	local healthBack = Instance.new("Frame")
	healthBack.Size = UDim2.new(1, -24, 0, 14)
	healthBack.Position = UDim2.new(0, 12, 0, 100)
	healthBack.BackgroundColor3 = Color3.fromRGB(18, 19, 24)
	healthBack.BorderSizePixel = 0
	healthBack.Parent = hero
	Layout.addCorner(healthBack, UDim.new(0, 999))
	Layout.addStroke(healthBack, 1, Color3.fromRGB(87, 89, 98))

	local healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = THEME.Green
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBack
	Layout.addCorner(healthFill, UDim.new(0, 999))

	local healthValue = Layout.createText(hero, "100%", UDim2.new(0, 80, 0, 14), UDim2.new(1, -92, 0, 84), Enum.Font.GothamBold, THEME.Text, Enum.TextXAlignment.Right, THEME)
	healthValue.TextSize = 11

	local statGrid = Instance.new("Frame")
	statGrid.Size = UDim2.new(1, -24, 0, 128)
	statGrid.Position = UDim2.new(0, 12, 0, 144)
	statGrid.BackgroundTransparency = 1
	statGrid.Parent = shell

	local statLabels = {}
	local function createStatCard(index, titleText, valueText, accentColor)
		local col = (index - 1) % 2
		local row = math.floor((index - 1) / 2)
		local card = Instance.new("Frame")
		card.Size = UDim2.new(0.5, -6, 0, 36)
		card.Position = UDim2.new(col * 0.5, col == 0 and 0 or 6, 0, row * 46)
		card.BackgroundColor3 = Color3.fromRGB(33, 35, 42)
		card.BorderSizePixel = 0
		card.Parent = statGrid
		Layout.addCorner(card, UDim.new(0, 10))
		Layout.addStroke(card, 1, Color3.fromRGB(77, 79, 90))

		local nameLabel = Layout.createText(card, titleText, UDim2.new(0.52, -10, 1, 0), UDim2.new(0, 10, 0, 0), Enum.Font.GothamBold, THEME.SubText, Enum.TextXAlignment.Left, THEME)
		nameLabel.TextSize = 11

		local valueLabel = Layout.createText(card, valueText, UDim2.new(0.48, -10, 1, 0), UDim2.new(0.52, 0, 0, 0), Enum.Font.GothamBlack, accentColor, Enum.TextXAlignment.Right, THEME)
		valueLabel.TextSize = 15
		statLabels[titleText] = valueLabel
	end

	createStatCard(1, "TOTAL BUILDINGS", "0", THEME.Text)
	createStatCard(2, "TOTAL UNITS", "0", THEME.Text)
	createStatCard(3, "INCOME", "$+0", THEME.Green)
	createStatCard(4, "ENERGY", "0 / 0", THEME.Accent)
	createStatCard(5, "UNITS", "0 / 0", THEME.Text)
	createStatCard(6, "WEAPON MODE", "BALANCED", Color3.fromRGB(215, 191, 132))

	local builderBay = Instance.new("Frame")
	builderBay.Size = UDim2.new(0.5, -16, 0, 304)
	builderBay.Position = UDim2.new(0, 12, 0, 286)
	builderBay.BackgroundColor3 = Color3.fromRGB(28, 33, 41)
	builderBay.BorderSizePixel = 0
	builderBay.Parent = shell
	Layout.addCorner(builderBay, UDim.new(0, 14))
	Layout.addStroke(builderBay, 1, Color3.fromRGB(88, 103, 126))

	local builderTitle = Layout.createText(builderBay, "BUILDER BAY", UDim2.new(1, -18, 0, 18), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Color3.fromRGB(176, 214, 255), Enum.TextXAlignment.Left, THEME)
	builderTitle.TextSize = 12

	local builderStatus = Layout.createText(builderBay, "Queue idle", UDim2.new(1, -18, 0, 20), UDim2.new(0, 10, 0, 34), Enum.Font.GothamBold, THEME.Text, Enum.TextXAlignment.Left, THEME)
	builderStatus.TextSize = 15

local builderEta = Layout.createText(builderBay, "No builder in production", UDim2.new(1, -18, 0, 18), UDim2.new(0, 10, 0, 56), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	builderEta.TextSize = 11

	local progressBack = Instance.new("Frame")
	progressBack.Size = UDim2.new(1, -20, 0, 10)
	progressBack.Position = UDim2.new(0, 10, 0, 82)
	progressBack.BackgroundColor3 = Color3.fromRGB(15, 17, 22)
	progressBack.BorderSizePixel = 0
	progressBack.Parent = builderBay
	Layout.addCorner(progressBack, UDim.new(0, 999))

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(113, 182, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	Layout.addCorner(progressFill, UDim.new(0, 999))

	local queueStrip = Instance.new("Frame")
	queueStrip.Size = UDim2.new(1, -20, 0, 52)
	queueStrip.Position = UDim2.new(0, 10, 0, 102)
	queueStrip.BackgroundTransparency = 1
	queueStrip.Parent = builderBay

	local queueLayout = Instance.new("UIListLayout")
	queueLayout.FillDirection = Enum.FillDirection.Horizontal
	queueLayout.Padding = UDim.new(0, 6)
	queueLayout.Parent = queueStrip

	local recruitButton = Instance.new("TextButton")
	recruitButton.Size = UDim2.new(1, -20, 0, 60)
	recruitButton.Position = UDim2.new(0, 10, 1, -66)
	recruitButton.BackgroundColor3 = Color3.fromRGB(43, 52, 66)
	recruitButton.BorderSizePixel = 0
	recruitButton.Text = ""
	recruitButton.Parent = builderBay
	Layout.addCorner(recruitButton, UDim.new(0, 12))
	Layout.addStroke(recruitButton, 1, Color3.fromRGB(111, 142, 187))

	local recruitIcon = Instance.new("Frame")
	recruitIcon.Size = UDim2.new(0, 42, 0, 42)
	recruitIcon.Position = UDim2.new(0, 8, 0, 7)
	recruitIcon.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
	recruitIcon.BorderSizePixel = 0
	recruitIcon.Parent = recruitButton
	Layout.addCorner(recruitIcon, UDim.new(0, 10))
	Layout.addStroke(recruitIcon, 1, Color3.fromRGB(123, 154, 208))
	Rendering.renderUnitViewport(recruitIcon, "Builder")

	local recruitTitle = Layout.createText(recruitButton, "TRAIN BUILDER", UDim2.new(1, -66, 0, 20), UDim2.new(0, 60, 0, 8), Enum.Font.GothamBold, THEME.Text, Enum.TextXAlignment.Left, THEME)
	recruitTitle.TextSize = 15

	local builderUnitData = Config.Units.Builder or {}
	local recruitMeta = Layout.createText(recruitButton, "$" .. tostring(builderUnitData.Cost or 0) .. "   " .. tostring(builderUnitData.TrainingTime or 0) .. "s", UDim2.new(1, -66, 0, 16), UDim2.new(0, 60, 0, 30), Enum.Font.GothamBold, THEME.Green, Enum.TextXAlignment.Left, THEME)
	recruitMeta.TextSize = 12

local recruitBody = Layout.createText(recruitButton, "Deploy a builder to expand your colony.", UDim2.new(1, -66, 0, 14), UDim2.new(0, 60, 0, 44), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	recruitBody.TextSize = 11

	local tuningPanel = Instance.new("Frame")
	tuningPanel.Size = UDim2.new(0.5, -16, 0, 304)
	tuningPanel.Position = UDim2.new(0.5, 4, 0, 286)
	tuningPanel.BackgroundColor3 = Color3.fromRGB(36, 28, 24)
	tuningPanel.BorderSizePixel = 0
	tuningPanel.Parent = shell
	Layout.addCorner(tuningPanel, UDim.new(0, 14))
	Layout.addStroke(tuningPanel, 1, Color3.fromRGB(161, 129, 92))

	local tuningTitle = Layout.createText(tuningPanel, "DEFENSE TUNING", UDim2.new(1, -18, 0, 18), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Color3.fromRGB(232, 191, 129), Enum.TextXAlignment.Left, THEME)
	tuningTitle.TextSize = 12

local tuningDesc = Layout.createText(tuningPanel, "Trade reach for stopping power. Retuning locks for 3 minutes.", UDim2.new(1, -18, 0, 28), UDim2.new(0, 10, 0, 34), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	tuningDesc.TextSize = 11
	tuningDesc.TextWrapped = true

	local liveStats = Layout.createText(tuningPanel, "Damage 0   Range 0", UDim2.new(1, -18, 0, 18), UDim2.new(0, 10, 0, 72), Enum.Font.GothamBold, THEME.Text, Enum.TextXAlignment.Left, THEME)
	liveStats.TextSize = 14

local cooldownText = Layout.createText(tuningPanel, "Mode available now", UDim2.new(1, -18, 0, 16), UDim2.new(0, 10, 0, 94), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	cooldownText.TextSize = 11

	local modeButtons = {}
	local buttonNames = {"Close", "Balanced", "Long"}
	for index, modeName in ipairs(buttonNames) do
		local previewDamage, previewRange, previewMode = getModeStats(modeName)
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -20, 0, 40)
		button.Position = UDim2.new(0, 10, 0, 132 + (index - 1) * 46)
		button.BackgroundColor3 = Color3.fromRGB(49, 38, 32)
		button.BorderSizePixel = 0
		button.Text = ""
		button.Parent = tuningPanel
		Layout.addCorner(button, UDim.new(0, 10))
		Layout.addStroke(button, 1, Color3.fromRGB(119, 97, 76))

		local modeLabel = Layout.createText(button, previewMode.Label, UDim2.new(0.55, -10, 1, 0), UDim2.new(0, 10, 0, 0), Enum.Font.GothamBold, THEME.Text, Enum.TextXAlignment.Left, THEME)
		modeLabel.TextSize = 12

		local modePreview = Layout.createText(button, string.format("DMG %d  RNG %d", previewDamage, previewRange), UDim2.new(0.45, -10, 1, 0), UDim2.new(0.55, 0, 0, 0), Enum.Font.GothamBold, THEME.SubText, Enum.TextXAlignment.Right, THEME)
		modePreview.TextSize = 11

		button.MouseButton1Click:Connect(function()
			HeadquartersControlEvent:FireServer("SetRangeMode", model, modeName)
		end)

		modeButtons[modeName] = {
			Button = button,
			Label = modeLabel,
			Preview = modePreview,
		}
	end

	local queueSignature = ""

	local function updateQueueStrip()
		local queue = Training.getQueue(model) or {}
		local signature = table.concat(queue, "|")
		if signature == queueSignature then
			return
		end
		queueSignature = signature

		for _, child in ipairs(queueStrip:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		if #queue == 0 then
			local empty = Layout.createText(queueStrip, "No active builder orders", UDim2.new(0, 160, 1, 0), UDim2.new(0, 0, 0, 0), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
			empty.TextSize = 11
			return
		end

		for index, queuedName in ipairs(queue) do
			local badge = Instance.new("TextButton")
			badge.Size = UDim2.new(0, 48, 0, 48)
			badge.BackgroundColor3 = Color3.fromRGB(40, 48, 60)
			badge.BorderSizePixel = 0
			badge.Text = ""
			badge.Parent = queueStrip
			Layout.addCorner(badge, UDim.new(0, 10))
			Layout.addStroke(badge, 1, Color3.fromRGB(98, 123, 164))

			local icon = Instance.new("Frame")
			icon.Size = UDim2.new(0, 34, 0, 34)
			icon.Position = UDim2.new(0, 7, 0, 7)
			icon.BackgroundColor3 = Color3.fromRGB(20, 23, 29)
			icon.BorderSizePixel = 0
			icon.Parent = badge
			Layout.addCorner(icon, UDim.new(0, 8))
			Layout.addStroke(icon, 1, Color3.fromRGB(123, 154, 208))
			Rendering.renderUnitViewport(icon, queuedName)

			local idx = Layout.createText(badge, tostring(index), UDim2.new(0, 12, 0, 12), UDim2.new(1, -14, 0, 2), Enum.Font.GothamBlack, THEME.SubText, Enum.TextXAlignment.Center, THEME)
	idx.TextSize = 11

			badge.MouseButton1Click:Connect(function()
				table.remove(queue, index)
				queueSignature = ""
				updateQueueStrip()
				UnitEvent:FireServer("CancelTrain", model, index)
			end)
		end
	end

	local function refreshHQOverview()
		if selectedBuilding ~= model then
			return
		end

		local totalBuildings, totalUnits = getOwnedWorldCounts(ownerName)
		statLabels["TOTAL BUILDINGS"].Text = tostring(totalBuildings)
		statLabels["TOTAL UNITS"].Text = tostring(totalUnits)

		local income = playerStats and playerStats:FindFirstChild("Income") and playerStats.Income.Value or 0
		statLabels["INCOME"].Text = "$+" .. tostring(income)
		statLabels["INCOME"].TextColor3 = income > 0 and THEME.Green or THEME.SubText

		local energy = playerStats and playerStats:FindFirstChild("Energy") and playerStats.Energy.Value or 0
		local maxEnergy = playerStats and playerStats:FindFirstChild("MaxEnergy") and playerStats.MaxEnergy.Value or 0
		local energyColor = energy > maxEnergy and THEME.Red or THEME.Accent
		statLabels["ENERGY"].Text = tostring(energy) .. " / " .. tostring(maxEnergy)
		statLabels["ENERGY"].TextColor3 = energyColor

		local currentSupply = playerStats and playerStats:FindFirstChild("CurrentUnits") and playerStats.CurrentUnits.Value or 0
		local unitLimit = playerStats and playerStats:FindFirstChild("UnitLimit") and playerStats.UnitLimit.Value or 0
		local supplyColor = currentSupply > unitLimit and THEME.Red or THEME.Text
		statLabels["UNITS"].Text = tostring(currentSupply) .. " / " .. tostring(unitLimit)
		statLabels["UNITS"].TextColor3 = supplyColor

		local hum = model:FindFirstChild("Humanoid")
		local hp = hum and hum.Health or (model:GetAttribute("Health") or 0)
		local maxHp = hum and hum.MaxHealth or (model:GetAttribute("MaxHealth") or 1)
		local healthPct = math.clamp((maxHp > 0 and hp / maxHp or 0), 0, 1)
		healthFill.Size = UDim2.new(healthPct, 0, 1, 0)
		healthFill.BackgroundColor3 = healthPct < 0.3 and THEME.Red or (healthPct < 0.6 and Color3.fromRGB(255, 200, 50) or THEME.Green)
		healthValue.Text = string.format("%d%%", math.floor(healthPct * 100 + 0.5))

		local activeModeName = tostring(model:GetAttribute("HQRangeMode") or "Balanced")
		local activeDamage = tonumber(model:GetAttribute("Damage") or 0) or 0
		local activeRange = tonumber(model:GetAttribute("Range") or 0) or 0
		local activeModeDef = MODE_DEFS[activeModeName] or MODE_DEFS.Balanced
		statLabels["WEAPON MODE"].Text = activeModeDef.Label
		statLabels["WEAPON MODE"].TextColor3 = Color3.fromRGB(215, 191, 132)
		liveStats.Text = string.format("Damage %d   Range %d", activeDamage, activeRange)

		local cooldownUntil = tonumber(model:GetAttribute("HQRangeCooldownUntil") or 0) or 0
		local remaining = math.max(0, cooldownUntil - workspace:GetServerTimeNow())
		if remaining > 0 then
			cooldownText.Text = "Retuning available in " .. formatDuration(remaining)
			cooldownText.TextColor3 = Color3.fromRGB(255, 206, 120)
		else
			cooldownText.Text = "Mode available now"
			cooldownText.TextColor3 = THEME.SubText
		end

		for modeName, refs in pairs(modeButtons) do
			local isActive = (modeName == activeModeName)
			local isLocked = remaining > 0
			refs.Button.AutoButtonColor = not isLocked and not isActive
			refs.Button.Active = not isLocked and not isActive
			refs.Button.BackgroundColor3 = isActive and Color3.fromRGB(92, 69, 45) or Color3.fromRGB(49, 38, 32)
			local stroke = refs.Button:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Color = isActive and Color3.fromRGB(218, 180, 116) or Color3.fromRGB(119, 97, 76)
			end
			refs.Label.TextColor3 = isLocked and THEME.SubText or THEME.Text
			refs.Preview.TextColor3 = isActive and Color3.fromRGB(232, 191, 129) or THEME.SubText
		end

		local queue = Training.getQueue(model) or {}
		local snapshot = Training.getTrainingSnapshot(model)
		updateQueueStrip()
		if #queue == 0 then
			builderStatus.Text = "Queue idle"
			builderEta.Text = "No builder in production"
			progressFill.Size = UDim2.new(0, 0, 1, 0)
		else
			builderStatus.Text = "Builder fabrication active"
			if snapshot then
				builderEta.Text = "Deployment in " .. formatDuration(snapshot.Remaining)
				progressFill.Size = UDim2.new(snapshot.Progress, 0, 1, 0)
			else
				builderEta.Text = tostring(#queue) .. " order(s) queued"
				progressFill.Size = UDim2.new(0, 0, 1, 0)
			end
		end
	end

	refreshHQOverview()
	table.insert(inspectorConnections, RunService.Heartbeat:Connect(refreshHQOverview))
	recruitButton.MouseButton1Click:Connect(function()
		UnitEvent:FireServer("Train", model, "Builder")
	end)

	if playerStats then
		for _, statName in ipairs({"Income", "Energy", "MaxEnergy", "CurrentUnits", "UnitLimit", "CanBuild"}) do
			local stat = playerStats:FindFirstChild(statName)
			if stat then
				table.insert(inspectorConnections, stat.Changed:Connect(refreshHQOverview))
			end
		end
	end

	local _, _, buildingContainer, armyContainer = getOwnedWorldCounts(ownerName)
	if buildingContainer then
		table.insert(inspectorConnections, buildingContainer.DescendantAdded:Connect(refreshHQOverview))
		table.insert(inspectorConnections, buildingContainer.DescendantRemoving:Connect(refreshHQOverview))
	end
	if armyContainer then
		table.insert(inspectorConnections, armyContainer.ChildAdded:Connect(refreshHQOverview))
		table.insert(inspectorConnections, armyContainer.ChildRemoved:Connect(refreshHQOverview))
	end
	table.insert(inspectorConnections, model:GetAttributeChangedSignal("IsUnderConstruction"):Connect(refreshHQOverview))
	table.insert(inspectorConnections, model:GetAttributeChangedSignal("IsUpgrading"):Connect(refreshHQOverview))
end

local function renderResearchCenterPanel(model, bData)
	ui.InspectorFrame.Size = UDim2.new(0, 470, 0, 670)
	ui.InspectorFrame.Position = UDim2.new(1, -490, 1, -690)
	ui.InspectorFrame.BackgroundColor3 = Color3.fromRGB(22, 24, 30)

	local inspectorStroke = ui.InspectorFrame:FindFirstChildWhichIsA("UIStroke")
	if inspectorStroke then
		inspectorStroke.Color = Color3.fromRGB(96, 100, 112)
		inspectorStroke.Thickness = 1.4
	end

	ui.InspTitle.Position = UDim2.new(0, 16, 0, 12)
	ui.InspTitle.Size = UDim2.new(1, -32, 0, 28)
	ui.InspTitle.Text = "RESEARCH CENTER"
	ui.InspTitle.TextXAlignment = Enum.TextXAlignment.Left
	ui.InspTitle.TextSize = 20
	ui.InspTitle.Visible = true

	ui.HPContainer.Position = UDim2.new(0, 16, 0, 52)
	ui.HPContainer.Size = UDim2.new(1, -32, 0, 16)
	ui.HPContainer.Visible = true

	ui.QueueLabel.Visible = false
	ui.QueueScroll.Visible = false
	ui.ActionBtn.Visible = false
	ui.UpgradeBtn.Visible = false
	ui.SellBtn.Visible = true
	ui.SellBtn.Size = UDim2.new(1, -32, 0, 42)
	ui.SellBtn.Position = UDim2.new(0, 16, 1, -58)
	ui.SellBtn.BackgroundColor3 = Color3.fromRGB(128, 59, 59)
	ui.SellBtn.Text = "SELL (+$" .. tostring(getSellActionRefundTotal()) .. ")"

	ui.TrainFrame.Position = UDim2.new(0, 12, 0, 84)
	ui.TrainFrame.Size = UDim2.new(1, -24, 1, -154)
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	ui.TrainFrame.ScrollBarThickness = 5
	ui.TrainFrame.ScrollingEnabled = true
	Training.hideQueueError()

	clearTrainFrameContent()

	local options = bData.ResearchOptions or {}
	local contentHeight = 148 + (#options * 116)
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, contentHeight)

	local content = Instance.new("Frame")
	content.Name = "ResearchContent"
	content.Size = UDim2.new(1, -4, 0, contentHeight)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Parent = ui.TrainFrame

	local hero = Instance.new("Frame")
	hero.Size = UDim2.new(1, 0, 0, 116)
	hero.BackgroundColor3 = Color3.fromRGB(28, 31, 40)
	hero.BorderSizePixel = 0
	hero.Parent = content
	Layout.addCorner(hero, UDim.new(0, 14))
	Layout.addStroke(hero, 1, Color3.fromRGB(92, 99, 114))

	local overline = Layout.createText(hero, "TECHNOLOGY DIRECTORATE", UDim2.new(1, -20, 0, 18), UDim2.new(0, 12, 0, 10), Enum.Font.GothamBold, Color3.fromRGB(173, 179, 196), Enum.TextXAlignment.Left, THEME)
	overline.TextSize = 11

	local heading = Layout.createText(hero, "RESEARCH PIPELINE", UDim2.new(1, -20, 0, 24), UDim2.new(0, 12, 0, 30), Enum.Font.GothamBlack, THEME.Text, Enum.TextXAlignment.Left, THEME)
	heading.TextSize = 22

local summary = Layout.createText(hero, "Unlock advanced units and strategic structures for your faction.", UDim2.new(1, -20, 0, 18), UDim2.new(0, 12, 0, 56), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	summary.TextSize = 12

	local statusLabel = Layout.createText(hero, "Standing by for new project", UDim2.new(1, -20, 0, 16), UDim2.new(0, 12, 0, 80), Enum.Font.GothamBold, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	statusLabel.TextSize = 12

	local progressBack = Instance.new("Frame")
	progressBack.Size = UDim2.new(1, -24, 0, 12)
	progressBack.Position = UDim2.new(0, 12, 0, 96)
	progressBack.BackgroundColor3 = Color3.fromRGB(14, 16, 20)
	progressBack.BorderSizePixel = 0
	progressBack.Parent = hero
	Layout.addCorner(progressBack, UDim.new(0, 999))

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Color3.fromRGB(110, 196, 255)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	Layout.addCorner(progressFill, UDim.new(0, 999))

	local cards = {}

	local function formatUnlockList(researchData)
		local unlocks = {}
		for _, unitName in ipairs(researchData.UnlockUnits or {}) do
			table.insert(unlocks, Rendering.formatUnitDisplayName(unitName))
		end
		for _, buildingName in ipairs(researchData.UnlockBuildings or {}) do
			table.insert(unlocks, Rendering.formatUnitDisplayName(buildingName))
		end
		return #unlocks > 0 and table.concat(unlocks, ", ") or "Future tech slot"
	end

	for index, researchId in ipairs(options) do
		local researchData = Config.Research[researchId]
		if researchData then
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, 0, 0, 102)
			card.Position = UDim2.new(0, 0, 0, 132 + (index - 1) * 116)
			card.BackgroundColor3 = Color3.fromRGB(30, 33, 42)
			card.BorderSizePixel = 0
			card.Parent = content
			Layout.addCorner(card, UDim.new(0, 12))
			Layout.addStroke(card, 1, Color3.fromRGB(79, 83, 95))

			local title = Layout.createText(card, tostring(researchData.DisplayName or researchId), UDim2.new(1, -156, 0, 24), UDim2.new(0, 12, 0, 10), Enum.Font.GothamBlack, THEME.Text, Enum.TextXAlignment.Left, THEME)
			title.TextSize = 18

			local meta = Layout.createText(card, "$" .. tostring(researchData.Cost or 0) .. "   " .. formatClockDuration(researchData.ResearchTime or 0), UDim2.new(1, -156, 0, 16), UDim2.new(0, 12, 0, 36), Enum.Font.GothamBold, THEME.Green, Enum.TextXAlignment.Left, THEME)
			meta.TextSize = 12

local body = Layout.createText(card, tostring(researchData.Description or ""), UDim2.new(1, -24, 0, 18), UDim2.new(0, 12, 0, 58), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
			body.TextSize = 11
			body.TextWrapped = true

local unlocks = Layout.createText(card, "Unlocks: " .. formatUnlockList(researchData), UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 78), Enum.Font.GothamMedium, Color3.fromRGB(190, 194, 204), Enum.TextXAlignment.Left, THEME)
	unlocks.TextSize = 11
			unlocks.TextWrapped = true

			local actionButton = Instance.new("TextButton")
			actionButton.Size = UDim2.new(0, 128, 0, 42)
			actionButton.Position = UDim2.new(1, -140, 0.5, -21)
			actionButton.BackgroundColor3 = Color3.fromRGB(56, 62, 74)
			actionButton.BorderSizePixel = 0
			actionButton.TextColor3 = THEME.Text
			actionButton.Font = Enum.Font.GothamBold
			actionButton.TextSize = 12
			actionButton.Parent = card
			Layout.addCorner(actionButton, UDim.new(0, 999))
			Layout.addStroke(actionButton, 1, Color3.fromRGB(98, 104, 120))

			actionButton.MouseButton1Click:Connect(function()
				ResearchEvent:FireServer("Start", model, researchId)
			end)

			cards[researchId] = {
				Button = actionButton,
				Card = card,
				Title = title,
				Meta = meta,
			}
		end
	end

	local function refreshResearchPanel()
		if selectedBuilding ~= model then
			return
		end

		local activeId = tostring(player:GetAttribute("ActiveResearchId") or "")
		local startedAt = tonumber(player:GetAttribute("ActiveResearchStartedAt") or 0) or 0
		local endsAt = tonumber(player:GetAttribute("ActiveResearchEndsAt") or 0) or 0
		local now = workspace:GetServerTimeNow()
		local hasActive = activeId ~= "" and endsAt > now and Config.Research[activeId] ~= nil

		if hasActive then
			local duration = math.max(0.001, endsAt - startedAt)
			local remaining = math.max(0, endsAt - now)
			local progress = math.clamp((now - startedAt) / duration, 0, 1)
			progressFill.Size = UDim2.new(progress, 0, 1, 0)
			statusLabel.Text = getResearchDisplayName(activeId) .. " underway - ETA " .. formatClockDuration(remaining)
			statusLabel.TextColor3 = THEME.Text
		else
			progressFill.Size = UDim2.new(0, 0, 1, 0)
			statusLabel.Text = "Standing by for new project"
			statusLabel.TextColor3 = THEME.SubText
		end

		for researchId, refs in pairs(cards) do
			local researchData = Config.Research[researchId]
			local completed = player:GetAttribute("Research_" .. researchId) == true
			local isActive = hasActive and activeId == researchId
			local button = refs.Button
			local stroke = refs.Card:FindFirstChildWhichIsA("UIStroke")

			if completed then
				button.Text = "COMPLETED"
				button.BackgroundColor3 = Color3.fromRGB(52, 92, 62)
				button.TextColor3 = Color3.fromRGB(225, 255, 228)
				button.AutoButtonColor = false
				button.Active = false
				if stroke then
					stroke.Color = Color3.fromRGB(86, 155, 102)
				end
			elseif isActive then
				local remaining = math.max(0, endsAt - now)
				button.Text = "IN PROGRESS\n" .. formatClockDuration(remaining)
				button.BackgroundColor3 = Color3.fromRGB(52, 74, 102)
				button.TextColor3 = THEME.Text
				button.AutoButtonColor = false
				button.Active = false
				if stroke then
					stroke.Color = Color3.fromRGB(98, 146, 210)
				end
			elseif hasActive then
				button.Text = "QUEUE BUSY"
				button.BackgroundColor3 = Color3.fromRGB(53, 56, 64)
				button.TextColor3 = THEME.SubText
				button.AutoButtonColor = false
				button.Active = false
				if stroke then
					stroke.Color = Color3.fromRGB(79, 83, 95)
				end
			else
				button.Text = "RESEARCH"
				button.BackgroundColor3 = Color3.fromRGB(82, 88, 102)
				button.TextColor3 = THEME.Text
				button.AutoButtonColor = true
				button.Active = true
				if stroke then
					stroke.Color = Color3.fromRGB(79, 83, 95)
				end
			end

			if researchData then
				refs.Meta.Text = "$" .. tostring(researchData.Cost or 0) .. "   " .. formatClockDuration(researchData.ResearchTime or 0)
			end
		end

		ui.SellBtn.Text = "SELL (+$" .. tostring(getSellActionRefundTotal()) .. ")"
	end

	refreshResearchPanel()
	table.insert(inspectorConnections, RunService.Heartbeat:Connect(refreshResearchPanel))
	for researchId in pairs(Config.Research) do
		table.insert(inspectorConnections, player:GetAttributeChangedSignal("Research_" .. researchId):Connect(refreshResearchPanel))
	end
	table.insert(inspectorConnections, player:GetAttributeChangedSignal("ActiveResearchId"):Connect(refreshResearchPanel))
	table.insert(inspectorConnections, player:GetAttributeChangedSignal("ActiveResearchStartedAt"):Connect(refreshResearchPanel))
	table.insert(inspectorConnections, player:GetAttributeChangedSignal("ActiveResearchEndsAt"):Connect(refreshResearchPanel))
end

local function renderOwnedInfo(model, bData)
	ui.TrainFrame.Position = CONSTANTS.TRAIN_POS_INFO
	ui.TrainFrame.Size = CONSTANTS.TRAIN_SIZE_INFO
	ui.QueueLabel.Text = "INFORMATION"
	ui.QueueLabel.Visible = true
	ui.QueueScroll.Visible = false
	Training.hideQueueError()

	local title = Layout.createText(ui.TrainFrame, "INFORMATION", UDim2.new(1, -8, 0, 26), UDim2.new(0, 0, 0, 0), Enum.Font.GothamBlack, THEME.Text, Enum.TextXAlignment.Left, THEME)
	title.TextSize = 16

local desc = Layout.createText(ui.TrainFrame, tostring(bData and bData.Description or "No description."), UDim2.new(1, -8, 0, 42), UDim2.new(0, 0, 0, 30), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	desc.TextSize = 12
	desc.TextWrapped = true
	desc.TextYAlignment = Enum.TextYAlignment.Top

	local power = tonumber(bData and bData.Energy or 0) or 0
	local income = tonumber(bData and bData.Income or 0) or 0
	local cap = tonumber(bData and bData.UnitLimit or 0) or 0
	local hp = tonumber(bData and bData.Health or 0) or 0
	local damage = tonumber(bData and bData.Damage or 0) or 0
	local range = tonumber(bData and (bData.Range or bData.HealRange) or 0) or 0
	local healRate = tonumber(bData and bData.HealRate or 0) or 0

	local powerLabel
	local powerColor
	if power > 0 then
		powerLabel = "+" .. tostring(power) .. " OUTPUT"
		powerColor = THEME.Green
	elseif power < 0 then
		powerLabel = "-" .. tostring(math.abs(power)) .. " USAGE"
		powerColor = Color3.fromRGB(255, 200, 95)
	else
		powerLabel = "0"
		powerColor = THEME.SubText
	end

	Rendering.createInfoRow(ui.TrainFrame, "INCOME", "$+" .. tostring(income), income > 0 and THEME.Green or THEME.SubText)
	Rendering.createInfoRow(ui.TrainFrame, "POWER", powerLabel, powerColor)
	Rendering.createInfoRow(ui.TrainFrame, "UNIT CAPACITY", "+" .. tostring(cap), cap > 0 and THEME.Accent or THEME.SubText)
	Rendering.createInfoRow(ui.TrainFrame, "MAX HP", tostring(hp), THEME.Text)
	if damage > 0 then
		Rendering.createInfoRow(ui.TrainFrame, "DAMAGE", tostring(damage), Color3.fromRGB(255, 170, 170))
	end
	if range > 0 then
		local rangeLabel = healRate > 0 and "HEAL RANGE" or "RANGE"
		local rangeColor = healRate > 0 and Color3.fromRGB(90, 230, 120) or THEME.Accent
		Rendering.createInfoRow(ui.TrainFrame, rangeLabel, tostring(range), rangeColor)
	end
	if healRate > 0 then
		Rendering.createInfoRow(ui.TrainFrame, "HEAL PER PULSE", tostring(healRate), Color3.fromRGB(90, 230, 120))
	end

	local statusText = "ACTIVE"
	local statusColor = THEME.Green
	if model:GetAttribute("IsUnderConstruction") then
		statusText = "UNDER CONSTRUCTION"
		statusColor = Color3.fromRGB(255, 200, 95)
	elseif model:GetAttribute("IsUpgrading") then
		statusText = "UPGRADING"
		statusColor = THEME.Accent
	end
	Rendering.createInfoRow(ui.TrainFrame, "STATUS", statusText, statusColor)
end

local function renderOwnedSelectionSummary(buildings, totalRefund, totalUpgradeCost, upgradableCount)
	ui.TrainFrame.Position = CONSTANTS.TRAIN_POS_INFO
	ui.TrainFrame.Size = CONSTANTS.TRAIN_SIZE_INFO
	ui.QueueLabel.Text = "SELECTION"
	ui.QueueLabel.Visible = true
	ui.QueueScroll.Visible = false
	Training.hideQueueError()

	local summary = summarizeSelectedBuildings(buildings)
	local headingText = summary.SameType and (string.upper(Rendering.formatUnitDisplayName(summary.TypeName)) .. " x" .. tostring(summary.Count)) or (tostring(summary.Count) .. " BUILDINGS SELECTED")

	local title = Layout.createText(ui.TrainFrame, "SELECTION OVERVIEW", UDim2.new(1, -8, 0, 26), UDim2.new(0, 0, 0, 0), Enum.Font.GothamBlack, THEME.Text, Enum.TextXAlignment.Left, THEME)
	title.TextSize = 16

	local desc = Layout.createText(ui.TrainFrame, headingText, UDim2.new(1, -8, 0, 24), UDim2.new(0, 0, 0, 30), Enum.Font.GothamBold, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	desc.TextSize = 13

	local breakdown = {}
	for buildingType, count in pairs(summary.CountsByType) do
		table.insert(breakdown, {Type = buildingType, Count = count})
	end
	table.sort(breakdown, function(a, b)
		if a.Count == b.Count then
			return a.Type < b.Type
		end
		return a.Count > b.Count
	end)

	local breakdownLines = {}
	for i = 1, math.min(4, #breakdown) do
		local entry = breakdown[i]
		table.insert(breakdownLines, string.format("%s x%d", Rendering.formatUnitDisplayName(entry.Type), entry.Count))
	end
	if #breakdown > 4 then
		table.insert(breakdownLines, "+" .. tostring(#breakdown - 4) .. " more types")
	end

local breakdownLabel = Layout.createText(ui.TrainFrame, table.concat(breakdownLines, "\n"), UDim2.new(1, -8, 0, 52), UDim2.new(0, 0, 0, 58), Enum.Font.GothamMedium, THEME.SubText, Enum.TextXAlignment.Left, THEME)
	breakdownLabel.TextSize = 12
	breakdownLabel.TextYAlignment = Enum.TextYAlignment.Top

	Rendering.createInfoRow(ui.TrainFrame, "TOTAL SELECTED", tostring(summary.Count), THEME.Text)
	Rendering.createInfoRow(ui.TrainFrame, "UPGRADABLE", tostring(upgradableCount), upgradableCount > 0 and THEME.Accent or THEME.SubText)
	Rendering.createInfoRow(ui.TrainFrame, "SELL REFUND", "$" .. tostring(totalRefund), totalRefund > 0 and THEME.Green or THEME.SubText)
	Rendering.createInfoRow(ui.TrainFrame, "UPGRADE COST", "$" .. tostring(totalUpgradeCost), totalUpgradeCost > 0 and THEME.Text or THEME.SubText)
end

function getSellActionRefundTotal()
	local total = 0
	for _, building in ipairs(sellActionTargets) do
		total += Training.getSellRefund(building)
	end
	if total <= 0 and selectedBuilding then
		total = Training.getSellRefund(selectedBuilding)
	end
	return total
end

local function renderRecruitButtons(model, bType, bData)
	if Production.renderProductionHub(model, bType, bData, {
		ui = ui,
		clearTrainFrameContent = clearTrainFrameContent,
		getSelectedBuilding = function()
			return selectedBuilding
		end,
		getSellActionRefundTotal = getSellActionRefundTotal,
		addInspectorConnection = function(conn)
			table.insert(inspectorConnections, conn)
		end,
	}) then
		return
	end

	ui.TrainFrame.Position = CONSTANTS.TRAIN_POS_WITH_QUEUE
	ui.TrainFrame.Size = CONSTANTS.TRAIN_SIZE_WITH_QUEUE
	ui.QueueLabel.Text = "TRAINING QUEUE"
	ui.QueueLabel.TextColor3 = THEME.SubText
	ui.QueueLabel.Visible = true
	ui.QueueScroll.Visible = true
	ui.QueueScroll.Position = UDim2.new(0, 10, 0, 143)
	ui.QueueScroll.Size = UDim2.new(1, -20, 0, 60)
	Training.hideQueueError()

	Training.ensureQueue(model)
	Training.refreshQueueUI(ui.QueueScroll, model, queueRenderHelpers())

	local recruitOptions = Training.getRecruitOptionsForBuilding(bType)
	if #recruitOptions == 0 then
		for _, unitName in ipairs(bData.CanRecruit or {}) do
			table.insert(recruitOptions, { Name = unitName, UnlockDepth = 0 })
		end
	end

	for _, entry in ipairs(recruitOptions) do
		local unitName = entry.Name
		local unlockDepth = entry.UnlockDepth or 0
		local uData = Config.Units[unitName]
		if uData then
			local researchRequired = uData.ResearchRequired
			local isResearchLocked = researchRequired and not isResearchUnlocked(researchRequired)
			local isLocked = unlockDepth > 0 or isResearchLocked
			local btn = Instance.new("TextButton", ui.TrainFrame)
			btn.Size = UDim2.new(1, -10, 0, 52)
			btn.BackgroundColor3 = isLocked and Color3.fromRGB(33, 33, 38) or THEME.Panel
			btn.Text = ""
			btn.AutoButtonColor = not isLocked
			Layout.addCorner(btn, THEME.Corner)
			Layout.addStroke(btn, 1, THEME.Stroke)

			local icon = Instance.new("Frame", btn)
			icon.Size = UDim2.new(0, 40, 0, 40)
			icon.Position = UDim2.new(0, 6, 0, 6)
			icon.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
			icon.BorderSizePixel = 0
			Layout.addCorner(icon, UDim.new(0, 8))
			Layout.addStroke(icon, 1, isLocked and Color3.fromRGB(130, 130, 140) or Rendering.getClassColor(uData.Class))
			Rendering.renderUnitViewport(icon, unitName)
			icon.BackgroundTransparency = isLocked and 0.25 or 0

			local titlePrefix = isLocked and "PREVIEW " or "TRAIN "
			Layout.createText(btn, titlePrefix .. string.upper(unitName), UDim2.new(1, -60, 0, 20), UDim2.new(0, 52, 0, 5), Enum.Font.GothamBold, isLocked and THEME.SubText or THEME.Text, Enum.TextXAlignment.Left, THEME).TextSize = 14

			local line2Text
			local line2Color
			if isResearchLocked then
				line2Text = "REQUIRES " .. getResearchDisplayName(researchRequired)
				line2Color = Color3.fromRGB(150, 190, 255)
			elseif isLocked then
				line2Text = "UNLOCKS AFTER +" .. tostring(unlockDepth) .. " UPGRADE"
				line2Color = Color3.fromRGB(255, 190, 130)
			else
				line2Text = "$" .. tostring(uData.Cost or 0) .. " | " .. tostring(uData.TrainingTime or 0) .. "s"
				line2Color = THEME.Green
			end
			Layout.createText(btn, line2Text, UDim2.new(1, -60, 0, 16), UDim2.new(0, 52, 0, 27), Enum.Font.GothamMedium, line2Color, Enum.TextXAlignment.Left, THEME).TextSize = 12

			btn.MouseButton1Click:Connect(function()
				if isResearchLocked then
					Training.showQueueError("Requires research: " .. getResearchDisplayName(researchRequired))
					return
				end
				if unlockDepth > 0 then
					Training.showQueueError("Upgrade building to unlock " .. unitName)
					return
				end
				UnitEvent:FireServer("Train", model, unitName)
			end)

			btn.MouseEnter:Connect(function()
				local lockHint = nil
				if isResearchLocked then
					lockHint = "Locked: requires " .. getResearchDisplayName(researchRequired)
				elseif unlockDepth > 0 then
					lockHint = "Locked: unlock after +" .. tostring(unlockDepth) .. " upgrade"
				end
				Rendering.showUnitTooltip(unitName, uData, unlockDepth, isLocked, lockHint)
			end)
			btn.MouseLeave:Connect(function()
				Rendering.hideUnitTooltip()
			end)
		end
	end
end

function UIInspector.init(mainScreen, gameFrame)
	ui = Layout.createBaseUI(mainScreen, gameFrame, THEME, CONSTANTS)

	Rendering.init({
		theme = THEME,
		unitsFolder = UnitsFolder,
		createText = Layout.createText,
		addCorner = Layout.addCorner,
		addStroke = Layout.addStroke,
		runService = RunService,
		userInputService = UserInputService,
		mainScreen = mainScreen,
	})

	Training.init({
		Config = Config,
		UnitEvent = UnitEvent,
		RunService = RunService,
		Theme = THEME,
		getSelectedBuilding = function()
			return selectedBuilding
		end,
		refreshSelectedQueue = refreshSelectedQueueUI,
		queueErrorLabel = ui.QueueErrorFrame,
	})

	Targeting.init({
		player = player,
		Config = Config,
		RunService = RunService,
		UserInputService = UserInputService,
		Training = Training,
		MissileSiloEvent = MissileSiloEvent,
	})

	SuperWeapons.init({
		Config = Config,
		UnitEvent = UnitEvent,
		Training = Training,
		Layout = Layout,
		Rendering = Rendering,
		RunService = RunService,
		Theme = THEME,
	})

	Production.init({
		Config = Config,
		UnitEvent = UnitEvent,
		Training = Training,
		Layout = Layout,
		Rendering = Rendering,
		RunService = RunService,
		Theme = THEME,
		UIStyle = UIStyle,
	})

	Panels.init({
		Config = Config,
		Layout = Layout,
		Rendering = Rendering,
		Training = Training,
		Theme = THEME,
		RunService = RunService,
		HeadquartersControlEvent = HeadquartersControlEvent,
		ResearchEvent = ResearchEvent,
		UnitEvent = UnitEvent,
		player = player,
	})

	ResearchEvent.OnClientEvent:Connect(function(action, payload)
		if action == "Error" and payload then
			ui.QueueErrorFrame.TextColor3 = THEME.Red
			Training.showQueueError(payload)
		elseif action == "Completed" and payload then
			ui.QueueErrorFrame.TextColor3 = THEME.Green
			Training.showQueueError(payload)
			task.delay(2.6, function()
				if ui and ui.QueueErrorFrame then
					ui.QueueErrorFrame.TextColor3 = THEME.Red
				end
			end)
		end
	end)

	ui.SellBtn.MouseButton1Click:Connect(function()
		if not selectedBuilding then
			return
		end
		local targets = sellActionTargets
		if #targets > 0 then
			for _, b in ipairs(targets) do
				SellEvent:FireServer(b)
			end
		else
			SellEvent:FireServer(selectedBuilding)
		end
		UIInspector.closeInspector()
	end)

	ui.UpgradeBtn.MouseButton1Click:Connect(function()
		if not selectedBuilding then
			return
		end
		local targets = upgradeActionTargets
		if #targets > 1 then
			UpgradeEvent:FireServer(targets)
		elseif #targets == 1 then
			UpgradeEvent:FireServer(targets[1])
		else
			UpgradeEvent:FireServer(selectedBuilding)
		end
		UIInspector.closeInspector()
	end)

	ui.ActionBtn.MouseButton1Click:Connect(function()
		if selectedBuilding and selectedBuilding:GetAttribute("Type") == "MissileSilo" then
			if (selectedBuilding:GetAttribute("StoredMissiles") or 0) > 0 then
				Targeting.startMissileTargeting(selectedBuilding)
			end
		end
	end)
end

function UIInspector.openInspector(model)
	if not ui or not model then
		return
	end

	disconnectInspectorSignals()
	Selection.destroySelectionVisuals(selectionVisuals)
	selectionVisuals = nil

	selectedBuilding = model
	Rendering.hideUnitTooltip()
	Targeting.destroyMissileTargeting()
	Training.hideQueueError()

	ui.InspectorFrame.Visible = true
	resetInspectorLayout()
	clearTrainFrameContent()

	local owner = model:GetAttribute("Owner")
	local isOwned = (owner == player.Name)
	local isAllied = Selection.isOwnerAllied(owner, model, player)
	local relationColor = isOwned and Color3.fromRGB(255, 255, 255) or (isAllied and THEME.BlueWarm or THEME.Red)
	ui.SellBtn.Visible = isOwned
	ui.ActionBtn.Visible = false
	ui.SpecialStatusLabel.Visible = false

	sellActionTargets = {}
	upgradeActionTargets = {}

	local selectedOwned = collectOwnedSelectedBuildings()
	local selectedSummary = summarizeSelectedBuildings(selectedOwned)
	if #selectedOwned > 0 then
		sellActionTargets = selectedOwned
	elseif isOwned then
		table.insert(sellActionTargets, model)
	end

	local totalRefund = 0
	local totalUpgradeCost = 0
	for _, b in ipairs(sellActionTargets) do
		totalRefund += Training.getSellRefund(b)
		if Training.canUpgradeBuilding(b) then
			table.insert(upgradeActionTargets, b)
			local d = Config.Buildings[b:GetAttribute("Type")]
			totalUpgradeCost += (d and d.UpgradeCost or 0)
		end
	end

	if isOwned and selectedSummary.Count > 1 then
		if selectedSummary.SameType then
			ui.InspTitle.Text = string.upper(Rendering.formatUnitDisplayName(selectedSummary.TypeName)) .. " x" .. tostring(selectedSummary.Count)
		else
			ui.InspTitle.Text = tostring(selectedSummary.Count) .. " BUILDINGS SELECTED"
		end
	else
		ui.InspTitle.Text = string.upper(model.Name)
	end

	ui.SellBtn.Text = (#sellActionTargets > 1 and "SELL BUILDINGS (+$" or "SELL BUILDING (+$") .. totalRefund .. ")"
	if #upgradeActionTargets > 1 then
		ui.UpgradeBtn.Text = "UPGRADE BUILDINGS ($" .. totalUpgradeCost .. ")"
	elseif #upgradeActionTargets == 1 then
		ui.UpgradeBtn.Text = "UPGRADE ($" .. totalUpgradeCost .. ")"
	else
		ui.UpgradeBtn.Text = "UPGRADE"
	end
	ui.UpgradeBtn.Visible = isOwned and (#upgradeActionTargets > 0)

	local bType = model:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	local healRange = tonumber(bData and bData.HealRange or 0) or 0
	local rangeColor = healRange > 0 and Color3.fromRGB(90, 230, 120) or relationColor

	if isOwned and bData and (bData.CanRecruit or bType == "ResearchCenter") then
		for researchId in pairs(Config.Research) do
			table.insert(inspectorConnections, player:GetAttributeChangedSignal("Research_" .. researchId):Connect(function()
				if selectedBuilding == model then
					UIInspector.openInspector(model)
				end
			end))
		end
	end

	if bData and bData.Capacity then
		local count = model:GetAttribute("GarrisonCount") or 0
		ui.GarrisonLabel.Text = "GARRISON: " .. count .. "/" .. bData.Capacity
		ui.GarrisonLabel.Visible = true
		table.insert(inspectorConnections, model:GetAttributeChangedSignal("GarrisonCount"):Connect(function()
			if selectedBuilding ~= model then
				return
			end
			local newCount = model:GetAttribute("GarrisonCount") or 0
			ui.GarrisonLabel.Text = "GARRISON: " .. newCount .. "/" .. bData.Capacity
			local dynamicRange = (newCount > 0 and (bData.RangeGarrisoned or bData.Range) or bData.RangeEmpty or 0)
			model:SetAttribute("Range", dynamicRange)
		end))
	else
		ui.GarrisonLabel.Visible = false
	end

	local selectedByMulti = UIMultiSelect.hasBuilding and UIMultiSelect.hasBuilding(model)
	selectionVisuals = Selection.createSelectionVisuals(model, bData, selectedByMulti, relationColor, rangeColor)

	if not isOwned then
		ui.InspectorFrame.Size = CONSTANTS.INSPECTOR_SIZE_COMPACT
		ui.InspectorFrame.Position = CONSTANTS.INSPECTOR_POS_COMPACT
		ui.GarrisonLabel.Visible = false
		ui.QueueLabel.Visible = false
		ui.QueueScroll.Visible = false
		ui.TrainFrame.Visible = false
		ui.SellBtn.Visible = false
		ui.UpgradeBtn.Visible = false
		ui.RelationshipLabel.Visible = true
		ui.RelationshipLabel.Text = isAllied and "ALLIED BUILDING" or "ENEMY BUILDING"
		ui.RelationshipLabel.TextColor3 = isAllied and THEME.BlueWarm or THEME.Red
	elseif selectedSummary.Count > 1 then
		Panels.renderOwnedSelectionSummary(selectedOwned, totalRefund, totalUpgradeCost, #upgradeActionTargets, {
			ui = ui,
			clearTrainFrameContent = clearTrainFrameContent,
			summarizeSelectedBuildings = summarizeSelectedBuildings,
		})
	elseif (bType == "Headquarters" or bType == "HeadquartersL2") and bData then
		Panels.renderHeadquartersPanel(model, bData, {
			ui = ui,
			clearTrainFrameContent = clearTrainFrameContent,
			getSelectedBuilding = function()
				return selectedBuilding
			end,
			addInspectorConnection = function(conn)
				table.insert(inspectorConnections, conn)
			end,
			getOwnerPlayer = getOwnerPlayer,
			getOwnedWorldCounts = getOwnedWorldCounts,
		})
	elseif bType == "ResearchCenter" and bData and not model:GetAttribute("IsUnderConstruction") and not model:GetAttribute("IsUpgrading") then
		Panels.renderResearchCenterPanel(model, bData, {
			ui = ui,
			clearTrainFrameContent = clearTrainFrameContent,
			getSelectedBuilding = function()
				return selectedBuilding
			end,
			addInspectorConnection = function(conn)
				table.insert(inspectorConnections, conn)
			end,
			getSellActionRefundTotal = getSellActionRefundTotal,
		})
	elseif bType == "MissileSilo" and bData and not model:GetAttribute("IsUnderConstruction") and not model:GetAttribute("IsUpgrading") then
		SuperWeapons.renderMissileSiloPanel(model, bData, {
			ui = ui,
			clearTrainFrameContent = clearTrainFrameContent,
			getSelectedBuilding = function()
				return selectedBuilding
			end,
			addInspectorConnection = function(conn)
				table.insert(inspectorConnections, conn)
			end,
			startMissileTargeting = Targeting.startMissileTargeting,
		})
	elseif bData and bData.CanRecruit and not model:GetAttribute("IsUnderConstruction") and not model:GetAttribute("IsUpgrading") then
		renderRecruitButtons(model, bType, bData)
	else
		Panels.renderOwnedInfo(model, bData, {
			ui = ui,
			clearTrainFrameContent = clearTrainFrameContent,
			getSelectedBuilding = function()
				return selectedBuilding
			end,
			addInspectorConnection = function(conn)
				table.insert(inspectorConnections, conn)
			end,
			getSellActionRefundTotal = getSellActionRefundTotal,
			canUpgrade = isOwned and (#upgradeActionTargets > 0),
		})
	end

	applyHPBinding(model)
end

function UIInspector.closeInspector()
	if not ui then
		return
	end

	ui.InspectorFrame.Visible = false
	resetInspectorLayout()
	Training.hideQueueError()
	Targeting.destroyMissileTargeting()
	Rendering.hideUnitTooltip()

	disconnectInspectorSignals()
	Selection.destroySelectionVisuals(selectionVisuals)
	selectionVisuals = nil

	selectedBuilding = nil
end

function UIInspector.getSelectedBuilding()
	return selectedBuilding
end

function UIInspector.isPointerOverInspector()
	if not ui or not ui.InspectorFrame or not ui.InspectorFrame.Visible then
		return false
	end
	local mousePos = UserInputService:GetMouseLocation()
	local framePos = ui.InspectorFrame.AbsolutePosition
	local frameSize = ui.InspectorFrame.AbsoluteSize
	return mousePos.X >= framePos.X
		and mousePos.X <= framePos.X + frameSize.X
		and mousePos.Y >= framePos.Y
		and mousePos.Y <= framePos.Y + frameSize.Y
end

function UIInspector.isMissileTargeting()
	return Targeting.isMissileTargeting()
end

return UIInspector
























