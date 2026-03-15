local DamageService = {}

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

function DamageService.applyRadialDamage(mapModel, center, radius, maxDamage, includeUnits, includeBuildings, predicate, options)
	if not mapModel or not center or radius <= 0 or maxDamage <= 0 then
		return 0
	end

	options = options or {}
	local minFactor = math.clamp(options.minFactor or 0.15, 0, 1)
	local totalApplied = 0

	local function processContainer(container)
		if not container then
			return
		end
		for _, target in ipairs(container:GetChildren()) do
			if target and target.Parent then
				local pos = DamageService.getPosition(target)
				if pos then
					local dist = (pos - center).Magnitude
					if dist <= radius and (not predicate or predicate(target)) then
						local alpha = math.clamp(dist / radius, 0, 1)
						local falloff = 1 - ((1 - minFactor) * alpha)
						local damage = maxDamage * falloff
						if damage > 0.05 then
							local applied = DamageService.applyDamage(target, damage)
							totalApplied += applied
						end
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

return DamageService
