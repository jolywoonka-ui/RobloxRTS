-- UnitAI.Builder (ModuleScript, ServerStorage)
local module = {}

local Players = game:GetService("Players")

local State

function module.init(deps)
	deps = deps or {}
	Players = deps.Players or Players
	State = deps.State
end

function module.tryBuild(builder, dt, attackEffect, config)
	local range = builder:GetAttribute("Range") or 30
	local buildPower = builder:GetAttribute("BuildPower") or 5
	local myPos = State.getPosition(builder)

	local map = workspace:FindFirstChild("CurrentMap")
	if not map then
		return
	end

	local buildings = map:FindFirstChild("PlayerBuildings")
	if not buildings then
		return
	end

	local bestTarget = nil
	local closestDist = range

	for _, b in pairs(buildings:GetChildren()) do
		if b:GetAttribute("IsUnderConstruction") then
			local health = b:GetAttribute("Health") or 0
			if health <= 0 then
				continue
			end
			if b:GetAttribute("Owner") == builder:GetAttribute("Owner") then
				local bPos = State.getPosition(b)
				local dist = (Vector3.new(myPos.X, 0, myPos.Z) - Vector3.new(bPos.X, 0, bPos.Z)).Magnitude
				if dist < closestDist then
					closestDist = dist
					bestTarget = b
				end
			end
		end
	end

	if not bestTarget then
		return
	end

	local root = State.getRoot(builder)
	if root then
		attackEffect:FireAllClients(builder, bestTarget, "Heal")
	end

	local curProg = bestTarget:GetAttribute("Progress") or 0
	local requiredProg = bestTarget:GetAttribute("BuildRequiredProgress") or 100
	local newProg = curProg + buildPower * dt

	if newProg >= requiredProg then
		newProg = requiredProg
		bestTarget:SetAttribute("IsUnderConstruction", nil)
		bestTarget:SetAttribute("Progress", requiredProg)
		bestTarget:SetAttribute("Health", bestTarget:GetAttribute("MaxHealth"))

		local hum = bestTarget:FindFirstChild("Humanoid")
		if hum then hum.Health = hum.MaxHealth end

		for _, p in pairs(bestTarget:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Transparency = 0
				p.CanCollide = true
			end
		end

		local ui = bestTarget:FindFirstChild("BuildProgressUI")
		if ui then ui:Destroy() end

		local ownerName = bestTarget:GetAttribute("Owner")
		local bName = bestTarget:GetAttribute("Type")
		local bData = config and config.Buildings and config.Buildings[bName]
		local player = Players:FindFirstChild(ownerName)
		if player and bData then
			local ps = player:FindFirstChild("PlayerStats")
			if ps then
				if bData.Income then ps.Income.Value += bData.Income end
				if bData.Energy > 0 then
					ps.MaxEnergy.Value += bData.Energy
				elseif bData.Energy < 0 and not bestTarget:GetAttribute("EnergyReserved") then
					ps.Energy.Value += math.abs(bData.Energy)
				end
				if bData.UnitLimit then ps.UnitLimit.Value += bData.UnitLimit end
			end
		end
	else
		bestTarget:SetAttribute("Progress", newProg)
		local ui = bestTarget:FindFirstChild("BuildProgressUI")
		if ui then
			local bar = ui:FindFirstChild("Frame") and ui.Frame:FindFirstChild("Bar")
			if bar then
				bar.Size = UDim2.new(math.clamp(newProg / requiredProg, 0, 1), 0, 1, 0)
			end
		end
	end
end

return module
