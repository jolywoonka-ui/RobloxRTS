local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local evInvite = ReplicatedStorage:WaitForChild("DiplomacyInvite")
local evRespond = ReplicatedStorage:WaitForChild("DiplomacyRespond")
local evUpdate = ReplicatedStorage:WaitForChild("DiplomacyUpdate")
local GameActive = ReplicatedStorage:WaitForChild("GameActive")

local THEME = UIStyle.Theme

local selectedPlayer
local pendingInviteTarget
local pendingSender
local openBtn
local lastOpenButtonPosition

local function updateOpenButtonPosition()
	local mainUi = playerGui:FindFirstChild("RTS_MainUI")
	local gameFrame = mainUi and mainUi:FindFirstChild("GameFrame")
	local statsBar = gameFrame and gameFrame:FindFirstChild("CommandStats")
	if statsBar and statsBar:IsA("GuiObject") then
		local pos = statsBar.Position
		local nextPosition = UDim2.new(pos.X.Scale, pos.X.Offset, pos.Y.Scale, pos.Y.Offset - 44)
		if lastOpenButtonPosition ~= nextPosition then
			lastOpenButtonPosition = nextPosition
			openBtn.Position = nextPosition
		end
	end
end

local function createLabel(parent, text, size, position, font, textSize, color, align)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or THEME.Text
	label.TextTransparency = 0
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
	button.Font = THEME.FontBody
	button.TextSize = 12
	button.TextTransparency = 0
	return button
end

local function readNestedInt(root, folderName, valueName)
	local folder = root:FindFirstChild(folderName)
	local valueObj = folder and folder:FindFirstChild(valueName)
	if valueObj and valueObj:IsA("IntValue") then
		return valueObj.Value
	end
	return 0
end

local function clearGuiChildren(container)
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function getPlayerStatus(target)
	if target == player then
		return "YOU", THEME.Accent, false
	end

	local myAlliance = player:GetAttribute("AllianceID")
	local targetAlliance = target:GetAttribute("AllianceID")
	if myAlliance and targetAlliance and myAlliance == targetAlliance then
		return "ALLY", THEME.Positive, false
	end
	if targetAlliance then
		return "IN ALLIANCE", THEME.Warning, false
	end
	return "SOLO", THEME.Accent, true
end

local screen = Instance.new("ScreenGui")
screen.Name = "DiplomacyUI"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 50
screen.Parent = playerGui

openBtn = createButton(screen, "ALLIANCE", UDim2.new(0, 145, 0, 35), UDim2.new(0, 20, 1, -424), "secondary")
openBtn.TextSize = 14
openBtn.Visible = false

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.Parent = screen

local window = Instance.new("Frame")
window.Name = "AllianceWindow"
window.Size = UDim2.new(0, 760, 0, 430)
window.Position = UDim2.new(0.5, 0, 0.5, 0)
window.AnchorPoint = Vector2.new(0.5, 0.5)
window.BorderSizePixel = 0
window.Visible = false
window.Parent = screen
UIStyle.applyPanel(window, "background")

local header = Instance.new("Frame")
header.Size = UDim2.new(1, -20, 0, 32)
header.Position = UDim2.new(0, 10, 0, 10)
header.BackgroundTransparency = 1
header.Parent = window

createLabel(header, "ALLIANCE", UDim2.new(0, 180, 1, 0), UDim2.new(0, 0, 0, 0), THEME.FontHeader, 20, THEME.Text)
local summaryText = createLabel(header, "Alliance: Solo", UDim2.new(0, 280, 1, 0), UDim2.new(0, 150, 0, 0), THEME.FontMain, 12, THEME.Text)
local closeX = createButton(header, "CLOSE", UDim2.new(0, 78, 0, 26), UDim2.new(1, -78, 0, 3), "secondary")

local rosterPanel = Instance.new("Frame")
rosterPanel.Size = UDim2.new(0, 256, 1, -60)
rosterPanel.Position = UDim2.new(0, 10, 0, 50)
rosterPanel.BorderSizePixel = 0
rosterPanel.Parent = window
UIStyle.applyPanel(rosterPanel, "panel")

createLabel(rosterPanel, "PLAYERS", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 10), THEME.FontMain, 11, THEME.SubText)

local rosterList = Instance.new("ScrollingFrame")
rosterList.Size = UDim2.new(1, -20, 1, -34)
rosterList.Position = UDim2.new(0, 10, 0, 26)
rosterList.BackgroundTransparency = 1
rosterList.BorderSizePixel = 0
rosterList.ScrollBarThickness = 4
rosterList.ScrollBarImageColor3 = THEME.Stroke
rosterList.AutomaticCanvasSize = Enum.AutomaticSize.Y
rosterList.CanvasSize = UDim2.new(0, 0, 0, 0)
rosterList.Parent = rosterPanel

