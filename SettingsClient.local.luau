local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local KeybindConfig = require(ReplicatedStorage:WaitForChild("KeybindConfig"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local PathVisuals = require(ReplicatedStorage:WaitForChild("UnitPathVisuals"))
local UnitSelection = require(ReplicatedStorage:WaitForChild("UnitSelection"))
local SquadManager = require(ReplicatedStorage:WaitForChild("UnitSquadManager"))

local GetSettings = ReplicatedStorage:WaitForChild("GetSettings")
local SaveSettings = ReplicatedStorage:WaitForChild("SaveSettings")

local DEFAULT_SETTINGS = {
	TeleportKey = "T",
	HighlightKey = "Z",
	PingKey = "C",
	ShowDetailedSquads = true,
}

local MANUAL_SECTIONS = {
	{
		Title = "Getting Started",
		Body = "Train builders from headquarters, secure economy first, then add production and defenses. Stable energy and unit capacity matter before trying to field a large army.",
	},
	{
		Title = "Selection & Movement",
		Body = "Left-click selects. Drag-select for multiple units. Right-click moves units. Hold CTRL while giving orders to queue them. Double-clicking your own unit or building selects all of that same type.",
	},
	{
		Title = "Buildings",
		Body = "Builders place structures from the build menu. Green placement is valid. Farms require farm nodes, and some advanced structures need research before they appear.",
	},
	{
		Title = "Headquarters",
		Body = "HQ trains builders, can upgrade, and lets you retune base weapon range. Close Defense is shorter but stronger. Long Reach covers more area but deals less damage.",
	},
	{
		Title = "Production",
		Body = "Barracks, Vehicle Factory, and Airport all use queues. Click active orders to cancel them. Research unlocks new options instead of directly changing unit stats.",
	},
	{
		Title = "Combat",
		Body = "Units fire automatically once enemies enter range. Spread out against artillery and splash damage. Pressure economy and production whenever openings appear.",
	},
	{
		Title = "Transport & Utility",
		Body = "Use F for context actions like walls and transports. Transport units move troops quickly, and walls help lock down choke points. Pings are visible only to you and allies.",
	},
	{
		Title = "Superweapons",
		Body = "Missile silos fabricate one payload at a time. Once a warhead is ready, use the silo panel to launch and left-click the target area.",
	},
	{
		Title = "Alliances",
		Body = "Use the Alliance button above the command bar to review commanders, send invites, and track allied income and unit strength. Allies can coordinate pings and share battlefield pressure without blocking each other's control.",
	},
}

local THEME = UIStyle.Theme

local function mergeSettings(loaded)
	local merged = {}
	loaded = loaded or {}
	for key, value in pairs(DEFAULT_SETTINGS) do
		if loaded[key] ~= nil then
			merged[key] = loaded[key]
		else
			merged[key] = value
		end
	end
	return merged
end

local settings = mergeSettings(GetSettings:InvokeServer())
KeybindConfig.TeleportKey = settings.TeleportKey
KeybindConfig.HighlightKey = settings.HighlightKey
KeybindConfig.PingKey = settings.PingKey
player:SetAttribute("ShowDetailedSquads", settings.ShowDetailedSquads)

local function saveKeybindSettings()
	SaveSettings:FireServer({
		TeleportKey = KeybindConfig.TeleportKey,
		HighlightKey = KeybindConfig.HighlightKey,
		PingKey = KeybindConfig.PingKey,
		ShowDetailedSquads = player:GetAttribute("ShowDetailedSquads") == true,
	})
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "SettingsUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.DisplayOrder = 150
screenGui.Parent = playerGui

local settingsBtn = UIStyle.createButton(screenGui, "SYSTEM", UDim2.new(0, 70, 0, 28), UDim2.new(1, -82, 0, 14), "ghost")
local faqBtn = UIStyle.createButton(screenGui, "MANUAL", UDim2.new(0, 70, 0, 28), UDim2.new(1, -158, 0, 14), "ghost")

local overlay = Instance.new("TextButton")
overlay.Size = UDim2.new(1, 0, 1, 0)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.55
overlay.BorderSizePixel = 0
overlay.Text = ""
overlay.AutoButtonColor = false
overlay.Visible = false
overlay.Parent = screenGui

local desk = Instance.new("Frame")
desk.Name = "CommandDesk"
desk.Size = UDim2.new(0, 912, 0, 600)
desk.AnchorPoint = Vector2.new(0.5, 0.5)
desk.Position = UDim2.new(0.5, 0, 0.5, 0)
desk.BorderSizePixel = 0
desk.Visible = false
desk.Parent = screenGui
UIStyle.applyPanel(desk, "background")

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, -20, 0, 32)
titleBar.Position = UDim2.new(0, 10, 0, 10)
titleBar.BackgroundTransparency = 1
titleBar.Parent = desk

local deskTitle = UIStyle.createLabel(titleBar, "SYSTEM", UDim2.new(1, -90, 1, 0), UDim2.new(0, 0, 0, 0), THEME.FontHeader, 24, THEME.Text)
local closeBtn = UIStyle.createButton(titleBar, "CLOSE", UDim2.new(0, 82, 0, 26), UDim2.new(1, -82, 0, 3), "secondary")

local navRail = Instance.new("Frame")
navRail.Size = UDim2.new(1, -20, 0, 32)
navRail.Position = UDim2.new(0, 10, 0, 50)
navRail.BackgroundTransparency = 1
navRail.Parent = desk

local navLayout = Instance.new("UIListLayout")
navLayout.FillDirection = Enum.FillDirection.Horizontal
navLayout.Padding = UDim.new(0, 8)
navLayout.Parent = navRail

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -20, 1, -98)
content.Position = UDim2.new(0, 10, 0, 84)
content.BorderSizePixel = 0
content.Parent = desk
UIStyle.applyPanel(content, "panel")

