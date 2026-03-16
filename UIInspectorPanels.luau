local module = {}

local Config
local Layout
local Rendering
local Training
local Theme
local RunService
local HeadquartersControlEvent
local ResearchEvent
local UnitEvent
local player

local function formatDuration(seconds)
	seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	if minutes > 0 then
		return string.format("%dm %02ds", minutes, remainder)
	end
	return string.format("%ds", remainder)
end

local function clearBody(ui, context)
	context.clearTrainFrameContent()
	ui.QueueLabel.Visible = false
	ui.QueueScroll.Visible = false
	ui.SpecialStatusLabel.Visible = false
	ui.ActionBtn.Visible = false
	ui.InspTitle.Visible = false
	ui.HPContainer.Visible = false
	ui.TrainFrame.Position = UDim2.new(0, 10, 0, 10)
	ui.TrainFrame.Size = UDim2.new(1, -20, 1, -20)
	ui.TrainFrame.ScrollBarThickness = 0
	ui.TrainFrame.ScrollingEnabled = false
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	Training.hideQueueError()
end

local function createShell(ui, size, position, contentHeight)
	ui.InspectorFrame.Size = size
	ui.InspectorFrame.Position = position
	ui.InspectorFrame.BackgroundColor3 = Theme.Background
	ui.InspectorFrame.BackgroundTransparency = 0
	local inspectorStroke = ui.InspectorFrame:FindFirstChildWhichIsA("UIStroke")
	if inspectorStroke then
		inspectorStroke.Color = Theme.Stroke
		inspectorStroke.Thickness = 1
		inspectorStroke.Transparency = 0
	end

	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, 0, 0, contentHeight)
	shell.BackgroundTransparency = 1
	shell.BorderSizePixel = 0
	shell.Parent = ui.TrainFrame

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 60)
	header.BackgroundTransparency = 1
	header.BorderSizePixel = 0
	header.Parent = shell

	return shell, header
end

