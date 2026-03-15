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

function module.renderHeadquartersPanel(model, bData, context)
	local MODE_DEFS = {
		Close = { Label = "CLOSE DEFENSE", Range = 6, Damage = 20 },
		Balanced = { Label = "BALANCED", Range = 8, Damage = 15 },
		Long = { Label = "LONG REACH", Range = 10, Damage = 10 },
	}

	local ui = context.ui
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
	local lastQueueRefresh = 0

	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, 0, 0, 304)
	shell.BackgroundTransparency = 1
	shell.BorderSizePixel = 0
	shell.Parent = ui.TrainFrame

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

	local builderUnitData = Config.Units.Builder or {}
	local builderButtonTitle = Layout.createText(builderButton, "TRAIN BUILDER", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 6), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
	builderButtonTitle.TextSize = 14
	local builderMeta = Layout.createText(builderButton, "$" .. tostring(builderUnitData.Cost or 0) .. "   " .. tostring(builderUnitData.TrainingTime or 0) .. "s", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 22), Enum.Font.GothamMedium, Theme.Positive, Enum.TextXAlignment.Left, Theme)
	builderMeta.TextSize = 12

	local defensePanel = Instance.new("Frame")
	defensePanel.Size = UDim2.new(0.56, -6, 1, 0)
	defensePanel.Position = UDim2.new(0.44, 12, 0, 0)
	defensePanel.BackgroundColor3 = Theme.Panel
	defensePanel.BorderSizePixel = 0
	defensePanel.Parent = shell
	Layout.addCorner(defensePanel, UDim.new(0, 3))
	Layout.addStroke(defensePanel, 1, Theme.Stroke)

	local defenseTitle = Layout.createText(defensePanel, "RANGE", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	defenseTitle.TextSize = 11
	local defenseStatus = Layout.createText(defensePanel, "Mode available now", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 28), Enum.Font.GothamMedium, Theme.Text, Enum.TextXAlignment.Left, Theme)
	defenseStatus.TextSize = 12

	local modeButtons = {}
	for index, modeName in ipairs({ "Close", "Balanced", "Long" }) do
		local info = MODE_DEFS[modeName]
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -20, 0, 40)
		button.Position = UDim2.new(0, 10, 0, 58 + (index - 1) * 46)
		button.BackgroundColor3 = Theme.PanelAlt
		button.BorderSizePixel = 0
		button.Text = ""
		button.Parent = defensePanel
		Layout.addCorner(button, UDim.new(0, 3))
		Layout.addStroke(button, 1, Theme.Stroke)

		local label = Layout.createText(button, info.Label, UDim2.new(0.58, -8, 1, 0), UDim2.new(0, 10, 0, 0), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
		label.TextSize = 13
		local meta = Layout.createText(button, string.format("DMG %d  RNG %d", info.Damage, info.Range), UDim2.new(0.42, -10, 1, 0), UDim2.new(0.58, 0, 0, 0), Enum.Font.GothamMedium, Theme.Text, Enum.TextXAlignment.Right, Theme)
		meta.TextSize = 12

		button.MouseButton1Click:Connect(function()
			HeadquartersControlEvent:FireServer("SetRangeMode", model, modeName)
		end)

		modeButtons[modeName] = { Button = button, Label = label, Meta = meta }
	end

	local function refresh()
		if context.getSelectedBuilding() ~= model then
			return
		end

		local hum = model:FindFirstChild("Humanoid")
		local hp = hum and hum.Health or (model:GetAttribute("Health") or 0)
		local maxHp = hum and hum.MaxHealth or (model:GetAttribute("MaxHealth") or 1)
		local hpPct = math.clamp((maxHp > 0 and hp / maxHp or 0), 0, 1)
		ui.HPBarFill.Size = UDim2.new(hpPct, 0, 1, 0)
		ui.HPBarFill.BackgroundColor3 = hpPct < 0.3 and Theme.Negative or (hpPct < 0.6 and Theme.Warning or Theme.Positive)

		if os.clock() - lastQueueRefresh >= 0.2 then
			lastQueueRefresh = os.clock()
			for _, child in ipairs(queueList:GetChildren()) do
				if child:IsA("GuiObject") then
					child:Destroy()
				end
			end

			local queue = Training.getQueue(model) or {}
			local snapshot = Training.getTrainingSnapshot(model)
			if #queue == 0 then
				local empty = Layout.createText(queueList, "No active orders", UDim2.new(1, 0, 0, 18), UDim2.new(), Enum.Font.GothamMedium, Theme.Text, Enum.TextXAlignment.Left, Theme)
				empty.TextSize = 12
			else
				for index, queuedName in ipairs(queue) do
					local row = Instance.new("TextButton")
					row.Size = UDim2.new(1, 0, 0, 34)
					row.BackgroundColor3 = Theme.Panel
					row.BorderSizePixel = 0
					row.Text = ""
					row.Parent = queueList
					Layout.addCorner(row, UDim.new(0, 3))
					Layout.addStroke(row, 1, Theme.Stroke)

					local nameLabel = Layout.createText(row, Rendering.formatUnitDisplayName(queuedName), UDim2.new(0.7, -8, 1, 0), UDim2.new(0, 10, 0, 0), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
					nameLabel.TextSize = 12
					local eta = snapshot and index == 1 and formatDuration(snapshot.Remaining) or ("#" .. tostring(index))
					local etaLabel = Layout.createText(row, eta, UDim2.new(0.3, -10, 1, 0), UDim2.new(0.7, 0, 0, 0), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Right, Theme)
					etaLabel.TextSize = 11

					row.MouseButton1Click:Connect(function()
						UnitEvent:FireServer("CancelTrain", model, index)
					end)
				end
			end
		end

		local activeModeName = tostring(model:GetAttribute("HQRangeMode") or "Balanced")
		local cooldownUntil = tonumber(model:GetAttribute("HQRangeCooldownUntil") or 0) or 0
		local remaining = math.max(0, cooldownUntil - workspace:GetServerTimeNow())
		defenseStatus.Text = remaining > 0 and ("Available in " .. formatDuration(remaining)) or "Mode available now"
		defenseStatus.TextColor3 = remaining > 0 and Theme.Warning or Theme.SubText

		for modeName, refs in pairs(modeButtons) do
			local isActive = activeModeName == modeName
			local locked = remaining > 0 and not isActive
			refs.Button.Active = not locked and not isActive
			refs.Button.AutoButtonColor = not locked and not isActive
			refs.Button.BackgroundColor3 = isActive and Theme.AccentSoft or Theme.Panel
			local stroke = refs.Button:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Color = isActive and Theme.Accent or Theme.Stroke
			end
			refs.Label.TextColor3 = locked and Theme.SubText or Theme.Text
			refs.Meta.TextColor3 = isActive and Theme.Text or Theme.SubText
		end

		ui.UpgradeBtn.Visible = Training.canUpgradeBuilding(model)
	end

	refresh()
	builderButton.MouseButton1Click:Connect(function()
		UnitEvent:FireServer("Train", model, "Builder")
	end)
	context.addInspectorConnection(RunService.Heartbeat:Connect(refresh))
end

function module.renderResearchCenterPanel(model, bData, context)
	local ui = context.ui
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

	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, 0, 0, 378)
	shell.BackgroundTransparency = 1
	shell.BorderSizePixel = 0
	shell.Parent = ui.TrainFrame

	local activePanel = Instance.new("Frame")
	activePanel.Size = UDim2.new(1, 0, 0, 86)
	activePanel.BackgroundColor3 = Theme.Panel
	activePanel.BorderSizePixel = 0
	activePanel.Parent = shell
	Layout.addCorner(activePanel, UDim.new(0, 3))
	Layout.addStroke(activePanel, 1, Theme.Stroke)

	local activeTitle = Layout.createText(activePanel, "STATUS", UDim2.new(0.4, -8, 0, 16), UDim2.new(0, 10, 0, 8), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
	activeTitle.TextSize = 12
	local activeName = Layout.createText(activePanel, "No active research", UDim2.new(0.6, -10, 0, 18), UDim2.new(0.4, 0, 0, 8), Enum.Font.GothamBold, Theme.Positive, Enum.TextXAlignment.Right, Theme)
	activeName.TextSize = 16
	local activeMeta = Layout.createText(activePanel, "Choose a project below to unlock new units and structures.", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 36), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
	activeMeta.TextSize = 13
	activeMeta.TextWrapped = true
	activeMeta.TextYAlignment = Enum.TextYAlignment.Top

	local progressBack = Instance.new("Frame")
	progressBack.Size = UDim2.new(1, -20, 0, 10)
	progressBack.Position = UDim2.new(0, 10, 1, -18)
	progressBack.BackgroundColor3 = Theme.Inset
	progressBack.BorderSizePixel = 0
	progressBack.Parent = activePanel
	Layout.addCorner(progressBack, UDim.new(0, 2))
	Layout.addStroke(progressBack, 1, Theme.Stroke)

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Theme.Accent
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	Layout.addCorner(progressFill, UDim.new(0, 2))

	local listPanel = Instance.new("Frame")
	listPanel.Size = UDim2.new(1, 0, 0, 280)
	listPanel.Position = UDim2.new(0, 0, 0, 98)
	listPanel.BackgroundColor3 = Theme.Panel
	listPanel.BorderSizePixel = 0
	listPanel.Parent = shell
	Layout.addCorner(listPanel, UDim.new(0, 3))
	Layout.addStroke(listPanel, 1, Theme.Stroke)

	local listHolder = Instance.new("ScrollingFrame")
	listHolder.Size = UDim2.new(1, -20, 1, -20)
	listHolder.Position = UDim2.new(0, 10, 0, 10)
	listHolder.BackgroundTransparency = 1
	listHolder.BorderSizePixel = 0
	listHolder.ScrollBarThickness = 4
	listHolder.ScrollBarImageColor3 = Theme.Stroke
	listHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
	listHolder.CanvasSize = UDim2.new(0, 0, 0, 0)
	listHolder.Parent = listPanel
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.Parent = listHolder

	local rowRefs = {}
	local options = bData.ResearchOptions or {}

	local function getActiveResearchState()
		local activeId = tostring(player:GetAttribute("ActiveResearchId") or "")
		local startedAt = tonumber(player:GetAttribute("ActiveResearchStartedAt") or 0) or 0
		local endsAt = tonumber(player:GetAttribute("ActiveResearchEndsAt") or 0) or 0
		local now = workspace:GetServerTimeNow()
		local hasActive = activeId ~= "" and endsAt > now and Config.Research[activeId] ~= nil
		return {
			ActiveId = activeId,
			HasActive = hasActive,
			Remaining = hasActive and math.max(0, endsAt - now) or 0,
			Progress = hasActive and math.clamp((now - startedAt) / math.max(0.001, endsAt - startedAt), 0, 1) or 0,
		}
	end

	for _, researchId in ipairs(options) do
		local researchData = Config.Research[researchId]
		if researchData then
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(1, 0, 0, 66)
			row.BackgroundColor3 = Theme.PanelSoft
			row.BorderSizePixel = 0
			row.Text = ""
			row.Parent = listHolder
			Layout.addCorner(row, UDim.new(0, 3))
			Layout.addStroke(row, 1, Theme.Stroke)

			local title = Layout.createText(row, tostring(researchData.DisplayName or researchId), UDim2.new(0.58, -8, 0, 18), UDim2.new(0, 8, 0, 6), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
			title.TextSize = 15
			local meta = Layout.createText(row, "$" .. tostring(researchData.Cost or 0) .. "   " .. formatDuration(researchData.ResearchTime or 0), UDim2.new(0.42, -10, 0, 14), UDim2.new(0.58, 0, 0, 7), Enum.Font.GothamMedium, Theme.Positive, Enum.TextXAlignment.Right, Theme)
			meta.TextSize = 12

			local unlocks = Layout.createText(row, getResearchUnlockSummary(researchData), UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 25), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
			unlocks.TextSize = 11
			unlocks.TextWrapped = true
			local status = Layout.createText(row, "START", UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 46), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
			status.TextSize = 12

			row.MouseButton1Click:Connect(function()
				local state = getActiveResearchState()
				local completed = player:GetAttribute("Research_" .. researchId) == true
				if completed or state.HasActive then
					return
				end
				ResearchEvent:FireServer("Start", model, researchId)
			end)

			rowRefs[researchId] = { Row = row, Title = title, Meta = meta, Unlocks = unlocks, Status = status }
		end
	end

	local function refresh()
		if context.getSelectedBuilding() ~= model then
			return
		end
		local hum = model:FindFirstChild("Humanoid")
		local hp = hum and hum.Health or (model:GetAttribute("Health") or 0)
		local maxHp = hum and hum.MaxHealth or (model:GetAttribute("MaxHealth") or 1)
		local hpPct = math.clamp((maxHp > 0 and hp / maxHp or 0), 0, 1)
		ui.HPBarFill.Size = UDim2.new(hpPct, 0, 1, 0)
		ui.HPBarFill.BackgroundColor3 = hpPct < 0.3 and Theme.Negative or (hpPct < 0.6 and Theme.Warning or Theme.Positive)

		local state = getActiveResearchState()
		if state.HasActive and Config.Research[state.ActiveId] then
			activeName.Text = tostring(Config.Research[state.ActiveId].DisplayName or state.ActiveId)
			activeName.TextColor3 = Theme.Text
			activeMeta.Text = "Complete in " .. formatDuration(state.Remaining)
			progressFill.Size = UDim2.new(state.Progress, 0, 1, 0)
		else
			activeName.Text = "No active research"
			activeName.TextColor3 = Theme.Positive
			activeMeta.Text = "Choose a project below to unlock new units and structures."
			progressFill.Size = UDim2.new(0, 0, 1, 0)
		end

		for researchId, refs in pairs(rowRefs) do
			local completed = player:GetAttribute("Research_" .. researchId) == true
			local active = state.HasActive and state.ActiveId == researchId
			local blocked = state.HasActive and state.ActiveId ~= researchId
			refs.Row.BackgroundColor3 = active and Theme.Panel or Theme.PanelSoft
			local stroke = refs.Row:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Color = active and Theme.Text or Theme.Stroke
			end
			refs.Title.TextColor3 = completed and Theme.Positive or Theme.Text
			refs.Meta.TextColor3 = completed and Theme.SubText or Theme.Positive
			if completed then
				refs.Status.Text = "COMPLETED"
				refs.Status.TextColor3 = Theme.Positive
				refs.Row.Active = false
			elseif active then
				refs.Status.Text = "IN PROGRESS"
				refs.Status.TextColor3 = Theme.Text
				refs.Row.Active = false
			elseif blocked then
				refs.Status.Text = "BUSY"
				refs.Status.TextColor3 = Theme.Warning
				refs.Row.Active = false
			else
				refs.Status.Text = "START"
				refs.Status.TextColor3 = Theme.Text
				refs.Row.Active = true
			end
		end
		ui.SellBtn.Text = "SELL (+$" .. tostring(context.getSellActionRefundTotal()) .. ")"
	end

	refresh()
	context.addInspectorConnection(RunService.Heartbeat:Connect(refresh))
	for researchId in pairs(Config.Research) do
		context.addInspectorConnection(player:GetAttributeChangedSignal("Research_" .. researchId):Connect(refresh))
	end
	context.addInspectorConnection(player:GetAttributeChangedSignal("ActiveResearchId"):Connect(refresh))
	context.addInspectorConnection(player:GetAttributeChangedSignal("ActiveResearchStartedAt"):Connect(refresh))
	context.addInspectorConnection(player:GetAttributeChangedSignal("ActiveResearchEndsAt"):Connect(refresh))
end

return module
