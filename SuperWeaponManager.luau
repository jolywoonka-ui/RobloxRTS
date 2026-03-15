local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local function findModule(container: Instance?, name: string): ModuleScript?
	if not container then
		return nil
	end
	local directChild = container:FindFirstChild(name)
	if directChild and directChild:IsA("ModuleScript") then
		return directChild
	end
	local nestedChild = container:FindFirstChild(name, true)
	if nestedChild and nestedChild:IsA("ModuleScript") then
		return nestedChild
	end
	return nil
end

local damageModuleScript: ModuleScript? = findModule(script.Parent, "DamageService")
	or findModule(ServerStorage, "DamageService")
	or findModule(ReplicatedStorage, "DamageService")

local DamageService
if damageModuleScript then
	DamageService = require(damageModuleScript)
else
	warn("SuperWeaponManager: DamageService module not found, using local fallback")
	DamageService = {}

	local function getRoot(target)
		if not target then
			return nil
		end
		if target:IsA("BasePart") then
			return target
		end
		if target:IsA("Model") then
			return target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
		end
		return nil
	end

	function DamageService.getPosition(target)
		local root = getRoot(target)
		if root then
			return root.Position
		end
		if target and target:IsA("Model") then
			local ok, pivot = pcall(function()
				return target:GetPivot()
			end)
			if ok then
				return pivot.Position
			end
		end
		return nil
	end

	function DamageService.getHealth(target)
		if not target or not target.Parent then
			return 0
		end
		local hpAttr = target:GetAttribute("Health")
		if typeof(hpAttr) == "number" then
			return hpAttr
		end
		local hum = target:FindFirstChild("Humanoid")
		return hum and hum.Health or 0
	end

	function DamageService.applyDamage(target, damage)
		if not target or not target.Parent or damage <= 0 then
			return 0, false
		end

		local currentHP = DamageService.getHealth(target)
		if currentHP <= 0 then
			return 0, false
		end

		local hum = target:FindFirstChild("Humanoid")
		local newHP = math.max(0, currentHP - damage)
		target:SetAttribute("Health", newHP)
		if hum then
			hum.Health = newHP
		elseif newHP <= 0 then
			target:Destroy()
		end

		return currentHP - newHP, newHP <= 0
	end

	function DamageService.applyAreaDamage(mapModel, center, radius, damage, includeUnits, includeBuildings, predicate)
		if not mapModel or not center or radius <= 0 or damage <= 0 then
			return 0
		end

		local totalApplied = 0

		local function processContainer(container)
			if not container then
				return
			end
			for _, target in ipairs(container:GetChildren()) do
				if target and target.Parent then
					local pos = DamageService.getPosition(target)
					if pos and (pos - center).Magnitude <= radius then
						if not predicate or predicate(target) then
							local applied = DamageService.applyDamage(target, damage)
							totalApplied += applied
						end
					end
				end
			end
		end

		if includeUnits then
			processContainer(mapModel:FindFirstChild("Army"))
		end
		if includeBuildings then
			processContainer(mapModel:FindFirstChild("PlayerBuildings"))
		end

		return totalApplied
	end
end
local WorldEffectEvent = ReplicatedStorage:WaitForChild("WorldEffectEvent")

local SuperWeaponManager = {}
SuperWeaponManager.__index = SuperWeaponManager

local FIELD_TICK = 0.25

local function getLaunchPart(model)
	if not model then
		return nil
	end
	return model:FindFirstChild("LaunchPoint", true)
		or model:FindFirstChild("MissileSpawn", true)
		or model.PrimaryPart
		or model:FindFirstChildWhichIsA("BasePart", true)
end

local function getAllianceRecipients(sourcePlayer)
	local recipients = {}
	local sourceAlliance = sourcePlayer:GetAttribute("AllianceID")
	for _, other in ipairs(Players:GetPlayers()) do
		if other == sourcePlayer then
			table.insert(recipients, other)
		elseif sourceAlliance and other:GetAttribute("AllianceID") == sourceAlliance then
			table.insert(recipients, other)
		end
	end
	return recipients
end

function SuperWeaponManager.new(mapModel)
	local self = setmetatable({}, SuperWeaponManager)
	self.MapModel = mapModel
	self.ActiveFields = {}
	self.LastPingAt = {}
	return self
end

function SuperWeaponManager:broadcastPing(player, worldPos)
	if not player or not worldPos then
		return
	end

	local now = tick()
	if now - (self.LastPingAt[player.UserId] or 0) < 1.0 then
		return
	end
	self.LastPingAt[player.UserId] = now

	for _, recipient in ipairs(getAllianceRecipients(player)) do
		ReplicatedStorage.PingEvent:FireClient(recipient, player.Name, worldPos)
	end
end

function SuperWeaponManager:launchMissile(player, silo, worldPos)
	if not self.MapModel or not silo or not silo.Parent or not worldPos then
		return false, "Missile silo unavailable"
	end
	if silo:GetAttribute("Owner") ~= player.Name then
		return false, "Not your missile silo"
	end
	if silo:GetAttribute("Type") ~= "MissileSilo" then
		return false, "This building cannot launch missiles"
	end
	if silo:GetAttribute("IsUnderConstruction") or silo:GetAttribute("IsUpgrading") then
		return false, "Missile silo is not ready"
	end

	local storedMissiles = silo:GetAttribute("StoredMissiles") or 0
	if storedMissiles <= 0 then
		return false, "No missile ready"
	end

	local launchPart = getLaunchPart(silo)
	local launchPos = launchPart and launchPart.Position or DamageService.getPosition(silo)
	if not launchPos then
		return false, "Missile silo launch point missing"
	end

	local missileData = Config.SuperWeapons and Config.SuperWeapons.MissileSilo
	if not missileData then
		return false, "Missile config missing"
	end

	silo:SetAttribute("StoredMissiles", storedMissiles - 1)
	WorldEffectEvent:FireAllClients("MissileLaunch", {
		startPos = launchPos,
		targetPos = worldPos,
		travelTime = missileData.TravelTime,
		arcHeight = missileData.ArcHeight,
		explosionDuration = missileData.ExplosionDuration,
		explosionRadius = missileData.ExplosionRadius,
		teamColor = player:GetAttribute("TeamColor"),
	})

	task.delay(missileData.TravelTime, function()
		if not self.MapModel then
			return
		end

		DamageService.applyAreaDamage(
			self.MapModel,
			worldPos,
			missileData.ImpactRadius,
			missileData.ImpactDamage,
			true,
			true
		)

		table.insert(self.ActiveFields, {
			center = worldPos,
			startTime = tick(),
			duration = missileData.ExplosionDuration,
			maxRadius = missileData.ExplosionRadius,
			baseDps = missileData.DamagePerSecond,
		})
	end)

	return true
end

function SuperWeaponManager:tick()
	if not self.MapModel then
		return
	end

	local now = tick()
	for index = #self.ActiveFields, 1, -1 do
		local field = self.ActiveFields[index]
		local elapsed = now - field.startTime
		if elapsed >= field.duration then
			table.remove(self.ActiveFields, index)
		elseif elapsed >= (field.lastTick or 0) + FIELD_TICK then
			field.lastTick = elapsed
			local progress = math.clamp(elapsed / field.duration, 0, 1)
			local radius = math.max(4, field.maxRadius * progress)
			local dpsScale = 1 - (0.4 * progress)
			local tickDamage = field.baseDps * dpsScale * FIELD_TICK
			DamageService.applyAreaDamage(self.MapModel, field.center, radius, tickDamage, true, true)
		end
	end
end

return SuperWeaponManager







