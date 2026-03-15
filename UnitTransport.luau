-- UnitTransport (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local UnitsFolder = ReplicatedStorage:WaitForChild("Units")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local UnitPhysics = require(ServerStorage:WaitForChild("UnitPhysics"))
local UnitSpawner = require(ServerStorage:WaitForChild("UnitSpawner"))

local lastToggle = {}
local UnitTransport = {}
local LoadedUnitsByTransport = setmetatable({}, {__mode = "k"})
local LoadedUnitsFolder = ReplicatedStorage:FindFirstChild("LoadedUnits")
if not LoadedUnitsFolder then
	LoadedUnitsFolder = Instance.new("Folder")
	LoadedUnitsFolder.Name = "LoadedUnits"
	LoadedUnitsFolder.Parent = ReplicatedStorage
end

-- Проверка, находится ли транспорт над землёй (для высадки)
local function isOverGround(transport)
	local pos = transport:GetPivot().Position
	local rayOrigin = pos + Vector3.new(0, 10, 0)
	local rayDir = Vector3.new(0, -30, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {transport}
	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then
		local hit = result.Instance
		if hit.Name == "Ground" or hit.Material == Enum.Material.Grass then
			return true
		end
		local map = workspace:FindFirstChild("CurrentMap")
		if map then
			local mapFolder = map:FindFirstChild("Map")
			if mapFolder then
				local forest = mapFolder:FindFirstChild("Forest")
				if forest then
					local current = hit
					while current do
						if current == forest then
							return true
						end
						current = current.Parent
					end
				end
			end
		end
	end
	return false
end

-- Поиск подходящей точки на земле в радиусе (только Ground, Grass, Forest)
local function findGroundNearby(centerPos, searchRadius, unitModel)
	local _, size = unitModel:GetBoundingBox()
	local heightOffset = size.Y / 2
	local map = workspace:FindFirstChild("CurrentMap")
	local targets = {workspace.Terrain}
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

	local angles = {0, 45, 90, 135, 180, 225, 270, 315}
	for _, angle in ipairs(angles) do
		local rad = math.rad(angle)
		local offset = Vector3.new(math.cos(rad) * searchRadius, 0, math.sin(rad) * searchRadius)
		local testPos = centerPos + offset
		local rayOrigin = testPos + Vector3.new(0, 50, 0)
		local rayDir = Vector3.new(0, -100, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = targets
		local result = workspace:Raycast(rayOrigin, rayDir, params)
		if result then
			local hit = result.Instance
			local isGround = false
			if hit.Name == "Ground" or hit.Material == Enum.Material.Grass then
				isGround = true
			else
				if map then
					local mapFolder = map:FindFirstChild("Map")
					if mapFolder then
						local forest = mapFolder:FindFirstChild("Forest")
						if forest then
							local current = hit
							while current do
								if current == forest then
									isGround = true
									break
								end
								current = current.Parent
							end
						end
					end
				end
			end
			if not isGround then
				continue
			end
			local groundY = result.Position.Y
			local spawnPos = Vector3.new(testPos.X, groundY + heightOffset, testPos.Z)
			local overlapParams = OverlapParams.new()
			overlapParams.FilterType = Enum.RaycastFilterType.Exclude
			overlapParams.FilterDescendantsInstances = {}
			local parts = workspace:GetPartBoundsInBox(CFrame.new(spawnPos), size, overlapParams)
			local blocked = false
			for _, part in ipairs(parts) do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and model:GetAttribute("IsUnit") then
					blocked = true
					break
				end
			end
			if not blocked then
				return CFrame.new(spawnPos)
			end
		end
	end
	return nil
end

local function setGroundKinematic(unit)
	if not unit then return end
	for _, part in pairs(unit:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
			part.CanCollide = false
			part.CollisionGroup = "Units"
			part.AssemblyLinearVelocity = Vector3.zero
			part.AssemblyAngularVelocity = Vector3.zero
		end
	end
	local root = unit:IsA("Model") and (unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")) or unit
	if root then
		for _, child in pairs(root:GetChildren()) do
			if child:IsA("LinearVelocity") or child:IsA("AlignOrientation") then
				child:Destroy()
			elseif child:IsA("Attachment") and child.Name == "BodyAttachment" then
				child:Destroy()
			end
		end
		local antiGravity = root:FindFirstChild("AntiGravity")
		if antiGravity and antiGravity:IsA("BodyForce") then
			antiGravity:Destroy()
		end
	end
end

function UnitTransport.toggle(transport, player, action)
	print("LoadTransport called by", player.Name, "action:", action)
	if not transport or not transport.Parent or transport:GetAttribute("Owner") ~= player.Name then 
		print("Transport invalid or not owned")
		return 
	end
	local isAir = (transport:GetAttribute("Class") == "Air")
	local capacity = transport:GetAttribute("Capacity") or (isAir and 10 or 6)

	local passengerJson = transport:GetAttribute("Passengers")
	local passengers = {}
	if passengerJson and passengerJson ~= "" then
		local success, decoded = pcall(HttpService.JSONDecode, HttpService, passengerJson)
		if success and type(decoded) == "table" then
			passengers = decoded
		end
	end

	if action == "Toggle" then
		local pos = transport:GetPivot().Position
		local range = transport:GetAttribute("Range") or 6
		local map = workspace:FindFirstChild("CurrentMap")
		local army = map and map:FindFirstChild("Army")

		if #passengers > 0 then
			-- Выгрузка
			print("Unloading infantry...")
			local ps = player:FindFirstChild("PlayerStats")
			local currentUnits = ps and ps:FindFirstChild("CurrentUnits")
			local unitLimit = ps and ps:FindFirstChild("UnitLimit")
			local totalSupply = 0

			for _, info in ipairs(passengers) do
				totalSupply = totalSupply + (info.Supply or 1)
			end

			-- Loaded passengers already count toward supply; allow unloading even if at limit.

			if isAir and not isOverGround(transport) then
				ReplicatedStorage.WallMessage:FireClient(player, "Can drop off units only on the Ground")
				return
			end

			local loadedUnits = LoadedUnitsByTransport[transport]
			if (not loadedUnits or #loadedUnits == 0) then
				local refFolder = transport:FindFirstChild("LoadedUnits")
				if refFolder then
					loadedUnits = {}
					for _, ref in ipairs(refFolder:GetChildren()) do
						if ref:IsA("ObjectValue") and ref.Value then
							table.insert(loadedUnits, ref.Value)
						end
					end
				end
			end
			if loadedUnits and #loadedUnits > 0 then
				for _, unit in ipairs(loadedUnits) do
					if unit and unit.Parent then
						local spawnCFrame = findGroundNearby(pos, 4, unit)
						if not spawnCFrame then
							spawnCFrame = UnitSpawner.findSafeSpawnPosition(CFrame.new(pos), unit, 3, 0)
						end
						unit:PivotTo(spawnCFrame)
						unit:SetAttribute("LoadedInTransport", false)
						setGroundKinematic(unit)
						if army then unit.Parent = army end
						print("Unloaded unit:", unit.Name)
					end
				end
			else
				for _, info in ipairs(passengers) do
					local template = UnitsFolder:FindFirstChild(info.Name)
					if template then
						local newUnit = template:Clone()
						newUnit.Name = info.Name

						local spawnCFrame = findGroundNearby(pos, 4, newUnit)
						if not spawnCFrame then
							spawnCFrame = UnitSpawner.findSafeSpawnPosition(CFrame.new(pos), newUnit, 3, 0)
						end
						newUnit:PivotTo(spawnCFrame)

						local root = newUnit:IsA("Model") and newUnit.PrimaryPart or newUnit
						if newUnit:IsA("Model") and not newUnit.PrimaryPart then
							local p = newUnit:FindFirstChildWhichIsA("BasePart")
							if p then newUnit.PrimaryPart = p; root = p end
						end
						if not root then
							newUnit:Destroy()
							continue
						end

						local hum = newUnit:FindFirstChild("Humanoid") or Instance.new("Humanoid", newUnit)
						hum.MaxHealth = info.MaxHealth
						hum.Health = info.Health
						hum.AutoRotate = false

						newUnit:SetAttribute("Owner", player.Name)
						newUnit:SetAttribute("AllianceID", player:GetAttribute("AllianceID"))
						newUnit:SetAttribute("IsUnit", true)
						newUnit:SetAttribute("MaxHealth", info.MaxHealth)
						newUnit:SetAttribute("Health", info.Health)
						newUnit:SetAttribute("Class", "Infantry")
						local uData = Config.Units[info.Name]
						if uData then
							newUnit:SetAttribute("Damage", uData.Damage)
							newUnit:SetAttribute("Speed", uData.Speed)
							newUnit:SetAttribute("Range", uData.Range or 40)
							newUnit:SetAttribute("AttackCooldown", uData.AttackCooldown or 1.5)
							if uData.BuildPower then newUnit:SetAttribute("BuildPower", uData.BuildPower) end
							newUnit:SetAttribute("Supply", uData.Supply or 1)
							newUnit:SetAttribute("TargetType", uData.TargetType or "Ground")
							newUnit:SetAttribute("AirDamageMultiplier", uData.AirDamageMultiplier or 1.0)
						end

						setGroundKinematic(newUnit)

						local _, hpFill, hpGradient = UnitPhysics.createHealthBar(newUnit, info.MaxHealth)
						newUnit:GetAttributeChangedSignal("Health"):Connect(function()
							local hp = newUnit:GetAttribute("Health")
							local max = newUnit:GetAttribute("MaxHealth")
							local p = math.clamp(hp / max, 0, 1)
							hpFill:TweenSize(UDim2.new(p, 0, 1, 0), "Out", "Quad", 0.1, true)
							if p < 0.3 then
								hpGradient.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 40, 40))
								}
							elseif p < 0.6 then
								hpGradient.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(230, 160, 0))
								}
							else
								hpGradient.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Color3.fromRGB(80, 255, 80)),
									ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 200, 40))
								}
							end
							local gui = newUnit:FindFirstChild("HP_Gui")
							if gui then gui.Enabled = (hp < max) end
							if hp <= 0 then
								local supply = newUnit:GetAttribute("Supply") or 1
								local ps = player:FindFirstChild("PlayerStats")
								if ps and ps:FindFirstChild("CurrentUnits") then
									ps.CurrentUnits.Value = math.max(0, ps.CurrentUnits.Value - supply)
								end
								newUnit:Destroy()
							end
						end)

						if army then newUnit.Parent = army end
						print("Unloaded unit:", info.Name)

					end
				end
			end

			transport:SetAttribute("Passengers", HttpService:JSONEncode({}))
			transport:SetAttribute("PassengerCount", 0)
			LoadedUnitsByTransport[transport] = nil
			local refFolder = transport:FindFirstChild("LoadedUnits")
			if refFolder then refFolder:Destroy() end
			print("Unload complete")

		else
			-- Загрузка
			local nearbyInfantry = false
			if army then
				for _, unit in pairs(army:GetChildren()) do
					if unit:GetAttribute("Owner") == player.Name and unit:GetAttribute("Class") == "Infantry" then
						local dx = unit:GetPivot().Position.X - pos.X
						local dz = unit:GetPivot().Position.Z - pos.Z
						local dist = math.sqrt(dx*dx + dz*dz)
						if dist <= range then
							nearbyInfantry = true
							break
						end
					end
				end
			end
			if nearbyInfantry and #passengers < capacity then
				local toLoad = {}
				for _, unit in pairs(army:GetChildren()) do
					if #passengers + #toLoad >= capacity then break end
					if unit:GetAttribute("Owner") == player.Name and unit:GetAttribute("Class") == "Infantry" then
						local dx = unit:GetPivot().Position.X - pos.X
						local dz = unit:GetPivot().Position.Z - pos.Z
						local dist = math.sqrt(dx*dx + dz*dz)
						if dist <= range then
							table.insert(toLoad, unit)
						end
					end
				end

				local totalSupply = 0

				for _, unit in ipairs(toLoad) do
					local unitName = unit.Name
					local uData = Config.Units[unitName]
					local supply = uData.Supply or 1
					totalSupply = totalSupply + supply

					local passengerInfo = {
						Name = unitName,
						Health = unit:GetAttribute("Health") or 100,
						MaxHealth = unit:GetAttribute("MaxHealth") or 100,
						Supply = supply,
					}
					table.insert(passengers, passengerInfo)

					if not LoadedUnitsByTransport[transport] then
						LoadedUnitsByTransport[transport] = {}
					end
					table.insert(LoadedUnitsByTransport[transport], unit)
					unit:SetAttribute("LoadedInTransport", true)
					unit.Parent = LoadedUnitsFolder

					local refFolder = transport:FindFirstChild("LoadedUnits")
					if not refFolder then
						refFolder = Instance.new("Folder")
						refFolder.Name = "LoadedUnits"
						refFolder.Parent = transport
					end
					local ref = Instance.new("ObjectValue")
					ref.Name = "UnitRef"
					ref.Value = unit
					ref.Parent = refFolder
				end

				local newJson = HttpService:JSONEncode(passengers)
				transport:SetAttribute("Passengers", newJson)
				transport:SetAttribute("PassengerCount", #passengers)
				print("Load complete, passengers:", #passengers)
			end
		end
	end
end

return UnitTransport
