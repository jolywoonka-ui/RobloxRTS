-- UnitServer (Script, ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local UnitEvent = ReplicatedStorage:WaitForChild("UnitEvent")
local SpawnUnitEvent = ServerStorage:WaitForChild("SpawnUnitEvent")
local SpawnNeutralUnitEvent = ServerStorage:FindFirstChild("SpawnNeutralUnitEvent")
local LoadTransport = ReplicatedStorage:FindFirstChild("LoadTransport")
local DeleteUnit = ReplicatedStorage:FindFirstChild("DeleteUnit")

local UnitSpawner = require(ServerStorage:WaitForChild("UnitSpawner"))
local UnitQueue = require(ServerStorage:WaitForChild("UnitQueue"))
local UnitTransport = require(ServerStorage:WaitForChild("UnitTransport"))
local UnitDeletion = require(ServerStorage:WaitForChild("UnitDeletion"))
local UnitPhysics = require(ServerStorage:WaitForChild("UnitPhysics"))
if not UnitPhysics then
	warn("UnitPhysics module failed to load!")
	return
end

-- Ensure SpawnNeutralUnitEvent exists
if not SpawnNeutralUnitEvent then
	SpawnNeutralUnitEvent = Instance.new("BindableEvent")
	SpawnNeutralUnitEvent.Name = "SpawnNeutralUnitEvent"
	SpawnNeutralUnitEvent.Parent = ServerStorage
end

-- Connect UnitEvent for training actions
UnitEvent.OnServerEvent:Connect(function(player, action, building, extra)
	if type(action) ~= "string" then return end
	if action == "Train" then
		if typeof(building) ~= "Instance" or building.Parent == nil then return end
		if building:GetAttribute("Owner") ~= player.Name then return end
		UnitQueue.addToQueue(player, building, extra)
	elseif action == "CancelTrain" then
		if typeof(building) ~= "Instance" or building.Parent == nil then return end
		if building:GetAttribute("Owner") ~= player.Name then return end
		UnitQueue.cancelTrain(player, building, extra)
	end
end)

-- Connect spawn events
SpawnUnitEvent.Event:Connect(function(player, building, unitName)
	UnitSpawner.spawnPlayer(player, building, unitName)
end)

SpawnNeutralUnitEvent.Event:Connect(function(building, unitName)
	UnitSpawner.spawnNeutral(building, unitName)
end)

-- Connect transport loading
if LoadTransport then
	LoadTransport.OnServerEvent:Connect(function(player, transport, action)
		if typeof(transport) ~= "Instance" then return end
		if type(action) ~= "string" and action ~= nil then return end
		UnitTransport.toggle(transport, player, action)
	end)
end

-- Connect unit deletion
if DeleteUnit then
	DeleteUnit.OnServerEvent:Connect(function(player, units)
		UnitDeletion.deleteUnits(player, units)
	end)
end

-- Attach health bar and death handling
local function attachHealthHandlers(unit)
	if not unit:GetAttribute("IsUnit") then return end
	local _, hpFill, hpGradient = UnitPhysics.createHealthBar(unit, unit:GetAttribute("MaxHealth"))

	local ownerName = unit:GetAttribute("Owner")
	local currentUnits = nil
	if ownerName then
		local ownerPlayer = Players:FindFirstChild(ownerName)
		if ownerPlayer then
			local ps = ownerPlayer:FindFirstChild("PlayerStats")
			if ps then
				currentUnits = ps:FindFirstChild("CurrentUnits")
			end
		end
	end

	unit:GetAttributeChangedSignal("Health"):Connect(function()
		local hp = unit:GetAttribute("Health")
		local max = unit:GetAttribute("MaxHealth")
		if hp < max then
			local gui = unit:FindFirstChild("HP_Gui")
			if gui then gui.Enabled = true end
		end
		local p = math.clamp(hp / max, 0, 1)
		hpFill:TweenSize(UDim2.new(p, 0, 1, 0), "Out", "Quad", 0.1, true)
		if p < 0.3 then
			hpGradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 40))
			}
		elseif p < 0.6 then
			hpGradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 160, 0))
			}
		else
			hpGradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 80)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 200, 40))
			}
		end
		if hp <= 0 then
			local isTransport = (unit:GetAttribute("Capacity") ~= nil) and ((unit:GetAttribute("Damage") or 0) == 0)
			if isTransport then
				-- Transport: kill passengers
				local owner = unit:GetAttribute("Owner")
				local player = owner and Players:FindFirstChild(owner)
				if player then
					local passengerJson = unit:GetAttribute("Passengers")
					if passengerJson and passengerJson ~= "" then
						local success, passengers = pcall(HttpService.JSONDecode, HttpService, passengerJson)
						if success and type(passengers) == "table" then
							local totalSupply = 0
							for _, info in ipairs(passengers) do
								totalSupply = totalSupply + (info.Supply or 1)
							end
							local ps = player:FindFirstChild("PlayerStats")
							if ps and ps:FindFirstChild("CurrentUnits") then
								ps.CurrentUnits.Value = math.max(0, ps.CurrentUnits.Value - totalSupply)
							end
						end
					end
				end
			end
			if currentUnits then
				currentUnits.Value = math.max(0, currentUnits.Value - (unit:GetAttribute("Supply") or 1))
			end
			unit:Destroy()
		end
	end)
end

-- Monitor army for added units
local function setupArmyMonitoring(army)
	army.ChildAdded:Connect(function(unit)
		task.wait() -- let attributes be set
		if unit:GetAttribute("IsUnit") then
			attachHealthHandlers(unit)
		end
	end)
	for _, unit in pairs(army:GetChildren()) do
		if unit:GetAttribute("IsUnit") then
			attachHealthHandlers(unit)
		end
	end
end

-- Find or create army folder
local function getArmy()
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return nil end
	local army = map:FindFirstChild("Army")
	if not army then
		army = Instance.new("Folder", map)
		army.Name = "Army"
	end
	return army
end

-- Initial setup
local army = getArmy()
if army then
	setupArmyMonitoring(army)
end

-- Also watch for map creation (round start)
workspace.ChildAdded:Connect(function(child)
	if child.Name == "CurrentMap" then
		task.wait(1)
		local army = child:FindFirstChild("Army")
		if army then
			setupArmyMonitoring(army)
		end
	end
end)

print("UnitServer (modular) loaded with health bar handling")
