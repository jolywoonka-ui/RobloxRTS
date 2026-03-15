-- PlacementClient (LocalScript, StarterPlayerScripts)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")

local BuildEvent = ReplicatedStorage:WaitForChild("BuildEvent")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local BuildingsFolder = ReplicatedStorage:WaitForChild("Buildings")
local StartBuildEvent = ReplicatedStorage:WaitForChild("StartBuild")
local WallMessage = ReplicatedStorage:FindFirstChild("WallMessage")

local isPlacing = false
local currentName = ""
local ghostModel = nil
local ghostBaseRotation = nil
local ghostBuildCFrame = nil
local rotation = 0
local snapEnabled = true
local GRID_SIZE = 4
local BUILD_RANGE_COLOR = Color3.fromRGB(0, 255, 100)
local BUILD_RANGE_BAD = Color3.fromRGB(255, 50, 50)
local THEME = UIStyle.Theme

local ghostFolder = workspace:FindFirstChild("Ghosts")
if not ghostFolder then
	ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "Ghosts"
	ghostFolder.Parent = workspace
end

-- Радиусы строителей (визуальные)
local showBuilderRanges = false
local builderDiscs = {}
local rangeVisualsFolder = Instance.new("Folder")
rangeVisualsFolder.Name = "BuilderRangeVisuals"
rangeVisualsFolder.Parent = workspace

-- Tooltip GUI
local tooltipGui = Instance.new("ScreenGui", playerGui)
tooltipGui.Name = "PlacementTooltip"
tooltipGui.ResetOnSpawn = false
tooltipGui.IgnoreGuiInset = true
local tooltipFrame = Instance.new("Frame", tooltipGui)
tooltipFrame.Size = UDim2.new(0, 280, 0, 170)
tooltipFrame.BackgroundColor3 = THEME.Background
tooltipFrame.BackgroundTransparency = 0.1
tooltipFrame.Visible = false
UIStyle.addCorner(tooltipFrame, UDim.new(0, 4))
UIStyle.addStroke(tooltipFrame, 1, THEME.Stroke)
local tooltipText = Instance.new("TextLabel", tooltipFrame)
tooltipText.Size = UDim2.new(1, -20, 1, -20)
tooltipText.Position = UDim2.new(0, 10, 0, 10)
tooltipText.BackgroundTransparency = 1
tooltipText.TextColor3 = THEME.Text
tooltipText.Font = THEME.FontBody
tooltipText.TextSize = 14
tooltipText.TextXAlignment = Enum.TextXAlignment.Left
tooltipText.TextYAlignment = Enum.TextYAlignment.Top
tooltipText.RichText = true
tooltipText.TextWrapped = true

local errorLabel = Instance.new("TextLabel", tooltipGui)
errorLabel.Size = UDim2.new(0, 400, 0, 40)
errorLabel.Position = UDim2.new(0.5, 0, 0.7, 0)
errorLabel.AnchorPoint = Vector2.new(0.5, 0.5)
errorLabel.BackgroundTransparency = 1
errorLabel.TextColor3 = THEME.Negative
errorLabel.Font = THEME.FontHeader
errorLabel.TextSize = 24
errorLabel.Visible = false

-- ==================== ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ====================

local function getMyBuilders()
	local builders = {}
	local map = workspace:FindFirstChild("CurrentMap")
	if map then
		local army = map:FindFirstChild("Army", true)
		if army then
			for _, unit in pairs(army:GetChildren()) do
				if unit.Name == "Builder" and unit:GetAttribute("Owner") == player.Name then
					table.insert(builders, unit)
				end
			end
		end
	end
	return builders
end

-- Функция получения высоты земли с исключением динамических объектов
local function getGroundY(pos)
	-- Собираем все статические части карты, которые считаем "землёй"
	local map = workspace:FindFirstChild("CurrentMap")
	local targets = {workspace.Terrain}
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

	-- Если нет целей, возвращаем текущую Y - 1 (грубо)
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
	-- fallback
	return pos.Y - 1
end