local detailPanel = Instance.new("Frame")
detailPanel.Size = UDim2.new(1, -286, 1, -60)
detailPanel.Position = UDim2.new(0, 276, 0, 50)
detailPanel.BorderSizePixel = 0
detailPanel.Parent = window
UIStyle.applyPanel(detailPanel, "panel")

local detailTitle = createLabel(detailPanel, "NO PLAYER SELECTED", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 10), THEME.FontHeader, 18, THEME.Text)
local detailStatus = createLabel(detailPanel, "Select a commander from the roster.", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 34), THEME.FontBody, 12, THEME.Text)

local statusTag = createLabel(detailPanel, "IDLE", UDim2.new(0, 110, 0, 16), UDim2.new(1, -120, 0, 12), THEME.FontMain, 10, THEME.Text, Enum.TextXAlignment.Right)

local intelStrip = Instance.new("Frame")
intelStrip.Size = UDim2.new(1, -20, 0, 66)
intelStrip.Position = UDim2.new(0, 10, 0, 60)
intelStrip.BorderSizePixel = 0
intelStrip.Parent = detailPanel
UIStyle.applyPanel(intelStrip, "background")

local intelValues = {
	Credits = createLabel(intelStrip, "-", UDim2.new(0.33, -8, 0, 20), UDim2.new(0, 8, 0, 28), THEME.FontHeader, 17, THEME.Positive),
	Income = createLabel(intelStrip, "-", UDim2.new(0.33, -8, 0, 20), UDim2.new(0.33, 4, 0, 28), THEME.FontHeader, 17, THEME.Text),
	Units = createLabel(intelStrip, "-", UDim2.new(0.33, -12, 0, 20), UDim2.new(0.66, 8, 0, 28), THEME.FontHeader, 17, THEME.Text),
}
createLabel(intelStrip, "CREDITS", UDim2.new(0.33, -8, 0, 12), UDim2.new(0, 8, 0, 10), THEME.FontMain, 10, THEME.SubText)
createLabel(intelStrip, "INCOME", UDim2.new(0.33, -8, 0, 12), UDim2.new(0.33, 4, 0, 10), THEME.FontMain, 10, THEME.SubText)
createLabel(intelStrip, "UNITS", UDim2.new(0.33, -12, 0, 12), UDim2.new(0.66, 8, 0, 10), THEME.FontMain, 10, THEME.SubText)

createLabel(detailPanel, "ACTION", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 142), THEME.FontMain, 11, THEME.SubText)
local actionBody = createLabel(detailPanel, "Select a solo player to send an alliance invite.", UDim2.new(1, -20, 0, 16), UDim2.new(0, 10, 0, 162), THEME.FontBody, 12, THEME.Text)
local inviteBtn = createButton(detailPanel, "SEND INVITE", UDim2.new(0, 126, 0, 28), UDim2.new(0, 10, 0, 186), "secondary")

local alliedPanel = Instance.new("Frame")
alliedPanel.Size = UDim2.new(1, -20, 1, -232)
alliedPanel.Position = UDim2.new(0, 10, 0, 222)
alliedPanel.BorderSizePixel = 0
alliedPanel.Parent = detailPanel
UIStyle.applyPanel(alliedPanel, "background")

createLabel(alliedPanel, "CURRENT ALLIANCE", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 10), THEME.FontMain, 11, THEME.SubText)

local alliesList = Instance.new("ScrollingFrame")
alliesList.Size = UDim2.new(1, -20, 1, -34)
alliesList.Position = UDim2.new(0, 10, 0, 26)
alliesList.BackgroundTransparency = 1
alliesList.BorderSizePixel = 0
alliesList.ScrollBarThickness = 4
alliesList.ScrollBarImageColor3 = THEME.Stroke
alliesList.AutomaticCanvasSize = Enum.AutomaticSize.Y
alliesList.CanvasSize = UDim2.new(0, 0, 0, 0)
alliesList.Parent = alliedPanel