local settingsPage = Instance.new("Frame")
settingsPage.Size = UDim2.new(1, 0, 1, 0)
settingsPage.BackgroundTransparency = 1
settingsPage.Parent = content

local manualPage = Instance.new("Frame")
manualPage.Size = UDim2.new(1, 0, 1, 0)
manualPage.BackgroundTransparency = 1
manualPage.Visible = false
manualPage.Parent = content

local navButtons = {}
local currentTab = "SETTINGS"

local function setNavActive(name)
	for tabName, button in pairs(navButtons) do
		local active = tabName == name
		button.BackgroundColor3 = active and THEME.PanelAlt or THEME.Panel
		local stroke = button:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Color = active and THEME.Selection or THEME.Stroke
		end
	end
	settingsPage.Visible = name == "SETTINGS"
	manualPage.Visible = name == "MANUAL"
	currentTab = name
	deskTitle.Text = name == "SETTINGS" and "SYSTEM" or "MANUAL"
end

local function addNavButton(name, caption)
	local button = UIStyle.createButton(navRail, caption, UDim2.new(0, 120, 1, 0), UDim2.new(), "secondary")
	button.MouseButton1Click:Connect(function()
		setNavActive(name)
	end)
	navButtons[name] = button
end

addNavButton("SETTINGS", "SYSTEM")
addNavButton("MANUAL", "MANUAL")

local function createSectionCard(parent, titleText, bodyText, size, position)
	local card = Instance.new("Frame")
	card.Size = size
	card.Position = position
	card.BorderSizePixel = 0
	card.Parent = parent
	UIStyle.applyPanel(card, "panel")
	UIStyle.createLabel(card, titleText, UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 10), THEME.FontMain, 12, THEME.SubText)
	UIStyle.createLabel(card, bodyText, UDim2.new(1, -16, 0, 20), UDim2.new(0, 8, 0, 30), THEME.FontHeader, 18, THEME.Text)
	return card
end

local function createRowButton(row, settingName)
	local button = UIStyle.createButton(row, KeybindConfig[settingName], UDim2.new(0, 92, 0, 26), UDim2.new(1, -100, 0.5, -13), "secondary")
	button.MouseButton1Click:Connect(function()
		button.Text = "..."
		local connection
		connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed then
				return
			end
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local keyName = input.KeyCode.Name
				KeybindConfig[settingName] = keyName
				button.Text = keyName
				saveKeybindSettings()
				if connection then
					connection:Disconnect()
				end
			end
		end)
	end)
	return button
