local module = {}

local Config
local UnitEvent
local Training
local Layout
local Rendering
local RunService
local Theme

local localPlayer = game:GetService("Players").LocalPlayer

local function formatQueueEta(seconds)
	seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	if minutes > 0 then
		return string.format("%dm %02ds", minutes, remainder)
	end
	return string.format("%ds", remainder)
end

local function isResearchUnlocked(researchId)
	if not researchId then
		return true
	end
	return localPlayer:GetAttribute("Research_" .. tostring(researchId)) == true
end

local function getResearchDisplayName(researchId)
	local researchData = Config.Research[researchId]
	return tostring(researchData and researchData.DisplayName or researchId or "RESEARCH")
end

local function getProductionRequirementLabel(bType, levelNumber)
	if bType == "Barracks" or bType == "BarracksL2" then
		return "level " .. tostring(levelNumber) .. " barracks"
	elseif bType == "Airport" or bType == "AirportL2" then
		return "level " .. tostring(levelNumber) .. " airport"
	end
	return "level " .. tostring(levelNumber) .. " vehicle factory"
end

local function getUnlockRequirementText(bType, unlockDepth, researchRequired)
	local parts = {}
	if unlockDepth > 0 then
		table.insert(parts, getProductionRequirementLabel(bType, unlockDepth + 1))
	end
	if researchRequired then
		table.insert(parts, getResearchDisplayName(researchRequired))
	end
	if #parts == 0 then
		return ""
	end
	return "Requires " .. table.concat(parts, " + ")
end

local function getProductionStyle(bType)
	if bType == "Barracks" or bType == "BarracksL2" then
		return "BARRACKS", "Train infantry units."
	elseif bType == "VehicleFactory" or bType == "VehicleFactoryL2" then
		return "VEHICLE FACTORY", "Assemble ground vehicles."
	elseif bType == "Airport" or bType == "AirportL2" then
		return "AIRPORT", "Deploy aircraft and transports."
	end
	return "PRODUCTION", "Manage active orders and available units."
end

function module.init(options)
	Config = options.Config
	UnitEvent = options.UnitEvent
	Training = options.Training
	Layout = options.Layout
	Rendering = options.Rendering
	RunService = options.RunService
	Theme = options.Theme
end

