-- WallManager (ModuleScript, ServerStorage)
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local WallManager = {}

local MAX_WALL_DISTANCE = 25
local WALL_THICKNESS = 0.5
local DEFAULT_WALL_HEIGHT = 2.5

local walls = {}
local towerWalls = {}
local cachedUnitAIState = nil

local function getUnitAIState()
	if cachedUnitAIState ~= nil then
		return cachedUnitAIState
	end
	local moduleScript = ServerStorage:FindFirstChild("UnitAI.State")
	if not moduleScript then
		local folder = ServerStorage:FindFirstChild("UnitAI")
		if folder then
			moduleScript = folder:FindFirstChild("State") or folder:FindFirstChild("UnitAI.State")
		end
	end
	if not (moduleScript and moduleScript:IsA("ModuleScript")) then
		return nil
	end
	local ok, result = pcall(require, moduleScript)
	if ok and type(result) == "table" then
		cachedUnitAIState = result
		return cachedUnitAIState
	end
	return nil
end

local function getUnitPosition(unit)
	if unit:IsA("Model") then
		return unit:GetPivot().Position
	end
	if unit:IsA("BasePart") then
		return unit.Position
	end
	return Vector3.zero
end

local function pointInsidePartXZ(part, worldPos, margin)
	local lp = part.CFrame:PointToObjectSpace(worldPos)
	local half = part.Size * 0.5
	return math.abs(lp.X) <= (half.X + margin) and math.abs(lp.Z) <= (half.Z + margin)
end

local function getPathFirstWallHitXZ(fromPos, toPos, wallPart, radius)
	local flatTo = Vector3.new(toPos.X, fromPos.Y, toPos.Z)
	local flat = flatTo - fromPos
	local dist = Vector3.new(flat.X, 0, flat.Z).Magnitude
	if dist < 0.001 then
		if pointInsidePartXZ(wallPart, fromPos, radius) then
			return fromPos, Vector3.zero, dist
		end
		return nil, nil, dist
	end
	local step = math.max(0.2, radius * 0.6)
	local count = math.max(1, math.ceil(dist / step))
	local dirUnit = Vector3.new(flat.X, 0, flat.Z).Unit
	for i = 0, count do
		local alpha = i / count
		local probe = fromPos:Lerp(flatTo, alpha)
		if pointInsidePartXZ(wallPart, probe, radius) then
			return probe, dirUnit, dist
		end
	end
	return nil, nil, dist
end

local function stopUnitsBlockedByNewWall(wallPart)
	local stateModule = getUnitAIState()
	if not stateModule then
		return
	end
	local map = workspace:FindFirstChild("CurrentMap")
	local army = map and map:FindFirstChild("Army")
	if not army then
		return
	end
	for _, unit in ipairs(army:GetChildren()) do
		if unit:GetAttribute("Class") ~= "Air" and (unit:GetAttribute("Health") or 0) > 0 then
			local state = stateModule.getState(unit)
			if state and state.State == "MOVING" and #state.Path > 0 then
				local currentPos = getUnitPosition(unit)
				local prevPos = currentPos
				for idx, waypoint in ipairs(state.Path) do
					if typeof(waypoint) == "Vector3" then
						local hitPos, dirUnit, segDist = getPathFirstWallHitXZ(prevPos, waypoint, wallPart, 0.95)
						if hitPos then
							-- Walk up to the new wall naturally: cut queued path at the first blocked segment
							-- and place a stop point just before collision.
							local stopMargin = math.max(0.6, math.min(1.0, segDist * 0.35))
							local stopPos = hitPos
							if dirUnit and dirUnit.Magnitude > 0 then
								stopPos = hitPos - dirUnit * stopMargin
							end
							stopPos = Vector3.new(stopPos.X, waypoint.Y, stopPos.Z)
							state.Path[idx] = stopPos
							for j = #state.Path, idx + 1, -1 do
								table.remove(state.Path, j)
							end
							state.State = "MOVING"
							state.BlockedSince = nil
							break
						end
						prevPos = waypoint
					end
				end
			end
		end
	end
end

local function generateWallID()
	return HttpService:GenerateGUID(false)
end