end

local function createToggleButton(row, state, callback)
	local button = UIStyle.createButton(row, state and "ON" or "OFF", UDim2.new(0, 92, 0, 26), UDim2.new(1, -100, 0.5, -13), state and "success" or "danger")
	button.MouseButton1Click:Connect(function()
		state = not state
		button.Text = state and "ON" or "OFF"
		UIStyle.applyButton(button, state and "success" or "danger")
		button.Font = THEME.FontMain
		button.TextSize = 12
		callback(state)
	end)
	return button
end

local function buildSettingsPage()
	local function createSettingRow(parent, titleText, subtitleText, layoutOrder)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 54)
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.LayoutOrder = layoutOrder
		row.Parent = parent

		UIStyle.createLabel(row, titleText, UDim2.new(0.62, -10, 0, 18), UDim2.new(0, 0, 0, 6), THEME.FontMain, 14, THEME.Text)
		UIStyle.createLabel(row, subtitleText, UDim2.new(0.62, -10, 0, 16), UDim2.new(0, 0, 0, 28), THEME.FontBody, 12, THEME.SubText)
		UIStyle.createDivider(row, 53, 1)
		return row
	end

	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, -20, 1, -20)
	shell.Position = UDim2.new(0, 10, 0, 10)
	shell.BackgroundTransparency = 1
	shell.Parent = settingsPage

	local inputList = Instance.new("Frame")
	inputList.Size = UDim2.new(0.5, -16, 1, 0)
	inputList.BackgroundTransparency = 1
	inputList.Parent = shell
	local inputLayout = Instance.new("UIListLayout")
	inputLayout.Padding = UDim.new(0, 8)
	inputLayout.Parent = inputList

	local visualsList = Instance.new("Frame")
	visualsList.Size = UDim2.new(0.5, -16, 1, 0)
	visualsList.Position = UDim2.new(0.5, 16, 0, 0)
	visualsList.BackgroundTransparency = 1
	visualsList.Parent = shell
	local visualsLayout = Instance.new("UIListLayout")
	visualsLayout.Padding = UDim.new(0, 8)
	visualsLayout.Parent = visualsList

	local verticalDivider = Instance.new("Frame")
	verticalDivider.Size = UDim2.new(0, 1, 1, -8)
	verticalDivider.Position = UDim2.new(0.5, 0, 0, 4)
	verticalDivider.BackgroundColor3 = THEME.Stroke
	verticalDivider.BackgroundTransparency = 0.6
	verticalDivider.BorderSizePixel = 0
	verticalDivider.Parent = shell

	local inputHeader = Instance.new("Frame")
	inputHeader.Size = UDim2.new(1, 0, 0, 46)
	inputHeader.BackgroundTransparency = 1
	inputHeader.LayoutOrder = 0
	inputHeader.Parent = inputList
	UIStyle.createLabel(inputHeader, "INPUT", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 0), THEME.FontMain, 12, THEME.SubText)
	UIStyle.createLabel(inputHeader, "Control bindings", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 20), THEME.FontBody, 18, THEME.Text)

	local visualsHeader = Instance.new("Frame")
	visualsHeader.Size = UDim2.new(1, 0, 0, 46)
	visualsHeader.BackgroundTransparency = 1
	visualsHeader.LayoutOrder = 0
	visualsHeader.Parent = visualsList
	UIStyle.createLabel(visualsHeader, "DISPLAY", UDim2.new(1, 0, 0, 14), UDim2.new(0, 0, 0, 0), THEME.FontMain, 12, THEME.SubText)
	UIStyle.createLabel(visualsHeader, "Battlefield helpers", UDim2.new(1, 0, 0, 20), UDim2.new(0, 0, 0, 20), THEME.FontBody, 18, THEME.Text)

	local teleportRow = createSettingRow(inputList, "Teleport Key", "Quick reposition order", 1)
	createRowButton(teleportRow, "TeleportKey")
	local highlightRow = createSettingRow(inputList, "Highlight Key", "Toggle range and emphasis helpers", 2)
	createRowButton(highlightRow, "HighlightKey")
	local pingRow = createSettingRow(inputList, "Ping Key", "Teammate ping marker", 3)
	createRowButton(pingRow, "PingKey")

	local showPaths = player:GetAttribute("ShowUnitPaths")
	if showPaths == nil then
		showPaths = true
	end
	PathVisuals.setShowPaths(showPaths)

	local showRanges = player:GetAttribute("ShowUnitRanges")
	if showRanges == nil then
		showRanges = false
	end
	UnitSelection.setShowRanges(showRanges)

	local showDetailedSquads = player:GetAttribute("ShowDetailedSquads")
	if showDetailedSquads == nil then
		showDetailedSquads = settings.ShowDetailedSquads == true
		player:SetAttribute("ShowDetailedSquads", showDetailedSquads)
	end
	SquadManager.setDetailedMode(showDetailedSquads)

	local pathsRow = createSettingRow(visualsList, "Show Paths", "Display movement route previews", 1)
	createToggleButton(pathsRow, showPaths, function(state)
		PathVisuals.setShowPaths(state)
		player:SetAttribute("ShowUnitPaths", state)
	end)

	local rangesRow = createSettingRow(visualsList, "Show Ranges", "Display unit engagement rings", 2)
	createToggleButton(rangesRow, showRanges, function(state)
		UnitSelection.setShowRanges(state)
		player:SetAttribute("ShowUnitRanges", state)
	end)

	local squadsRow = createSettingRow(visualsList, "Detailed Squads", "Show unit rows and health bars in the squad panel", 3)
	createToggleButton(squadsRow, showDetailedSquads, function(state)
		player:SetAttribute("ShowDetailedSquads", state)
		SquadManager.setDetailedMode(state)
		saveKeybindSettings()
	end)
