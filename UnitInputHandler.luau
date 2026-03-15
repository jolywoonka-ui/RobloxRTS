-- UnitInputHandler (ModuleScript, ReplicatedStorage)
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MoveCommand = ReplicatedStorage:WaitForChild("MoveCommand")
local UIInspector = require(ReplicatedStorage:WaitForChild("UIInspector"))
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))

local InputHandler = {}

local Selection = nil
local PathVisuals = nil
local SquadManager = nil

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local dragScreen = nil
local dragFrame = nil
local isDragging = false
local dragStart = Vector2.new()
local SELECTION_COLOR = Color3.fromRGB(0, 255, 255)

local currentFormation = "circle"
local lastUnitClick = nil
local lastUnitClickTime = 0
local DOUBLE_CLICK_WINDOW = 0.35


function InputHandler.setFormation(formation)
	currentFormation = formation
end

function InputHandler.getFormation()
	return currentFormation
end

local function isMissileTargeting()
	return UIInspector.isMissileTargeting and UIInspector.isMissileTargeting()
end

local function findRootPart(unit)
	if unit:IsA("BasePart") then return unit end
	if unit:IsA("Model") then
		if unit.PrimaryPart then return unit.PrimaryPart end
		return unit:FindFirstChildWhichIsA("BasePart", true)
	end
	return nil
end

local function getUnitsInScreenBox(rectMin, rectMax)
	local unitsFound = {}
	local map = workspace:FindFirstChild("CurrentMap")
	local army = map and map:FindFirstChild("Army")
	if army then
		for _, unit in pairs(army:GetChildren()) do
			if unit:GetAttribute("Owner") == player.Name and unit:GetAttribute("IsUnit") then
				local root = findRootPart(unit)
				if root then
					local pos, onScreen = camera:WorldToViewportPoint(root.Position)
					if onScreen and pos.X > rectMin.X and pos.X < rectMax.X and pos.Y > rectMin.Y and pos.Y < rectMax.Y then
						table.insert(unitsFound, unit)
					end
				end
			end
		end
	end
	return unitsFound
end

local function getUnitTypeName(unit)
	if Selection and Selection.getUnitTypeName then
		return Selection.getUnitTypeName(unit)
	end
	return tostring(unit and unit.Name or "")
end

local function getOwnedUnitsOfType(unitTypeName)
	local matches = {}
	local map = workspace:FindFirstChild("CurrentMap")
	local army = map and map:FindFirstChild("Army")
	if not army then
		return matches
	end

	for _, unit in ipairs(army:GetChildren()) do
		if unit:GetAttribute("Owner") == player.Name and unit:GetAttribute("IsUnit") and getUnitTypeName(unit) == unitTypeName then
			table.insert(matches, unit)
		end
	end

	return matches
end

local function createDragUI()
	dragScreen = Instance.new("ScreenGui", player:WaitForChild("PlayerGui"))
	dragScreen.Name = "DragSelect"
	dragScreen.IgnoreGuiInset = true
	dragScreen.ResetOnSpawn = false

	dragFrame = Instance.new("Frame", dragScreen)
	dragFrame.BackgroundTransparency = 0.8
	dragFrame.BackgroundColor3 = SELECTION_COLOR
	dragFrame.BorderSizePixel = 1
	dragFrame.BorderColor3 = Color3.fromRGB(200, 255, 255)
	dragFrame.Visible = false
end