function module.renderProductionHub(model, bType, bData, context)
	if not bData then
		return false
	end

	local ui = context.ui
	local overline = getProductionStyle(bType)
	ui.InspectorFrame.Size = UDim2.new(0, 480, 0, 560)
	ui.InspectorFrame.Position = UDim2.new(1, -500, 1, -580)
	ui.InspectorFrame.BackgroundColor3 = Theme.Background

	local UIStyle = require(game:GetService("ReplicatedStorage"):WaitForChild("UIStyle"))
	UIStyle.animateWindowOpen(ui.InspectorFrame)
	ui.InspTitle.Visible = true
	ui.InspTitle.Text = overline
	ui.InspTitle.Position = UDim2.new(0, 16, 0, 12)
	ui.InspTitle.Size = UDim2.new(1, -32, 0, 28)
	ui.InspTitle.TextXAlignment = Enum.TextXAlignment.Left
	ui.InspTitle.TextSize = 22
	ui.HPContainer.Visible = true
	ui.HPContainer.Position = UDim2.new(0, 16, 0, 46)
	ui.HPContainer.Size = UDim2.new(1, -32, 0, 16)
	ui.QueueLabel.Visible = false
	ui.QueueScroll.Visible = false
	ui.TrainFrame.Visible = true
	ui.TrainFrame.Position = UDim2.new(0, 16, 0, 76)
	ui.TrainFrame.Size = UDim2.new(1, -32, 0, 420)
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	ui.TrainFrame.ScrollBarThickness = 6
	ui.TrainFrame.ScrollingEnabled = true
	Training.hideQueueError()

	ui.SellBtn.Visible = true
	ui.SellBtn.Size = UDim2.new(0.25, 0, 0, 36)
	ui.SellBtn.Position = UDim2.new(0.24, -8, 1, -48)
	ui.SellBtn.BackgroundColor3 = Theme.Negative
	ui.SellBtn.Text = "SELL (+$" .. tostring(context.getSellActionRefundTotal()) .. ")"

	ui.UpgradeBtn.Visible = Training.canUpgradeBuilding(model)
	ui.UpgradeBtn.Size = UDim2.new(0.25, 0, 0, 36)
	ui.UpgradeBtn.Position = UDim2.new(0.51, 8, 1, -48)
	ui.UpgradeBtn.BackgroundColor3 = Theme.Accent
	ui.UpgradeBtn.TextColor3 = Theme.Text

	context.clearTrainFrameContent()
	Training.ensureQueue(model)

	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 8)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = ui.TrainFrame

	local overviewPanel = Instance.new("Frame")
	overviewPanel.LayoutOrder = 1
	overviewPanel.Size = UDim2.new(1, 0, 0, 58)
	overviewPanel.BackgroundColor3 = Theme.Panel
	overviewPanel.BorderSizePixel = 0
	overviewPanel.Parent = ui.TrainFrame
	Layout.addCorner(overviewPanel, UDim.new(0, 3))
	Layout.addStroke(overviewPanel, 1, Theme.Stroke)

	local overviewTitle = Layout.createText(overviewPanel, "STATUS", UDim2.new(0.4, -10, 0, 14), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
	overviewTitle.TextSize = 12
	local overviewState = Layout.createText(overviewPanel, "READY", UDim2.new(0.6, -10, 0, 18), UDim2.new(0.4, 0, 0, 8), Enum.Font.GothamBold, Theme.Positive, Enum.TextXAlignment.Right, Theme)
	overviewState.TextSize = 14
	local overviewBody = Layout.createText(overviewPanel, "Queue units, cancel orders from the queue, and train from the list below.", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 30), Enum.Font.GothamMedium, Theme.Text, Enum.TextXAlignment.Left, Theme)
	overviewBody.TextSize = 12

	local queuePanel = Instance.new("Frame")
	queuePanel.LayoutOrder = 2
	queuePanel.Size = UDim2.new(1, 0, 0, 98)
	queuePanel.BackgroundColor3 = Theme.Panel
	queuePanel.BorderSizePixel = 0
	queuePanel.Parent = ui.TrainFrame
	Layout.addCorner(queuePanel, UDim.new(0, 3))
	Layout.addStroke(queuePanel, 1, Theme.Stroke)

	local queueOverline = Layout.createText(queuePanel, "QUEUE", UDim2.new(0, 80, 0, 14), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
	queueOverline.TextSize = 12

	local queueList = Instance.new("ScrollingFrame")
	queueList.Size = UDim2.new(1, -20, 0, 56)
	queueList.Position = UDim2.new(0, 10, 0, 30)
	queueList.BackgroundColor3 = Theme.Inset
	queueList.BorderSizePixel = 0
	queueList.ScrollBarThickness = 4
	queueList.ScrollBarImageColor3 = Theme.Stroke
	queueList.AutomaticCanvasSize = Enum.AutomaticSize.X
	queueList.CanvasSize = UDim2.new(0, 0, 0, 0)
	queueList.Parent = queuePanel
	Layout.addCorner(queueList, UDim.new(0, 3))
	Layout.addStroke(queueList, 1, Theme.Stroke)
	local queueLayout = Instance.new("UIListLayout")
	queueLayout.FillDirection = Enum.FillDirection.Horizontal
	queueLayout.Padding = UDim.new(0, 6)
	queueLayout.Parent = queueList
	local queuePad = Instance.new("UIPadding")
	queuePad.PaddingTop = UDim.new(0, 6)
	queuePad.PaddingBottom = UDim.new(0, 6)
	queuePad.PaddingLeft = UDim.new(0, 8)
	queuePad.PaddingRight = UDim.new(0, 8)
	queuePad.Parent = queueList

	local function rebuildQueue()
		for _, child in ipairs(queueList:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end

		local queue = Training.getQueue(model) or {}
		local snapshot = Training.getTrainingSnapshot(model)
		overviewState.Text = #queue > 0 and (tostring(#queue) .. " ORDER" .. (#queue == 1 and "" or "S")) or "READY"
		overviewState.TextColor3 = #queue > 0 and Theme.Text or Theme.Positive

		if #queue == 0 then
			queuePanel.Size = UDim2.new(1, 0, 0, 36)
			queueList.Visible = false
			local empty = Layout.createText(queueList, "No active orders.", UDim2.new(1, 0, 0, 18), UDim2.new(), Enum.Font.GothamMedium, Theme.Text, Enum.TextXAlignment.Left, Theme)
			empty.TextSize = 13
			return
		else
			queuePanel.Size = UDim2.new(1, 0, 0, 98)
			queueList.Visible = true
		end

		for index, unitName in ipairs(queue) do
			local row = Instance.new("TextButton")
			row.Size = UDim2.new(0, 56, 1, 0)
			row.BackgroundColor3 = Theme.Panel
			row.BorderSizePixel = 0
			row.Text = ""
			row.Parent = queueList
			Layout.addCorner(row, UDim.new(0, 3))
			Layout.addStroke(row, 1, Theme.Stroke)

			local icon = Instance.new("Frame")
			icon.Size = UDim2.new(1, -8, 0, 28)
			icon.Position = UDim2.new(0, 4, 0, 4)
			icon.BackgroundColor3 = Theme.Inset
			icon.BorderSizePixel = 0
			icon.Parent = row
			Layout.addCorner(icon, UDim.new(0, 2))
			Rendering.renderUnitViewport(icon, unitName)

			local etaText = snapshot and index == 1 and formatQueueEta(snapshot.Remaining) or ("#" .. tostring(index))
			local meta = Layout.createText(row, etaText, UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 1, -16), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Center, Theme)
			meta.TextSize = 11

			row.MouseButton1Click:Connect(function()
				UnitEvent:FireServer("CancelTrain", model, index)
			end)
		end
	end

	local lastQueueRefresh = 0

	local recruitOptions = Training.getRecruitOptionsForBuilding(bType)
	if #recruitOptions == 0 then
		for _, unitName in ipairs(bData.CanRecruit or {}) do
			table.insert(recruitOptions, { Name = unitName, UnlockDepth = 0 })
		end
	end

	local gridFrame = Instance.new("Frame")
	gridFrame.LayoutOrder = 3
	gridFrame.Size = UDim2.new(1, 0, 0, 0)
	gridFrame.AutomaticSize = Enum.AutomaticSize.Y
	gridFrame.BackgroundTransparency = 1
	gridFrame.Parent = ui.TrainFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.CellSize = UDim2.new(0.5, -3, 0, 66)
	gridLayout.CellPadding = UDim2.new(0, 6, 0, 6)
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.Parent = gridFrame

	for order, entry in ipairs(recruitOptions) do
		local unitName = entry.Name
		local unlockDepth = entry.UnlockDepth or 0
		local uData = Config.Units[unitName]
		if uData then
			local researchRequired = uData.ResearchRequired
			local researchLocked = researchRequired and not isResearchUnlocked(researchRequired)
			local isLocked = unlockDepth > 0 or researchLocked

			local card = Instance.new("TextButton")
			card.LayoutOrder = order
			card.BackgroundColor3 = isLocked and Theme.PanelSoft or Theme.Panel
			card.BorderSizePixel = 0
			card.Text = ""
			card.Parent = gridFrame
			Layout.addCorner(card, UDim.new(0, 3))
			Layout.addStroke(card, 1, Theme.Stroke)

			local icon = Instance.new("Frame")
			icon.Size = UDim2.new(0, 40, 0, 40)
			icon.Position = UDim2.new(0, 6, 0.5, -20)
			icon.BackgroundColor3 = Theme.Inset
			icon.BorderSizePixel = 0
			icon.Parent = card
			Layout.addCorner(icon, UDim.new(0, 3))
			Layout.addStroke(icon, 1, Theme.Stroke)
			Rendering.renderUnitViewport(icon, unitName)
			icon.BackgroundTransparency = isLocked and 0.2 or 0

			local title = Layout.createText(card, Rendering.formatUnitDisplayName(unitName), UDim2.new(1, -54, 0, 16), UDim2.new(0, 52, 0, 6), Enum.Font.GothamBold, Theme.Text, Enum.TextXAlignment.Left, Theme)
			title.TextSize = 13
			title.TextScaled = true

			local line2Text
			local line2Color
			if researchLocked or unlockDepth > 0 then
				line2Text = getUnlockRequirementText(bType, unlockDepth, researchLocked and researchRequired or nil)
				line2Color = researchLocked and Theme.Warning or Theme.SubText
			else
				line2Text = "$" .. tostring(uData.Cost or 0) .. "  " .. tostring(uData.TrainingTime or 0) .. "s"
				line2Color = Theme.Positive
			end
			local meta = Layout.createText(card, line2Text, UDim2.new(1, -54, 0, 28), UDim2.new(0, 52, 0, 24), Enum.Font.GothamBold, line2Color, Enum.TextXAlignment.Left, Theme)
			meta.TextSize = 11
			meta.TextWrapped = true

			card.MouseButton1Click:Connect(function()
				if researchLocked then
					Training.showQueueError("Requires research: " .. getResearchDisplayName(researchRequired))
					return
				end
				if unlockDepth > 0 then
					Training.showQueueError("Upgrade building to unlock " .. unitName)
					return
				end
				UnitEvent:FireServer("Train", model, unitName)
			end)
		end
	end

	rebuildQueue()
	context.addInspectorConnection(RunService.Heartbeat:Connect(function()
		if os.clock() - lastQueueRefresh >= 0.2 then
			lastQueueRefresh = os.clock()
			rebuildQueue()
		end
	end))
	return true
end

return module
