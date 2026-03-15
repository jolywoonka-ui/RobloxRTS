local module = {}

local Config
local UnitEvent
local Training
local Layout
local Rendering
local RunService
local Theme

local function formatMissileEta(seconds)
	seconds = math.max(0, math.floor((tonumber(seconds) or 0) + 0.5))
	local minutes = math.floor(seconds / 60)
	local remainder = seconds % 60
	if minutes > 0 then
		return string.format("%dm %02ds", minutes, remainder)
	end
	return string.format("%ds", remainder)
end

local function getMissileState(model)
	local storedMissiles = model:GetAttribute("StoredMissiles") or 0
	local capacity = model:GetAttribute("MissileCapacity") or 1
	local queue = Training.getQueue(model) or {}
	local snapshot = Training.getTrainingSnapshot(model)
	local payloadData = Config.Units.MissilePayload or {}

	return {
		Stored = storedMissiles,
		Capacity = capacity,
		Queued = #queue,
		Progress = snapshot and snapshot.Progress or 0,
		Remaining = snapshot and snapshot.Remaining or (payloadData.TrainingTime or 0),
		PayloadCost = payloadData.Cost or 0,
		PayloadTime = payloadData.TrainingTime or 0,
	}
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

function module.renderMissileSiloPanel(model, bData, context)
	local ui = context.ui
	ui.InspectorFrame.Size = UDim2.new(0, 640, 0, 470)
	ui.InspectorFrame.Position = UDim2.new(1, -660, 1, -490)
	ui.InspectorFrame.BackgroundColor3 = Theme.Background
	local inspectorStroke = ui.InspectorFrame:FindFirstChildWhichIsA("UIStroke")
	if inspectorStroke then
		inspectorStroke.Color = Theme.Stroke
		inspectorStroke.Thickness = 1
		inspectorStroke.Transparency = 0
	end

	ui.InspTitle.Visible = false
	ui.HPContainer.Visible = false
	ui.QueueLabel.Visible = false
	ui.QueueScroll.Visible = false
	ui.SpecialStatusLabel.Visible = false
	ui.ActionBtn.Visible = false
	ui.TrainFrame.Position = UDim2.new(0, 10, 0, 10)
	ui.TrainFrame.Size = UDim2.new(1, -20, 1, -20)
	ui.TrainFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
	ui.TrainFrame.ScrollBarThickness = 0
	ui.TrainFrame.ScrollingEnabled = false
	Training.hideQueueError()

	ui.SellBtn.Size = UDim2.new(0, 176, 0, 42)
	ui.SellBtn.Position = UDim2.new(0, 10, 1, -52)
	ui.SellBtn.BackgroundColor3 = Theme.Negative
	ui.SellBtn.Text = "SELL (+$" .. tostring(Training.getSellRefund(model)) .. ")"

	context.clearTrainFrameContent()
	Training.ensureQueue(model)

	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, 0, 0, 400)
	shell.BackgroundTransparency = 1
	shell.Parent = ui.TrainFrame

	local header = Instance.new("Frame")
	header.Size = UDim2.new(1, 0, 0, 76)
	header.BackgroundColor3 = Theme.Panel
	header.BorderSizePixel = 0
	header.Parent = shell
	Layout.addCorner(header, UDim.new(0, 4))
	Layout.addStroke(header, 1, Theme.Stroke)

	local eyebrow = Layout.createText(header, "STRATEGIC STRIKE COMMAND", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	eyebrow.TextSize = 11
	local title = Layout.createText(header, "MISSILE SILO", UDim2.new(1, -20, 0, 26), UDim2.new(0, 10, 0, 24), Enum.Font.GothamBlack, Theme.Text, Enum.TextXAlignment.Left, Theme)
	title.TextSize = 22
local subtitle = Layout.createText(header, "Fabricate a warhead, then authorize a precision strike.", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 52), Enum.Font.GothamMedium, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	subtitle.TextSize = 12

	local fabrication = Instance.new("Frame")
	fabrication.Size = UDim2.new(0, 250, 0, 304)
	fabrication.Position = UDim2.new(0, 0, 0, 92)
	fabrication.BackgroundColor3 = Theme.Panel
	fabrication.BorderSizePixel = 0
	fabrication.Parent = shell
	Layout.addCorner(fabrication, UDim.new(0, 4))
	Layout.addStroke(fabrication, 1, Theme.Stroke)

	local launch = Instance.new("Frame")
	launch.Size = UDim2.new(1, -262, 0, 304)
	launch.Position = UDim2.new(0, 262, 0, 92)
	launch.BackgroundColor3 = Theme.Panel
	launch.BorderSizePixel = 0
	launch.Parent = shell
	Layout.addCorner(launch, UDim.new(0, 4))
	Layout.addStroke(launch, 1, Theme.Stroke)

	local fabTitle = Layout.createText(fabrication, "WARHEAD FABRICATION", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	fabTitle.TextSize = 11
	local readiness = Layout.createText(fabrication, "0%", UDim2.new(1, -20, 0, 28), UDim2.new(0, 10, 0, 26), Enum.Font.GothamBlack, Theme.Text, Enum.TextXAlignment.Left, Theme)
	readiness.TextSize = 28
local fabDetail = Layout.createText(fabrication, "Awaiting fabrication order", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 58), Enum.Font.GothamMedium, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	fabDetail.TextSize = 12

	local progressBack = Instance.new("Frame")
	progressBack.Size = UDim2.new(1, -20, 0, 12)
	progressBack.Position = UDim2.new(0, 10, 0, 82)
	progressBack.BackgroundColor3 = Theme.Inset
	progressBack.BorderSizePixel = 0
	progressBack.Parent = fabrication
	Layout.addCorner(progressBack, UDim.new(0, 2))
	Layout.addStroke(progressBack, 1, Theme.Stroke)

	local progressFill = Instance.new("Frame")
	progressFill.Size = UDim2.new(0, 0, 1, 0)
	progressFill.BackgroundColor3 = Theme.Accent
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBack
	Layout.addCorner(progressFill, UDim.new(0, 2))

	local payloadCard = Instance.new("TextButton")
	payloadCard.Size = UDim2.new(1, -20, 0, 92)
	payloadCard.Position = UDim2.new(0, 10, 0, 114)
	payloadCard.BackgroundColor3 = Theme.PanelAlt
	payloadCard.BorderSizePixel = 0
	payloadCard.Text = ""
	payloadCard.Parent = fabrication
	Layout.addCorner(payloadCard, UDim.new(0, 4))
	Layout.addStroke(payloadCard, 1, Theme.Stroke)

	local payloadIcon = Instance.new("Frame")
	payloadIcon.Size = UDim2.new(0, 56, 0, 56)
	payloadIcon.Position = UDim2.new(0, 10, 0, 18)
	payloadIcon.BackgroundColor3 = Theme.Inset
	payloadIcon.BorderSizePixel = 0
	payloadIcon.Parent = payloadCard
	Layout.addCorner(payloadIcon, UDim.new(0, 3))
	Layout.addStroke(payloadIcon, 1, Theme.Stroke)
	Rendering.renderUnitViewport(payloadIcon, "MissilePayload")

	local payloadTitle = Layout.createText(payloadCard, "FABRICATE PAYLOAD", UDim2.new(1, -78, 0, 18), UDim2.new(0, 74, 0, 14), Enum.Font.GothamBlack, Theme.Text, Enum.TextXAlignment.Left, Theme)
	payloadTitle.TextSize = 15
	local payloadMeta = Layout.createText(payloadCard, "", UDim2.new(1, -78, 0, 16), UDim2.new(0, 74, 0, 36), Enum.Font.GothamBold, Theme.Positive, Enum.TextXAlignment.Left, Theme)
	payloadMeta.TextSize = 12
local payloadBody = Layout.createText(payloadCard, "Produce a nuclear missile and protect it at all costs.", UDim2.new(1, -78, 0, 28), UDim2.new(0, 74, 0, 56), Enum.Font.GothamMedium, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	payloadBody.TextSize = 11
	payloadBody.TextWrapped = true

	local launchTitle = Layout.createText(launch, "LAUNCH AUTHORIZATION", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 10), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	launchTitle.TextSize = 11
	local launchState = Layout.createText(launch, "NO WARHEAD", UDim2.new(1, -20, 0, 18), UDim2.new(0, 10, 0, 28), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	launchState.TextSize = 12

	local launchButton = Instance.new("TextButton")
	launchButton.Size = UDim2.new(0, 138, 0, 138)
	launchButton.AnchorPoint = Vector2.new(0.5, 0)
	launchButton.Position = UDim2.new(0.5, 0, 0, 64)
	launchButton.BackgroundColor3 = Theme.PanelAlt
	launchButton.BorderSizePixel = 0
	launchButton.Text = ""
	launchButton.Parent = launch
	Layout.addCorner(launchButton, UDim.new(0, 4))
	Layout.addStroke(launchButton, 1, Theme.Stroke)

	local launchLabel = Layout.createText(launchButton, "LAUNCH", UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0.5, -22), Enum.Font.GothamBlack, Theme.Text, Enum.TextXAlignment.Center, Theme)
	launchLabel.TextSize = 22
	local launchSub = Layout.createText(launchButton, "LOCKED", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0.5, 8), Enum.Font.GothamBold, Theme.SubText, Enum.TextXAlignment.Center, Theme)
	launchSub.TextSize = 11

local launchBody = Layout.createText(launch, "Select the silo, press launch, then left-click a ground target.", UDim2.new(1, -20, 0, 34), UDim2.new(0, 10, 1, -44), Enum.Font.GothamMedium, Theme.SubText, Enum.TextXAlignment.Left, Theme)
	launchBody.TextSize = 11
	launchBody.TextWrapped = true

	local function refresh()
		if context.getSelectedBuilding() ~= model then
			return
		end
		local state = getMissileState(model)
		local ready = state.Stored > 0
		local queued = state.Queued > 0 and not ready

		readiness.Text = string.format("%d%%", math.floor((ready and 1 or state.Progress) * 100 + 0.5))
		progressFill.Size = UDim2.new(ready and 1 or math.clamp(state.Progress, 0, 1), 0, 1, 0)
		payloadMeta.Text = "$" .. tostring(state.PayloadCost) .. "   " .. tostring(state.PayloadTime) .. "s"
		ui.SellBtn.Text = "SELL (+$" .. tostring(Training.getSellRefund(model)) .. ")"

		if ready then
			fabDetail.Text = "Warhead armed: " .. tostring(state.Stored) .. "/" .. tostring(state.Capacity)
			launchState.Text = "TARGETING AVAILABLE"
			launchButton.BackgroundColor3 = Theme.Negative
			launchLabel.TextColor3 = Theme.Text
			launchSub.Text = "READY"
			launchSub.TextColor3 = Theme.Text
			local readyStroke = launchButton:FindFirstChildWhichIsA("UIStroke")
			if readyStroke then
				readyStroke.Color = Theme.Negative
				readyStroke.Transparency = 0
			end
			payloadCard.Active = false
			payloadCard.AutoButtonColor = false
		elseif queued then
			fabDetail.Text = "Approximate delivery in " .. formatMissileEta(state.Remaining)
			launchState.Text = "WARHEAD IN PRODUCTION"
			launchButton.BackgroundColor3 = Theme.PanelAlt
			launchLabel.TextColor3 = Theme.Text
			launchSub.Text = "BUILDING"
			launchSub.TextColor3 = Theme.SubText
			local queuedStroke = launchButton:FindFirstChildWhichIsA("UIStroke")
			if queuedStroke then
				queuedStroke.Color = Theme.Stroke
				queuedStroke.Transparency = 0
			end
			payloadCard.Active = false
			payloadCard.AutoButtonColor = false
		else
			fabDetail.Text = "Awaiting fabrication order"
			launchState.Text = "NO WARHEAD"
			launchButton.BackgroundColor3 = Theme.PanelAlt
			launchLabel.TextColor3 = Theme.Text
			launchSub.Text = "LOCKED"
			launchSub.TextColor3 = Theme.SubText
			local idleStroke = launchButton:FindFirstChildWhichIsA("UIStroke")
			if idleStroke then
				idleStroke.Color = Theme.Stroke
				idleStroke.Transparency = 0
			end
			payloadCard.Active = true
			payloadCard.AutoButtonColor = true
		end
	end

	payloadCard.MouseButton1Click:Connect(function()
		local state = getMissileState(model)
		if state.Stored > 0 or state.Queued > 0 then
			return
		end
		UnitEvent:FireServer("Train", model, "MissilePayload")
	end)

	launchButton.MouseButton1Click:Connect(function()
		local state = getMissileState(model)
		if state.Stored <= 0 then
			return
		end
		context.startMissileTargeting(model)
	end)

	refresh()
	context.addInspectorConnection(RunService.Heartbeat:Connect(refresh))
end

return module
