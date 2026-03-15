-- UpgradeManager (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local BuildingsFolder = ReplicatedStorage:WaitForChild("Buildings")

local templateDescendantsCache = {}

local UpgradeManager = {}
UpgradeManager.__index = UpgradeManager

function UpgradeManager.new(mapModel)
	local self = setmetatable({}, UpgradeManager)
	self.MapModel = mapModel
	self.UpgradingBuildings = {}
	return self
end

function UpgradeManager:startUpgrade(player, building)
	if not building or building.Parent == nil then return "Building missing" end
	if building:GetAttribute("Owner") ~= player.Name then return "Not your building" end
	if building:GetAttribute("IsUnderConstruction") then return "Still under construction" end
	if building:GetAttribute("IsUpgrading") then return "Already upgrading" end

	local ps = player:FindFirstChild("PlayerStats")
	if ps and ps:FindFirstChild("Energy") and ps:FindFirstChild("MaxEnergy") and ps.Energy.Value > ps.MaxEnergy.Value then
		return "Low power"
	end

	local bType = building:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	if not bData or not bData.CanUpgrade then return "Cannot upgrade" end

	local ls = player:FindFirstChild("Stats")
	if not ls or ls.Credits.Value < bData.UpgradeCost then return "Not enough credits" end

	local targetType = bData.UpgradesTo
	if not targetType then return "No upgrade path" end
	local targetData = Config.Buildings[targetType]
	if not targetData then return "Upgrade target missing" end

	ls.Credits.Value -= bData.UpgradeCost

	building:SetAttribute("IsUpgrading", true)
	building:SetAttribute("UpgradeProgress", 0)
	building:SetAttribute("UpgradeTarget", targetType)

	self.UpgradingBuildings[building] = {
		startTime = tick(),
		duration = bData.UpgradeTime,
		cost = bData.UpgradeCost,
		targetType = targetType,
		player = player
	}

	self:showProgressBar(building, 0)
	return "Success"
end

function UpgradeManager:tick(dt)
	local now = tick()
	local toRemove = {}

	for building, data in pairs(self.UpgradingBuildings) do
		if not building.Parent then
			table.insert(toRemove, building)
		else
			local elapsed = now - data.startTime
			local progress = math.min(1, elapsed / data.duration)
			building:SetAttribute("UpgradeProgress", progress * 100)
			self:showProgressBar(building, progress)

			if progress >= 1 then
				self:completeUpgrade(building, data)
				table.insert(toRemove, building)
			end
		end
	end

	for _, b in ipairs(toRemove) do
		self.UpgradingBuildings[b] = nil
	end
end

function UpgradeManager:showProgressBar(building, progress)
	local bg = building:FindFirstChild("UpgradeProgressBar")
	if not bg then
		local _, size = building:GetBoundingBox()
		bg = Instance.new("BillboardGui", building)
		bg.Name = "UpgradeProgressBar"
		bg.Size = UDim2.new(5, 0, 0.6, 0)
		bg.StudsOffset = Vector3.new(0, size.Y/2 + 2, 0)
		bg.MaxDistance = 80
		bg.AlwaysOnTop = true

		local barBg = Instance.new("Frame", bg)
		barBg.Size = UDim2.new(1, 0, 0.4, 0)
		barBg.BackgroundColor3 = Color3.new(0,0,0)
		barBg.BorderSizePixel = 0
		Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)
		Instance.new("UIStroke", barBg).Color = Color3.new(0.3,0.3,0.3)

		local barFill = Instance.new("Frame", barBg)
		barFill.Name = "Fill"
		barFill.Size = UDim2.new(progress, 0, 1, 0)
		barFill.BackgroundColor3 = Color3.fromRGB(100,200,255)
		barFill.BorderSizePixel = 0
		Instance.new("UICorner", barFill).CornerRadius = UDim.new(0, 4)
	else
		local barFill = bg:FindFirstChild("Frame") and bg.Frame:FindFirstChild("Fill")
		if barFill then
			barFill.Size = UDim2.new(progress, 0, 1, 0)
		end
	end
end

