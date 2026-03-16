local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local SquadManager = {}

local BASE_SQUAD_LIMIT = 5
local MAX_SQUADS = 10
local SQUADS_PER_PAGE = 4

local THEME = UIStyle.Theme

local squads = {}
local currentPage = 1
local selectedSquad
local collapsed = false
local detailedMode = true
local callbacks = {
	onAddToSquad = nil,
	onSelectSquad = nil,
	onCreateSquad = nil,
	onSelectUnit = nil,
}

local squadScreen
local mainFrame
local pagerFrame
local cardsHolder
local prevBtn
local nextBtn
local pageLabel
local collapseBtn
local reopenBtn
local cardRefs = {}
local lastVisualRefresh = 0
local VISUAL_REFRESH_INTERVAL = 0.25
local getTotalPages
local clampPage
local getSlice

local function getCardsPerPage()
	return detailedMode and 4 or 5
end

local function getLayoutMetrics()
	local cardsPerPage = getCardsPerPage()
	local cardWidth = detailedMode and 151 or 138
	local gap = 12
	local cardsWidth = cardsPerPage * cardWidth + math.max(0, cardsPerPage - 1) * gap
	return {
		MainWidth = cardsWidth,
		MainHeight = 220,
		CardsWidth = cardsWidth,
		CardWidth = cardWidth,
		CardHeight = 186,
		Gap = gap,
	}
end

local function getVisibleCardsOnPage()
	local startIndex, endIndex = getSlice()
	local squadCount = math.max(0, endIndex - startIndex + 1)
	local hasCreateCard = #squads < MAX_SQUADS and squadCount < getCardsPerPage()
	return squadCount + (hasCreateCard and 1 or 0)
end

local function applyFrameWidth()
	if not mainFrame then
		return
	end

	local metrics = getLayoutMetrics()
	local visibleCards = math.max(1, getVisibleCardsOnPage())
	local contentWidth = visibleCards * metrics.CardWidth + math.max(0, visibleCards - 1) * metrics.Gap
	local height = collapsed and 26 or metrics.MainHeight
	mainFrame.Size = UDim2.new(0, math.max(contentWidth, 176), 0, height)
end

local function getUnitDisplayName(unit)
	return tostring(unit and (unit:GetAttribute("UnitType") or unit:GetAttribute("Type") or unit.Name) or "UNIT")
end

local function getUnitHealth(unit)
	local health = tonumber(unit and unit:GetAttribute("Health") or 100) or 100
	local maxHealth = math.max(1, tonumber(unit and unit:GetAttribute("MaxHealth") or 100) or 100)
	local pct = math.clamp(health / maxHealth, 0, 1)
	return health, maxHealth, pct
end

local function getAverageHPPercent(squad)
	if not squad or #squad.Units == 0 then
		return 0
	end
	local total = 0
	local count = 0
	for _, unit in ipairs(squad.Units) do
		if unit and unit.Parent then
			local _, _, pct = getUnitHealth(unit)
			total += pct
			count += 1
		end
	end
	return count > 0 and math.floor((total / count) * 100 + 0.5) or 0
end

local function clearCards()
	for _, child in ipairs(cardsHolder:GetChildren()) do
		if child:IsA("GuiObject") or child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	cardRefs = {}
end

getTotalPages = function()
	local visibleSlots = #squads
	if visibleSlots < MAX_SQUADS then
		visibleSlots += 1
	end
	return math.max(1, math.ceil(visibleSlots / getCardsPerPage()))
end

clampPage = function()
	currentPage = math.clamp(currentPage, 1, getTotalPages())
end

