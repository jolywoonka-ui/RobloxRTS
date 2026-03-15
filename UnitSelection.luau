-- UnitSelection (ModuleScript, ReplicatedStorage)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local Selection = {}

local selectedUnits = {}
local hoveredUnit = nil
local rangeIndicator = nil
local lastHoveredUnit = nil
local infoGui = nil
local infoFrame = nil
local infoTitle = nil
local healthFill = nil
local leftColumn = nil
local rightColumn = nil
local updateConnection = nil
local selectionChangedCallbacks = {}

local constantRangeIndicators = {}
local showAllRanges = true

local SELECTION_COLOR = Color3.new(1, 1, 1)
local ENEMY_COLOR = Color3.fromRGB(255, 80, 80)

local THEME = {
	Background = UIStyle.Theme.Background,
	Panel = UIStyle.Theme.Panel,
	PanelSoft = UIStyle.Theme.PanelSoft,
	Accent = UIStyle.Theme.Accent,
	Text = UIStyle.Theme.Text,
	SubText = UIStyle.Theme.SubText,
	Green = UIStyle.Theme.Positive,
	Red = UIStyle.Theme.Negative,
	Stroke = UIStyle.Theme.Stroke,
	FontBody = UIStyle.Theme.FontBody,
	Corner = UDim.new(0, 4),
}

local function addStroke(obj, thickness, color)
	local s = Instance.new("UIStroke")
	s.Thickness = thickness or 1
	s.Color = color or THEME.Stroke
	s.Parent = obj
end