local function createHeader(header, eyebrowText, titleText, subtitleText)
	local eyebrow = Layout.createText(header, eyebrowText, UDim2.new(1, -20, 0, 14), UDim2.new(0, 0, 0, 0), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	eyebrow.TextSize = 11

	local title = Layout.createText(header, titleText, UDim2.new(1, -20, 0, 24), UDim2.new(0, 0, 0, 16), Enum.Font.GothamBlack, Theme.Text, Enum.TextXAlignment.Left, Theme)
	title.TextSize = 20

	local subtitle = Layout.createText(header, subtitleText, UDim2.new(1, -20, 0, 14), UDim2.new(0, 0, 0, 40), Enum.Font.GothamMedium, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	subtitle.TextSize = 12

	return eyebrow, title, subtitle
end

local function createHealthStrip(parent, position)
	local label = Layout.createText(parent, "STRUCTURE", UDim2.new(0.3, 0, 0, 14), position, Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	label.TextSize = 11

	local barBack = Instance.new("Frame")
	barBack.Size = UDim2.new(0.7, -76, 0, 10)
	barBack.Position = UDim2.new(0.3, 8, position.Y.Scale, position.Y.Offset + 2)
	barBack.BackgroundColor3 = Theme.Inset
	barBack.BorderSizePixel = 0
	barBack.Parent = parent
	Layout.addCorner(barBack, UDim.new(0, 2))
	Layout.addStroke(barBack, 1, Theme.Stroke)

	local barFill = Instance.new("Frame")
	barFill.Size = UDim2.new(1, 0, 1, 0)
	barFill.BackgroundColor3 = Theme.Positive
	barFill.BorderSizePixel = 0
	barFill.Parent = barBack
	Layout.addCorner(barFill, UDim.new(0, 2))

	local value = Layout.createText(parent, "100%", UDim2.new(0, 54, 0, 14), UDim2.new(1, -60, position.Y.Scale, position.Y.Offset), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Right, Theme)
	value.TextSize = 11

	return barFill, value
end

local function createMetricCell(parent, position, size, titleText)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Theme.Panel
	frame.BorderSizePixel = 0
	frame.Parent = parent
	Layout.addCorner(frame, UDim.new(0, 3))
	Layout.addStroke(frame, 1, Theme.Stroke)

	local title = Layout.createText(frame, titleText, UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 8), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	title.TextSize = 11

	local value = Layout.createText(frame, "-", UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 24), Enum.Font.GothamBlack, Theme.Text, Enum.TextXAlignment.Left, Theme)
	value.TextSize = 16

	return frame, value
end

local function getResearchUnlockSummary(researchData)
	if not researchData then
		return "No unlock data"
	end

	local items = {}
	for _, unitName in ipairs(researchData.UnlockUnits or {}) do
		table.insert(items, tostring(unitName))
	end
	for _, buildingName in ipairs(researchData.UnlockBuildings or {}) do
		table.insert(items, tostring(buildingName))
	end
	if #items == 0 then
		return tostring(researchData.Description or "No unlock data")
	end
	return "Unlocks: " .. table.concat(items, ", ")
end

function module.init(options)
	Config = options.Config
	Layout = options.Layout
	Rendering = options.Rendering
	Training = options.Training
	Theme = options.Theme
	RunService = options.RunService
	HeadquartersControlEvent = options.HeadquartersControlEvent
	ResearchEvent = options.ResearchEvent
	UnitEvent = options.UnitEvent
	player = options.player
end

function module.renderOwnedInfo(model, bData, context)
	local ui = context.ui
	clearBody(ui, context)
	ui.TrainFrame.Visible = false
	ui.InspTitle.Visible = true
	ui.HPContainer.Visible = true
	ui.InspTitle.Text = string.upper(Rendering.formatUnitDisplayName(model:GetAttribute("Type") or model.Name))
	ui.InspTitle.Position = UDim2.new(0, 14, 0, 10)
	ui.InspTitle.Size = UDim2.new(1, -28, 0, 24)
	ui.InspTitle.TextXAlignment = Enum.TextXAlignment.Left
	ui.InspTitle.TextSize = 20
	ui.HPContainer.Position = UDim2.new(0, 14, 0, 42)
	ui.HPContainer.Size = UDim2.new(1, -28, 0, 14)
	ui.SellBtn.Visible = true
	ui.UpgradeBtn.Visible = context.canUpgrade
	ui.SellBtn.Text = "SELL (+$" .. tostring(context.getSellActionRefundTotal()) .. ")"
	ui.InspectorFrame.Size = UDim2.new(0, 380, 0, 160)
	ui.InspectorFrame.Position = UDim2.new(1, -400, 1, -180)

	if context.canUpgrade then
		ui.SellBtn.Size = UDim2.new(0.25, 0, 0, 36)
		ui.SellBtn.Position = UDim2.new(0.24, -8, 1, -48)
		ui.UpgradeBtn.Size = UDim2.new(0.25, 0, 0, 36)
		ui.UpgradeBtn.Position = UDim2.new(0.51, 8, 1, -48)
	else
		ui.SellBtn.Size = UDim2.new(0.28, 0, 0, 36)
		ui.SellBtn.Position = UDim2.new(0.36, 0, 1, -48)
	end

	local function refresh()
		if context.getSelectedBuilding() ~= model then
			return
		end

		local hum = model:FindFirstChild("Humanoid")
		local currentHealth = hum and hum.Health or (model:GetAttribute("Health") or 0)
		local maxHealth = hum and hum.MaxHealth or (model:GetAttribute("MaxHealth") or 1)
		local hpPct = math.clamp((maxHealth > 0 and currentHealth / maxHealth or 0), 0, 1)
		ui.HPBarFill.Size = UDim2.new(hpPct, 0, 1, 0)
		ui.HPBarFill.BackgroundColor3 = hpPct < 0.3 and Theme.Negative or (hpPct < 0.6 and Theme.Warning or Theme.Positive)
		ui.UpgradeBtn.Visible = context.canUpgrade
	end

	refresh()
	context.addInspectorConnection(RunService.Heartbeat:Connect(refresh))
end

function module.renderOwnedSelectionSummary(buildings, totalRefund, totalUpgradeCost, upgradableCount, context)
	local ui = context.ui
	clearBody(ui, context)
	ui.TrainFrame.Visible = true
	ui.InspTitle.Visible = true
	ui.HPContainer.Visible = false
	ui.SellBtn.Visible = true
	ui.UpgradeBtn.Visible = upgradableCount > 0
	ui.SellBtn.Text = "SELL BUILDINGS (+$" .. tostring(totalRefund) .. ")"
	ui.UpgradeBtn.Text = "UPGRADE BUILDINGS ($" .. tostring(totalUpgradeCost) .. ")"
	ui.InspectorFrame.Size = UDim2.new(0, 400, 0, 230)
	ui.InspectorFrame.Position = UDim2.new(1, -420, 1, -250)
	ui.InspTitle.Position = UDim2.new(0, 14, 0, 10)
	ui.InspTitle.Size = UDim2.new(1, -28, 0, 24)
	ui.InspTitle.TextXAlignment = Enum.TextXAlignment.Left
	ui.InspTitle.TextSize = 20
	ui.TrainFrame.Position = UDim2.new(0, 14, 0, 44)
	ui.TrainFrame.Size = UDim2.new(1, -28, 0, 110)
	ui.TrainFrame.ScrollBarThickness = 0
	ui.TrainFrame.ScrollingEnabled = false
	ui.SellBtn.Size = UDim2.new(0.25, 0, 0, 36)
	ui.SellBtn.Position = UDim2.new(0.24, -8, 1, -48)
	ui.UpgradeBtn.Size = UDim2.new(0.25, 0, 0, 36)
	ui.UpgradeBtn.Position = UDim2.new(0.51, 8, 1, -48)

	local summary = context.summarizeSelectedBuildings(buildings)
	local headingText = summary.SameType and (string.upper(Rendering.formatUnitDisplayName(summary.TypeName)) .. " x" .. tostring(summary.Count)) or (tostring(summary.Count) .. " BUILDINGS SELECTED")
	ui.InspTitle.Text = headingText

	local breakdown = {}
	for buildingType, count in pairs(summary.CountsByType) do
		table.insert(breakdown, string.format("%s x%d", Rendering.formatUnitDisplayName(buildingType), count))
	end
	table.sort(breakdown)

	local lines = {
		"Types: " .. table.concat(breakdown, ", "),
		"Refund $" .. tostring(totalRefund) .. "    Upgrade $" .. tostring(totalUpgradeCost),
	}
	if upgradableCount > 0 then
		table.insert(lines, tostring(upgradableCount) .. " building(s) can upgrade")
	end

	local info = Layout.createText(ui.TrainFrame, table.concat(lines, "\n"), UDim2.new(1, -4, 1, 0), UDim2.new(0, 0, 0, 0), Enum.Font.GothamMedium, Theme.Text, Enum.TextXAlignment.Left, Theme)
	info.TextSize = 12
	info.TextWrapped = true
	info.TextYAlignment = Enum.TextYAlignment.Top
end


local MODE_DEFS = {
	Close = { Label = "CLOSE DEFENSE", Range = 6, Damage = 20 },
	Balanced = { Label = "BALANCED", Range = 8, Damage = 15 },
	Long = { Label = "LONG REACH", Range = 10, Damage = 10 },
}

local function _setupHQBaseUI(ui, model, bData, context)
	local Rendering = require(game:GetService("ReplicatedStorage"):WaitForChild("UIInspector.Rendering"))
	local Training = require(game:GetService("ReplicatedStorage"):WaitForChild("UIInspector.Training"))

	clearBody(ui, context)
	ui.TrainFrame.Visible = true
	ui.InspTitle.Visible = true
	ui.HPContainer.Visible = true
	ui.InspectorFrame.Size = UDim2.new(0, 560, 0, 432)
	ui.InspectorFrame.Position = UDim2.new(1, -580, 1, -452)
	ui.InspTitle.Text = string.upper(Rendering.formatUnitDisplayName(model.Name))
	ui.InspTitle.Position = UDim2.new(0, 14, 0, 10)
	ui.InspTitle.Size = UDim2.new(1, -28, 0, 24)
	ui.InspTitle.TextXAlignment = Enum.TextXAlignment.Left
	ui.InspTitle.TextSize = 20
	ui.HPContainer.Position = UDim2.new(0, 14, 0, 42)
	ui.HPContainer.Size = UDim2.new(1, -28, 0, 14)
	ui.TrainFrame.Position = UDim2.new(0, 14, 0, 68)
	ui.TrainFrame.Size = UDim2.new(1, -28, 0, 304)
	ui.TrainFrame.ScrollBarThickness = 0
	ui.TrainFrame.ScrollingEnabled = false
	ui.SellBtn.Visible = true
	ui.SellBtn.Text = "SURRENDER"
	ui.SellBtn.Size = UDim2.new(0.25, 0, 0, 36)
	ui.SellBtn.Position = UDim2.new(0.24, -8, 1, -48)
	ui.UpgradeBtn.Visible = Training.canUpgradeBuilding(model)
	ui.UpgradeBtn.Text = "UPGRADE ($" .. tostring(bData and bData.UpgradeCost or 0) .. ")"
	ui.UpgradeBtn.Size = UDim2.new(0.25, 0, 0, 36)
	ui.UpgradeBtn.Position = UDim2.new(0.51, 8, 1, -48)
end

local function _createBuilderPanel(shell)
	local builderPanel = Instance.new("Frame")
	builderPanel.Size = UDim2.new(0.44, -6, 1, 0)
	builderPanel.BackgroundColor3 = Theme.Panel
	builderPanel.BorderSizePixel = 0
	builderPanel.Parent = shell
	Layout.addCorner(builderPanel, UDim.new(0, 3))
	Layout.addStroke(builderPanel, 1, Theme.Stroke)

	local builderTitle = Layout.createText(builderPanel, "BUILDERS", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	builderTitle.TextSize = 11

	local queueList = Instance.new("Frame")
	queueList.Size = UDim2.new(1, -20, 0, 194)
	queueList.Position = UDim2.new(0, 10, 0, 30)
	queueList.BackgroundColor3 = Theme.Inset
	queueList.BorderSizePixel = 0
	queueList.Parent = builderPanel
	Layout.addCorner(queueList, UDim.new(0, 3))
	Layout.addStroke(queueList, 1, Theme.Stroke)
	local queueLayout = Instance.new("UIListLayout")
	queueLayout.Padding = UDim.new(0, 6)
	queueLayout.Parent = queueList
	local queuePad = Instance.new("UIPadding")
	queuePad.PaddingTop = UDim.new(0, 8)
	queuePad.PaddingBottom = UDim.new(0, 8)
	queuePad.PaddingLeft = UDim.new(0, 8)
	queuePad.PaddingRight = UDim.new(0, 8)
	queuePad.Parent = queueList

	local builderButton = Instance.new("TextButton")
	builderButton.Size = UDim2.new(1, -20, 0, 42)
	builderButton.Position = UDim2.new(0, 10, 1, -52)
	builderButton.BorderSizePixel = 0
	builderButton.BackgroundColor3 = Theme.PanelAlt
	builderButton.Text = ""
	builderButton.Parent = builderPanel
	Layout.addCorner(builderButton, UDim.new(0, 3))
	Layout.addStroke(builderButton, 1, Theme.Stroke)

	return builderPanel, queueList, builderButton
end

local function _updateBuilderQueue(queueList, queue, lastQueueRefresh, model)
	if tick() - lastQueueRefresh > 0.5 then
		for _, child in ipairs(queueList:GetChildren()) do
			if child:IsA("Frame") then child:Destroy() end
		end
		for i, id in ipairs(queue) do
			if i > 5 then break end
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 24)
			row.BackgroundTransparency = 1
			row.Parent = queueList
			local num = Layout.createText(row, tostring(i) .. ".", UDim2.new(0, 20, 1, 0), UDim2.new(0, 0, 0, 0), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
			num.TextSize = 13
			local name = Layout.createText(row, id, UDim2.new(1, -24, 1, 0), UDim2.new(0, 24, 0, 0), Enum.Font.GothamMedium, Theme.SubText, Enum.TextXAlignment.Left, Theme)
			name.TextSize = 12
			if i == 1 then
				local pb = Instance.new("Frame")
				pb.Size = UDim2.new(1, 0, 0, 3)
				pb.Position = UDim2.new(0, 0, 1, -3)
				pb.BackgroundColor3 = Theme.Stroke
				pb.BorderSizePixel = 0
				pb.Parent = row
				local fill = Instance.new("Frame")
				local pct = model:GetAttribute("QueueProgress") or 0
				fill.Size = UDim2.new(pct, 0, 1, 0)
				fill.BackgroundColor3 = Theme.Highlight
				fill.BorderSizePixel = 0
				fill.Parent = pb
			end
		end
		return tick()
	end
	return lastQueueRefresh
end

local function _createDefensePanel(shell, model, context)
	local ServerEvents = game:GetService("ReplicatedStorage"):WaitForChild("ServerEvents")
	local defPanel = Instance.new("Frame")
	defPanel.Size = UDim2.new(0.56, -6, 1, 0)
	defPanel.Position = UDim2.new(0.44, 6, 0, 0)
	defPanel.BackgroundColor3 = Theme.Panel
	defPanel.BorderSizePixel = 0
	defPanel.Parent = shell
	Layout.addCorner(defPanel, UDim.new(0, 3))
	Layout.addStroke(defPanel, 1, Theme.Stroke)

	local defTitle = Layout.createText(defPanel, "BASE DEFENSE", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	defTitle.TextSize = 11

	local modesList = Instance.new("Frame")
	modesList.Size = UDim2.new(1, -20, 0, 194)
	modesList.Position = UDim2.new(0, 10, 0, 30)
	modesList.BackgroundColor3 = Theme.Inset
	modesList.BorderSizePixel = 0
	modesList.Parent = defPanel
	Layout.addCorner(modesList, UDim.new(0, 3))
	Layout.addStroke(modesList, 1, Theme.Stroke)
	local modesLayout = Instance.new("UIListLayout")
	modesLayout.Padding = UDim.new(0, 8)
	modesLayout.Parent = modesList
	local modesPad = Instance.new("UIPadding")
	modesPad.PaddingTop = UDim.new(0, 10)
	modesPad.PaddingBottom = UDim.new(0, 10)
	modesPad.PaddingLeft = UDim.new(0, 10)
	modesPad.PaddingRight = UDim.new(0, 10)
	modesPad.Parent = modesList

	local mButtons = {}
	for k, def in pairs(MODE_DEFS) do
		local mb = Instance.new("TextButton")
		mb.Size = UDim2.new(1, 0, 0, 50)
		mb.BackgroundColor3 = Theme.PanelAlt
		mb.BorderSizePixel = 0
		mb.Text = ""
		mb.Parent = modesList
		Layout.addCorner(mb, UDim.new(0, 3))
		Layout.addStroke(mb, 1, Theme.Stroke)

		local ml = Layout.createText(mb, def.Label, UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 6), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
		ml.TextSize = 13
		local md = Layout.createText(mb, "Rng: " .. def.Range .. " | Dmg: " .. def.Damage, UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 28), Enum.Font.Gotham, Theme.SubText, Enum.TextXAlignment.Left, Theme)
		md.TextSize = 11

		table.insert(context.connections, mb.MouseButton1Click:Connect(function()
			ServerEvents.ChangeHQDefenseMode:FireServer(model, k)
		end))
		mButtons[k] = mb
	end

	return defPanel, mButtons
end


function module.renderHeadquartersPanel(model, bData, context)
	local ServerEvents = game:GetService("ReplicatedStorage"):WaitForChild("ServerEvents")
	local ui = context.ui
	_setupHQBaseUI(ui, model, bData, context)

	local lastQueueRefresh = 0
	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, 0, 0, 304)
	shell.BackgroundTransparency = 1
	shell.BorderSizePixel = 0
	shell.Parent = ui.TrainFrame

	local _builderPanel, queueList, builderButton = _createBuilderPanel(shell)
	local _defPanel, mButtons = _createDefensePanel(shell, model, context)

	table.insert(context.connections, builderButton.MouseButton1Click:Connect(function()
		local cur = model:GetAttribute("Queue")
		if not cur or #string.split(cur, ",") < 5 then
			ServerEvents.QueueBuilder:FireServer(model)
		end
	end))

	table.insert(context.connections, game:GetService("RunService").RenderStepped:Connect(function()
		local m = model:GetAttribute("DefenseMode") or "Balanced"
		for k, btn in pairs(mButtons) do
			btn.BackgroundColor3 = (k == m) and Theme.Highlight or Theme.PanelAlt
			local stroke = btn:FindFirstChild("UIStroke")
			if stroke then stroke.Color = (k == m) and Theme.Highlight or Theme.Stroke end
		end

		local qStr = model:GetAttribute("Queue") or ""
		local queue = qStr ~= "" and string.split(qStr, ",") or {}

		lastQueueRefresh = _updateBuilderQueue(queueList, queue, lastQueueRefresh, model)

		local count = #queue
		if count >= 5 then
			builderButton.Text = "QUEUE FULL"
			builderButton.BackgroundColor3 = Theme.Alert
		else
			builderButton.Text = "HIRE BUILDER ($500)"
			builderButton.BackgroundColor3 = Theme.Highlight
		end
	end))
end


local function _setupResearchBaseUI(ui, context)
	clearBody(ui, context)
	ui.TrainFrame.Visible = true
	ui.InspTitle.Visible = true
	ui.HPContainer.Visible = true
	ui.SellBtn.Visible = true
	ui.UpgradeBtn.Visible = false
	ui.InspectorFrame.Size = UDim2.new(0, 540, 0, 500)
	ui.InspectorFrame.Position = UDim2.new(1, -560, 1, -520)
	ui.InspTitle.Text = "RESEARCH CENTER"
	ui.InspTitle.Position = UDim2.new(0, 14, 0, 10)
	ui.InspTitle.Size = UDim2.new(1, -28, 0, 24)
	ui.InspTitle.TextXAlignment = Enum.TextXAlignment.Left
	ui.InspTitle.TextSize = 20
	ui.HPContainer.Position = UDim2.new(0, 14, 0, 42)
	ui.HPContainer.Size = UDim2.new(1, -28, 0, 14)
	ui.TrainFrame.Position = UDim2.new(0, 14, 0, 68)
	ui.TrainFrame.Size = UDim2.new(1, -28, 0, 378)
	ui.TrainFrame.ScrollBarThickness = 4
	ui.TrainFrame.ScrollingEnabled = true
	ui.SellBtn.Size = UDim2.new(0.28, 0, 0, 36)
	ui.SellBtn.Position = UDim2.new(0.36, 0, 1, -48)
	ui.SellBtn.Text = "SELL (+$" .. tostring(context.getSellActionRefundTotal()) .. ")"
end

local function _createResearchActivePanel(shell)
	local activePanel = Instance.new("Frame")
	activePanel.Size = UDim2.new(1, 0, 0, 86)
	activePanel.BackgroundColor3 = Theme.Panel
	activePanel.BorderSizePixel = 0
	activePanel.Parent = shell
	Layout.addCorner(activePanel, UDim.new(0, 3))
	Layout.addStroke(activePanel, 1, Theme.Stroke)

	local activeTitle = Layout.createText(activePanel, "STATUS", UDim2.new(0.4, -8, 0, 16), UDim2.new(0, 10, 0, 8), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
	activeTitle.TextSize = 11
	local activeItem = Layout.createText(activePanel, "IDLE", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 28), Enum.Font.GothamMedium, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	activeItem.TextSize = 13
	local pBarBg = Instance.new("Frame")
	pBarBg.Size = UDim2.new(1, -20, 0, 8)
	pBarBg.Position = UDim2.new(0, 10, 0, 56)
	pBarBg.BackgroundColor3 = Theme.Inset
	pBarBg.BorderSizePixel = 0
	pBarBg.Parent = activePanel
	local pFill = Instance.new("Frame")
	pFill.Size = UDim2.new(0, 0, 1, 0)
	pFill.BackgroundColor3 = Theme.Highlight
	pFill.BorderSizePixel = 0
	pFill.Parent = pBarBg
	local rTime = Layout.createText(activePanel, "", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 66), Enum.Font.Gotham, Theme.SubText, Enum.TextXAlignment.Right, Theme)
	rTime.TextSize = 11

	return activePanel, activeItem, pFill, rTime
end

local function _getResearchUnlockSummary(key)
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BuildingConfig"))
	local c = Config.TechTree[key]
	if not c then return "" end
	local out = "Unlocks: "
	local first = true
	local found = false
	if c.Unlocks then
		for _, u in ipairs(c.Unlocks) do
			if u.Type == "Unit" then
				out = out .. (first and "" or ", ") .. u.Id
				first = false
				found = true
			elseif u.Type == "Building" then
				out = out .. (first and "" or ", ") .. u.Id
				first = false
				found = true
			elseif u.Type == "Action" then
				out = out .. (first and "" or ", ") .. u.Id .. " Action"
				first = false
				found = true
			end
		end
	end
	return found and out or "Upgrades capabilities"
end

local function _updateResearchGrid(treePanel, listLayout, shell, model, context)
	local ServerEvents = game:GetService("ReplicatedStorage"):WaitForChild("ServerEvents")
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BuildingConfig"))
	local pStats = context.pStats
	for _, child in ipairs(treePanel:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local keys = {}
	for k, _ in pairs(Config.TechTree) do table.insert(keys, k) end
	table.sort(keys, function(a, b)
		local ca = Config.TechTree[a]
		local cb = Config.TechTree[b]
		if ca.Cost ~= cb.Cost then return ca.Cost < cb.Cost end
		return a < b
	end)

	local rState = pStats:GetAttribute("ResearchState")
	local st = rState and game:GetService("HttpService"):JSONDecode(rState) or {}
	local rActive = model:GetAttribute("ResearchActive")

	for _, k in ipairs(keys) do
		local info = Config.TechTree[k]
		local done = st[k] == true
		local progressing = rActive == k
		local prereqOk = true
		if info.Prerequisite then
			prereqOk = st[info.Prerequisite] == true
		end

		local item = Instance.new("Frame")
		item.Size = UDim2.new(1, 0, 0, 68)
		item.BackgroundColor3 = Theme.PanelAlt
		item.BorderSizePixel = 0
		item.Parent = treePanel
		Layout.addCorner(item, UDim.new(0, 3))
		Layout.addStroke(item, 1, Theme.Stroke)

		local t = Layout.createText(item, k, UDim2.new(1, -130, 0, 20), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
		t.TextSize = 14
		local desc = Layout.createText(item, _getResearchUnlockSummary(k), UDim2.new(1, -130, 0, 16), UDim2.new(0, 10, 0, 34), Enum.Font.Gotham, Theme.SubText, Enum.TextXAlignment.Left, Theme)
		desc.TextSize = 11

		local statLbl = Layout.createText(item, "", UDim2.new(0, 100, 0, 20), UDim2.new(1, -110, 0.5, -10), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Right, Theme)
		statLbl.TextSize = 13

		if done then
			statLbl.Text = "RESEARCHED"
			statLbl.TextColor3 = Theme.Highlight
		elseif progressing then
			statLbl.Text = "RESEARCHING"
			statLbl.TextColor3 = Theme.Warning
		elseif prereqOk then
			statLbl.Visible = false
			local btn = Instance.new("TextButton")
			btn.Size = UDim2.new(0, 110, 0, 36)
			btn.Position = UDim2.new(1, -120, 0.5, -18)
			btn.BackgroundColor3 = Theme.Highlight
			btn.BorderSizePixel = 0
			btn.Text = "RESEARCH ($" .. info.Cost .. ")"
			btn.Font = Enum.Font.GothamBold
			btn.TextColor3 = Theme.Text
			btn.TextSize = 12
			btn.Parent = item
			Layout.addCorner(btn, UDim.new(0, 3))
			table.insert(context.connections, btn.MouseButton1Click:Connect(function()
				ServerEvents.StartResearch:FireServer(model, k)
			end))
		else
			statLbl.Text = "LOCKED"
			local lockMsg = Layout.createText(item, "Req: " .. info.Prerequisite, UDim2.new(0, 100, 0, 14), UDim2.new(1, -110, 0.5, 6), Enum.Font.Gotham, Theme.Alert, Enum.TextXAlignment.Right, Theme)
			lockMsg.TextSize = 10
		end
	end
	shell.Size = UDim2.new(1, 0, 0, 86 + 12 + listLayout.AbsoluteContentSize.Y)
end


function module.renderResearchCenterPanel(model, bData, context)
	local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("BuildingConfig"))
	local ui = context.ui
	_setupResearchBaseUI(ui, context)

	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, 0, 0, 378)
	shell.BackgroundTransparency = 1
	shell.BorderSizePixel = 0
	shell.Parent = ui.TrainFrame

	local _activePanel, activeItem, pFill, rTime = _createResearchActivePanel(shell)

	local treePanel = Instance.new("Frame")
	treePanel.Size = UDim2.new(1, 0, 1, -98)
	treePanel.Position = UDim2.new(0, 0, 0, 98)
	treePanel.BackgroundTransparency = 1
	treePanel.BorderSizePixel = 0
	treePanel.Parent = shell
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = treePanel

	local function refreshTree()
		_updateResearchGrid(treePanel, listLayout, shell, model, context)
	end

	table.insert(context.connections, model:GetAttributeChangedSignal("ResearchActive"):Connect(refreshTree))
	table.insert(context.connections, context.pStats:GetAttributeChangedSignal("ResearchState"):Connect(refreshTree))
	refreshTree()

	table.insert(context.connections, game:GetService("RunService").RenderStepped:Connect(function()
		local ra = model:GetAttribute("ResearchActive")
		if ra and ra ~= "" then
			local t = Config.TechTree[ra]
			activeItem.Text = "RESEARCHING: " .. string.upper(ra)
			local dur = t and t.Duration or 60
			local elapsed = model:GetAttribute("ResearchTimeElapsed") or 0
			local pct = math.clamp(elapsed / dur, 0, 1)
			pFill.Size = UDim2.new(pct, 0, 1, 0)
			rTime.Text = tostring(math.max(0, math.floor(dur - elapsed))) .. "s"
			activeItem.TextColor3 = Theme.Warning
		else
			activeItem.Text = "IDLE - SELECT A TECH"
			activeItem.TextColor3 = Theme.SubText
			pFill.Size = UDim2.new(0, 0, 1, 0)
			rTime.Text = ""
		end
	end))
end


return module
