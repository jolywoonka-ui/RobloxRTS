local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local StartBuildEvent = ReplicatedStorage:WaitForChild("StartBuild")

local localPlayer = Players.LocalPlayer
local THEME = UIStyle.Theme

local UIBuildMenu = {}

local BuildDock
local TabsHolder
local Scroll
local collapseBtn
local statsContainer
local currentTab = "ECONOMY"
local collapsed = false
local expandedPos
local collapsedPos
local statsExpandedPos
local statsCollapsedPos
local researchAttributeConnections = {}
local refreshBuildMenu
local TAB_FONT = Enum.Font.GothamMedium

local BUILD_DOCK_SIZE = Vector2.new(510, 386)
local EXPANDED_OFFSET = Vector2.new(20, -426)
local COLLAPSED_OFFSET = Vector2.new(20, -97)
local STATS_EXPANDED_OFFSET = Vector2.new(20, -494)
local STATS_COLLAPSED_OFFSET = Vector2.new(20, -183)

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

local function isResearchUnlocked(researchId)
	if not researchId then
		return true
	end
	return localPlayer:GetAttribute("Research_" .. tostring(researchId)) == true
end

local function bindResearchRefresh()
	for _, conn in ipairs(researchAttributeConnections) do
		conn:Disconnect()
	end
	researchAttributeConnections = {}

	for researchId in pairs(Config.Research or {}) do
		table.insert(researchAttributeConnections, localPlayer:GetAttributeChangedSignal("Research_" .. tostring(researchId)):Connect(function()
			if BuildDock and refreshBuildMenu then
				refreshBuildMenu()
			end
		end))
	end
end

local function updateTabVisuals()
	for _, child in ipairs(TabsHolder:GetChildren()) do
		if child:IsA("TextButton") then
			local active = child.Name == currentTab
			child.BackgroundColor3 = active and THEME.Accent or THEME.PanelAlt
			child.TextColor3 = active and THEME.Text or THEME.SubText
			child.TextTransparency = 0
			local stroke = child:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Color = active and THEME.Selection or THEME.Stroke
				stroke.Transparency = active and 0.15 or 0.45
			end
		end
	end
end

function UIBuildMenu.init(mainScreen, gameFrame, statsContainerRef)
	statsContainer = statsContainerRef
	bindResearchRefresh()

	BuildDock = Instance.new("Frame")
	BuildDock.Name = "BuildDock"
	BuildDock.Size = UDim2.new(0, BUILD_DOCK_SIZE.X, 0, BUILD_DOCK_SIZE.Y)
	BuildDock.Position = UDim2.new(0, EXPANDED_OFFSET.X, 1, EXPANDED_OFFSET.Y)
	BuildDock.BorderSizePixel = 0
	BuildDock.Parent = gameFrame
	UIStyle.applyPanel(BuildDock, "background")
	BuildDock.BackgroundColor3 = THEME.Panel

	expandedPos = BuildDock.Position
	collapsedPos = UDim2.new(0, COLLAPSED_OFFSET.X, 1, COLLAPSED_OFFSET.Y)
	statsExpandedPos = UDim2.new(0, STATS_EXPANDED_OFFSET.X, 1, STATS_EXPANDED_OFFSET.Y)
	statsCollapsedPos = UDim2.new(0, STATS_COLLAPSED_OFFSET.X, 1, STATS_COLLAPSED_OFFSET.Y)
	if statsContainer then
		statsContainer.Position = statsExpandedPos
	end

	createLabel(BuildDock, "BUILD MENU", UDim2.new(1, -60, 0, 18), UDim2.new(0, 12, 0, 10), THEME.FontHeader, 18, THEME.Text)

	collapseBtn = Instance.new("TextButton")
	collapseBtn.Size = UDim2.new(0, 28, 0, 24)
	collapseBtn.Position = UDim2.new(1, -40, 0, 12)
	collapseBtn.BackgroundTransparency = 1
	collapseBtn.Text = "-"
	collapseBtn.TextColor3 = THEME.Text
	collapseBtn.TextTransparency = 0
	collapseBtn.Font = THEME.FontHeader
	collapseBtn.TextSize = 18
	collapseBtn.Parent = BuildDock

	local function setCollapsed(state)
		collapsed = state
		local tweenInfo = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(BuildDock, tweenInfo, { Position = state and collapsedPos or expandedPos }):Play()
		if statsContainer then
			TweenService:Create(statsContainer, tweenInfo, { Position = state and statsCollapsedPos or statsExpandedPos }):Play()
		end
		collapseBtn.Text = state and "+" or "-"
	end

	collapseBtn.MouseButton1Click:Connect(function()
		setCollapsed(not collapsed)
	end)

	TabsHolder = Instance.new("Frame")
	TabsHolder.Size = UDim2.new(1, -24, 0, 34)
	TabsHolder.Position = UDim2.new(0, 12, 0, 40)
	TabsHolder.BackgroundTransparency = 1
	TabsHolder.Parent = BuildDock

	local tabsLayout = Instance.new("UIListLayout")
	tabsLayout.FillDirection = Enum.FillDirection.Horizontal
	tabsLayout.Padding = UDim.new(0, 6)
	tabsLayout.Parent = TabsHolder

	for _, category in ipairs({ "ECONOMY", "ARMY", "DEFENSE", "INFRA" }) do
		local button = Instance.new("TextButton")
		button.Name = category
		button.Size = UDim2.new(0, 119, 1, 0)
		button.BorderSizePixel = 0
		button.Text = category
		button.Font = TAB_FONT
		button.TextSize = 14
		button.TextTransparency = 0
		button.Parent = TabsHolder
		UIStyle.applyButton(button, "secondary")

		button.MouseButton1Click:Connect(function()
			if collapsed then
				setCollapsed(false)
			end
			currentTab = category
			updateTabVisuals()
			refreshBuildMenu()
		end)
	end

	Scroll = Instance.new("ScrollingFrame")
	Scroll.Size = UDim2.new(1, -24, 1, -96)
	Scroll.Position = UDim2.new(0, 12, 0, 78)
	Scroll.BackgroundTransparency = 1
	Scroll.BorderSizePixel = 0
	Scroll.ScrollBarThickness = 4
	Scroll.ScrollBarImageColor3 = THEME.Stroke
	Scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	Scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	Scroll.Parent = BuildDock

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.new(0.5, -5, 0, 126)
	grid.CellPadding = UDim2.new(0, 10, 0, 10)
	grid.FillDirectionMaxCells = 2
	grid.Parent = Scroll

	updateTabVisuals()
	refreshBuildMenu()