end

local function buildManualPage()
	local shell = Instance.new("Frame")
	shell.Size = UDim2.new(1, -20, 1, -20)
	shell.Position = UDim2.new(0, 10, 0, 10)
	shell.BorderSizePixel = 0
	shell.BackgroundTransparency = 1
	shell.Parent = manualPage

	local categoryRail = Instance.new("Frame")
	categoryRail.Size = UDim2.new(0, 180, 1, -20)
	categoryRail.Position = UDim2.new(0, 10, 0, 10)
	categoryRail.BackgroundTransparency = 1
	categoryRail.Parent = shell

	local railLayout = Instance.new("UIListLayout")
	railLayout.Padding = UDim.new(0, 6)
	railLayout.Parent = categoryRail

	local contentPanel = Instance.new("Frame")
	contentPanel.Size = UDim2.new(1, -210, 1, -20)
	contentPanel.Position = UDim2.new(0, 200, 0, 10)
	contentPanel.BackgroundTransparency = 1
	contentPanel.BorderSizePixel = 0
	contentPanel.Parent = shell

	local manualDivider = Instance.new("Frame")
	manualDivider.Size = UDim2.new(0, 1, 1, -20)
	manualDivider.Position = UDim2.new(0, 190, 0, 10)
	manualDivider.BackgroundColor3 = THEME.Stroke
	manualDivider.BackgroundTransparency = 0.65
	manualDivider.BorderSizePixel = 0
	manualDivider.Parent = shell

	local manualPages = {}
	local manualButtons = {}
	local activeManualTitle
	local activeManualBody

	local function setManualSection(title)
		for sectionTitle, button in pairs(manualButtons) do
			local active = sectionTitle == title
			button.BackgroundColor3 = active and THEME.PanelSoft or THEME.PanelAlt
			local stroke = button:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Color = active and THEME.Selection or THEME.Stroke
				stroke.Transparency = active and 0.15 or 0.5
			end
		end

		local section = manualPages[title]
		if section then
			activeManualTitle.Text = string.upper(section.Title)
			activeManualBody.Text = section.Body
		end
	end

	UIStyle.createLabel(contentPanel, "FIELD MANUAL", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 12), THEME.FontMain, 12, THEME.SubText)
	activeManualTitle = UIStyle.createLabel(contentPanel, "", UDim2.new(1, -24, 0, 28), UDim2.new(0, 12, 0, 34), THEME.FontHeader, 22, THEME.Text)
	activeManualBody = UIStyle.createLabel(contentPanel, "", UDim2.new(1, -24, 1, -88), UDim2.new(0, 12, 0, 76), THEME.FontBody, 16, THEME.Text)
	activeManualBody.TextWrapped = true
	activeManualBody.TextYAlignment = Enum.TextYAlignment.Top

	for index, section in ipairs(MANUAL_SECTIONS) do
		manualPages[section.Title] = section

		local button = UIStyle.createButton(categoryRail, string.upper(section.Title), UDim2.new(1, 0, 0, 32), UDim2.new(), "secondary")
		button.LayoutOrder = index
		button.MouseButton1Click:Connect(function()
			setManualSection(section.Title)
		end)
		manualButtons[section.Title] = button
	end

	if MANUAL_SECTIONS[1] then
		setManualSection(MANUAL_SECTIONS[1].Title)
	end
