-- MapInitializer (ModuleScript, ServerStorage)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local MapInitializer = {}
MapInitializer.__index = MapInitializer

function MapInitializer.new(serverStorage, setupBuildingFunc)
	local self = setmetatable({}, MapInitializer)
	self.ServerStorage = serverStorage
	self.SetupBuilding = setupBuildingFunc
	self.CurrentMap = nil
	self.PlayerBuildings = nil
	self.Army = nil
	return self
end

function MapInitializer:loadMap(templateName)
	local mapsFolder = self.ServerStorage:FindFirstChild("Maps")
	local template = nil
	if mapsFolder and mapsFolder:IsA("Folder") then
		template = mapsFolder:FindFirstChild(templateName)
	end
	if not template then
		template = self.ServerStorage:FindFirstChild(templateName)
	end
	if not template then
		warn("Map template not found:", templateName)
		return nil
	end
	local map = template:Clone()
	map.Name = "CurrentMap"
	map.Parent = workspace
	self.CurrentMap = map

	self.PlayerBuildings = map:FindFirstChild("PlayerBuildings", true)
	if not self.PlayerBuildings then
		self.PlayerBuildings = Instance.new("Folder", map)
		self.PlayerBuildings.Name = "PlayerBuildings"
	end

	self.Army = map:FindFirstChild("Army", true)
	if not self.Army then
		self.Army = Instance.new("Folder", map)
		self.Army.Name = "Army"
	end

	self:_setupBuildings()
	return map
end

function MapInitializer:_setupBuildings()
	if not self.PlayerBuildings then return end
	for _, building in pairs(self.PlayerBuildings:GetChildren()) do
		local typeName = nil
		if building.Name:match("^Headquarter") then
			typeName = "Headquarters"
		elseif Config.Buildings[building.Name] then
			typeName = building.Name
		else
			warn("Unknown building type for", building.Name)
		end

		if typeName then
			local data = Config.Buildings[typeName]
			if data then
				building:SetAttribute("Type", typeName)
				building:SetAttribute("MaxHealth", data.Health)
				building:SetAttribute("Health", data.Health)
				-- Combat attributes
				if data.Damage then building:SetAttribute("Damage", data.Damage) end
				if data.Range then building:SetAttribute("Range", data.Range) end
				if data.AttackCooldown then building:SetAttribute("AttackCooldown", data.AttackCooldown) end
				if typeName == "Headquarters" or typeName == "HeadquartersL2" then
					building:SetAttribute("BaseDamage", data.Damage or 0)
					building:SetAttribute("BaseRange", data.Range or 0)
					building:SetAttribute("HQRangeMode", building:GetAttribute("HQRangeMode") or "Balanced")
					building:SetAttribute("HQRangeCooldownUntil", building:GetAttribute("HQRangeCooldownUntil") or 0)
				end

				local hum = building:FindFirstChild("Humanoid")
				if not hum then
					hum = Instance.new("Humanoid", building)
				end
				hum.MaxHealth = data.Health
				hum.Health = data.Health
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

				if self.SetupBuilding then
					self.SetupBuilding(building)
				end
			end
		end
	end
end

function MapInitializer:getCurrentMap()
	return self.CurrentMap
end

function MapInitializer:getPlayerBuildings()
	return self.PlayerBuildings
end

function MapInitializer:getArmy()
	return self.Army
end

return MapInitializer