local function createModal(name, titleText, primaryLabel, secondaryLabel, primaryKind, secondaryKind)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = UDim2.new(0, 340, 0, 154)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen
	UIStyle.applyPanel(frame, "background")

	createLabel(frame, titleText, UDim2.new(1, -20, 0, 20), UDim2.new(0, 10, 0, 14), THEME.FontHeader, 18, THEME.Text, Enum.TextXAlignment.Center)
	local body = createLabel(frame, "", UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 0, 46), THEME.FontBody, 12, THEME.SubText, Enum.TextXAlignment.Center)
	body.TextWrapped = true
	local primary = createButton(frame, primaryLabel, UDim2.new(0.45, -6, 0, 28), UDim2.new(0.05, 0, 1, -40), primaryKind)
	local secondary = createButton(frame, secondaryLabel, UDim2.new(0.45, -6, 0, 28), UDim2.new(0.5, 6, 1, -40), secondaryKind)
	return frame, body, primary, secondary
end

local confirmFrame, confirmText, yesBtn, noBtn = createModal("ConfirmInvite", "CONFIRM INVITE", "SEND", "CANCEL", "primary", "secondary")
local inviteFrame, invText, accBtn, decBtn = createModal("IncomingInvite", "INCOMING INVITE", "ACCEPT", "DECLINE", "success", "danger")

local function refreshOverlay()
	overlay.Visible = window.Visible or confirmFrame.Visible or inviteFrame.Visible
end

local function setWindowVisible(visible)
	window.Visible = visible
	if not visible then
		pendingInviteTarget = nil
	end
	refreshOverlay()
end

local function rebuildDetail()
	if not selectedPlayer then
		detailTitle.Text = "NO PLAYER SELECTED"
		detailStatus.Text = "Select a commander from the roster."
		statusTag.Text = "IDLE"
		statusTag.TextColor3 = THEME.SubText
		intelValues.Credits.Text = "-"
		intelValues.Income.Text = "-"
		intelValues.Units.Text = "-"
		actionBody.Text = "Select a solo player to send an alliance invite."
		inviteBtn.Active = false
		inviteBtn.AutoButtonColor = false
		inviteBtn.BackgroundColor3 = THEME.Inset
		return
	end

	local statusText, statusColor, canInvite = getPlayerStatus(selectedPlayer)
	detailTitle.Text = string.upper(selectedPlayer.Name)
	detailStatus.Text = selectedPlayer == player and "This is your command record." or "Review current status before offering an alliance."
	statusTag.Text = statusText
	statusTag.TextColor3 = statusColor

	intelValues.Credits.Text = "$" .. tostring(readNestedInt(selectedPlayer, "Stats", "Credits"))
	intelValues.Income.Text = "+" .. tostring(readNestedInt(selectedPlayer, "PlayerStats", "Income"))
	intelValues.Income.TextColor3 = THEME.Positive
	intelValues.Units.Text = tostring(readNestedInt(selectedPlayer, "PlayerStats", "CurrentUnits"))
	actionBody.Text = canInvite and "This player is available for alliance requests." or "This commander cannot receive an invite right now."
	inviteBtn.Active = canInvite
	inviteBtn.AutoButtonColor = canInvite
	inviteBtn.BackgroundColor3 = canInvite and THEME.PanelAlt or THEME.Inset
end

local function rebuildAllies()
	clearGuiChildren(alliesList)
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = alliesList

	local myAlliance = player:GetAttribute("AllianceID")
	local allyCount = 0
	for _, target in ipairs(Players:GetPlayers()) do
		local targetAlliance = target:GetAttribute("AllianceID")
		if myAlliance and targetAlliance and myAlliance == targetAlliance then
			allyCount += 1
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 32)
			row.BorderSizePixel = 0
			row.Parent = alliesList
			UIStyle.applyPanel(row, "panel")

			createLabel(row, target.Name, UDim2.new(0.6, -10, 1, 0), UDim2.new(0, 8, 0, 0), THEME.FontMain, 12, THEME.Text)
			createLabel(row, "$" .. tostring(readNestedInt(target, "Stats", "Credits")), UDim2.new(0.4, -8, 1, 0), UDim2.new(0.6, 0, 0, 0), THEME.FontBody, 11, THEME.SubText, Enum.TextXAlignment.Right)
		end
	end

	summaryText.Text = (myAlliance and ("Alliance: " .. tostring(myAlliance)) or "Alliance: Solo") .. "  |  Allies online: " .. tostring(math.max(0, allyCount - 1))

	if allyCount == 0 then
		local empty = createLabel(alliesList, "No allies yet.", UDim2.new(1, 0, 0, 18), UDim2.new(), THEME.FontBody, 12, THEME.SubText, Enum.TextXAlignment.Center)
		empty.LayoutOrder = 1
	end
end

