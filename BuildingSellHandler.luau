-- BuildingSellHandler (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local WallManager = require(ServerStorage:WaitForChild("WallManager"))

local BuildingSellHandler = {}
BuildingSellHandler.__index = BuildingSellHandler

function BuildingSellHandler.new(nodeManager, playerBuildingsCount)
	local self = setmetatable({}, BuildingSellHandler)
	self.NodeManager = nodeManager
	self.PlayerBuildingsCount = playerBuildingsCount  -- reference to a table keyed by player.UserId -> { buildingName = count }
	return self
end

function BuildingSellHandler:sell(player, building)
	if not building or not building.Parent then return end
	if building:GetAttribute("Owner") ~= player.Name or building:GetAttribute("Selling") then return end
	local typeName = building:GetAttribute("Type")

	local data = Config.Buildings[typeName]
	if not data then return end

	building:SetAttribute("Selling", true)

	local ls = player:FindFirstChild("Stats")
	local ps = player:FindFirstChild("PlayerStats")
	if not ls or not ps then return end

	local refund = math.floor(data.Cost * (building:GetAttribute("IsUnderConstruction") and 0.75 or 0.5))
	ls.Credits.Value += refund

	-- Free node
	local nodeID = building:GetAttribute("OccupiedNodeID")
	local nodeName = building:GetAttribute("OccupiedNodeName")
	local nodePos = building:GetAttribute("OccupiedNodePos")
	self.NodeManager:freeNode(nodeID, nodeName, nodePos)

	-- Decrease building count
	if self.PlayerBuildingsCount[player.UserId] and self.PlayerBuildingsCount[player.UserId][typeName] then
		self.PlayerBuildingsCount[player.UserId][typeName] = self.PlayerBuildingsCount[player.UserId][typeName] - 1
	end

	local isUnderConstruction = building:GetAttribute("IsUnderConstruction")
	local energyReserved = building:GetAttribute("EnergyReserved")

	-- Revert complete-only bonuses
	if not isUnderConstruction then
		if data.Income then ps.Income.Value = math.max(Config.BaseIncome or 10, ps.Income.Value - data.Income) end
		if data.Energy > 0 then
			ps.MaxEnergy.Value = math.max(Config.BaseEnergy or 100, ps.MaxEnergy.Value - data.Energy)
		end
		if data.UnitLimit then ps.UnitLimit.Value -= data.UnitLimit end
	end

	-- Revert energy usage if it was already being consumed (reserved as ghost or completed old flow)
	if data.Energy < 0 and (energyReserved or not isUnderConstruction) then
		ps.Energy.Value = math.max(0, ps.Energy.Value - math.abs(data.Energy))
	end

	-- Remove walls
	if building:GetAttribute("ConnectsWalls") then
		WallManager.removeWallsForTower(building)
	end

	-- Explosion and destroy
	local exp = Instance.new("Explosion")
	exp.Position = building:GetPivot().Position
	exp.BlastRadius = 0
	exp.Parent = workspace
	building:Destroy()
end

return BuildingSellHandler
