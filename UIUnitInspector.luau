local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Selection = require(ReplicatedStorage:WaitForChild("UnitSelection"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local DeleteUnit = ReplicatedStorage:WaitForChild("DeleteUnit")

local UIUnitInspector = {}

local THEME = UIStyle.Theme

local inspectorFrame
local titleLabel
local subtitleLabel
local healthFill
local healthText
local deleteBtn
local summaryFrame
local summaryLabel
local metaLabel

local currentUnits = {}
local currentUnit
local connections = {}

local function getUnitTypeName(unit)
	return tostring(unit and (unit:GetAttribute("UnitType") or unit:GetAttribute("Type") or unit.Name) or "UNIT")
end

local function formatDisplayName(name)
	name = tostring(name or "UNIT")
	name = name:gsub("([a-z])([A-Z])", "%1 %2")
	name = name:gsub("AA(%u)", "AA %1")
	return string.upper(name)
end

local function getMultiSelectionTitle(units)
	if #units == 0 then
		return "UNITS"
	end

	local counts = {}
	local ordered = {}
	for _, unit in ipairs(units) do
		local typeName = getUnitTypeName(unit)
		if counts[typeName] == nil then
			counts[typeName] = 0
			table.insert(ordered, typeName)
		end
		counts[typeName] += 1
	end

	table.sort(ordered, function(a, b)
		if counts[a] == counts[b] then
			return a < b
		end
		return counts[a] > counts[b]
	end)

	local segments = {}
	for _, typeName in ipairs(ordered) do
		table.insert(segments, string.format("%dx %s", counts[typeName], string.lower(formatDisplayName(typeName))))
	end
	return table.concat(segments, "  ")
end

local function disconnectAll()
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	connections = {}
end

local function setHealthDisplay(percent, text)
	healthFill.Size = UDim2.new(math.clamp(percent, 0, 1), 0, 1, 0)
	if percent < 0.3 then
		healthFill.BackgroundColor3 = THEME.Negative
	elseif percent < 0.6 then
		healthFill.BackgroundColor3 = THEME.Warning
	else
		healthFill.BackgroundColor3 = THEME.Positive
	end
	healthText.Text = text
end

local function updateHealthBar(unit)
	local health = tonumber(unit:GetAttribute("Health") or 100) or 100
	local maxHealth = math.max(1, tonumber(unit:GetAttribute("MaxHealth") or 100) or 100)
	local pct = math.clamp(health / maxHealth, 0, 1)
	setHealthDisplay(pct, string.format("%d / %d", math.floor(health + 0.5), math.floor(maxHealth + 0.5)))
end

local function updateSingleDisplay(unit)
	titleLabel.Text = formatDisplayName(unit.Name)
	subtitleLabel.Text = "Single unit selected"
	summaryFrame.Visible = false
	metaLabel.Visible = false
	updateHealthBar(unit)
end

local function getMultiSelectionBreakdown(units)
	local counts = {}
	local ordered = {}
	for _, unit in ipairs(units) do
		if unit and unit.Parent then
			local typeName = formatDisplayName(getUnitTypeName(unit))
			if counts[typeName] == nil then
				counts[typeName] = 0
				table.insert(ordered, typeName)
			end
			counts[typeName] += 1
		end
	end

	table.sort(ordered, function(a, b)
		if counts[a] == counts[b] then
			return a < b
		end
		return counts[a] > counts[b]
	end)

	local parts = {}
	for _, typeName in ipairs(ordered) do
		table.insert(parts, string.format("%dx %s", counts[typeName], string.lower(typeName)))
	end
	return table.concat(parts, "  ")
end

local function updateMultiDisplay(units)
	local totalPct = 0
	local count = 0
	for _, unit in ipairs(units) do
		if unit and unit.Parent then
			local health = tonumber(unit:GetAttribute("Health") or 100) or 100
			local maxHealth = math.max(1, tonumber(unit:GetAttribute("MaxHealth") or 100) or 100)
			totalPct += math.clamp(health / maxHealth, 0, 1)
			count += 1
		end
	end
	local averagePct = count > 0 and (totalPct / count) or 1
	subtitleLabel.Text = string.format("%d units selected", #units)
	summaryFrame.Visible = true
	summaryLabel.Text = getMultiSelectionBreakdown(units)
	metaLabel.Visible = true
	metaLabel.Text = "Selection summary"
	setHealthDisplay(averagePct, string.format("Squad health %d%%", math.floor(averagePct * 100 + 0.5)))
end

function UIUnitInspector.init(mainScreen, gameFrame)
	inspectorFrame = Instance.new("Frame")
	inspectorFrame.Name = "UnitInspector"
	inspectorFrame.Size = UDim2.new(0, 320, 0, 190)
	inspectorFrame.Position = UDim2.new(1, -340, 0.5, -95)
	inspectorFrame.BorderSizePixel = 0
	inspectorFrame.Visible = false
	inspectorFrame.Parent = gameFrame
	UIStyle.applyPanel(inspectorFrame, "background")

	titleLabel = UIStyle.createLabel(inspectorFrame, "UNIT", UDim2.new(1, -20, 0, 22), UDim2.new(0, 10, 0, 10), THEME.FontHeader, 18, THEME.Text)
	subtitleLabel = UIStyle.createLabel(inspectorFrame, "", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 34), THEME.FontBody, 11, THEME.SubText)

	local healthBack = Instance.new("Frame")
	healthBack.Size = UDim2.new(1, -20, 0, 12)
	healthBack.Position = UDim2.new(0, 10, 0, 58)
	healthBack.BackgroundColor3 = THEME.Inset
	healthBack.BorderSizePixel = 0
	healthBack.Parent = inspectorFrame
	UIStyle.addCorner(healthBack, UDim.new(0, 2))
	UIStyle.addStroke(healthBack, 1, THEME.Stroke)

	healthFill = Instance.new("Frame")
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = THEME.Positive
	healthFill.BorderSizePixel = 0
	healthFill.Parent = healthBack
	UIStyle.addCorner(healthFill, UDim.new(0, 2))

	healthText = UIStyle.createLabel(inspectorFrame, "100 / 100", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 76), THEME.FontBody, 11, THEME.SubText, Enum.TextXAlignment.Right)

	metaLabel = UIStyle.createLabel(inspectorFrame, "Selection summary", UDim2.new(1, -20, 0, 14), UDim2.new(0, 10, 0, 96), THEME.FontBody, 11, THEME.SubText)
	metaLabel.Visible = false

	summaryFrame = Instance.new("Frame")
	summaryFrame.Size = UDim2.new(1, -20, 0, 28)
	summaryFrame.Position = UDim2.new(0, 10, 0, 114)
	summaryFrame.BorderSizePixel = 0
	summaryFrame.Visible = false
	summaryFrame.Parent = inspectorFrame
	UIStyle.applyPanel(summaryFrame, "panelAlt")

	summaryLabel = UIStyle.createLabel(summaryFrame, "", UDim2.new(1, -12, 1, 0), UDim2.new(0, 6, 0, 0), THEME.FontBody, 12, THEME.Text)
	summaryLabel.TextWrapped = true

	deleteBtn = Instance.new("TextButton")
	deleteBtn.Size = UDim2.new(1, -20, 0, 28)
	deleteBtn.Position = UDim2.new(0, 10, 1, -40)
	deleteBtn.Parent = inspectorFrame
	UIStyle.applyButton(deleteBtn, "danger")
	deleteBtn.Text = "DELETE UNIT"
	deleteBtn.Font = THEME.FontMain
	deleteBtn.TextSize = 13

	deleteBtn.MouseButton1Click:Connect(function()
		if #currentUnits > 0 then
			DeleteUnit:FireServer(currentUnits)
			UIUnitInspector.hide()
		end
	end)
end

function UIUnitInspector.showForUnit(unit)
	currentUnits = { unit }
	currentUnit = unit
	inspectorFrame.Visible = true
	deleteBtn.Text = "DELETE UNIT"

	disconnectAll()

	for _, attributeName in ipairs({ "Health", "MaxHealth" }) do
		table.insert(connections, unit:GetAttributeChangedSignal(attributeName):Connect(function()
			updateSingleDisplay(unit)
		end))
	end

	table.insert(connections, unit.AncestryChanged:Connect(function()
		if not unit.Parent then
			UIUnitInspector.hide()
		end
	end))

	updateSingleDisplay(unit)
end

function UIUnitInspector.showForMultiple(count)
	currentUnits = Selection.getSelected()
	currentUnit = nil
	inspectorFrame.Visible = true
	titleLabel.Text = getMultiSelectionTitle(currentUnits)
	deleteBtn.Text = "DELETE " .. tostring(count) .. " UNIT(S)"

	disconnectAll()
	updateMultiDisplay(currentUnits)
end

function UIUnitInspector.hide()
	inspectorFrame.Visible = false
	currentUnits = {}
	currentUnit = nil
	disconnectAll()
end

return UIUnitInspector
