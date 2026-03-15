local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local mapVoteEvent = ReplicatedStorage:WaitForChild("MapVoteEvent")
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local THEME = UIStyle.Theme

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MapVoteUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = playerGui

local function setLobbyStatusVisible(visible)
	local mainUi = playerGui:FindFirstChild("RTS_MainUI")
	if not mainUi then
		return
	end
	local lobbyBar = mainUi:FindFirstChild("LobbyBar")
	if lobbyBar and lobbyBar:IsA("GuiObject") then
		lobbyBar.Visible = visible
	end
end

local overlay = Instance.new("Frame")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel = 0
overlay.Parent = screenGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.new(0, 1160, 0, 410)
root.AnchorPoint = Vector2.new(0.5, 0)
root.Position = UDim2.new(0.5, 0, 0, 70)
root.BackgroundTransparency = 1
root.Parent = screenGui

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

createLabel(root, "MAP VOTE", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 0), THEME.FontHeader, 24, THEME.Text, Enum.TextXAlignment.Center)
local subtitle = createLabel(root, "Choose the next battlefield", UDim2.new(1, 0, 0, 16), UDim2.new(0, 0, 0, 28), THEME.FontBody, 12, THEME.SubText, Enum.TextXAlignment.Center)

local timerLabel = Instance.new("TextLabel")
timerLabel.Size = UDim2.new(0, 190, 0, 28)
timerLabel.Position = UDim2.new(0.5, -95, 0, 56)
timerLabel.BorderSizePixel = 0
timerLabel.TextColor3 = THEME.Text
timerLabel.Font = THEME.FontMain
timerLabel.TextSize = 13
timerLabel.Text = "10s"
timerLabel.Parent = root
UIStyle.applyPanel(timerLabel, "panel")

local cardsHolder = Instance.new("Frame")
cardsHolder.Size = UDim2.new(1, 0, 0, 308)
cardsHolder.Position = UDim2.new(0, 0, 0, 98)
cardsHolder.BackgroundTransparency = 1
cardsHolder.Parent = root

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Horizontal
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
listLayout.Padding = UDim.new(0, 16)
listLayout.Parent = cardsHolder

local voteEndsAt = 0
local selectedTemplateName = nil
local cardByTemplate = {}

local function normalizeImageValue(value)
	local image = tostring(value or "")
	if image ~= "" and string.match(image, "^%d+$") then
		return "rbxassetid://" .. image
	end
	return image
end

local function createCard(index)
	local card = Instance.new("TextButton")
	card.Name = "MapCard" .. index
	card.AutoButtonColor = true
	card.Size = UDim2.new(0, 356, 1, 0)
	card.BorderSizePixel = 0
	card.Text = ""
	card.Parent = cardsHolder
	UIStyle.applyButton(card, "secondary")
	UIStyle.addShadow(card, 0.84)

	local previewFrame = Instance.new("Frame")
	previewFrame.Name = "PreviewFrame"
	previewFrame.Size = UDim2.new(1, -20, 0, 158)
	previewFrame.Position = UDim2.new(0, 10, 0, 10)
	previewFrame.BackgroundColor3 = THEME.Inset
	previewFrame.BorderSizePixel = 0
	previewFrame.Parent = card
	UIStyle.addStroke(previewFrame, 1, THEME.Stroke, 0.6)

	local previewImage = Instance.new("ImageLabel")
	previewImage.Name = "PreviewImage"
	previewImage.Size = UDim2.new(1, 0, 1, 0)
	previewImage.BackgroundTransparency = 1
	previewImage.BorderSizePixel = 0
	previewImage.ScaleType = Enum.ScaleType.Crop
	previewImage.Parent = previewFrame

	local previewShade = Instance.new("Frame")
	previewShade.Size = UDim2.new(1, 0, 1, 0)
	previewShade.BackgroundColor3 = Color3.new(0, 0, 0)
	previewShade.BackgroundTransparency = 0.45
	previewShade.BorderSizePixel = 0
	previewShade.Parent = previewFrame

	local previewFallback = createLabel(previewFrame, "PREVIEW UNAVAILABLE", UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0.5, -9), THEME.FontMain, 11, THEME.SubText, Enum.TextXAlignment.Center)
	previewFallback.Name = "PreviewFallback"

	local nameLabel = createLabel(card, "MAP NAME", UDim2.new(1, -16, 0, 22), UDim2.new(0, 10, 0, 178), THEME.FontHeader, 18, THEME.Text)
	nameLabel.Name = "NameLabel"
	local sizeLabel = createLabel(card, "SIZE TBD", UDim2.new(1, -16, 0, 14), UDim2.new(0, 10, 0, 204), THEME.FontBody, 11, THEME.SubText)
	sizeLabel.Name = "SizeLabel"
	local percentLabel = createLabel(card, "0%", UDim2.new(0.42, -10, 0, 22), UDim2.new(0, 10, 0, 230), THEME.FontHeader, 22, THEME.Text)
	percentLabel.Name = "PercentLabel"
	local bodyLabel = createLabel(card, "Vote to select this map.", UDim2.new(1, -16, 0, 44), UDim2.new(0, 10, 0, 258), THEME.FontBody, 12, THEME.SubText)
	bodyLabel.Name = "BodyLabel"
	bodyLabel.TextWrapped = true
	bodyLabel.TextYAlignment = Enum.TextYAlignment.Top

	local voteMarker = createLabel(card, "YOUR VOTE", UDim2.new(0, 90, 0, 16), UDim2.new(1, -100, 0, 232), THEME.FontMain, 10, THEME.Positive, Enum.TextXAlignment.Right)
	voteMarker.Name = "VoteMarker"
	voteMarker.Visible = false

	local lockedOverlay = createLabel(card, "UNAVAILABLE", UDim2.new(1, -16, 0, 16), UDim2.new(0, 10, 1, -22), THEME.FontMain, 10, THEME.Negative, Enum.TextXAlignment.Left)
	lockedOverlay.Name = "LockedOverlay"
	lockedOverlay.Visible = false

	return card