local function isGroundHit(raycastResult)
	if not raycastResult then return false end
	local hit = raycastResult.Instance
	if hit.Name == "Ground" then return true end
	if hit.Material == Enum.Material.Grass then return true end

	local map = workspace:FindFirstChild("CurrentMap")
	if map then
		local mapFolder = map:FindFirstChild("Map")
		if mapFolder then
			local forest = mapFolder:FindFirstChild("Forest")
			if forest then
				local current = hit
				while current do
					if current == forest then
						return true
					end
					current = current.Parent
				end
			end
		end
	end
	return false
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end
	if isMissileTargeting() then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			return
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if UIUtils.isPointerOverGui() or (UIInspector.isPointerOverInspector and UIInspector.isPointerOverInspector()) then
			return
		end
		isDragging = true
		dragStart = UserInputService:GetMouseLocation()
		dragFrame.Visible = true
		dragFrame.Size = UDim2.new(0, 0, 0, 0)
		dragFrame.Position = UDim2.new(0, dragStart.X, 0, dragStart.Y)

	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		local selected = Selection.getSelected()
		if #selected > 0 then
			local ray = mouse.UnitRay
			local params = RaycastParams.new()
			local ignore = {player.Character}

			local visuals = {
				workspace:FindFirstChild("UnitPathVisuals"),
				workspace:FindFirstChild("FormationGhosts"),
				workspace:FindFirstChild("BuilderRangeVisuals"),
				workspace:FindFirstChild("Ghosts"),
				workspace:FindFirstChild("LocalVisuals")
			}
			for _, v in ipairs(visuals) do
				if v then table.insert(ignore, v) end
			end

			local map = workspace:FindFirstChild("CurrentMap")
			if map then
				local army = map:FindFirstChild("Army")
				if army then table.insert(ignore, army) end
				local buildings = map:FindFirstChild("PlayerBuildings")
				if buildings then table.insert(ignore, buildings) end
				local walls = map:FindFirstChild("Walls")
				if walls then table.insert(ignore, walls) end
			end

			for _, u in ipairs(selected) do
				table.insert(ignore, u)
			end

			params.FilterDescendantsInstances = ignore
			params.FilterType = Enum.RaycastFilterType.Exclude

			local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
			if res then
				if not isGroundHit(res) then
					if PathVisuals and PathVisuals.showError then
						PathVisuals.showError("Unable to move unit there")
					end
					return
				end

				local pos = res.Position
				local isQueued = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				local formation = (#selected > 1) and currentFormation or "none"

				MoveCommand:FireServer(selected, pos, isQueued, formation)
			end
		end

	elseif input.KeyCode == Enum.KeyCode.E then
		Selection.deselectAll()
	end
end

local function onInputChanged(input)
	if isMissileTargeting() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement and isDragging then
		local curr = UserInputService:GetMouseLocation()
		local diff = curr - dragStart
		local x = math.min(dragStart.X, curr.X)
		local y = math.min(dragStart.Y, curr.Y)
		dragFrame.Position = UDim2.new(0, x, 0, y)
		dragFrame.Size = UDim2.new(0, math.abs(diff.X), 0, math.abs(diff.Y))
	end
end

local function onInputEnded(input)
	if isMissileTargeting() then
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
			dragFrame.Visible = false
		end
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and isDragging then
		if UIUtils.isPointerOverGui() or (UIInspector.isPointerOverInspector and UIInspector.isPointerOverInspector()) then
			isDragging = false
			dragFrame.Visible = false
			return
		end
		isDragging = false
		dragFrame.Visible = false
		local dragEnd = UserInputService:GetMouseLocation()

		if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			Selection.deselectAll()
		end

		if (dragEnd - dragStart).Magnitude > 5 then
			lastUnitClick = nil
			local min = Vector2.new(math.min(dragStart.X, dragEnd.X), math.min(dragStart.Y, dragEnd.Y))
			local max = Vector2.new(math.max(dragStart.X, dragEnd.X), math.max(dragStart.Y, dragEnd.Y))
			for _, u in ipairs(getUnitsInScreenBox(min, max)) do
				Selection.selectUnit(u)
			end
		else
			local ray = mouse.UnitRay
			local params = RaycastParams.new()
			params.FilterDescendantsInstances = {player.Character}
			params.FilterType = Enum.RaycastFilterType.Exclude
			local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
			local selectedUnit = nil

			if res and res.Instance then
				local hit = res.Instance
				local current = hit
				while current do
					if current:GetAttribute("IsUnit") then
						selectedUnit = current
						break
					end
					current = current.Parent
				end
			end

			if selectedUnit then
				local ctrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
				local now = tick()
				local isDoubleClick = (selectedUnit == lastUnitClick) and ((now - lastUnitClickTime) <= DOUBLE_CLICK_WINDOW)
				lastUnitClick = selectedUnit
				lastUnitClickTime = now

				if isDoubleClick then
					local unitTypeName = getUnitTypeName(selectedUnit)
					local matchingUnits = getOwnedUnitsOfType(unitTypeName)
					if Selection.replaceSelection then
						Selection.replaceSelection(matchingUnits)
					else
						Selection.deselectAll()
						for _, unit in ipairs(matchingUnits) do
							Selection.selectUnit(unit)
						end
					end
				else
					if not ctrlDown then
						Selection.deselectAll()
					end
					Selection.selectUnit(selectedUnit)
				end
			else
				lastUnitClick = nil
				Selection.deselectAll()
			end
		end
	end
end

function InputHandler.initialize(selectionModule, pathVisualsModule, squadManagerModule)
	Selection = selectionModule
	PathVisuals = pathVisualsModule
	SquadManager = squadManagerModule
	createDragUI()

	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
end

function InputHandler.updateHover()
	Selection.updateHover(mouse.Target)
end

return InputHandler