local function getModelBottomOffset(model)
	local pivotY = model:GetPivot().Position.Y
	local bboxCFrame, bboxSize = model:GetBoundingBox()
	local lowestY = bboxCFrame.Position.Y - (bboxSize.Y / 2)
	return pivotY - lowestY
end

local function updateRangeVisuals()
	if not showBuilderRanges then
		for _, disc in pairs(builderDiscs) do
			disc:Destroy()
		end
		table.clear(builderDiscs)
		return
	end

	local builders = getMyBuilders()
	local currentBuildersSet = {}
	for _, b in ipairs(builders) do
		currentBuildersSet[b] = true
	end

	-- Удаляем диски для исчезнувших строителей
	for b, disc in pairs(builderDiscs) do
		if not currentBuildersSet[b] then
			disc:Destroy()
			builderDiscs[b] = nil
		end
	end

	for _, builder in ipairs(builders) do
		local range = builder:GetAttribute("Range") or 15
		local pos = builder:GetPivot().Position
		-- Получаем высоту земли под строителем, игнорируя самого строителя
		local groundY = getGroundY(pos)
		local diameter = range * 2
		local thickness = 0.05

		local disc = builderDiscs[builder]
		if not disc then
			disc = Instance.new("Part")
			disc.Anchored = true
			disc.CanCollide = false
			disc.CanQuery = false
			disc.CastShadow = false
			disc.Material = Enum.Material.SmoothPlastic
			disc.Color = Color3.fromRGB(0, 200, 255)
			disc.Transparency = 1

			local function addRingFace(face)
				local gui = Instance.new("SurfaceGui")
				gui.Face = face
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 28
				gui.LightInfluence = 0
				gui.AlwaysOnTop = false
				gui.Parent = disc

				local ring = Instance.new("Frame")
				ring.Size = UDim2.fromScale(1, 1)
				ring.BackgroundColor3 = disc.Color
				ring.BackgroundTransparency = 0.86
				ring.Parent = gui

				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(1, 0)
				corner.Parent = ring

				local stroke = Instance.new("UIStroke")
				stroke.Color = disc.Color
				stroke.Thickness = 2
				stroke.Transparency = 0.2
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = ring
			end

			addRingFace(Enum.NormalId.Top)
			addRingFace(Enum.NormalId.Bottom)
			disc.Parent = rangeVisualsFolder
			builderDiscs[builder] = disc
		end
		disc.Size = Vector3.new(diameter, thickness, diameter)
		disc.CFrame = CFrame.new(pos.X, groundY + thickness/2 + 0.03, pos.Z)
	end
end

local function updateTooltip()
	if not isPlacing then return end
	local mPos = UserInputService:GetMouseLocation()
	tooltipFrame.Position = UDim2.new(0, mPos.X + 20, 0, mPos.Y)
	local data = Config.Buildings[currentName]
	local snapText = snapEnabled and '<font color="#00FF00">ON</font>' or '<font color="#FF0000">OFF</font>'
	local rangeText = showBuilderRanges and '<font color="#00FF00">ON</font>' or '<font color="#FF0000">OFF</font>'
	tooltipText.Text = string.format(
		'<b><font size="18">%s</font></b>\nCost: <font color="#00FF00">$%d</font>\n\n<b>[R]</b> Rotate\n<b>[T]</b> Snap: %s\n<b>[Y]</b> Ranges: %s\n<b>[SHIFT]</b> Hold to build multiple\n<b>[E]</b> Cancel',
		string.upper(currentName), data.Cost, snapText, rangeText
	)
end

local function findAllNodes(container, nodeName)
	local nodes = {}
	local function search(c)
		for _, child in pairs(c:GetChildren()) do
			if child:IsA("BasePart") and child.Name == nodeName then
				table.insert(nodes, child)
			elseif child:IsA("Folder") or child:IsA("Model") then
				search(child)
			end
		end
	end
	search(container)
	return nodes
end