local function rebuildRoster()
	clearGuiChildren(rosterList)

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = rosterList

	for _, target in ipairs(Players:GetPlayers()) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, 0, 0, 46)
		row.BorderSizePixel = 0
		row.Text = ""
		row.Parent = rosterList
		UIStyle.applyButton(row, target == selectedPlayer and "primary" or "secondary")

		local statusText, statusColor = getPlayerStatus(target)
		createLabel(row, target.Name, UDim2.new(1, -104, 0, 16), UDim2.new(0, 8, 0, 6), THEME.FontMain, 12, THEME.Text)
		createLabel(row, string.format("$%d  |  +%d  |  %d units", readNestedInt(target, "Stats", "Credits"), readNestedInt(target, "PlayerStats", "Income"), readNestedInt(target, "PlayerStats", "CurrentUnits")), UDim2.new(1, -104, 0, 14), UDim2.new(0, 8, 0, 24), THEME.FontBody, 10, THEME.SubText)
		createLabel(row, statusText, UDim2.new(0, 88, 0, 14), UDim2.new(1, -96, 0.5, -7), THEME.FontMain, 10, statusColor, Enum.TextXAlignment.Right)

		row.MouseButton1Click:Connect(function()
			selectedPlayer = target
			rebuildRoster()
			rebuildDetail()
		end)
	end

	if not selectedPlayer or not selectedPlayer.Parent then
		selectedPlayer = Players:GetPlayers()[1]
	end
	rebuildDetail()
end

local function updateLists()
	if not window.Visible then
		return
	end
	rebuildAllies()
	rebuildRoster()
end

local function updateVisibility()
	local active = GameActive.Value == true
	openBtn.Visible = active
	if not active then
		window.Visible = false
		confirmFrame.Visible = false
		inviteFrame.Visible = false
		pendingInviteTarget = nil
		pendingSender = nil
	end
	refreshOverlay()
end

openBtn.MouseButton1Click:Connect(function()
	local nextVisible = not window.Visible
	setWindowVisible(nextVisible)
	if nextVisible then
		updateLists()
	end
end)

closeX.MouseButton1Click:Connect(function()
	setWindowVisible(false)
end)

overlay.MouseButton1Click:Connect(function()
	if inviteFrame.Visible then
		pendingSender = nil
		inviteFrame.Visible = false
	elseif confirmFrame.Visible then
		pendingInviteTarget = nil
		confirmFrame.Visible = false
	elseif window.Visible then
		setWindowVisible(false)
	end
	refreshOverlay()
end)

inviteBtn.MouseButton1Click:Connect(function()
	if not selectedPlayer then
		return
	end
	local _, _, canInvite = getPlayerStatus(selectedPlayer)
	if not canInvite then
		return
	end
	pendingInviteTarget = selectedPlayer
	confirmText.Text = "Invite " .. selectedPlayer.Name .. " to your alliance?"
	confirmFrame.Visible = true
	refreshOverlay()
end)

noBtn.MouseButton1Click:Connect(function()
	pendingInviteTarget = nil
	confirmFrame.Visible = false
	refreshOverlay()
end)

yesBtn.MouseButton1Click:Connect(function()
	if pendingInviteTarget and pendingInviteTarget.Parent == Players then
		evInvite:FireServer(pendingInviteTarget)
	end
	pendingInviteTarget = nil
	confirmFrame.Visible = false
	refreshOverlay()
end)

accBtn.MouseButton1Click:Connect(function()
	if pendingSender and pendingSender.Parent == Players then
		evRespond:FireServer(pendingSender, true)
	end
	pendingSender = nil
	inviteFrame.Visible = false
	refreshOverlay()
end)

decBtn.MouseButton1Click:Connect(function()
	if pendingSender and pendingSender.Parent == Players then
		evRespond:FireServer(pendingSender, false)
	end
	pendingSender = nil
	inviteFrame.Visible = false
	refreshOverlay()
end)

evUpdate.OnClientEvent:Connect(function()
	updateLists()
end)

evInvite.OnClientEvent:Connect(function(sender)
	if not sender then
		return
	end
	pendingSender = sender
	invText.Text = sender.Name .. " invited you to form an alliance."
	inviteFrame.Visible = true
	refreshOverlay()
end)

GameActive.Changed:Connect(updateVisibility)
updateVisibility()
RunService.RenderStepped:Connect(updateOpenButtonPosition)

task.spawn(function()
	while true do
		task.wait(1)
		if window.Visible then
			updateLists()
		end
	end
end)

Players.PlayerAdded:Connect(function()
	if window.Visible then
		updateLists()
	end
end)

Players.PlayerRemoving:Connect(function(leaving)
	if selectedPlayer == leaving then
		selectedPlayer = nil
	end
	if window.Visible then
		updateLists()
	end
end)