function UpgradeManager:completeUpgrade(building, data)
	local oldType = building:GetAttribute("Type")
	local newType = data.targetType
	local newData = Config.Buildings[newType]
	if not newData then return end

	local owner = building:GetAttribute("Owner")
	local health = building:GetAttribute("Health")
	local maxHealth = building:GetAttribute("MaxHealth")
	local healthPercent = health / maxHealth
	local cframe = building:GetPivot()
	local parent = building.Parent
	local garrison = building:GetAttribute("Garrison")
	local garrisonCount = building:GetAttribute("GarrisonCount")

	local template = BuildingsFolder:FindFirstChild(newType)
	if not template then
		warn("UpgradeManager: Template for", newType, "not found")
		return
	end

	local BuildingSpawner = require(ServerStorage:WaitForChild("BuildingSpawner"))

	-- Получаем высоту земли под старым зданием (игнорируя все здания)
	local groundY = BuildingSpawner.getGroundHeightStatic(cframe.Position)
	-- Нижняя точка нового здания (относительно его pivot в шаблоне)
	local newBottomOffset = BuildingSpawner.getModelBottomOffsetStatic(template)

	local targetY = groundY + newBottomOffset
	local finalPos = Vector3.new(cframe.X, targetY, cframe.Z)
	local finalCF = CFrame.new(finalPos) * cframe.Rotation

	local newBuilding = template:Clone()
	newBuilding.Name = newType
	newBuilding:PivotTo(finalCF)

	if not templateDescendantsCache[newType] then
		local baseParts = {}
		local teamPaints = {}
		for i, part in ipairs(template:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(baseParts, i)
				if part.Name == "TeamPaint" then
					table.insert(teamPaints, i)
				end
			end
		end
		templateDescendantsCache[newType] = {
			baseParts = baseParts,
			teamPaints = teamPaints
		}
	end

	local cache = templateDescendantsCache[newType]
	local descendants = newBuilding:GetDescendants()

	local function applyTeamColor(player)
		if not player then return end
		local teamColor = player:GetAttribute("TeamColor")
		if not teamColor then return end
		for _, idx in ipairs(cache.teamPaints) do
			local part = descendants[idx]
			if part then
				part.Color = teamColor
			end
		end
	end
	applyTeamColor(data.player)

	newBuilding:SetAttribute("Owner", owner)
	newBuilding:SetAttribute("Type", newType)
	newBuilding:SetAttribute("MaxHealth", newData.Health)
	newBuilding:SetAttribute("Health", newData.Health * healthPercent)
	newBuilding:SetAttribute("Damage", newData.Damage or 0)
	newBuilding:SetAttribute("Range", newData.Range or 0)
	newBuilding:SetAttribute("AttackCooldown", newData.AttackCooldown or 1.5)
	if newType == "HeadquartersL2" or newType == "Headquarters" then
		local preservedMode = building:GetAttribute("HQRangeMode") or "Balanced"
		local preservedCooldown = building:GetAttribute("HQRangeCooldownUntil") or 0
		local modeStats = {
			Close = {Range = 6, Damage = 20},
			Balanced = {Range = 8, Damage = 15},
			Long = {Range = 10, Damage = 10},
		}
		local modeData = modeStats[preservedMode] or modeStats.Balanced
		newBuilding:SetAttribute("BaseDamage", newData.Damage or 0)
		newBuilding:SetAttribute("BaseRange", newData.Range or 0)
		newBuilding:SetAttribute("HQRangeMode", preservedMode)
		newBuilding:SetAttribute("HQRangeCooldownUntil", preservedCooldown)
		newBuilding:SetAttribute("Damage", modeData.Damage)
		newBuilding:SetAttribute("Range", modeData.Range)
	end
	newBuilding:SetAttribute("Energy", newData.Energy or 0)
	newBuilding:SetAttribute("Income", newData.Income or 0)
	newBuilding:SetAttribute("UnitLimit", newData.UnitLimit or 0)
	if garrison then
		newBuilding:SetAttribute("Garrison", garrison)
		newBuilding:SetAttribute("GarrisonCount", garrisonCount or 0)
	end
	-- Добавить копирование узла
	local nodeID = building:GetAttribute("OccupiedNodeID")
	local nodeName = building:GetAttribute("OccupiedNodeName")
	local nodePos = building:GetAttribute("OccupiedNodePos")
	if nodeID then
		newBuilding:SetAttribute("OccupiedNodeID", nodeID)
		newBuilding:SetAttribute("OccupiedNodeName", nodeName)
		newBuilding:SetAttribute("OccupiedNodePos", nodePos)
	end

	if newData.CanRecruit then
		newBuilding:SetAttribute("CanRecruit", table.concat(newData.CanRecruit, ","))
	end

	local hum = newBuilding:FindFirstChild("Humanoid")
	if hum then
		hum.MaxHealth = newData.Health
		hum.Health = newData.Health * healthPercent
	end

	for _, idx in ipairs(cache.baseParts) do
		local part = descendants[idx]
		if part then
			part.Anchored = true
			if _G.setCollisionGroup then
				_G.setCollisionGroup(newBuilding, "Buildings")
			else
				part.CollisionGroup = "Default"
			end
		end
	end

	BuildingSpawner.addHealthBar(newBuilding)

	newBuilding.Parent = parent

	local player = data.player
	if player then
		local ps = player:FindFirstChild("PlayerStats")
		local oldData = Config.Buildings[oldType]
		if ps and oldData then
			if oldData.Energy ~= newData.Energy then
				if oldData.Energy > 0 then
					ps.MaxEnergy.Value = ps.MaxEnergy.Value - oldData.Energy + newData.Energy
				elseif oldData.Energy < 0 then
					ps.Energy.Value = ps.Energy.Value - math.abs(oldData.Energy) + math.abs(newData.Energy)
				end
			end
			if (oldData.Income or 0) ~= (newData.Income or 0) then
				ps.Income.Value = ps.Income.Value - (oldData.Income or 0) + (newData.Income or 0)
			end
			if (oldData.UnitLimit or 0) ~= (newData.UnitLimit or 0) then
				ps.UnitLimit.Value = ps.UnitLimit.Value - (oldData.UnitLimit or 0) + (newData.UnitLimit or 0)
			end
		end
	end

	building:Destroy()
	print("Building upgraded and model replaced:", oldType, "->", newType)
end

return UpgradeManager



