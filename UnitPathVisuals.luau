-- UnitPathVisuals (ModuleScript, ReplicatedStorage)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PathVisuals = {}

local unitData = {}
local VisualsFolder = nil
local showPaths = true
local REACHED_DIST = 2.5

local player = Players.LocalPlayer

local function loadShowPaths()
	local success, value = pcall(function()
		return player:GetAttribute("ShowUnitPaths")
	end)
	if success and value ~= nil then
		showPaths = value
	else
		showPaths = true
	end
end
loadShowPaths()

function PathVisuals.setShowPaths(enabled)
	showPaths = enabled
	player:SetAttribute("ShowUnitPaths", enabled)
	if not enabled then
		for unit in pairs(unitData) do
			PathVisuals.clearPath(unit)
		end
	end
end

local errorGui = Instance.new("ScreenGui")
errorGui.Name = "MoveErrorGui"
errorGui.Parent = player:WaitForChild("PlayerGui")
errorGui.ResetOnSpawn = false
errorGui.IgnoreGuiInset = true

local errorLabel = Instance.new("TextLabel", errorGui)
errorLabel.Size = UDim2.new(0, 300, 0, 50)
errorLabel.Position = UDim2.new(0.5, -150, 0.5, -25)
errorLabel.BackgroundTransparency = 1
errorLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
errorLabel.Font = Enum.Font.Gotham
errorLabel.TextSize = 24
errorLabel.Visible = false

function PathVisuals.showError(text)
	errorLabel.Text = text
	errorLabel.Visible = true
	task.delay(2, function() errorLabel.Visible = false end)
end

local function getVisualsFolder()
	if not VisualsFolder then
		VisualsFolder = Instance.new("Folder")
		VisualsFolder.Name = "UnitPathVisuals"
		VisualsFolder.Parent = workspace
	end
	return VisualsFolder
end

local function createLinePart()
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = Color3.new(1, 1, 1)
	part.Transparency = 0.3
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = getVisualsFolder()
	return part
end

local function updateLinePart(part, startPos, endPos)
	if not part or not part.Parent then return end
	local dir = endPos - startPos
	local length = dir.Magnitude
	if length < 0.5 then
		part.Transparency = 1
		return
	end
	part.Transparency = 0.3
	part.Size = Vector3.new(0.2, length, 0.2)
	local mid = (startPos + endPos) / 2
	part.CFrame = CFrame.lookAt(mid, endPos) * CFrame.Angles(math.pi/2, 0, 0)
end

local function getUnitWorldPosition(unit)
	if not unit or not unit.Parent then return nil end
	if unit:IsA("BasePart") then
		return unit.Position
	end
	if unit:IsA("Model") then
		local root = unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
		if root and root:IsA("BasePart") then
			return root.Position
		end
		local ok, pivot = pcall(function()
			return unit:GetPivot()
		end)
		if ok and pivot then
			return pivot.Position
		end
	end
	return nil
end

local function rebuildVisuals(unit, waypoints)
	if not unit or not unit.Parent then return end
	if not unit:IsA("Model") and not unit:IsA("BasePart") then return end
	local data = unitData[unit]
	if not data then
		data = { waypoints = {}, lines = {}, movingLine = nil }
		unitData[unit] = data
	end

	if data.movingLine then
		data.movingLine:Destroy()
		data.movingLine = nil
	end
	if data.updateConn then
		data.updateConn:Disconnect()
		data.updateConn = nil
	end
	for _, line in ipairs(data.lines) do
		if line then line:Destroy() end
	end
	data.lines = {}

	if not showPaths or #waypoints == 0 then
		data.waypoints = {}
		return
	end

	data.waypoints = waypoints

	for i = 1, #waypoints - 1 do
		local line = createLinePart()
		updateLinePart(line, waypoints[i], waypoints[i+1])
		table.insert(data.lines, line)
	end

	local movingLine = createLinePart()
	data.movingLine = movingLine
	local function updateMovingLine()
		if not unit or not unit.Parent or not data.movingLine then
			return
		end
		local startPos = getUnitWorldPosition(unit)
		if not startPos then
			data.movingLine.Transparency = 1
			return
		end
		local endPos = data.waypoints[1]
		if endPos then
			updateLinePart(data.movingLine, startPos, endPos)
		else
			data.movingLine.Transparency = 1
		end
	end
	updateMovingLine()
	data.updateConn = RunService.Heartbeat:Connect(updateMovingLine)
end

local function checkWaypointReached(unit)
	if not unit or not unit.Parent then
		PathVisuals.clearPath(unit)
		return
	end
	if not unit:IsA("Model") and not unit:IsA("BasePart") then
		PathVisuals.clearPath(unit)
		return
	end
	local data = unitData[unit]
	if not data or not data.waypoints or #data.waypoints == 0 then
		return
	end
	local pos = getUnitWorldPosition(unit)
	if not pos then return end
	local target = data.waypoints[1]
	local dist = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(target.X, 0, target.Z)).Magnitude

	if dist < REACHED_DIST then
		table.remove(data.waypoints, 1)
		rebuildVisuals(unit, data.waypoints)
	end
end

function PathVisuals.updatePath(unit, waypoints)
	if typeof(unit) ~= "Instance" then return end
	if not unit.Parent then return end
	if not unit:IsA("Model") and not unit:IsA("BasePart") then return end
	if unit:GetAttribute("Owner") ~= player.Name then return end
	rebuildVisuals(unit, waypoints)
end

function PathVisuals.clearPath(unit)
	if typeof(unit) ~= "Instance" then return end
	local data = unitData[unit]
	if data then
		if data.updateConn then
			data.updateConn:Disconnect()
		end
		if data.movingLine then
			data.movingLine:Destroy()
		end
		for _, line in ipairs(data.lines) do
			if line then line:Destroy() end
		end
		unitData[unit] = nil
	end
end

RunService.Heartbeat:Connect(function()
	if not showPaths then return end
	for unit, data in pairs(unitData) do
		if unit and unit.Parent then
			checkWaypointReached(unit)
		else
			PathVisuals.clearPath(unit)
		end
	end
end)

workspace.DescendantRemoving:Connect(function(desc)
	if desc and desc:IsA("Model") and desc:GetAttribute("IsUnit") then
		PathVisuals.clearPath(desc)
	end
end)

local MoveCommand = ReplicatedStorage:FindFirstChild("MoveCommand")
if MoveCommand then
	MoveCommand.OnClientEvent:Connect(function(unitList, pathArray)
		if not pathArray then return end
		for i, unit in ipairs(unitList) do
			local waypoints = pathArray[i] or {}
			PathVisuals.updatePath(unit, waypoints)
		end
	end)
end

return PathVisuals