getSlice = function()
	clampPage()
	local perPage = getCardsPerPage()
	local startIndex = (currentPage - 1) * perPage + 1
	local endIndex = math.min(startIndex + perPage - 1, #squads)
	return startIndex, endIndex
end

local function removeSquadByReference(targetSquad)
	for index, squad in ipairs(squads) do
		if squad == targetSquad then
			table.remove(squads, index)
			if selectedSquad == targetSquad then
				selectedSquad = nil
			end
			return
		end
	end
end

local function setSelectedSquad(squad, notify)
	selectedSquad = squad
	for refSquad, card in pairs(cardRefs) do
		local active = refSquad == squad
		card.BackgroundColor3 = THEME.Card
		local stroke = card:FindFirstChildWhichIsA("UIStroke")
		if stroke then
			stroke.Color = active and THEME.Selection or THEME.Stroke
			stroke.Thickness = active and 2 or 1
			stroke.Transparency = active and 0 or 0.45
		end
	end

	if notify and selectedSquad and callbacks.onSelectSquad then
		callbacks.onSelectSquad(selectedSquad)
	end
end

local function removeFromAllSquads(unit)
	for i = #squads, 1, -1 do
		local squad = squads[i]
		for k = #squad.Units, 1, -1 do
			if squad.Units[k] == unit then
				table.remove(squad.Units, k)
			end
		end
		if #squad.Units == 0 then
			if selectedSquad == squad then
				selectedSquad = nil
			end
			table.remove(squads, i)
		end
	end
end

local function createUnitRow(parent, unit, index)
	local health, maxHealth, pct = getUnitHealth(unit)

	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 18)
	row.Position = UDim2.new(0, 0, 0, (index - 1) * 20)
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Parent = parent

	UIStyle.createLabel(row, getUnitDisplayName(unit), UDim2.new(0.62, -8, 0, 12), UDim2.new(0, 0, 0, 0), THEME.FontBody, 10, THEME.Text)
	local hpLabel = UIStyle.createLabel(row, string.format("%d/%d", math.floor(health + 0.5), math.floor(maxHealth + 0.5)), UDim2.new(0.38, 0, 0, 12), UDim2.new(0.62, 0, 0, 0), THEME.FontBody, 9, THEME.SubText, Enum.TextXAlignment.Right)

	local hpBack = Instance.new("Frame")
	hpBack.Size = UDim2.new(1, 0, 0, 6)
	hpBack.Position = UDim2.new(0, 0, 1, -6)
	hpBack.BackgroundColor3 = THEME.Inset
	hpBack.BorderSizePixel = 0
	hpBack.Parent = row
	UIStyle.addCorner(hpBack, UDim.new(0, 2))

	local hpFill = Instance.new("Frame")
	hpFill.Size = UDim2.new(pct, 0, 1, 0)
	hpFill.BackgroundColor3 = pct < 0.3 and THEME.Negative or (pct < 0.6 and THEME.Warning or THEME.Positive)
	hpFill.BorderSizePixel = 0
	hpFill.Parent = hpBack
	UIStyle.addCorner(hpFill, UDim.new(0, 2))

	local unitSelectArea = Instance.new("TextButton")
	unitSelectArea.Size = UDim2.new(0.54, 0, 1, 0)
	unitSelectArea.BackgroundTransparency = 1
	unitSelectArea.BorderSizePixel = 0
	unitSelectArea.Text = ""
	unitSelectArea.AutoButtonColor = false
	unitSelectArea.Parent = row

	unitSelectArea.MouseButton1Down:Connect(function()
		if callbacks.onSelectUnit then
			callbacks.onSelectUnit(unit)
		end
	end)

	local function updateDisplay()
		if not row.Parent then return end
		local h, mh, p = getUnitHealth(unit)
		hpLabel.Text = string.format("%d/%d", math.floor(h + 0.5), math.floor(mh + 0.5))
		hpFill.Size = UDim2.new(p, 0, 1, 0)
		hpFill.BackgroundColor3 = p < 0.3 and THEME.Negative or (p < 0.6 and THEME.Warning or THEME.Positive)
	end

	unit:GetAttributeChangedSignal("Health"):Connect(updateDisplay)
	unit:GetAttributeChangedSignal("MaxHealth"):Connect(updateDisplay)
end

