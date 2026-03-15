-- UnitAI.Combat (ModuleScript, ServerStorage)
local module = {}

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

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

local damageModuleScript: ModuleScript? = findModule(ServerStorage, "DamageService")
	or findModule(script.Parent, "DamageService")
	or findModule(script.Parent.Parent, "DamageService")
	or findModule(ReplicatedStorage, "DamageService")

if not damageModuleScript then
	error("UnitAI.Combat: DamageService module not found")
end
local DamageService = require(damageModuleScript)

local WorldEffectEvent = ReplicatedStorage:WaitForChild("WorldEffectEvent")

local State

function module.init(deps)
	deps = deps or {}
	Players = deps.Players or Players
	State = deps.State
end

function module.areAllies(unitA, unitB)
	local ownerA = unitA:GetAttribute("Owner")
	local ownerB = unitB:GetAttribute("Owner")
	if ownerA == ownerB then
		return true
	end

	local pA = ownerA and Players:FindFirstChild(ownerA)
	local pB = ownerB and Players:FindFirstChild(ownerB)
	if pA and pB then
		local a1 = pA:GetAttribute("AllianceID")
		local a2 = pB:GetAttribute("AllianceID")
		if a1 and a2 and a1 == a2 then
			return true
		end
	end

	local allianceA = unitA:GetAttribute("AllianceID")
	local allianceB = unitB:GetAttribute("AllianceID")
	return allianceA and allianceB and allianceA == allianceB
end

function module.canAttack(attacker, target)
	local attackerTargetType = attacker:GetAttribute("TargetType") or "Ground"
	local targetIsAir = (target:GetAttribute("Class") == "Air")

	if attacker:GetAttribute("TargetsBuildingsOnly") and target:GetAttribute("IsUnit") then
		return false
	end
	if attackerTargetType == "None" then return false end
	if attackerTargetType == "All" then return true end
	if attackerTargetType == "Air" then return targetIsAir end
	if attackerTargetType == "Ground" then return not targetIsAir end
	return false
end

local function getDamage(attacker, target)
	local baseDamage = attacker:GetAttribute("Damage") or 0
	local targetIsAir = (target:GetAttribute("Class") == "Air")
	if targetIsAir then
		local multiplier = attacker:GetAttribute("AirDamageMultiplier") or 1.0
		return baseDamage * multiplier
	end
	return baseDamage
end

local function awardDamage(attacker, amount)
	local owner = attacker:GetAttribute("Owner")
	if not owner or amount <= 0 then
		return
	end
	local p = Players:FindFirstChild(owner)
	if p and p:FindFirstChild("PlayerStats") and p.PlayerStats:FindFirstChild("DamageDealt") then
		p.PlayerStats.DamageDealt.Value += math.floor(amount + 0.5)
	end
end

local function applySplashDamage(attacker, primaryTarget, mapModel)
	local radius = attacker:GetAttribute("SplashRadius") or 0
	if radius <= 0 or not mapModel then
		return 0
	end

	local center = DamageService.getPosition(primaryTarget)
	if not center then
		return 0
	end

	local hitsUnits = attacker:GetAttribute("SplashHitsUnits")
	if hitsUnits == nil then
		hitsUnits = true
	end
	local hitsBuildings = attacker:GetAttribute("SplashHitsBuildings")
	if hitsBuildings == nil then
		hitsBuildings = false
	end

	return DamageService.applyRadialDamage(
		mapModel,
		center,
		radius,
		attacker:GetAttribute("Damage") or 0,
		hitsUnits,
		hitsBuildings,
		function(other)
			return other ~= primaryTarget
				and not module.areAllies(attacker, other)
				and module.canAttack(attacker, other)
		end,
		{
			minFactor = attacker:GetAttribute("SplashMinFactor") or 0.15,
		}
	)
end

function module.attack(attacker, target, state, attackEffect, mapModel)
	local cooldown = attacker:GetAttribute("AttackCooldown") or 1.5
	local now = tick()
	if now - state.LastFire < cooldown then
		return
	end
	state.LastFire = now

	local currentHP = DamageService.getHealth(target)
	if currentHP <= 0 then
		state.Target = nil
		return
	end

	local damage = getDamage(attacker, target)
	if attacker:GetAttribute("ProjectileArcHeight") then
		local startPos = State.getPosition(attacker)
		local targetPos = State.getPosition(target)
		local travelTime = attacker:GetAttribute("ProjectileTravelTime") or 1.5
		local arcHeight = attacker:GetAttribute("ProjectileArcHeight") or 30
		local explosionRadius = attacker:GetAttribute("ExplosionRadius") or 10

		WorldEffectEvent:FireAllClients("ArtilleryShot", {
			startPos = startPos,
			targetPos = targetPos,
			travelTime = travelTime,
			arcHeight = arcHeight,
			explosionRadius = explosionRadius,
		})

		task.delay(travelTime, function()
			if not attacker or not attacker.Parent then
				return
			end
			if not target or not target.Parent then
				return
			end

			local applied = DamageService.applyDamage(target, damage)
			awardDamage(attacker, applied)
		end)
		return
	end

	local impactPos = DamageService.getPosition(target)
	attackEffect:FireAllClients(attacker, target, "Laser", impactPos)
	local applied = DamageService.applyDamage(target, damage)
	if DamageService.getHealth(target) <= 0 then
		state.Target = nil
	end

	awardDamage(attacker, applied)
	local splashApplied = applySplashDamage(attacker, target, mapModel)
	awardDamage(attacker, splashApplied)
end

function module.updateCombat(unit, state, now, army, buildings, attackEffect)
	if now < state.NextScan then
		return
	end

	state.NextScan = now + 0.3
	local range = unit:GetAttribute("Range") or 30
	local myPos = State.getPosition(unit)

	local bestEnemy = nil
	local bestDist = range
	local buildingsOnly = unit:GetAttribute("TargetsBuildingsOnly")

	if not buildingsOnly then
		for _, enemy in pairs(army:GetChildren()) do
			if enemy ~= unit and not module.areAllies(unit, enemy) and module.canAttack(unit, enemy) then
				local ehp = enemy:GetAttribute("Health") or 0
				local ehum = enemy:FindFirstChild("Humanoid")
				if (ehp > 0) or (ehum and ehum.Health > 0) then
					local ePos = State.getPosition(enemy)
					local dist = (ePos - myPos).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestEnemy = enemy
					end
				end
			end
		end
	end

	if buildings then
		for _, b in pairs(buildings:GetChildren()) do
			if b ~= unit and not module.areAllies(unit, b) and module.canAttack(unit, b) then
				local bhp = b:GetAttribute("Health") or 0
				local bhum = b:FindFirstChild("Humanoid")
				if (bhp > 0) or (bhum and bhum.Health > 0) then
					local bPos = State.getPosition(b)
					local dist = (bPos - myPos).Magnitude
					if dist < bestDist then
						bestDist = dist
						bestEnemy = b
					end
				end
			end
		end
	end

	if bestEnemy then
		module.attack(unit, bestEnemy, state, attackEffect, army and army.Parent)
	end
end

return module