local function addCorner(obj, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or THEME.Corner
	c.Parent = obj
end

local function getGroundY(pos)
	local map = workspace:FindFirstChild("CurrentMap")
	local targets = {}

	table.insert(targets, workspace.Terrain)

	if map then
		local mapFolder = map:FindFirstChild("Map")
		if mapFolder then
			local function collectParts(container)
				for _, child in pairs(container:GetChildren()) do
					if child:IsA("BasePart") then
						table.insert(targets, child)
					elseif child:IsA("Folder") or child:IsA("Model") then
						collectParts(child)
					end
				end
			end
			collectParts(mapFolder)
		end
	end

	if #targets == 0 then return pos.Y - 1 end

	local rayOrigin = pos + Vector3.new(0, 200, 0)
	local rayDir = Vector3.new(0, -400, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets

	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then
		return result.Position.Y
	end
	return pos.Y - 1
end

local function getUnitData(unit)
	if not unit then return nil end
	return {
		name = unit.Name,
		speed = unit:GetAttribute("Speed") or 16,
		damage = unit:GetAttribute("Damage") or 0,
		health = unit:GetAttribute("Health") or 100,
		maxHealth = unit:GetAttribute("MaxHealth") or 100,
		range = unit:GetAttribute("Range") or 30,
		owner = unit:GetAttribute("Owner"),
		isBuilder = unit.Name == "Builder"
	}
end

local function createHoverInfoGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "UnitHoverInfo"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = playerGui

	local frame = Instance.new("Frame", gui)
	frame.Size = UDim2.new(0, 304, 0, 214)
	frame.Position = UDim2.new(1, -324, 0.5, -107)
	frame.BackgroundColor3 = THEME.Background
	frame.Visible = false
	addCorner(frame)
	addStroke(frame, 1)
	UIStyle.addShadow(frame, 0.82)

	infoTitle = Instance.new("TextLabel", frame)
	infoTitle.Size = UDim2.new(1, -20, 0, 28)
	infoTitle.Position = UDim2.new(0, 10, 0, 10)
	infoTitle.BackgroundTransparency = 1
	infoTitle.TextColor3 = THEME.Text
	infoTitle.Font = THEME.FontBody
	infoTitle.TextSize = 18
	infoTitle.TextXAlignment = Enum.TextXAlignment.Left

	local subtitle = Instance.new("TextLabel", frame)
	subtitle.Size = UDim2.new(1, -20, 0, 14)
	subtitle.Position = UDim2.new(0, 10, 0, 36)
	subtitle.BackgroundTransparency = 1
	subtitle.Text = "UNIT INTEL"
	subtitle.TextColor3 = THEME.SubText
	subtitle.Font = THEME.FontBody
	subtitle.TextSize = 11
	subtitle.TextXAlignment = Enum.TextXAlignment.Left

	local healthBg = Instance.new("Frame", frame)
	healthBg.Size = UDim2.new(1, -20, 0, 12)
	healthBg.Position = UDim2.new(0, 10, 0, 58)
	healthBg.BackgroundColor3 = UIStyle.Theme.Inset
	addCorner(healthBg)
	addStroke(healthBg, 1, THEME.Stroke)

	healthFill = Instance.new("Frame", healthBg)
	healthFill.Name = "HealthFill"
	healthFill.Size = UDim2.new(1, 0, 1, 0)
	healthFill.BackgroundColor3 = THEME.Green
	addCorner(healthFill)

	local statsFrame = Instance.new("Frame", frame)
	statsFrame.Size = UDim2.new(1, -20, 0, 118)
	statsFrame.Position = UDim2.new(0, 10, 0, 82)
	statsFrame.BackgroundTransparency = 1

	leftColumn = Instance.new("Frame", statsFrame)
	leftColumn.Size = UDim2.new(0.5, -5, 1, 0)
	leftColumn.BackgroundTransparency = 1
	local leftLayout = Instance.new("UIListLayout", leftColumn)
	leftLayout.Padding = UDim.new(0, 4)

	rightColumn = Instance.new("Frame", statsFrame)
	rightColumn.Size = UDim2.new(0.5, -5, 1, 0)
	rightColumn.Position = UDim2.new(0.5, 5, 0, 0)
	rightColumn.BackgroundTransparency = 1
	local rightLayout = Instance.new("UIListLayout", rightColumn)
	rightLayout.Padding = UDim.new(0, 4)

	return gui, frame
end

local function createStatRow(col, label, value, color)
	local row = Instance.new("Frame", col)
	row.Size = UDim2.new(1, 0, 0, 22)
	row.BackgroundColor3 = THEME.Panel
	row.BorderSizePixel = 0
	addCorner(row, UDim.new(0, 3))
	addStroke(row, 1, THEME.Stroke)

	local lbl = Instance.new("TextLabel", row)
	lbl.Size = UDim2.new(0.5, -10, 1, 0)
	lbl.Position = UDim2.new(0, 8, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = label .. ":"
	lbl.TextColor3 = THEME.SubText
	lbl.Font = THEME.FontBody
	lbl.TextSize = 12
	lbl.TextXAlignment = Enum.TextXAlignment.Left

	local val = Instance.new("TextLabel", row)
	val.Size = UDim2.new(0.5, -10, 1, 0)
	val.Position = UDim2.new(0.5, 2, 0, 0)
	val.BackgroundTransparency = 1
	val.Text = tostring(value)
	val.TextColor3 = color or THEME.Text
	val.Font = THEME.FontBody
	val.TextSize = 12
	val.TextXAlignment = Enum.TextXAlignment.Right
end

local function createRangeIndicator(color)
	local part = Instance.new("Part")
	part.Name = "RangeIndicator"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color or Color3.fromRGB(255, 255, 255)
	part.Size = Vector3.new(10, 0.05, 10)
	part.Transparency = 1

	local function addRingFace(face)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 28
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Parent = part

		local ring = Instance.new("Frame")
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundColor3 = part.Color
		ring.BackgroundTransparency = 0.86
		ring.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ring

		local stroke = Instance.new("UIStroke")
		stroke.Color = part.Color
		stroke.Thickness = 2
		stroke.Transparency = 0.2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = ring
	end

	addRingFace(Enum.NormalId.Top)
	addRingFace(Enum.NormalId.Bottom)
	return part
end

local function init()
	if not infoGui then
		infoGui, infoFrame = createHoverInfoGui()
	end
	if not rangeIndicator then
		rangeIndicator = createRangeIndicator(Color3.new(1,1,1))
		rangeIndicator.Parent = nil
	end
end
init()

local function loadShowRanges()
	local success, value = pcall(function()
		return player:GetAttribute("ShowUnitRanges")
	end)
	if success and value ~= nil then
		showAllRanges = value
	else
		showAllRanges = false
	end
end
loadShowRanges()

local function hideRange()
	rangeIndicator.Parent = nil
	if updateConnection then
		updateConnection:Disconnect()
		updateConnection = nil
	end
end

local function startRangeUpdate(unit)
	if updateConnection then updateConnection:Disconnect() end
	updateConnection = RunService.RenderStepped:Connect(function()
		if not unit or not unit.Parent or hoveredUnit ~= unit then
			updateConnection:Disconnect()
			updateConnection = nil
			hideRange()
			return
		end
		local rootPart = unit:IsA("Model") and unit.PrimaryPart or unit
		if rootPart then
			local data = getUnitData(unit)
			if data and data.range > 0 then
				local groundY = getGroundY(rootPart.Position)
				local diameter = data.range * 2
				local thickness = 0.05
				rangeIndicator.Size = Vector3.new(diameter, thickness, diameter)
				rangeIndicator.CFrame = CFrame.new(rootPart.Position.X, groundY + thickness/2 + 0.03, rootPart.Position.Z)
				rangeIndicator.Parent = workspace
			else
				hideRange()
			end
		else
			hideRange()
		end
	end)
end

local function showRange(unit)
	if not unit then return end
	local data = getUnitData(unit)
	if not data or data.range <= 0 then return end
	local rootPart = unit:IsA("Model") and unit.PrimaryPart or unit
	if rootPart then
		startRangeUpdate(unit)
	else
		warn("showRange: no PrimaryPart for", unit.Name)
	end
end

local function createConstantRangeIndicator(unit)
	if not unit or not unit.Parent then return nil, nil end
	local data = getUnitData(unit)
	if not data or data.range <= 0 then return nil, nil end
	local root = unit:IsA("Model") and (unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")) or unit
	if not root then return nil, nil end

	local color = (data.owner == player.Name) and Color3.new(1,1,1) or Color3.fromRGB(255,80,80)
	local indicator = createRangeIndicator(color)

	local conn
	conn = RunService.RenderStepped:Connect(function()
		if not unit or not unit.Parent then
			if indicator then indicator:Destroy() end
			return
		end
		local groundY = getGroundY(root.Position)
		local diameter = data.range * 2
		local thickness = 0.05
		indicator.Size = Vector3.new(diameter, thickness, diameter)
		indicator.CFrame = CFrame.new(root.Position.X, groundY + thickness/2 + 0.03, root.Position.Z)
		indicator.Parent = workspace
	end)
	return indicator, conn
end

local function refreshConstantRanges()
	for unit, data in pairs(constantRangeIndicators) do
		if data.conn then data.conn:Disconnect() end
		if data.indicator then data.indicator:Destroy() end
	end
	table.clear(constantRangeIndicators)

	if not showAllRanges then return end

	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return end
	local army = map:FindFirstChild("Army")
	if not army then return end

	for _, unit in pairs(army:GetChildren()) do
		if unit:GetAttribute("Owner") == player.Name and unit:GetAttribute("IsUnit") then
			local indicator, conn = createConstantRangeIndicator(unit)
			if indicator then
				constantRangeIndicators[unit] = {indicator = indicator, conn = conn}
			end
		end
	end
end

function Selection.setShowRanges(enabled)
	showAllRanges = enabled
	player:SetAttribute("ShowUnitRanges", enabled)
	refreshConstantRanges()
end

local function setupArmyMonitoring()
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return end
	local army = map:FindFirstChild("Army")
	if not army then return end

	army.ChildAdded:Connect(function(unit)
		task.wait()
		if unit:GetAttribute("Owner") == player.Name and unit:GetAttribute("IsUnit") and showAllRanges then
			local indicator, conn = createConstantRangeIndicator(unit)
			if indicator then
				constantRangeIndicators[unit] = {indicator = indicator, conn = conn}
			end
		end
	end)

	army.ChildRemoved:Connect(function(unit)
		local data = constantRangeIndicators[unit]
		if data then
			if data.conn then data.conn:Disconnect() end
			if data.indicator then data.indicator:Destroy() end
			constantRangeIndicators[unit] = nil
		end
	end)
end

task.spawn(function()
	local map = workspace:FindFirstChild("CurrentMap")
	if map then
		setupArmyMonitoring()
		refreshConstantRanges()
	else
		local conn
		conn = workspace.ChildAdded:Connect(function(child)
			if child.Name == "CurrentMap" then
				conn:Disconnect()
				task.wait(1)
				setupArmyMonitoring()
				refreshConstantRanges()
			end
		end)
	end
end)

local function updateHoverInfo(unit)
	if not unit or #selectedUnits > 0 then
		infoFrame.Visible = false
		lastHoveredUnit = nil
		return
	end
	if unit == lastHoveredUnit then return end

	lastHoveredUnit = unit
	local data = getUnitData(unit)
	if not data then
		infoFrame.Visible = false
		return
	end

	for _, child in pairs(leftColumn:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, child in pairs(rightColumn:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	infoTitle.Text = data.owner == player.Name and data.name or "[ENEMY] " .. data.name
	infoTitle.TextColor3 = (data.owner == player.Name and THEME.Text or ENEMY_COLOR)

	local healthPct = data.health / data.maxHealth
	healthFill.Size = UDim2.new(healthPct, 0, 1, 0)
	healthFill.BackgroundColor3 = healthPct < 0.3 and THEME.Red or (healthPct < 0.6 and Color3.fromRGB(255, 200, 50) or THEME.Green)

	createStatRow(leftColumn, "Health", string.format("%.0f/%.0f", data.health, data.maxHealth), THEME.Green)
	createStatRow(leftColumn, "Damage", tostring(data.damage), THEME.Red)
	createStatRow(leftColumn, "Speed", tostring(data.speed), THEME.Text)
	createStatRow(rightColumn, "Range", tostring(data.range), THEME.Accent)
	if data.isBuilder then
		createStatRow(rightColumn, "Builder", "Yes", THEME.Green)
	end

	infoFrame.Visible = true
end

local function addSelectionCircle(unit)
	if not unit or unit:FindFirstChild("SelectionHighlight") then return end
	local hl = Instance.new("Highlight")
	hl.Name = "SelectionHighlight"
	hl.Adornee = unit
	hl.FillTransparency = 1
	hl.OutlineColor = SELECTION_COLOR
	hl.OutlineTransparency = 0.2
	hl.Parent = unit
end

local function removeSelectionCircle(unit)
	if unit and unit:FindFirstChild("SelectionHighlight") then
		unit.SelectionHighlight:Destroy()
	end
end

local function fireSelectionChanged()
	for _, cb in ipairs(selectionChangedCallbacks) do
		cb(selectedUnits)
	end
end

function Selection.getSelected()
	return selectedUnits
end

function Selection.getUnitTypeName(unit)
	if not unit then
		return ""
	end
	return tostring(unit:GetAttribute("UnitType") or unit:GetAttribute("Type") or unit.Name)
end

function Selection.selectUnit(unit)
	local owner = unit:GetAttribute("Owner")
	if owner and owner ~= player.Name then return end

	if not table.find(selectedUnits, unit) then
		table.insert(selectedUnits, unit)
		addSelectionCircle(unit)
		fireSelectionChanged()
	end
	if #selectedUnits > 1 then
		updateHoverInfo(nil)
		hideRange()
	end
end

function Selection.replaceSelection(units)
	for _, unit in ipairs(selectedUnits) do
		removeSelectionCircle(unit)
	end
	table.clear(selectedUnits)

	local seen = {}
	for _, unit in ipairs(units or {}) do
		if unit and unit.Parent and unit:GetAttribute("IsUnit") and unit:GetAttribute("Owner") == player.Name and not seen[unit] then
			seen[unit] = true
			table.insert(selectedUnits, unit)
			addSelectionCircle(unit)
		end
	end

	hideRange()
	updateHoverInfo(nil)
	fireSelectionChanged()
end

function Selection.deselectAll()
	for _, unit in ipairs(selectedUnits) do
		removeSelectionCircle(unit)
	end
	table.clear(selectedUnits)
	hideRange()
	updateHoverInfo(nil)
	fireSelectionChanged()
end

function Selection.onSelectionChanged(callback)
	table.insert(selectionChangedCallbacks, callback)
end

function Selection.updateHover(mouseTarget)
	if #selectedUnits > 0 then
		if hoveredUnit then
			hoveredUnit = nil
			hideRange()
			updateHoverInfo(nil)
		end
		return
	end

	local target = mouseTarget
	if target then
		local unit = target:FindFirstAncestorWhichIsA("Model")
		if unit and unit:GetAttribute("IsUnit") then
			if unit ~= hoveredUnit then
				hoveredUnit = unit
				if not showAllRanges then
					showRange(unit)
				end
				updateHoverInfo(unit)
			end
		elseif hoveredUnit then
			hoveredUnit = nil
			hideRange()
			updateHoverInfo(nil)
		end
	elseif hoveredUnit then
		hoveredUnit = nil
		hideRange()
		updateHoverInfo(nil)
	end
end

workspace.DescendantRemoving:Connect(function(desc)
	if desc:GetAttribute("IsUnit") then
		local idx = table.find(selectedUnits, desc)
		if idx then
			table.remove(selectedUnits, idx)
			removeSelectionCircle(desc)
			fireSelectionChanged()
		end
		if hoveredUnit == desc then
			hoveredUnit = nil
			hideRange()
			updateHoverInfo(nil)
		end
		local data = constantRangeIndicators[desc]
		if data then
			if data.conn then data.conn:Disconnect() end
			if data.indicator then data.indicator:Destroy() end
			constantRangeIndicators[desc] = nil
		end
	end
end)

return Selection