local function buildSquadCard(parent, squad, metrics, layoutOrder)
	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, metrics.CardWidth, 0, metrics.CardHeight)
	card.LayoutOrder = layoutOrder or 0
	card.BackgroundColor3 = THEME.Card
	card.BorderSizePixel = 0
	card.Text = ""
	card.Parent = parent
	UIStyle.addCorner(card, UDim.new(0, 4))
	UIStyle.addStroke(card, 1, squad == selectedSquad and THEME.Selection or THEME.Stroke, squad == selectedSquad and 0 or 0.45)
	UIStyle.addShadow(card, 0.84)

	local nameBox = Instance.new("TextBox")
	nameBox.Size = UDim2.new(1, -16, 0, 16)
	nameBox.Position = UDim2.new(0, 8, 0, 8)
	nameBox.BackgroundTransparency = 1
	nameBox.BorderSizePixel = 0
	nameBox.Text = string.upper(squad.Name)
	nameBox.TextColor3 = THEME.Text
	nameBox.PlaceholderText = "SQUAD"
	nameBox.Font = THEME.FontHeader
	nameBox.TextSize = 13
	nameBox.TextXAlignment = Enum.TextXAlignment.Left
	nameBox.ClearTextOnFocus = false
	nameBox.Parent = card

	nameBox.FocusLost:Connect(function()
		local nextName = string.gsub(nameBox.Text or "", "^%s*(.-)%s*$", "%1")
		squad.Name = nextName ~= "" and nextName or squad.Name
		nameBox.Text = string.upper(squad.Name)
	end)

	nameBox.Focused:Connect(function()
		setSelectedSquad(squad, true)
	end)

	UIStyle.createLabel(card, string.format("%d / %d units", #squad.Units, squad.Limit), UDim2.new(1, -16, 0, 14), UDim2.new(0, 8, 0, 26), THEME.FontBody, 12, THEME.SubText)

	local unitList = Instance.new("Frame")
	unitList.Size = UDim2.new(1, -16, 0, 102)
	unitList.Position = UDim2.new(0, 8, 0, 44)
	unitList.BackgroundTransparency = 1
	unitList.Active = false
	unitList.Parent = card

	local squadSelectArea = Instance.new("TextButton")
	squadSelectArea.Size = UDim2.new(0.46, -6, 0, 102)
	squadSelectArea.Position = UDim2.new(0.54, 2, 0, 44)
	squadSelectArea.BackgroundTransparency = 1
	squadSelectArea.BorderSizePixel = 0
	squadSelectArea.Text = ""
	squadSelectArea.AutoButtonColor = false
	squadSelectArea.Parent = card

	if #squad.Units == 0 then
		UIStyle.createLabel(unitList, "No units assigned", UDim2.new(1, 0, 0, 16), UDim2.new(), THEME.FontBody, 10, THEME.SubText)
	else
		for unitIndex, unit in ipairs(squad.Units) do
			if unit and unit.Parent then
				createUnitRow(unitList, unit, unitIndex)
			end
		end
	end

	local assignBtn = UIStyle.createButton(card, "ASSIGN", UDim2.new(0.42, 0, 0, 22), UDim2.new(0, 8, 1, -30), "secondary")
	local disbandBtn = UIStyle.createButton(card, "DISBAND", UDim2.new(0.42, 0, 0, 22), UDim2.new(0.58, -8, 1, -30), "danger")
	assignBtn.TextSize = 12
	disbandBtn.TextSize = 12

	squadSelectArea.MouseButton1Down:Connect(function()
		setSelectedSquad(squad, true)
	end)

	assignBtn.MouseButton1Down:Connect(function()
		setSelectedSquad(squad, false)
		if callbacks.onAddToSquad then
			callbacks.onAddToSquad(squad)
		end
	end)

	disbandBtn.MouseButton1Down:Connect(function()
		removeSquadByReference(squad)
		SquadManager.renderCurrentPage()
	end)

	cardRefs[squad] = card
end

local function buildCreateCard(parent, metrics, alignRight, layoutOrder)
	local createCard = Instance.new("Frame")
	createCard.Size = UDim2.new(0, metrics.CardWidth, 0, metrics.CardHeight)
	createCard.LayoutOrder = layoutOrder or 0
	createCard.BackgroundTransparency = 1
	createCard.BorderSizePixel = 0
	createCard.Parent = parent

	local createPosition = alignRight and UDim2.new(1, -50, 0.5, -21) or UDim2.new(0.5, -21, 0.5, -21)
	local createBtn = UIStyle.createButton(createCard, "+", UDim2.new(0, 42, 0, 42), createPosition, "secondary")
	createBtn.TextSize = 24
	createBtn.MouseButton1Down:Connect(function()
		if callbacks.onCreateSquad then
			callbacks.onCreateSquad()
		end
	end)
end

local function rebuildCards()
	if not cardsHolder then
		return
	end

	clearCards()
	applyFrameWidth()
	local metrics = getLayoutMetrics()

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, metrics.Gap)
	layout.Parent = cardsHolder

	local startIndex, endIndex = getSlice()
	for index = startIndex, endIndex do
		buildSquadCard(cardsHolder, squads[index], metrics, index - startIndex + 1)
	end

	if #squads < MAX_SQUADS and endIndex - startIndex + 1 < getCardsPerPage() then
		local createOrder = math.max(1, endIndex - startIndex + 2)
		buildCreateCard(cardsHolder, metrics, #squads > 0, createOrder)
	end

	pageLabel.Text = string.format("%d / %d", currentPage, getTotalPages())
	prevBtn.Visible = currentPage > 1
	nextBtn.Visible = currentPage < getTotalPages()
	setSelectedSquad(selectedSquad, false)
end

local function toggleCollapse()
	collapsed = not collapsed
	if not mainFrame or not collapseBtn then
		return
	end

	local metrics = getLayoutMetrics()
	local visibleCards = math.max(1, getVisibleCardsOnPage())
	local contentWidth = visibleCards * metrics.CardWidth + math.max(0, visibleCards - 1) * metrics.Gap
	local targetSize = UDim2.new(0, math.max(contentWidth, 176), 0, collapsed and 26 or metrics.MainHeight)

	collapseBtn.Text = collapsed and "+" or "-"
	TweenService:Create(
		mainFrame,
		TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = targetSize }
	):Play()
end

local function createSquadUI()
	squadScreen = Instance.new("ScreenGui")
	squadScreen.Name = "SquadsHUD"
	squadScreen.ResetOnSpawn = false
	squadScreen.IgnoreGuiInset = true
	squadScreen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	squadScreen.DisplayOrder = 20
	squadScreen.Enabled = false
	squadScreen.Parent = playerGui

	local metrics = getLayoutMetrics()

	mainFrame = Instance.new("Frame")
	mainFrame.Size = UDim2.new(0, metrics.MainWidth, 0, metrics.MainHeight)
	mainFrame.AnchorPoint = Vector2.new(0.5, 1)
	mainFrame.Position = UDim2.new(0.5, 0, 1, -18)
	mainFrame.BorderSizePixel = 0
	mainFrame.BackgroundTransparency = 1
	mainFrame.Active = false
	mainFrame.ClipsDescendants = true
	mainFrame.Parent = squadScreen

	pagerFrame = Instance.new("Frame")
	pagerFrame.Size = UDim2.new(0, 176, 0, 26)
	pagerFrame.AnchorPoint = Vector2.new(0.5, 0)
	pagerFrame.Position = UDim2.new(0.5, 0, 0, 0)
	pagerFrame.BorderSizePixel = 0
	pagerFrame.Active = false
	pagerFrame.Parent = mainFrame
	UIStyle.applyPanel(pagerFrame, "card")
	UIStyle.addShadow(pagerFrame, 0.84)

	pageLabel = UIStyle.createLabel(pagerFrame, "1 / 1", UDim2.new(0, 56, 1, 0), UDim2.new(0.5, -28, 0, 0), THEME.FontBody, 11, THEME.SubText, Enum.TextXAlignment.Center)
	prevBtn = UIStyle.createButton(pagerFrame, "<", UDim2.new(0, 24, 0, 20), UDim2.new(0, 8, 0, 3), "ghost")
	nextBtn = UIStyle.createButton(pagerFrame, ">", UDim2.new(0, 24, 0, 20), UDim2.new(1, -56, 0, 3), "ghost")
	collapseBtn = UIStyle.createButton(pagerFrame, "-", UDim2.new(0, 24, 0, 20), UDim2.new(1, -28, 0, 3), "ghost")

	cardsHolder = Instance.new("Frame")
	cardsHolder.Size = UDim2.new(1, 0, 1, -34)
	cardsHolder.Position = UDim2.new(0, 0, 0, 34)
	cardsHolder.BackgroundTransparency = 1
	cardsHolder.Active = false
	cardsHolder.Parent = mainFrame

	reopenBtn = UIStyle.createButton(squadScreen, "SQUADS", UDim2.new(0, 84, 0, 24), UDim2.new(0.5, -42, 1, -28), "secondary")
	reopenBtn.Visible = false
	reopenBtn.MouseButton1Click:Connect(function()
		collapsed = false
		mainFrame.Visible = true
		reopenBtn.Visible = false
	end)

	prevBtn.MouseButton1Click:Connect(function()
		currentPage -= 1
		rebuildCards()
	end)

	nextBtn.MouseButton1Click:Connect(function()
		currentPage += 1
		rebuildCards()
	end)

	collapseBtn.MouseButton1Click:Connect(toggleCollapse)
	collapseBtn.Text = collapsed and "+" or "-"

	rebuildCards()
end

function SquadManager.renderCurrentPage()
	if not squadScreen then
		createSquadUI()
	end

	applyFrameWidth()
	rebuildCards()
end

function SquadManager.updateUnitRows(_squad)
	rebuildCards()
end

function SquadManager.setCallbacks(cb)
	callbacks = cb or callbacks
end

function SquadManager.getSquads()
	return squads
end

function SquadManager.createSquad(units, limit)
	limit = limit or BASE_SQUAD_LIMIT
	local cleanUnits = {}
	for _, unit in ipairs(units or {}) do
		if unit and unit.Parent then
			removeFromAllSquads(unit)
			table.insert(cleanUnits, unit)
		end
	end

	local newSquad = {
		Name = "Squad " .. tostring(#squads + 1),
		Units = cleanUnits,
		Limit = limit,
	}
	table.insert(squads, newSquad)
	currentPage = getTotalPages()
	selectedSquad = newSquad
	SquadManager.renderCurrentPage()
	return newSquad
end

function SquadManager.addToSquad(squad, units)
	if not squad then
		return
	end
	for _, unit in ipairs(units or {}) do
		if #squad.Units >= squad.Limit then
			break
		end
		if unit and unit.Parent then
			removeFromAllSquads(unit)
			if not table.find(squad.Units, unit) then
				table.insert(squad.Units, unit)
			end
		end
	end
	selectedSquad = squad
	SquadManager.renderCurrentPage()
end

function SquadManager.removeSquad(index)
	if squads[index] then
		if selectedSquad == squads[index] then
			selectedSquad = nil
		end
		table.remove(squads, index)
		SquadManager.renderCurrentPage()
	end
end

function SquadManager.showUI(show)
	if not squadScreen then
		createSquadUI()
	end
	squadScreen.Enabled = show
	if not show and reopenBtn then
		reopenBtn.Visible = false
		collapsed = false
		mainFrame.Visible = true
		collapseBtn.Text = "-"
	end
	if show then
		SquadManager.renderCurrentPage()
	end
end

function SquadManager.setDetailedMode(enabled)
	detailedMode = enabled == true
	if squadScreen then
		local wasEnabled = squadScreen.Enabled
		squadScreen:Destroy()
		squadScreen = nil
		mainFrame = nil
		cardsHolder = nil
		reopenBtn = nil
		cardRefs = {}
		createSquadUI()
		squadScreen.Enabled = wasEnabled
		reopenBtn.Visible = false
		collapsed = false
		if wasEnabled then
			SquadManager.renderCurrentPage()
		end
	end
end

RunService.Heartbeat:Connect(function()
	local changed = false
	for i = #squads, 1, -1 do
		local squad = squads[i]
		for k = #squad.Units, 1, -1 do
			local unit = squad.Units[k]
			if not unit or not unit.Parent then
				table.remove(squad.Units, k)
				changed = true
			end
		end
		if #squad.Units == 0 then
			if selectedSquad == squad then
				selectedSquad = nil
			end
			table.remove(squads, i)
			changed = true
		end
	end

	if changed and squadScreen and squadScreen.Enabled then
		rebuildCards()
	end
end)

return SquadManager
