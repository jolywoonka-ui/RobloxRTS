-- UIMultiSelect (ModuleScript, ReplicatedStorage) - OPTIMIZED
-- Single global RenderStepped for all selected building ranges

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local BuildWall = ReplicatedStorage:FindFirstChild("BuildWall")

local UIMultiSelect = {}

local selectedBuildings = {}
local buildingHighlights = {}
local buildingRangeIndicators = {}

-- Single global update loop
local rangeUpdateConn = nil
local lastRangeUpdate = 0
local RANGE_THROTTLE = 0.1

local function getGroundY(pos, building)
	local rayOrigin = pos + Vector3.new(0, 200, 0)
	local rayDir = Vector3.new(0, -400, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local map = workspace:FindFirstChild("CurrentMap")
	local mapFolder = map and map:FindFirstChild("Map")
	if mapFolder then
		params.FilterDescendantsInstances = {mapFolder}
	else
		params.FilterDescendantsInstances = {}
	end

	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then return result.Position.Y end

	params.FilterDescendantsInstances = {workspace.Terrain}
	result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then return result.Position.Y end
	return pos.Y - 1
end

local function createBuildingRangeIndicator(color)
	local part = Instance.new("Part")
	part.Name = "BuildingRangeIndicator"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color or Color3.new(1, 1, 1)
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

local function startGlobalRangeUpdates()
	if rangeUpdateConn then return end
	rangeUpdateConn = RunService.RenderStepped:Connect(function()
		local now = tick()
		if now - lastRangeUpdate < RANGE_THROTTLE then return end
		lastRangeUpdate = now

		for building, indicator in pairs(buildingRangeIndicators) do
			if building and building.Parent then
				local bType = building:GetAttribute("Type")
				local bData = Config.Buildings[bType]
				local rangeAttr = tonumber(building:GetAttribute("Range") or 0) or 0
				local range = (rangeAttr > 0) and rangeAttr or (tonumber(bData and (bData.Range or bData.HealRange) or 0) or 0)
				if range <= 0 then
					if indicator.Parent then indicator.Parent = nil end
					continue
				end
				local root = building:IsA("Model") and (building.PrimaryPart or building:FindFirstChildWhichIsA("BasePart")) or building
				if root then
					local groundY = getGroundY(root.Position, building)
					local thickness = 0.05
					local diameter = range * 2
					indicator.Size = Vector3.new(diameter, thickness, diameter)
					indicator.CFrame = CFrame.new(root.Position.X, groundY + thickness/2 + 0.03, root.Position.Z)
					indicator.Parent = workspace
				end
			else
				if indicator then indicator:Destroy() end
				buildingRangeIndicators[building] = nil
			end
		end
	end)
end

local function stopGlobalRangeUpdates()
	if rangeUpdateConn then
		rangeUpdateConn:Disconnect()
		rangeUpdateConn = nil
	end
end

function UIMultiSelect.addBuilding(building)
	if selectedBuildings[building] then return end
	selectedBuildings[building] = true

	local owner = building:GetAttribute("Owner")
	local isOwned = (owner == player.Name)
	local bType = building:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	local healRange = tonumber(bData and bData.HealRange or 0) or 0
	local rangeColor = healRange > 0 and Color3.fromRGB(90, 230, 120) or (isOwned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 80, 80))
	local hl = Instance.new("Highlight")
	hl.Name = "BuildingHighlight"
	hl.Adornee = building
	hl.FillColor = isOwned and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(255, 80, 80)
	hl.FillTransparency = 0.5
	hl.OutlineColor = Color3.new(1, 1, 1)
	hl.Parent = building
	buildingHighlights[building] = hl

	local rangeAttr = tonumber(building:GetAttribute("Range") or 0) or 0
	local range = (rangeAttr > 0) and rangeAttr or (tonumber(bData and (bData.Range or bData.HealRange) or 0) or 0)
	if range > 0 then
		local indicator = createBuildingRangeIndicator(rangeColor)
		buildingRangeIndicators[building] = indicator
		startGlobalRangeUpdates()
	end
end

function UIMultiSelect.removeBuilding(building)
	if not selectedBuildings[building] then return end
	selectedBuildings[building] = nil
	if buildingHighlights[building] then
		buildingHighlights[building]:Destroy()
		buildingHighlights[building] = nil
	end
	if buildingRangeIndicators[building] then
		buildingRangeIndicators[building]:Destroy()
		buildingRangeIndicators[building] = nil
	end
	if next(selectedBuildings) == nil then
		stopGlobalRangeUpdates()
	end
end

function UIMultiSelect.clearAll()
	for b, _ in pairs(selectedBuildings) do
		if buildingHighlights[b] then buildingHighlights[b]:Destroy() end
	end
	for b, indicator in pairs(buildingRangeIndicators) do
		if indicator then
			indicator:Destroy()
		end
		buildingRangeIndicators[b] = nil
	end
	table.clear(selectedBuildings)
	table.clear(buildingHighlights)
	stopGlobalRangeUpdates()
end

function UIMultiSelect.getSelected()
	local list = {}
	for b, _ in pairs(selectedBuildings) do table.insert(list, b) end
	return list
end

function UIMultiSelect.hasBuilding(building)
	return selectedBuildings[building] == true
end

function UIMultiSelect.tryBuildWall()
	local towers = {}
	for b, _ in pairs(selectedBuildings) do
		if b:GetAttribute("ConnectsWalls") then
			table.insert(towers, b)
		end
	end
	if #towers == 2 and BuildWall then
		BuildWall:FireServer(towers[1], towers[2])
	end
end

workspace.DescendantRemoving:Connect(function(desc)
	if selectedBuildings[desc] then
		UIMultiSelect.removeBuilding(desc)
	end
end)

return UIMultiSelect
