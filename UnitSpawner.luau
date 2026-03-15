-- UnitSpawner (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local UnitsFolder = ReplicatedStorage:WaitForChild("Units")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local UnitPhysics = require(ServerStorage:WaitForChild("UnitPhysics"))

local UnitSpawner = {}
local AIR_HEIGHT_FACTOR = 0.75

local templateCache = {}

local function initTemplateCache(template, unitName, uData)
	if templateCache[unitName] then return end
	local cache = { teamPaintPaths = {} }
	local isAir = uData.Class == "Air"
	local collisionGroup = isAir and "AirUnits" or "Units"

	local function getPath(instance, rootModel)
		local path = {}
		local current = instance
		while current and current ~= rootModel do
			table.insert(path, 1, current.Name)
			current = current.Parent
		end
		return path
	end

	for _, p in pairs(template:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			p.CollisionGroup = collisionGroup
			if not isAir then
				p.AssemblyLinearVelocity = Vector3.zero
				p.AssemblyAngularVelocity = Vector3.zero
			end
			if p.Name == "TeamPaint" then
				table.insert(cache.teamPaintPaths, getPath(p, template))
			end
		end
	end

	if not isAir then
		local root = template:IsA("Model") and template.PrimaryPart or template
		if template:IsA("Model") and not template.PrimaryPart then
			local p = template:FindFirstChildWhichIsA("BasePart")
			if p then template.PrimaryPart = p; root = p end
		end
		if root then
			local bf = root:FindFirstChild("AntiGravity")
			if bf and bf:IsA("BodyForce") then
				bf:Destroy()
			end
		end
	end

	templateCache[unitName] = cache
end

-- ÃÂ¤Ã‘Æ’ÃÂ½ÃÂºÃ‘â€ ÃÂ¸Ã‘Â ÃÂ¿ÃÂ¾ÃÂºÃ‘â‚¬ÃÂ°Ã‘ÂÃÂºÃÂ¸ ÃÂ² Ã‘â€ ÃÂ²ÃÂµÃ‘â€š ÃÂºÃÂ¾ÃÂ¼ÃÂ°ÃÂ½ÃÂ´Ã‘â€¹
local function applyTeamColor(model, player, unitName)
	if not player then return end
	local teamColor = player:GetAttribute("TeamColor")
	if not teamColor then return end

	local cache = templateCache[unitName]
	if not cache then return end

	for _, path in ipairs(cache.teamPaintPaths) do
		local current = model
		for _, name in ipairs(path) do
			current = current:FindFirstChild(name)
			if not current then break end
		end
		if current and current:IsA("BasePart") then
			current.Color = teamColor
		end
	end
end

-- ÃÂ¤Ã‘Æ’ÃÂ½ÃÂºÃ‘â€ ÃÂ¸Ã‘Â ÃÂ¿ÃÂ¾ÃÂ»Ã‘Æ’Ã‘â€¡ÃÂµÃÂ½ÃÂ¸Ã‘Â ÃÂ²Ã‘â€¹Ã‘ÂÃÂ¾Ã‘â€šÃ‘â€¹ ÃÂ·ÃÂµÃÂ¼ÃÂ»ÃÂ¸ (Ã‘â€šÃÂ¾ÃÂ»Ã‘Å’ÃÂºÃÂ¾ Terrain ÃÂ¸ ÃÂ´ÃÂµÃ‘â€šÃÂ°ÃÂ»ÃÂ¸ Map)
local function getGroundY(pos)
	local map = workspace:FindFirstChild("CurrentMap")
	local targets = {}

	table.insert(targets, workspace.Terrain)

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
	return pos.Y - 1
end

-- ÃÂ¤Ã‘Æ’ÃÂ½ÃÂºÃ‘â€ ÃÂ¸Ã‘Â ÃÂ¿ÃÂ¾ÃÂ¸Ã‘ÂÃÂºÃÂ° ÃÂ±ÃÂµÃÂ·ÃÂ¾ÃÂ¿ÃÂ°Ã‘ÂÃÂ½ÃÂ¾ÃÂ¹ ÃÂ¿ÃÂ¾ÃÂ·ÃÂ¸Ã‘â€ ÃÂ¸ÃÂ¸ (ÃÂ´ÃÂ»Ã‘Â ÃÂ½ÃÂ°ÃÂ·ÃÂµÃÂ¼ÃÂ½Ã‘â€¹Ã‘â€¦)
local function findSafeSpawnPosition(originCFrame, unitModel, maxAttempts)
	local _, size = unitModel:GetBoundingBox()
	local radius = math.max(size.X, size.Z) / 2 + 1.5
	local heightOffset = size.Y / 2

	for attempt = 1, maxAttempts do
		local rayOrigin = originCFrame.Position + Vector3.new(0, 20, 0)
		local rayDir = Vector3.new(0, -50, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {}
		local groundHit = workspace:Raycast(rayOrigin, rayDir, params)
		if groundHit then
			local groundY = groundHit.Position.Y
			local testPos = Vector3.new(originCFrame.X, groundY + heightOffset, originCFrame.Z)

			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			overlapParams.FilterDescendantsInstances = {}
			local parts = workspace:GetPartBoundsInBox(CFrame.new(testPos), size, overlapParams)
			local blocked = false
			for _, part in ipairs(parts) do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and model:GetAttribute("IsUnit") then
					blocked = true
					break
				end
			end
			if not blocked then
				return CFrame.new(testPos)
			end
		end

		local angle = (attempt / maxAttempts) * math.pi * 2
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		originCFrame = originCFrame + offset
	end

	-- fallback
	return CFrame.new(originCFrame.X, originCFrame.Y + heightOffset, originCFrame.Z)
end

UnitSpawner.findSafeSpawnPosition = findSafeSpawnPosition

local function getSpawnCFrame(building)
	local spawnPart = building:FindFirstChild("SpawnPoint", true)
	if spawnPart and spawnPart:IsA("BasePart") then
		return spawnPart.CFrame
	end
	return building:GetPivot() * CFrame.new(0, 0, 12)
end

function UnitSpawner.spawnNeutral(building, unitName)
	if not building or not building.Parent then return end
	if building:GetAttribute("IsUnderConstruction") then return end

	local uData = Config.Units[unitName]
	if not uData then return end

	local template = UnitsFolder:FindFirstChild(unitName)
	if not template then return end

	initTemplateCache(template, unitName, uData)

	local unit = template:Clone()
	unit.Name = unitName

	local spawnCFrame = getSpawnCFrame(building)
	local safeCFrame
	if uData.Class == "Air" and uData.FlightHeight then
		local elevated = spawnCFrame.Position + Vector3.new(0, uData.FlightHeight * AIR_HEIGHT_FACTOR, 0)
		safeCFrame = CFrame.new(elevated) * spawnCFrame.Rotation
	else
		safeCFrame = findSafeSpawnPosition(spawnCFrame, unit, 8)
	end
	unit:PivotTo(safeCFrame)

	local root = unit:IsA("Model") and unit.PrimaryPart or unit
	if unit:IsA("Model") and not unit.PrimaryPart then
		local p = unit:FindFirstChildWhichIsA("BasePart")
		if p then unit.PrimaryPart = p; root = p end
	end
	if not root then unit:Destroy() return end

	local hum = unit:FindFirstChild("Humanoid") or Instance.new("Humanoid", unit)
	hum.MaxHealth = uData.Health
	hum.Health = uData.Health
	hum.AutoRotate = false
	if uData.Class == "Air" then
		hum.PlatformStand = true
	end

	unit:SetAttribute("Owner", nil)
	unit:SetAttribute("IsUnit", true)
	unit:SetAttribute("MaxHealth", uData.Health)
	unit:SetAttribute("Health", uData.Health)
	unit:SetAttribute("Damage", uData.Damage)
	unit:SetAttribute("Speed", uData.Speed)
	unit:SetAttribute("Range", uData.Range or 40)
	unit:SetAttribute("AttackCooldown", uData.AttackCooldown or 1.5)
	if uData.BuildPower then unit:SetAttribute("BuildPower", uData.BuildPower) end
	unit:SetAttribute("Class", uData.Class or "Infantry")
	if uData.Capacity then unit:SetAttribute("Capacity", uData.Capacity) end
	if uData.Supply then unit:SetAttribute("Supply", uData.Supply) end
	if uData.FlightHeight then unit:SetAttribute("FlightHeight", uData.FlightHeight) end
	unit:SetAttribute("TargetType", uData.TargetType or "Ground")
	unit:SetAttribute("AirDamageMultiplier", uData.AirDamageMultiplier or 1.0)
	if uData.TargetsBuildingsOnly then unit:SetAttribute("TargetsBuildingsOnly", true) end
	if uData.ProjectileArcHeight then unit:SetAttribute("ProjectileArcHeight", uData.ProjectileArcHeight) end
	if uData.ProjectileTravelTime then unit:SetAttribute("ProjectileTravelTime", uData.ProjectileTravelTime) end
	if uData.ExplosionRadius then unit:SetAttribute("ExplosionRadius", uData.ExplosionRadius) end
	local hqIndex = tonumber(tostring(building.Name):match("%d+$"))
	if hqIndex then
		unit:SetAttribute("SpawnHQIndex", hqIndex)
	end

	local map = workspace:FindFirstChild("CurrentMap")
	local army = map and map:FindFirstChild("Army")
	if not army and map then
		army = Instance.new("Folder", map)
		army.Name = "Army"
	end
	unit.Parent = army or workspace
	return unit
end

function UnitSpawner.spawnPlayer(player, building, unitName, supplyAlreadyReserved)
	if not building or not building.Parent then return end
	if building:GetAttribute("IsUnderConstruction") then return end

	local uData = Config.Units[unitName]
	if not uData then return end

	local ps = player:FindFirstChild("PlayerStats")
	if ps and ps.Energy.Value > ps.MaxEnergy.Value then return end

	local currentUnits = ps and ps:FindFirstChild("CurrentUnits")
	local unitLimit = ps and ps:FindFirstChild("UnitLimit")
	local incomingSupply = supplyAlreadyReserved and 0 or (uData.Supply or 1)
	if currentUnits and unitLimit then
		if currentUnits.Value + incomingSupply > unitLimit.Value then return end
	end

	local template = UnitsFolder:FindFirstChild(unitName)
	if not template then return end

	initTemplateCache(template, unitName, uData)

	local unit = template:Clone()
	unit.Name = unitName

	local spawnCFrame = getSpawnCFrame(building)
	local safeCFrame
	if uData.Class == "Air" and uData.FlightHeight then
		local elevated = spawnCFrame.Position + Vector3.new(0, uData.FlightHeight * AIR_HEIGHT_FACTOR, 0)
		safeCFrame = CFrame.new(elevated) * spawnCFrame.Rotation
	else
		safeCFrame = findSafeSpawnPosition(spawnCFrame, unit, 8)
	end
	unit:PivotTo(safeCFrame)

	local root = unit:IsA("Model") and unit.PrimaryPart or unit
	if unit:IsA("Model") and not unit.PrimaryPart then
		local p = unit:FindFirstChildWhichIsA("BasePart")
		if p then unit.PrimaryPart = p; root = p end
	end
	if not root then unit:Destroy() return end

	applyTeamColor(unit, player, unitName)

	local hum = unit:FindFirstChild("Humanoid")
	if not hum then
		hum = Instance.new("Humanoid", unit)
	end
	hum.MaxHealth = uData.Health
	hum.Health = uData.Health
	hum.AutoRotate = false
	if uData.Class == "Air" then
		hum.PlatformStand = true
	end

	unit:SetAttribute("Owner", player.Name)
	unit:SetAttribute("IsUnit", true)
	unit:SetAttribute("MaxHealth", uData.Health)
	unit:SetAttribute("Health", uData.Health)
	unit:SetAttribute("Damage", uData.Damage)
	unit:SetAttribute("Speed", uData.Speed)
	unit:SetAttribute("Range", uData.Range or 40)
	unit:SetAttribute("AttackCooldown", uData.AttackCooldown or 1.5)
	if uData.BuildPower then unit:SetAttribute("BuildPower", uData.BuildPower) end
	unit:SetAttribute("AllianceID", player:GetAttribute("AllianceID"))
	unit:SetAttribute("Class", uData.Class or "Infantry")
	if uData.Capacity then unit:SetAttribute("Capacity", uData.Capacity) end
	unit:SetAttribute("Supply", uData.Supply or 1)
	if uData.FlightHeight then unit:SetAttribute("FlightHeight", uData.FlightHeight) end
	unit:SetAttribute("TargetType", uData.TargetType or "Ground")
	unit:SetAttribute("AirDamageMultiplier", uData.AirDamageMultiplier or 1.0)
	if uData.TargetsBuildingsOnly then unit:SetAttribute("TargetsBuildingsOnly", true) end
	if uData.ProjectileArcHeight then unit:SetAttribute("ProjectileArcHeight", uData.ProjectileArcHeight) end
	if uData.ProjectileTravelTime then unit:SetAttribute("ProjectileTravelTime", uData.ProjectileTravelTime) end
	if uData.ExplosionRadius then unit:SetAttribute("ExplosionRadius", uData.ExplosionRadius) end

	if currentUnits and not supplyAlreadyReserved then
		currentUnits.Value += (uData.Supply or 1)
	end

	local map = workspace:FindFirstChild("CurrentMap")
	local army = map and map:FindFirstChild("Army")
	if not army and map then
		army = Instance.new("Folder", map)
		army.Name = "Army"
	end
	unit.Parent = army or workspace
	return unit
end

return UnitSpawner


