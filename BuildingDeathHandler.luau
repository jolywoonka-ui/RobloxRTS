-- BuildingDeathHandler (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WallManager = require(ServerStorage:WaitForChild("WallManager"))

local BuildingDeathHandler = {}
BuildingDeathHandler.__index = BuildingDeathHandler

function BuildingDeathHandler.new(nodeManager)
	local self = setmetatable({}, BuildingDeathHandler)
	self.NodeManager = nodeManager
	return self
end

function BuildingDeathHandler:handleDeath(building, playerBuildingCounts)
	if not building.Parent or building:GetAttribute("Selling") then return end

	local buildingType = building:GetAttribute("Type")
	local ownerName = building:GetAttribute("Owner")
	local player = ownerName and Players:FindFirstChild(ownerName)
	local ps = player and player:FindFirstChild("PlayerStats")
	local data = Config.Buildings[buildingType]

	local nodeID = building:GetAttribute("OccupiedNodeID")
	local nodeName = building:GetAttribute("OccupiedNodeName")
	local nodePos = building:GetAttribute("OccupiedNodePos")
	self.NodeManager:freeNode(nodeID, nodeName, nodePos)

	if playerBuildingCounts and buildingType then
		if playerBuildingCounts[buildingType] then
			playerBuildingCounts[buildingType] = math.max(0, playerBuildingCounts[buildingType] - 1)
		end
	end

	if ps and data then
		local isUnderConstruction = building:GetAttribute("IsUnderConstruction")
		local energyReserved = building:GetAttribute("EnergyReserved")

		if not isUnderConstruction then
			if data.Income then ps.Income.Value -= data.Income end
			if data.Energy > 0 then
				ps.MaxEnergy.Value -= data.Energy
			end
			if data.UnitLimit then ps.UnitLimit.Value -= data.UnitLimit end
		end

		if data.Energy < 0 and (energyReserved or not isUnderConstruction) then
			ps.Energy.Value = math.max(0, ps.Energy.Value - math.abs(data.Energy))
		end
	end

	if building.Name:match("^Headquarter") then
		if ps then ps.CanBuild.Value = 0 end
	end

	if building:GetAttribute("ConnectsWalls") then
		WallManager.removeWallsForTower(building)
	end

	if building:GetAttribute("Capacity") then
		local BunkerManager = require(ServerStorage:WaitForChild("BunkerManager"))
		BunkerManager:onBunkerDestroyed(building)
	end

	local exp = Instance.new("Explosion")
	exp.Position = building:GetPivot().Position
	exp.BlastRadius = 0
	exp.Parent = workspace

	task.wait(0.2)
	building:Destroy()
end

return BuildingDeathHandler