end

refreshBuildMenu = function()
	for _, child in ipairs(Scroll:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	local count = 0
	for name, data in pairs(Config.Buildings) do
		local category = data.Category and string.upper(data.Category)
		if category == currentTab and data.Category ~= "HIDDEN" and isResearchUnlocked(data.ResearchRequired) then
			count += 1

			local card = Instance.new("TextButton")
			card.LayoutOrder = count
			card.BorderSizePixel = 0
			card.Text = ""
			card.Parent = Scroll
			UIStyle.applyButton(card, "secondary")
			card.TextTransparency = 0
			card.BackgroundColor3 = THEME.PanelAlt
			local stroke = card:FindFirstChildWhichIsA("UIStroke")
			if stroke then
				stroke.Transparency = 0.5
			end

			createLabel(card, string.upper(name), UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 8), THEME.FontBody, 12, THEME.Text)
			createLabel(card, "$" .. tostring(data.Cost), UDim2.new(1, -16, 0, 18), UDim2.new(0, 8, 0, 28), THEME.FontHeader, 17, THEME.Positive)

			local detailBits = {}
			if data.Energy < 0 then
				table.insert(detailBits, "Power -" .. tostring(math.abs(data.Energy)))
			elseif data.Energy > 0 then
				table.insert(detailBits, "Power +" .. tostring(data.Energy))
			end
			if data.UnitLimit then
				table.insert(detailBits, "Unit cap +" .. tostring(data.UnitLimit))
			end
			if data.Income and data.Income > 0 then
				table.insert(detailBits, "Income +" .. tostring(data.Income))
			end
			if #detailBits == 0 then
				table.insert(detailBits, "No extra stats")
			end

			local info = createLabel(card, table.concat(detailBits, "\n"), UDim2.new(1, -16, 0, 38), UDim2.new(0, 8, 1, -44), THEME.FontBody, 12, THEME.Text)
			info.TextWrapped = true
			info.TextYAlignment = Enum.TextYAlignment.Top

			card.MouseButton1Click:Connect(function()
				StartBuildEvent:Fire(name)
			end)

			card.MouseEnter:Connect(function()
				card.BackgroundColor3 = THEME.PanelSoft
			end)
			card.MouseLeave:Connect(function()
				card.BackgroundColor3 = THEME.PanelAlt
			end)
		end
	end
end

return UIBuildMenu
