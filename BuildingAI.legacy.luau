-- BuildingAI (Script, ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local AttackEffect = ReplicatedStorage:WaitForChild("AttackEffect")

-- Use weak table for lastFire to auto-cleanup
local lastFire = setmetatable({}, {__mode = "k"})

local function areAllies(ownerA, ownerB, unitA, unitB)
	if ownerA == ownerB then return true end

	local pA = ownerA and Players:FindFirstChild(ownerA)
	local pB = ownerB and Players:FindFirstChild(ownerB)
	if pA and pB then
		local a1 = pA:GetAttribute("AllianceID")
		local a2 = pB:GetAttribute("AllianceID")
		if a1 and a2 and a1 == a2 then return true end
	end

	if unitA and unitB then
		local allianceA = unitA:GetAttribute("AllianceID")
		local allianceB = unitB:GetAttribute("AllianceID")
		if allianceA and allianceB and allianceA == allianceB then return true end
	end
	return false
end

local function getPosition(obj)
	if obj:IsA("BasePart") then return obj.Position end
	if obj:IsA("Model") then return obj:GetPivot().Position end
	return Vector3.zero
end

local function getGunPart(building)
	local gun = building:FindFirstChild("Gun", true)
	if gun then return gun end
	if building:IsA("Model") then
		return building.PrimaryPart or building:FindFirstChildWhichIsA("BasePart")
	end
	return building
end

local function attack(building, target, damage, cooldown)
	local now = tick()
	local key = building
	if not lastFire[key] then lastFire[key] = 0 end
	if now - lastFire[key] < cooldown then return end
	lastFire[key] = now

	local hpAttr = target:GetAttribute("Health") or 0
	local hum = target:FindFirstChild("Humanoid")
	local currentHP = (hpAttr > 0) and hpAttr or (hum and hum.Health or 0)
	if currentHP <= 0 then return end

	local newHP = math.max(0, currentHP - damage)
	target:SetAttribute("Health", newHP)
	if hum then hum.Health = newHP end

	-- Отправляем само здание и цель, а не позиции
	AttackEffect:FireAllClients(building, target, "Laser")

	local owner = building:GetAttribute("Owner")
	if owner then
		local p = Players:FindFirstChild(owner)
		if p and p:FindFirstChild("PlayerStats") then
			local ps = p.PlayerStats
			if ps:FindFirstChild("DamageDealt") then
				ps.DamageDealt.Value += damage
			end
		end
	end
end

-- Throttle scan: every 0.5 seconds
RunService.Heartbeat:Connect(function()
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return end
	local pBuildings = map:FindFirstChild("PlayerBuildings", true)
	if not pBuildings then return end
	local army = map:FindFirstChild("Army")
	local now = tick()
	-- Simple throttling: only scan every 0.5 seconds
	local scanTime = (now % 0.5) < 0.1 -- approx every 0.5s

	for _, building in pairs(pBuildings:GetChildren()) do
		local damage = building:GetAttribute("Damage")
		if damage and damage > 0 then
			local range = building:GetAttribute("Range") or 30
			local cooldown = building:GetAttribute("AttackCooldown") or 1.5
			local myPos = getPosition(building)
			local bestEnemy = nil
			local bestDist = range

			if army and scanTime then -- scan at reduced rate
				for _, enemy in pairs(army:GetChildren()) do
					if enemy ~= building then
						local eOwner = enemy:GetAttribute("Owner")
						local bOwner = building:GetAttribute("Owner")
						if not areAllies(bOwner, eOwner, building, enemy) then
							local hp = enemy:GetAttribute("Health") or 0
							local hum = enemy:FindFirstChild("Humanoid")
							if (hp > 0) or (hum and hum.Health > 0) then
								local ePos = getPosition(enemy)
								local dist = (ePos - myPos).Magnitude
								if dist < bestDist then
									bestDist = dist
									bestEnemy = enemy
								end
							end
						end
					end
				end
			end

			if bestEnemy then
				attack(building, bestEnemy, damage, cooldown)
			end
		end
	end
end)