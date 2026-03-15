-- UIMouseHandler (ModuleScript, ReplicatedStorage)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIUtils = require(ReplicatedStorage:WaitForChild("UIUtils"))
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local SellEvent = ReplicatedStorage:WaitForChild("SellEvent")

local UIMouseHandler = {}

local UIInspector = nil
local UIUnitInspector = nil
local UIMultiSelect = nil
local Selection = nil

local lastBuildingClick = nil
local lastBuildingClickTime = 0
local DOUBLE_CLICK_WINDOW = 0.35

local sharedRaycastParams = RaycastParams.new()

local function isCtrlDown()
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

local function getOwnedBuildingsOfType(buildingType)
	local list = {}
	local map = workspace:FindFirstChild("CurrentMap")
	local container = map and map:FindFirstChild("PlayerBuildings")
	if not container then
		return list
	end

	for _, inst in ipairs(container:GetChildren()) do
		if inst:IsA("Model") and inst:GetAttribute("Type") == buildingType and inst:GetAttribute("Owner") == player.Name then
			table.insert(list, inst)
		end
	end
	return list
end

local function isBuildingSelected(building)
	for _, b in ipairs(UIMultiSelect.getSelected()) do
		if b == building then
			return true
		end
	end
	return false
end

local function getPrimarySelectedBuilding()
	local selected = UIMultiSelect.getSelected()
	for _, building in ipairs(selected) do
		if building and building.Parent then
			return building
		end
	end
	return nil
end

local function sellSelectedBuildings()
	local targets = {}
	local seen = {}

	for _, b in ipairs(UIMultiSelect.getSelected()) do
		if b and b.Parent and b:GetAttribute("Owner") == player.Name and not seen[b] then
			seen[b] = true
			table.insert(targets, b)
		end
	end

	if #targets == 0 then
		local current = UIInspector.getSelectedBuilding()
		if current and current.Parent and current:GetAttribute("Owner") == player.Name then
			table.insert(targets, current)
		end
	end

	for _, b in ipairs(targets) do
		SellEvent:FireServer(b)
	end

	if #targets > 0 then
		UIMultiSelect.clearAll()
		UIInspector.closeInspector()
	end
end

local function onInputBegan(input, g)
	if g then return end
    if UIInspector and UIInspector.isMissileTargeting and UIInspector.isMissileTargeting() then
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            return
        end
    end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if UIUtils.isPointerOverGui() or (UIInspector and UIInspector.isPointerOverInspector and UIInspector.isPointerOverInspector()) then
			return
		end
		local ray = mouse.UnitRay
		sharedRaycastParams.FilterDescendantsInstances = {player.Character}
		sharedRaycastParams.FilterType = Enum.RaycastFilterType.Exclude
		local res = workspace:Raycast(ray.Origin, ray.Direction * 1000, sharedRaycastParams)
		local ctrlDown = isCtrlDown()

		if res and res.Instance then
			local m = res.Instance:FindFirstAncestorOfClass("Model")
			if m then
				if m:GetAttribute("Type") then
					UIUnitInspector.hide()
					local isOwned = (m:GetAttribute("Owner") == player.Name)
					local now = tick()
					local isDoubleClick = (m == lastBuildingClick) and ((now - lastBuildingClickTime) <= DOUBLE_CLICK_WINDOW)
					lastBuildingClick = m
					lastBuildingClickTime = now

					if isDoubleClick and isOwned then
						local buildingType = m:GetAttribute("Type")
						local owned = getOwnedBuildingsOfType(buildingType)
						UIMultiSelect.clearAll()
						for _, b in ipairs(owned) do
							UIMultiSelect.addBuilding(b)
						end
						UIInspector.openInspector(m)
						return
					end

					if ctrlDown then
						if not isOwned then
							UIMultiSelect.clearAll()
							UIInspector.openInspector(m)
							return
						end
						-- Keep the previously single-selected building when Ctrl is pressed after initial click.
						if #UIMultiSelect.getSelected() == 0 then
							local current = UIInspector.getSelectedBuilding()
							if current and current.Parent and current:GetAttribute("Owner") == player.Name then
								UIMultiSelect.addBuilding(current)
							end
						end
						if isBuildingSelected(m) then
							UIMultiSelect.removeBuilding(m)
						else
							UIMultiSelect.addBuilding(m)
						end
						local primary = getPrimarySelectedBuilding()
						if primary then
							UIInspector.openInspector(primary)
						else
							UIInspector.closeInspector()
						end
					else
						UIMultiSelect.clearAll()
						UIInspector.openInspector(m)
					end
					return
				elseif m:GetAttribute("IsUnit") then
					lastBuildingClick = nil
					UIInspector.closeInspector()
					return
				end
			end
		end
		lastBuildingClick = nil
		UIMultiSelect.clearAll()
		UIInspector.closeInspector()
		UIUnitInspector.hide()
	elseif input.KeyCode == Enum.KeyCode.Delete then
		sellSelectedBuildings()
	elseif input.KeyCode == Enum.KeyCode.F then
		local selected = Selection and Selection.getSelected() or {}
		if #selected == 1 then
			local obj = selected[1]
			local class = obj:GetAttribute("Class")
			local damage = obj:GetAttribute("Damage")
			if (class == "Vehicle" or class == "Air") and damage == 0 then
				local LoadTransport = ReplicatedStorage:FindFirstChild("LoadTransport")
				if LoadTransport then
					LoadTransport:FireServer(obj, "Toggle")
				end
				return
			end
			if obj:GetAttribute("Capacity") then
				local BunkerEvent = ReplicatedStorage:FindFirstChild("BunkerEvent")
				if BunkerEvent then
					BunkerEvent:FireServer(obj, "Toggle")
				end
				return
			end
		end
		local count = 0
		local towers = {}
		for _, b in ipairs(UIMultiSelect.getSelected()) do
			count = count + 1
			table.insert(towers, b)
		end
		if count == 2 and towers[1]:GetAttribute("ConnectsWalls") and towers[2]:GetAttribute("ConnectsWalls") then
			local BuildWall = ReplicatedStorage:FindFirstChild("BuildWall")
			if BuildWall then
				BuildWall:FireServer(towers[1], towers[2])
			end
		end
	end
end

function UIMouseHandler.init(inspectorModule, unitInspectorModule, multiSelectModule, selectionModule)
	UIInspector = inspectorModule
	UIUnitInspector = unitInspectorModule
	UIMultiSelect = multiSelectModule
	Selection = selectionModule

	UserInputService.InputBegan:Connect(onInputBegan)
end

return UIMouseHandler