-- Функция получения высоты земли под точкой (игнорируя здания и юниты)
local function getGroundHeight(pos)
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

	local rayOrigin = pos + Vector3.new(0, 200, 0)
	local rayDir = Vector3.new(0, -400, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets

	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then
		return result.Position.Y
	end
	return pos.Y
end

-- Получить нижнюю и верхнюю точки коннектора (если есть Part), иначе точку на земле
local function getConnectorBounds(tower)
	local connector = tower:FindFirstChild("WallConnector", true)
	if connector and connector:IsA("BasePart") then
		local pos = connector.Position
		local halfHeight = connector.Size.Y / 2
		return pos.Y - halfHeight, pos.Y + halfHeight, Vector3.new(pos.X, pos.Y, pos.Z)
	else
		-- fallback: точка на земле под башней
		local pivot = tower:GetPivot().Position
		local groundY = getGroundHeight(pivot)
		return groundY, groundY + DEFAULT_WALL_HEIGHT, Vector3.new(pivot.X, groundY, pivot.Z)
	end
end

-- Проверка, свободен ли путь для стены
local function isWallPathClear(towerA, towerB, player)
	local lowA, highA, posA = getConnectorBounds(towerA)
	local lowB, highB, posB = getConnectorBounds(towerB)

	local dir = posB - posA
	local horDir = Vector3.new(dir.X, 0, dir.Z)
	local length = horDir.Magnitude
	if length == 0 then return false end

	local mid = (posA + posB) / 2
	local wallHeight = math.max(highA, highB) - math.min(lowA, lowB)

	-- Создаём временную часть для проверки коллизий
	local checkPart = Instance.new("Part")
	checkPart.Size = Vector3.new(length, wallHeight, WALL_THICKNESS)
	checkPart.CFrame = CFrame.lookAt(mid, posB) * CFrame.Angles(0, math.rad(90), 0)
	checkPart.Anchored = true
	checkPart.CanCollide = false
	checkPart.Parent = workspace

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {towerA, towerB, player.Character}
	params.FilterDescendantsInstances = ignore

	local parts = workspace:GetPartsInPart(checkPart, params)
	checkPart:Destroy()

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model:GetAttribute("Owner") then
			if model ~= towerA and model ~= towerB then
				return false, "Another building is in the way"
			end
		end
	end
	return true
end

function WallManager.hasWall(towerA, towerB)
	for wallId, data in pairs(walls) do
		if (data.towerA == towerA and data.towerB == towerB) or (data.towerA == towerB and data.towerB == towerA) then
			return true
		end
	end
	return false
end

function WallManager.createWall(towerA, towerB, player)
	if not towerA or not towerB or not towerA.Parent or not towerB.Parent then
		return false, "Tower missing"
	end
	if towerA == towerB then
		return false, "Same tower"
	end
	if not towerA:GetAttribute("ConnectsWalls") or not towerB:GetAttribute("ConnectsWalls") then
		return false, "Not a wall tower"
	end
	if towerA:GetAttribute("IsUnderConstruction") or towerB:GetAttribute("IsUnderConstruction") then
		return false, "Tower is still under construction"
	end
	if WallManager.hasWall(towerA, towerB) then
		return false, "Wall already exists"
	end

	local lowA, highA, posA = getConnectorBounds(towerA)
	local lowB, highB, posB = getConnectorBounds(towerB)

	local horDir = Vector3.new(posB.X - posA.X, 0, posB.Z - posA.Z)
	local distance = horDir.Magnitude
	if distance > MAX_WALL_DISTANCE then
		return false, "Towers too far apart (max " .. MAX_WALL_DISTANCE .. " studs)"
	end
	if distance < 2 then
		return false, "Towers too close"
	end

	local clear, msg = isWallPathClear(towerA, towerB, player)
	if not clear then
		return false, msg
	end

	local midpoint = (posA + posB) / 2
	local minY = math.min(lowA, lowB)
	local maxY = math.max(highA, highB)
	local wallHeight = maxY - minY

	local wall = Instance.new("Part")
	wall.Name = "WallSegment"
	wall.Anchored = true
	wall.CanCollide = true
	wall.CanQuery = true
	wall.CanTouch = true
	wall.Material = Enum.Material.Concrete
	wall.Color = Color3.fromRGB(150, 150, 150)
	wall.CollisionGroup = "Walls"
	wall.Size = Vector3.new(distance, wallHeight, WALL_THICKNESS)

	local finalPos = Vector3.new(midpoint.X, minY + wallHeight/2, midpoint.Z)
	wall.CFrame = CFrame.lookAt(finalPos, posB) * CFrame.Angles(0, math.rad(90), 0)

	local owner = towerA:GetAttribute("Owner")
	wall:SetAttribute("Owner", owner)
	wall:SetAttribute("WallID", generateWallID())

	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return false, "No map" end
	local wallsFolder = map:FindFirstChild("Walls")
	if not wallsFolder then
		wallsFolder = Instance.new("Folder")
		wallsFolder.Name = "Walls"
		wallsFolder.Parent = map
	end
	wall.Parent = wallsFolder

	if _G.setCollisionGroup then
		_G.setCollisionGroup(wall, "Walls")
	end

	stopUnitsBlockedByNewWall(wall)

	local wallId = wall:GetAttribute("WallID")
	walls[wallId] = { towerA = towerA, towerB = towerB, part = wall }

	towerWalls[towerA] = towerWalls[towerA] or {}
	table.insert(towerWalls[towerA], wallId)
	towerWalls[towerB] = towerWalls[towerB] or {}
	table.insert(towerWalls[towerB], wallId)

	print("Wall created between", towerA.Name, "and", towerB.Name, "height:", wallHeight)
	return true, "Wall created"
end

function WallManager.removeWall(towerA, towerB)
	local wallIdToRemove = nil
	for wallId, data in pairs(walls) do
		if (data.towerA == towerA and data.towerB == towerB) or (data.towerA == towerB and data.towerB == towerA) then
			wallIdToRemove = wallId
			break
		end
	end
	if not wallIdToRemove then return false end

	local data = walls[wallIdToRemove]
	if data.part and data.part.Parent then
		data.part:Destroy()
	end
	walls[wallIdToRemove] = nil

	if towerWalls[towerA] then
		for i, id in ipairs(towerWalls[towerA]) do
			if id == wallIdToRemove then
				table.remove(towerWalls[towerA], i)
				break
			end
		end
	end
	if towerWalls[towerB] then
		for i, id in ipairs(towerWalls[towerB]) do
			if id == wallIdToRemove then
				table.remove(towerWalls[towerB], i)
				break
			end
		end
	end
	return true
end

function WallManager.removeWallsForTower(tower)
	local wallIds = towerWalls[tower]
	if not wallIds then return end

	local idsToRemove = {}
	for _, wallId in ipairs(wallIds) do
		table.insert(idsToRemove, wallId)
	end

	for _, wallId in ipairs(idsToRemove) do
		local data = walls[wallId]
		if data then
			WallManager.removeWall(data.towerA, data.towerB)
		end
	end
	towerWalls[tower] = nil
end

return WallManager