end

buildSettingsPage()
buildManualPage()
setNavActive("SETTINGS")

local function showDesk(tabName)
	setNavActive(tabName or currentTab)
	overlay.Visible = true
	desk.Visible = true
	desk.Position = UDim2.new(0.5, 0, 0.5, 14)
	TweenService:Create(desk, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 0),
	}):Play()
end

local function hideDesk()
	overlay.Visible = false
	desk.Visible = false
end

settingsBtn.MouseButton1Click:Connect(function()
	if desk.Visible and currentTab == "SETTINGS" then
		hideDesk()
	else
		showDesk("SETTINGS")
	end
end)

faqBtn.MouseButton1Click:Connect(function()
	if desk.Visible and currentTab == "MANUAL" then
		hideDesk()
	else
		showDesk("MANUAL")
	end
end)

closeBtn.MouseButton1Click:Connect(hideDesk)
overlay.MouseButton1Click:Connect(hideDesk)

local tipPopup = Instance.new("Frame")
tipPopup.Name = "HelpPrompt"
tipPopup.Size = UDim2.new(0, 388, 0, 92)
tipPopup.Position = UDim2.new(1, -390, 0, 54)
tipPopup.BorderSizePixel = 0
tipPopup.Parent = screenGui
UIStyle.applyPanel(tipPopup, "background")

UIStyle.createLabel(tipPopup, "FIELD MANUAL", UDim2.new(1, -24, 0, 16), UDim2.new(0, 12, 0, 10), THEME.FontMain, 12, THEME.SubText)
local promptText = UIStyle.createLabel(tipPopup, "Open MANUAL in the top-right corner for the controls and game systems.", UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 0, 28), THEME.FontBody, 13, THEME.Text)
promptText.TextWrapped = true

local openManualBtn = UIStyle.createButton(tipPopup, "OPEN", UDim2.new(0, 78, 0, 24), UDim2.new(0, 12, 1, -34), "primary")
local dismissPromptBtn = UIStyle.createButton(tipPopup, "DISMISS", UDim2.new(0, 92, 0, 24), UDim2.new(1, -104, 1, -34), "secondary")

local function hidePrompt()
	if not tipPopup or not tipPopup.Parent then
		return
	end
	local tween = TweenService:Create(tipPopup, TweenInfo.new(0.18), { BackgroundTransparency = 1 })
	tween:Play()
	for _, child in ipairs(tipPopup:GetChildren()) do
		if child:IsA("GuiObject") then
			local goal = {}
			if child:IsA("TextLabel") or child:IsA("TextButton") then
				goal.TextTransparency = 1
			end
			if not child:IsA("TextLabel") then
				goal.BackgroundTransparency = 1
			end
			TweenService:Create(child, TweenInfo.new(0.18), goal):Play()
		end
	end
	task.delay(0.2, function()
		if tipPopup then
			tipPopup:Destroy()
		end
	end)
end

openManualBtn.MouseButton1Click:Connect(function()
	showDesk("MANUAL")
	hidePrompt()
end)

dismissPromptBtn.MouseButton1Click:Connect(hidePrompt)

task.delay(12, function()
	if tipPopup and tipPopup.Parent then
		hidePrompt()
	end
end)
