-- UIInspector.Layout (ModuleScript, ReplicatedStorage)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local module = {}

function module.addStroke(obj, thickness, color)
	return UIStyle.addStroke(obj, thickness, color)
end

function module.addCorner(obj, radius)
	return UIStyle.addCorner(obj, radius or UIStyle.Theme.Corner)
end

function module.createPanel(parent, size, pos, theme)
	local panel = Instance.new("Frame")
	panel.Size = size
	panel.Position = pos
	panel.Parent = parent
	UIStyle.applyPanel(panel, "background")
	return panel
end

function module.createText(parent, text, size, pos, font, color, align, theme)
	local label = Instance.new("TextLabel")
	label.Size = size or UDim2.new(1, 0, 1, 0)
	label.Position = pos or UDim2.new(0, 0, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or theme.Text
	label.Font = theme.FontBody
	label.TextSize = 16
	label.Parent = parent
	if align then
		label.TextXAlignment = align
	end
	return label
end

function module.createBaseUI(mainScreen, gameFrame, theme, constants)
	local ui = {}

	ui.InspectorFrame = module.createPanel(gameFrame, constants.INSPECTOR_SIZE_FULL, constants.INSPECTOR_POS_FULL, theme)
	ui.InspectorFrame.Visible = false

	ui.InspTitle = module.createText(ui.InspectorFrame, "BUILDING NAME", UDim2.new(1, -20, 0, 40), UDim2.new(0, 10, 0, 5), Enum.Font.GothamBlack, theme.Text, Enum.TextXAlignment.Center, theme)
	ui.InspTitle.TextSize = 22

	ui.HPContainer = Instance.new("Frame", ui.InspectorFrame)
	ui.HPContainer.Size = UDim2.new(1, -40, 0, 20)
	ui.HPContainer.Position = UDim2.new(0, 20, 0, 50)
	ui.HPContainer.BackgroundColor3 = theme.Inset
	module.addCorner(ui.HPContainer, theme.Corner)
	module.addStroke(ui.HPContainer, 1, theme.Stroke)

	ui.HPBarFill = Instance.new("Frame", ui.HPContainer)
	ui.HPBarFill.Size = UDim2.new(1, 0, 1, 0)
	ui.HPBarFill.BackgroundColor3 = theme.Green
	module.addCorner(ui.HPBarFill, theme.Corner)

	ui.GarrisonLabel = module.createText(ui.InspectorFrame, "GARRISON: 0/0", UDim2.new(1, -20, 0, 30), UDim2.new(0, 10, 0, 75), Enum.Font.GothamBold, theme.SubText, Enum.TextXAlignment.Left, theme)
	ui.GarrisonLabel.TextSize = 14
	ui.GarrisonLabel.Visible = false

	ui.RelationshipLabel = module.createText(ui.InspectorFrame, "", UDim2.new(1, -20, 0, 24), UDim2.new(0, 10, 0, 80), Enum.Font.GothamBold, theme.Red, Enum.TextXAlignment.Center, theme)
	ui.RelationshipLabel.TextSize = 16
	ui.RelationshipLabel.Visible = false

	ui.SpecialStatusLabel = module.createText(ui.InspectorFrame, "", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 102), Enum.Font.GothamBold, theme.BlueWarm, Enum.TextXAlignment.Center, theme)
	ui.SpecialStatusLabel.TextSize = 13
	ui.SpecialStatusLabel.Visible = false

	ui.QueueLabel = module.createText(ui.InspectorFrame, "TRAINING QUEUE", UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 118), Enum.Font.GothamBold, theme.SubText, Enum.TextXAlignment.Left, theme)
	ui.QueueLabel.TextSize = 11

	ui.QueueErrorFrame = Instance.new("TextLabel", mainScreen)
	ui.QueueErrorFrame.Size = UDim2.new(0, 700, 0, 44)
	ui.QueueErrorFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	ui.QueueErrorFrame.Position = UDim2.new(0.5, 0, 0.45, 0)
	ui.QueueErrorFrame.BackgroundTransparency = 1
	ui.QueueErrorFrame.BorderSizePixel = 0
	ui.QueueErrorFrame.Visible = false
	ui.QueueErrorFrame.ZIndex = 50
	ui.QueueErrorFrame.Text = ""
	ui.QueueErrorFrame.TextColor3 = theme.Red
	ui.QueueErrorFrame.TextXAlignment = Enum.TextXAlignment.Center
	ui.QueueErrorFrame.TextYAlignment = Enum.TextYAlignment.Center
	ui.QueueErrorFrame.Font = theme.FontBody
	ui.QueueErrorFrame.TextSize = 24

	ui.QueueScroll = Instance.new("ScrollingFrame", ui.InspectorFrame)
	ui.QueueScroll.Size = UDim2.new(1, -20, 0, 60)
	ui.QueueScroll.Position = UDim2.new(0, 10, 0, 143)
	ui.QueueScroll.BackgroundTransparency = 1
	ui.QueueScroll.BorderSizePixel = 0
	ui.QueueScroll.ScrollingDirection = Enum.ScrollingDirection.X
	ui.QueueScroll.ScrollBarThickness = 4
	ui.QueueScroll.AutomaticCanvasSize = Enum.AutomaticSize.X

	local queueLayout = Instance.new("UIListLayout", ui.QueueScroll)
	queueLayout.FillDirection = Enum.FillDirection.Horizontal
	queueLayout.Padding = UDim.new(0, 5)

	local queuePad = Instance.new("UIPadding", ui.QueueScroll)
	queuePad.PaddingLeft = UDim.new(0, 0)
	queuePad.PaddingTop = UDim.new(0, 0)

	ui.TrainFrame = Instance.new("ScrollingFrame", ui.InspectorFrame)
	ui.TrainFrame.Size = constants.TRAIN_SIZE_WITH_QUEUE
	ui.TrainFrame.Position = constants.TRAIN_POS_WITH_QUEUE
	ui.TrainFrame.BackgroundTransparency = 1
	ui.TrainFrame.BorderSizePixel = 0
	ui.TrainFrame.ScrollBarThickness = 5
	ui.TrainFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

	local trainPad = Instance.new("UIPadding", ui.TrainFrame)
	trainPad.PaddingLeft = UDim.new(0, 8)
	trainPad.PaddingRight = UDim.new(0, 8)
	trainPad.PaddingTop = UDim.new(0, 2)
	trainPad.PaddingBottom = UDim.new(0, 2)

	local trainLayout = Instance.new("UIListLayout", ui.TrainFrame)
	trainLayout.Padding = UDim.new(0, 6)

	ui.UpgradeContainer = Instance.new("Frame", ui.InspectorFrame)
	ui.UpgradeContainer.Size = UDim2.new(1, -40, 0, 20)
	ui.UpgradeContainer.Position = UDim2.new(0, 20, 1, -215)
	ui.UpgradeContainer.BackgroundColor3 = theme.Inset
	ui.UpgradeContainer.Visible = false
	module.addCorner(ui.UpgradeContainer, theme.Corner)
	module.addStroke(ui.UpgradeContainer, 1, theme.Stroke)

	ui.UpgradeProgress = Instance.new("Frame", ui.UpgradeContainer)
	ui.UpgradeProgress.Size = UDim2.new(0, 0, 1, 0)
	ui.UpgradeProgress.BackgroundColor3 = theme.Accent
	module.addCorner(ui.UpgradeProgress, theme.Corner)

	ui.SellBtn = Instance.new("TextButton", ui.InspectorFrame)
	ui.SellBtn.Size = UDim2.new(1, -40, 0, 40)
	ui.SellBtn.Position = UDim2.new(0, 20, 1, -145)
	ui.SellBtn.Text = "SELL BUILDING"
	ui.SellBtn.Font = theme.FontBody
	ui.SellBtn.TextSize = 14
	UIStyle.applyButton(ui.SellBtn, "danger")

	ui.UpgradeBtn = Instance.new("TextButton", ui.InspectorFrame)
	ui.UpgradeBtn.Size = UDim2.new(1, -40, 0, 40)
	ui.UpgradeBtn.Position = UDim2.new(0, 20, 1, -95)
	ui.UpgradeBtn.Text = "UPGRADE"
	ui.UpgradeBtn.Font = theme.FontBody
	ui.UpgradeBtn.TextSize = 14
	ui.UpgradeBtn.Visible = false
	UIStyle.applyButton(ui.UpgradeBtn, "primary")

	ui.ActionBtn = Instance.new("TextButton", ui.InspectorFrame)
	ui.ActionBtn.Size = UDim2.new(1, -40, 0, 40)
	ui.ActionBtn.Position = UDim2.new(0, 20, 1, -45)
	ui.ActionBtn.Text = "SPECIAL ACTION"
	ui.ActionBtn.Font = theme.FontBody
	ui.ActionBtn.TextSize = 14
	ui.ActionBtn.Visible = false
	UIStyle.applyButton(ui.ActionBtn, "warning")

	return ui
end

return module