-- Проверка наличия союзного юнита или здания в радиусе
local function hasAllyNearby(pos, radius)
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return false end

	local army = map:FindFirstChild("Army", true)
	if army then
		for _, unit in pairs(army:GetChildren()) do
			if unit:GetAttribute("Owner") == player.Name then
				local dist = (unit:GetPivot().Position - pos).Magnitude
				if dist < radius then
					return true
				end
			end
		end
	end

	local pBuildings = map:FindFirstChild("PlayerBuildings", true)
	if pBuildings then
		for _, b in pairs(pBuildings:GetChildren()) do
			if b:GetAttribute("Owner") == player.Name then
				local dist = (b:GetPivot().Position - pos).Magnitude
				if dist < radius then
					return true
				end
			end
		end
	end

	return false
end

local BLACKLISTED_MATERIALS = {
	[Enum.Material.Rock] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Concrete] = true,
	[Enum.Material.Brick] = true,
	[Enum.Material.Glacier] = true,
	[Enum.Material.Sandstone] = true,
	[Enum.Material.ForceField] = true,
}

-- ==================== ОСНОВНАЯ ЛОГИКА ====================

local function updateGhost()
	if not ghostModel then return end
	local map = workspace:FindFirstChild("CurrentMap")
	local filter = {workspace.Terrain}
	if map and map:FindFirstChild("Map") then
		table.insert(filter, map.Map)
	end

	local rayOrigin = mouse.UnitRay.Origin
	local rayDir = mouse.UnitRay.Direction * 2000
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = filter
	params.FilterType = Enum.RaycastFilterType.Include
	local res = workspace:Raycast(rayOrigin, rayDir, params)
	local groundPos = res and res.Position or (rayOrigin + rayDir * (-rayOrigin.Y / rayDir.Y))
	local normal = res and res.Normal or Vector3.new(0, 1, 0)
	local hitMaterial = res and res.Material or Enum.Material.Grass

	local finalX = groundPos.X
	local finalZ = groundPos.Z
	if snapEnabled then
		finalX = math.floor(finalX / GRID_SIZE + 0.5) * GRID_SIZE
		finalZ = math.floor(finalZ / GRID_SIZE + 0.5) * GRID_SIZE
	end

	local _, size = ghostModel:GetBoundingBox()
	local bottomOffset = getModelBottomOffset(ghostModel)
	local finalPos = Vector3.new(finalX, groundPos.Y + bottomOffset, finalZ)
	local isValid = true
	local errorMsg = ""
	local data = Config.Buildings[currentName]

	-- Проверка узла (для ферм)
	local snappedToNode = false
	local bestNode = nil
	if data.RestrictedNode and map then
		local allNodes = findAllNodes(map, data.RestrictedNode)
		local bestDist = math.huge
		for _, node in ipairs(allNodes) do
			if not node:GetAttribute("Occupied") then
				local dist = (Vector3.new(node.Position.X, 0, node.Position.Z) - Vector3.new(finalX, 0, finalZ)).Magnitude
				if dist < bestDist then
					bestDist = dist
					bestNode = node
				end
			end
		end
		if bestNode and bestDist < 4 then
			finalPos = Vector3.new(bestNode.Position.X, bestNode.Position.Y + bottomOffset, bestNode.Position.Z)
			snappedToNode = true
		elseif bestNode then
			isValid = false
			errorMsg = "Node too far (need <4)"
		else
			isValid = false
			errorMsg = "Need " .. data.RestrictedNode
		end
	end

	-- Проверка материала (если не на узле)
	if not snappedToNode and res and BLACKLISTED_MATERIALS[hitMaterial] then
		isValid = false
		errorMsg = "Can't build on " .. hitMaterial.Name
	end

	-- Проверка крутизны
	if not snappedToNode and normal.Y < 0.7 then
		isValid = false
		errorMsg = "Too steep"
	end

	-- Проверка наличия союзников рядом (для всех зданий, кроме штаба)
	if currentName ~= "Headquarters" then
		if not hasAllyNearby(finalPos, 15) then
			isValid = false
			errorMsg = "No ally nearby"
		end
	end

	ghostBuildCFrame = CFrame.new(finalPos) * CFrame.Angles(0, math.rad(rotation), 0)
	local modelRotation = ghostBaseRotation or CFrame.identity
	local finalCF = ghostBuildCFrame * modelRotation
	ghostModel:PivotTo(finalCF)

	-- Проверка коллизий с другими зданиями (но не с игроками)
	local op = OverlapParams.new()
	local ignoreList = {ghostModel}
	op.FilterDescendantsInstances = ignoreList
	op.FilterType = Enum.RaycastFilterType.Exclude
	local hits = workspace:GetPartBoundsInBox(finalCF, size * 0.9, op)

	for _, hit in pairs(hits) do
		local model = hit:FindFirstAncestorOfClass("Model") or hit
		-- Проверяем только здания (имеют Owner)
		if model:GetAttribute("Owner") and model ~= bestNode then
			isValid = false
			errorMsg = "Blocked by building"
			break
		end
	end

	local color = isValid and BUILD_RANGE_COLOR or BUILD_RANGE_BAD
	for _, p in pairs(ghostModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Color = color
		end
	end

	if not isValid then
		errorLabel.Visible = true
		errorLabel.Position = UDim2.new(0, UserInputService:GetMouseLocation().X, 0, UserInputService:GetMouseLocation().Y + 40)
		errorLabel.Text = string.upper(errorMsg)
	else
		errorLabel.Visible = false
	end
	updateTooltip()
end

local function cancel()
	isPlacing = false
	currentName = ""
	if ghostModel then
		ghostModel:Destroy()
		ghostModel = nil
	end
	ghostBaseRotation = nil
	ghostBuildCFrame = nil
	tooltipFrame.Visible = false
	errorLabel.Visible = false
	for _, disc in pairs(builderDiscs) do
		disc:Destroy()
	end
	table.clear(builderDiscs)
end

local function startPlacement(name)
	cancel()
	local ps = player:FindFirstChild("PlayerStats")
	if ps and ps:FindFirstChild("CanBuild") and ps.CanBuild.Value == 0 then
		return
	end
	if not BuildingsFolder:FindFirstChild(name) then return end
	isPlacing = true
	currentName = name
	rotation = 0
	local template = BuildingsFolder[name]
	ghostModel = template:Clone()
	ghostModel.Name = "Ghost"
	ghostBaseRotation = ghostModel:GetPivot().Rotation
	for _, p in pairs(ghostModel:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Transparency = 0.5
			p.CanCollide = false
			p.Material = Enum.Material.ForceField
			p.Color = BUILD_RANGE_COLOR
		elseif p:IsA("BillboardGui") or p:IsA("SurfaceGui") then
			p:Destroy()
		end
	end
	ghostModel.Parent = ghostFolder
	tooltipFrame.Visible = true
end

StartBuildEvent.Event:Connect(startPlacement)

if WallMessage then
	WallMessage.OnClientEvent:Connect(function(message)
		errorLabel.Text = string.upper(message)
		errorLabel.Visible = true
		task.delay(3, function() errorLabel.Visible = false end)
	end)
end

UserInputService.InputBegan:Connect(function(input, g)
	if g then return end
	if not isPlacing then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if ghostModel then
			local isValid = false
			for _, p in pairs(ghostModel:GetDescendants()) do
				if p:IsA("BasePart") and p.Color == BUILD_RANGE_COLOR then
					isValid = true
					break
				end
			end
			if isValid then
				BuildEvent:FireServer("Build", currentName, ghostBuildCFrame or ghostModel:GetPivot())
				if not UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
					cancel()
				end
			end
		end
	elseif input.KeyCode == Enum.KeyCode.R then
		rotation = (rotation + 90) % 360
	elseif input.KeyCode == Enum.KeyCode.T then
		snapEnabled = not snapEnabled
	elseif input.KeyCode == Enum.KeyCode.Y then
		showBuilderRanges = not showBuilderRanges
		updateRangeVisuals()
	elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.X then
		cancel()
	end
end)

RunService.RenderStepped:Connect(function()
	if isPlacing and ghostModel then
		updateRangeVisuals()
		updateGhost()
	else
		for _, disc in pairs(builderDiscs) do
			disc:Destroy()
		end
		table.clear(builderDiscs)
	end
end)

player.CharacterRemoving:Connect(cancel)



