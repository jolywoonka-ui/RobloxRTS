-- HospitalAI (Script, ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local AttackEffect = ReplicatedStorage:WaitForChild("AttackEffect")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local lastHeal = setmetatable({}, { __mode = "k" })
local lastHealedTarget = setmetatable({}, { __mode = "k" })

local function areAllies(ownerA, ownerB, unitA, unitB)
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

	local allianceA = unitA and unitA:GetAttribute("AllianceID")
	local allianceB = unitB and unitB:GetAttribute("AllianceID")
	return allianceA and allianceB and allianceA == allianceB
end

local function getPosition(obj)
	if obj:IsA("BasePart") then
		return obj.Position
	end
	if obj:IsA("Model") then
		return obj:GetPivot().Position
	end
	return Vector3.zero
end

local function getHospitalData(hospital)
	local bType = hospital:GetAttribute("Type")
	local data = bType and Config.Buildings[bType]
	if not data then
		data = Config.Buildings[hospital.Name]
	end
	return data or Config.Buildings["Hospital"]
end

local function pickNextHealTarget(hospital, healRange, army)
	local myPos = getPosition(hospital)
	local hospitalOwner = hospital:GetAttribute("Owner")
	local candidates = {}

	for _, unit in ipairs(army:GetChildren()) do
		local health = unit:GetAttribute("Health")
		local maxHealth = unit:GetAttribute("MaxHealth")
		if health and maxHealth and health < maxHealth then
			local owner = unit:GetAttribute("Owner")
			if areAllies(hospitalOwner, owner, hospital, unit) then
				local unitPos = getPosition(unit)
				if (unitPos - myPos).Magnitude <= healRange then
					table.insert(candidates, {
						Unit = unit,
						HealthPct = maxHealth > 0 and (health / maxHealth) or 1,
						Health = health,
						Dist = (unitPos - myPos).Magnitude,
					})
				end
			end
		end
	end

	if #candidates == 0 then
		lastHealedTarget[hospital] = nil
		return nil
	end

	table.sort(candidates, function(a, b)
		if a.HealthPct ~= b.HealthPct then
			return a.HealthPct < b.HealthPct
		end
		if a.Health ~= b.Health then
			return a.Health < b.Health
		end
		if a.Dist ~= b.Dist then
			return a.Dist < b.Dist
		end
		return a.Unit:GetDebugId() < b.Unit:GetDebugId()
	end)

	return candidates[1].Unit
end

RunService.Heartbeat:Connect(function()
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then
		return
	end

	local hospitals = {}
	local pBuildings = map:FindFirstChild("PlayerBuildings", true)
	if pBuildings then
		for _, b in ipairs(pBuildings:GetChildren()) do
			local bData = getHospitalData(b)
			if bData and bData.HealRange and not b:GetAttribute("IsUnderConstruction") then
				table.insert(hospitals, b)
			end
		end
	end
	if #hospitals == 0 then
		return
	end

	local army = map:FindFirstChild("Army")
	if not army then
		return
	end

	local now = tick()
	for _, hospital in ipairs(hospitals) do
		local data = getHospitalData(hospital)
		local healRange = data.HealRange or 20
		local healRate = data.HealRate or 5
		local healCooldown = data.HealCooldown or 1.0

		local last = lastHeal[hospital] or 0
		if now - last < healCooldown then
			continue
		end
		lastHeal[hospital] = now

		local unit = pickNextHealTarget(hospital, healRange, army)
		if unit then
			local health = unit:GetAttribute("Health")
			local maxHealth = unit:GetAttribute("MaxHealth")
			if health and maxHealth and health < maxHealth then
				local newHealth = math.min(maxHealth, health + healRate)
				unit:SetAttribute("Health", newHealth)
				local hum = unit:FindFirstChild("Humanoid")
				if hum then
					hum.Health = newHealth
				end
				lastHealedTarget[hospital] = unit
				AttackEffect:FireAllClients(hospital, unit, "Heal")
			end
		end
	end
end)