end

local cards = {
	createCard(1),
	createCard(2),
	createCard(3),
}

local function applyCardVisual(card, isSelected, isLocked)
	card.BackgroundColor3 = isSelected and THEME.PanelAlt or THEME.Panel
	local stroke = card:FindFirstChildWhichIsA("UIStroke")
	if stroke then
		if isLocked then
			stroke.Color = THEME.Negative
		elseif isSelected then
			stroke.Color = THEME.Selection
		else
			stroke.Color = THEME.Stroke
		end
	end
end

local function refreshCards(payload)
	cardByTemplate = {}
	local options = payload.options or {}
	for index, card in ipairs(cards) do
		local option = options[index]
		if option then
			card.Visible = true
			card:SetAttribute("TemplateName", option.templateName)
			card.NameLabel.Text = option.displayName
			card.SizeLabel.Text = option.sizeLabel
			card.PercentLabel.Text = string.format("%d%%", option.percent or 0)
			card.BodyLabel.Text = option.locked and "This map cannot be selected right now." or "Click to cast your vote."
			local imageValue = normalizeImageValue(option.image)
			local previewFrame = card:FindFirstChild("PreviewFrame")
			local previewImage = previewFrame and previewFrame:FindFirstChild("PreviewImage")
			local previewFallback = previewFrame and previewFrame:FindFirstChild("PreviewFallback")
			if previewImage and previewImage:IsA("ImageLabel") then
				previewImage.Image = imageValue
				previewImage.Visible = imageValue ~= ""
			end
			if previewFallback and previewFallback:IsA("TextLabel") then
				previewFallback.Visible = imageValue == ""
			end
			card.VoteMarker.Visible = option.templateName ~= "" and selectedTemplateName == option.templateName
			card.LockedOverlay.Visible = option.locked == true
			applyCardVisual(card, option.templateName ~= "" and selectedTemplateName == option.templateName, option.locked == true)
			if option.templateName ~= "" then
				cardByTemplate[option.templateName] = card
			end
		else
			card.Visible = false
		end
	end
end

for _, card in ipairs(cards) do
	card.MouseButton1Click:Connect(function()
		if not screenGui.Enabled then
			return
		end
		local templateName = card:GetAttribute("TemplateName")
		if typeof(templateName) ~= "string" or templateName == "" then
			return
		end
		if card.LockedOverlay.Visible then
			return
		end
		selectedTemplateName = templateName
		mapVoteEvent:FireServer("Vote", templateName)
		for template, mappedCard in pairs(cardByTemplate) do
			mappedCard.VoteMarker.Visible = template == selectedTemplateName
			applyCardVisual(mappedCard, template == selectedTemplateName, mappedCard.LockedOverlay.Visible)
		end
	end)
end

RunService.RenderStepped:Connect(function()
	if not screenGui.Enabled or voteEndsAt <= 0 then
		return
	end
	local remaining = math.max(0, voteEndsAt - workspace:GetServerTimeNow())
	timerLabel.Text = string.format("VOTING ENDS IN %ds", math.ceil(remaining))
end)

mapVoteEvent.OnClientEvent:Connect(function(action, payload)
	if action == "Start" then
		selectedTemplateName = nil
		voteEndsAt = (payload and payload.endsAt) or 0
		screenGui.Enabled = true
		setLobbyStatusVisible(false)
		subtitle.Text = "Choose the next battlefield"
		refreshCards(payload or {})
	elseif action == "State" then
		if payload then
			voteEndsAt = payload.endsAt or voteEndsAt
			refreshCards(payload)
		end
	elseif action == "End" then
		voteEndsAt = 0
		subtitle.Text = "Winner: " .. tostring((payload and payload.winnerDisplayName) or "UNKNOWN")
		timerLabel.Text = "LOADING"
		task.delay(2, function()
			screenGui.Enabled = false
			setLobbyStatusVisible(true)
			subtitle.Text = "Choose the next battlefield"
		end)
	end
end)
