-- UnitAI.Blockers (ModuleScript, ServerStorage)
local module = {}

local Players = game:GetService("Players")

local C
local getRoot

local mapQueryPreparedFor = nil
local mapQueryAddedConn = nil
local blockerPartsPreparedFor = nil
local blockerParts = {}
local blockerSet = {}
local blockerConns = {}
local blockerRoots = {}
local blockerRootSet = {}
local groundPartsPreparedFor = nil
local groundParts = {}
local groundPartSet = {}
local groundConns = {}

local isStaticMapBlocker
local isWalkableGroundPart

local function resolveRoot(unit)
    if getRoot then
        return getRoot(unit)
    end
    if unit:IsA("Model") then
        return unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
    end
    return unit
end

function module.init(deps)
    deps = deps or {}
    Players = deps.Players or Players
    C = deps.Constants
    getRoot = deps.getRoot
end

local function isWaterLikePart(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    if part.Material == Enum.Material.Water then
        return true
    end

    local lowerName = string.lower(part.Name)
    return string.find(lowerName, "water", 1, true) ~= nil
end

local function disconnectGroundConns()
    for _, conn in ipairs(groundConns) do
        if conn then
            conn:Disconnect()
        end
    end
    table.clear(groundConns)
end

local function clearGroundParts()
    table.clear(groundParts)
    table.clear(groundPartSet)
end

local function addGroundPart(part)
    if not part or not part:IsA("BasePart") then
        return
    end
    if groundPartSet[part] then
        return
    end
    if not isWalkableGroundPart(part) then
        return
    end
    groundPartSet[part] = true
    table.insert(groundParts, part)
end

local function removeGroundPart(part)
    if not groundPartSet[part] then
        return
    end
    groundPartSet[part] = nil
    for i = #groundParts, 1, -1 do
        if groundParts[i] == part then
            table.remove(groundParts, i)
            break
        end
    end
end

function module.ensureGroundPartsCache()
    local currentMap = workspace:FindFirstChild("CurrentMap")
    if currentMap ~= groundPartsPreparedFor then
        disconnectGroundConns()
        clearGroundParts()
        groundPartsPreparedFor = currentMap

        if not currentMap then
            return
        end

        for _, inst in ipairs(currentMap:GetDescendants()) do
            if inst:IsA("BasePart") then
                addGroundPart(inst)
            end
        end

        table.insert(groundConns, currentMap.DescendantAdded:Connect(function(inst)
            if inst:IsA("BasePart") then
                addGroundPart(inst)
            end
        end))

        table.insert(groundConns, currentMap.DescendantRemoving:Connect(function(inst)
            if inst:IsA("BasePart") then
                removeGroundPart(inst)
            end
        end))
    end
end

local function getGroundParts()
    module.ensureGroundPartsCache()
    return groundParts
end

local function getGroundPart()
    local parts = getGroundParts()
    return parts[1]
end

function module.ensureMapQueryEnabled()
    local map = workspace:FindFirstChild("CurrentMap")
    if map == mapQueryPreparedFor then
        return
    end

    if mapQueryAddedConn then
        mapQueryAddedConn:Disconnect()
        mapQueryAddedConn = nil
    end

    mapQueryPreparedFor = map
    if not map then
        return
    end

    local function makeQueryable(inst)
        if inst and inst:IsA("BasePart") and inst:IsDescendantOf(map) and not inst.CanQuery then
            inst.CanQuery = true
        end
    end

    for _, inst in ipairs(map:GetDescendants()) do
        makeQueryable(inst)
    end

    mapQueryAddedConn = map.DescendantAdded:Connect(makeQueryable)
end

local function disconnectBlockerConns()
    for _, conn in ipairs(blockerConns) do
        if conn then
            conn:Disconnect()
        end
    end
    table.clear(blockerConns)
end

local function clearBlockerParts()
    table.clear(blockerParts)
    table.clear(blockerSet)
    table.clear(blockerRoots)
    table.clear(blockerRootSet)
end

local function addBlockerPart(part)
    if not part or not part:IsA("BasePart") then
        return
    end
    if blockerSet[part] then
        return
    end
    blockerSet[part] = true
    table.insert(blockerParts, part)
end

local function removeBlockerPart(part)
    if not blockerSet[part] then
        return
    end
    blockerSet[part] = nil
    for i = #blockerParts, 1, -1 do
        if blockerParts[i] == part then
            table.remove(blockerParts, i)
            break
        end
    end
end

local function collectBlockerFolder(folder)
    if not folder then
        return
    end
    if blockerRootSet[folder] then
        return
    end

    blockerRootSet[folder] = true
    table.insert(blockerRoots, folder)

    for _, inst in ipairs(folder:GetDescendants()) do
        if inst:IsA("BasePart") then
            addBlockerPart(inst)
        end
    end

    table.insert(blockerConns, folder.DescendantAdded:Connect(function(inst)
        if inst:IsA("BasePart") then
            addBlockerPart(inst)
        end
    end))

    table.insert(blockerConns, folder.DescendantRemoving:Connect(function(inst)
        if inst:IsA("BasePart") then
            removeBlockerPart(inst)
        end
    end))
end

function module.ensureBlockerPartsCache()
    local currentMap = workspace:FindFirstChild("CurrentMap")
    if currentMap ~= blockerPartsPreparedFor then
        disconnectBlockerConns()
        clearBlockerParts()
        blockerPartsPreparedFor = currentMap

        if not currentMap then
            return
        end

        local function watchForBlockerFolders(container)
            if not container then
                return
            end
            table.insert(blockerConns, container.ChildAdded:Connect(function(child)
                if not child then
                    return
                end
                if child.Name == "Walls" or child.Name == "Mountains" then
                    collectBlockerFolder(child)
                end
            end))
        end

        watchForBlockerFolders(currentMap)
        local initialMapFolder = currentMap:FindFirstChild("Map")
        if initialMapFolder then
            watchForBlockerFolders(initialMapFolder)
        else
            table.insert(blockerConns, currentMap.ChildAdded:Connect(function(child)
                if child and child.Name == "Map" then
                    watchForBlockerFolders(child)
                    collectBlockerFolder(child:FindFirstChild("Walls"))
                    collectBlockerFolder(child:FindFirstChild("Mountains"))
                end
            end))
        end
    end

    if not currentMap then
        return
    end

    local mapFolder = currentMap:FindFirstChild("Map")
    if mapFolder then
        collectBlockerFolder(mapFolder:FindFirstChild("Walls"))
        collectBlockerFolder(mapFolder:FindFirstChild("Mountains"))
    end
    collectBlockerFolder(currentMap:FindFirstChild("Walls"))
end

local function getActiveBlockerRoots()
    module.ensureBlockerPartsCache()

    local roots = {}
    local rootSet = {}

    local function addRoot(root)
        if root and root.Parent and (not rootSet[root]) then
            rootSet[root] = true
            table.insert(roots, root)
        end
    end

    for _, root in ipairs(blockerRoots) do
        addRoot(root)
    end

    local currentMap = workspace:FindFirstChild("CurrentMap")
    if currentMap then
        addRoot(currentMap:FindFirstChild("Walls"))
        local mapFolder = currentMap:FindFirstChild("Map")
        if mapFolder then
            addRoot(mapFolder:FindFirstChild("Walls"))
            addRoot(mapFolder:FindFirstChild("Mountains"))
        end
    end

    return roots
end

local function pointInsideExpandedPart(part, worldPos, horizontalRadius, verticalHalfHeight)
    if not (part and part.Parent and part:IsA("BasePart")) then
        return false
    end

    local localPos = part.CFrame:PointToObjectSpace(worldPos)
    local half = part.Size * 0.5
    return math.abs(localPos.X) <= (half.X + horizontalRadius)
        and math.abs(localPos.Y) <= (half.Y + verticalHalfHeight)
        and math.abs(localPos.Z) <= (half.Z + horizontalRadius)
end

local function intersectsKnownBlockers(fromPos, toPos, state)
    module.ensureBlockerPartsCache()
    if #blockerParts == 0 then
        return false
    end

    local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
    local dist = flat.Magnitude
    if dist < 0.001 then
        return false
    end

    local castSize = (state and state.CollisionSize) or Vector3.new(1.5, 2, 1.5)
    local horizontalRadius = math.max(0.45, math.max(castSize.X, castSize.Z) * 0.45)
    local verticalHalfHeight = math.max(0.45, castSize.Y * 0.45)
    local sampleStep = math.max(0.25, horizontalRadius * 0.5)
    local sampleCount = math.max(1, math.ceil(dist / sampleStep))

    for i = 0, sampleCount do
        local alpha = i / sampleCount
        local probePos = fromPos:Lerp(toPos, alpha)
        for _, part in ipairs(blockerParts) do
            if part and part.Parent and (part.CanCollide or part:GetAttribute("WallID")) and pointInsideExpandedPart(part, probePos, horizontalRadius, verticalHalfHeight) then
                return true
            end
        end
    end

    return false
end

function module.refreshGroundProfile(unit, state)
    if not state then
        return
    end

    if unit:IsA("Model") then
        local ok, boxCFrame, size = pcall(function()
            local cf, s = unit:GetBoundingBox()
            return cf, s
        end)

        if ok and boxCFrame and size then
            local pivotY = unit:GetPivot().Position.Y
            local bottomY = boxCFrame.Position.Y - (size.Y * 0.5)
            state.GroundOffset = math.max(0.2, pivotY - bottomY)
            state.UnitHeight = math.max(1, size.Y)
            state.CollisionSize = Vector3.new(
                math.max(0.8, size.X * 0.65),
                math.max(1.0, size.Y * 0.8),
                math.max(0.8, size.Z * 0.65)
            )
            return
        end
    end

    local root = resolveRoot(unit)
    if root then
        state.GroundOffset = math.max(0.2, root.Size.Y * 0.5)
        state.UnitHeight = math.max(1, root.Size.Y)
        state.CollisionSize = Vector3.new(
            math.max(0.8, root.Size.X * 0.7),
            math.max(1.0, root.Size.Y * 0.8),
            math.max(0.8, root.Size.Z * 0.7)
        )
    end
end

function module.getGroundSnapY(unit, targetPos, state)
    local grounds = getGroundParts()
    if #grounds == 0 then
        return targetPos.Y
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = grounds

    local origin = Vector3.new(targetPos.X, targetPos.Y + 500, targetPos.Z)
    local result = workspace:Raycast(origin, Vector3.new(0, -1000, 0), params)
    if not result then
        return targetPos.Y
    end

    local offset = (state and state.GroundOffset) or 1
    return result.Position.Y + offset - C.GROUND_SNAP_BIAS
end

isStaticMapBlocker = function(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    if C.NON_WALKABLE_MATERIALS[part.Material] then
        return true
    end

    local lowerName = string.lower(part.Name)
    if string.find(lowerName, "forcefield", 1, true)
        or string.find(lowerName, "rock", 1, true)
        or string.find(lowerName, "mountain", 1, true) then
        return true
    end

    local current = part.Parent
    while current do
        local n = current.Name
        if n == "ForceFields" or n == "Rocks" or n == "Rock" or n == "Mountains" or n == "Walls" then
            return true
        end
        current = current.Parent
    end

    return false
end

isWalkableGroundPart = function(part)
    if not part or not part:IsA("BasePart") then
        return false
    end

    local currentMap = workspace:FindFirstChild("CurrentMap")
    local mapFolder = currentMap and currentMap:FindFirstChild("Map")
    if not (currentMap and mapFolder and part:IsDescendantOf(mapFolder)) then
        return false
    end

    if not part.CanCollide then
        return false
    end

    if isWaterLikePart(part) then
        return false
    end

    if isStaticMapBlocker(part) then
        return false
    end

    return true
end

function module.getMapContext()
    local currentMap = workspace:FindFirstChild("CurrentMap")
    if not currentMap then
        return nil, nil, nil
    end

    local mapFolder = currentMap:FindFirstChild("Map")
    local ground = getGroundPart()
    return currentMap, mapFolder, ground
end

function module.getAirTargetY(pos, unit, flightHeight)
    local rayOrigin = pos + Vector3.new(0, 200, 0)
    local rayDir = Vector3.new(0, -400, 0)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local ignore = {unit}
    local map = workspace:FindFirstChild("CurrentMap")
    if map then
        local army = map:FindFirstChild("Army")
        local buildings = map:FindFirstChild("PlayerBuildings")
        if army then table.insert(ignore, army) end
        if buildings then table.insert(ignore, buildings) end
    end

    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            table.insert(ignore, p.Character)
        end
    end

    params.FilterDescendantsInstances = ignore

    local result = workspace:Raycast(rayOrigin, rayDir, params)
    local groundY = pos.Y
    if result then
        local hit = result.Instance
        if hit and hit:IsA("BasePart") then
            if hit.Material == Enum.Material.ForceField or hit.Material == Enum.Material.Rock then
                groundY = result.Position.Y
            else
                if map then
                    local mapFolder = map:FindFirstChild("Map")
                    if mapFolder then
                        local mountains = mapFolder:FindFirstChild("Mountains")
                        local walls = mapFolder:FindFirstChild("Walls")
                        if mountains then
                            local current = hit
                            while current do
                                if current == mountains then
                                    groundY = result.Position.Y
                                    break
                                end
                                current = current.Parent
                            end
                        end
                        if groundY == pos.Y and walls then
                            local current = hit
                            while current do
                                if current == walls then
                                    groundY = result.Position.Y
                                    break
                                end
                                current = current.Parent
                            end
                        end
                    end
                end
            end
        end
    end

    local glide = 0
    if groundY ~= pos.Y then
        glide = C.AIR_GLIDE_OFFSET
    end
    return groundY + (flightHeight * C.AIR_HEIGHT_FACTOR) + glide
end

local function isWallPart(part)
    if part:GetAttribute("WallID") then return true end
    if part.Name == "WallSegment" then return true end

    local current = part
    while current do
        if current.Name == "Walls" then
            return true
        end
        current = current.Parent
    end
    return false
end

local function getOwnerFromHitPart(part)
    local current = part
    while current do
        local owner = current:GetAttribute("Owner")
        if owner ~= nil then
            return owner
        end
        current = current.Parent
    end
    return nil
end

local function areOwnersAllied(ownerPlayer, otherOwnerName)
    if not (ownerPlayer and otherOwnerName) then
        return false
    end
    local otherPlayer = Players:FindFirstChild(otherOwnerName)
    if not otherPlayer then
        return false
    end
    local a1 = ownerPlayer:GetAttribute("AllianceID")
    local a2 = otherPlayer:GetAttribute("AllianceID")
    return a1 and a2 and a1 == a2
end

local function getUnitRadius(unit, state)
    if state and state.CollisionSize then
        return math.max(0.5, math.max(state.CollisionSize.X, state.CollisionSize.Z) * 0.45)
    end
    local root = resolveRoot(unit)
    if root and root:IsA("BasePart") then
        return math.max(0.5, math.max(root.Size.X, root.Size.Z) * 0.45)
    end
    return 0.9
end

local function distPointToSegmentXZ(point, segA, segB)
    local px, pz = point.X, point.Z
    local ax, az = segA.X, segA.Z
    local bx, bz = segB.X, segB.Z
    local abx, abz = (bx - ax), (bz - az)
    local len2 = abx * abx + abz * abz
    if len2 < 1e-4 then
        local dx, dz = (px - ax), (pz - az)
        return math.sqrt(dx * dx + dz * dz)
    end
    local t = ((px - ax) * abx + (pz - az) * abz) / len2
    t = math.clamp(t, 0, 1)
    local cx = ax + abx * t
    local cz = az + abz * t
    local dx, dz = (px - cx), (pz - cz)
    return math.sqrt(dx * dx + dz * dz)
end

local function getLiveTowerWallParts()
    local currentMap = workspace:FindFirstChild("CurrentMap")
    if not currentMap then
        return {}
    end
    local wallsFolder = currentMap:FindFirstChild("Walls")
    if not wallsFolder then
        return {}
    end

    local parts = {}
    for _, child in ipairs(wallsFolder:GetDescendants()) do
        if child:IsA("BasePart") and (child:GetAttribute("WallID") or child.Name == "WallSegment") then
            if not child.CanQuery then
                child.CanQuery = true
            end
            table.insert(parts, child)
        end
    end
    return parts
end

local function pointInsideExpandedPartXZ(part, worldPos, horizontalRadius)
    if not (part and part.Parent and part:IsA("BasePart")) then
        return false
    end
    local localPos = part.CFrame:PointToObjectSpace(worldPos)
    local half = part.Size * 0.5
    return math.abs(localPos.X) <= (half.X + horizontalRadius)
        and math.abs(localPos.Z) <= (half.Z + horizontalRadius)
end

local function intersectsLiveTowerWalls(fromPos, toPos, state)
    local wallParts = getLiveTowerWallParts()
    if #wallParts == 0 then
        return false
    end

    local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
    local dist = flat.Magnitude
    if dist < 0.001 then
        return false
    end

    local castSize = (state and state.CollisionSize) or Vector3.new(1.5, 2, 1.5)
    local horizontalRadius = math.max(0.45, math.max(castSize.X, castSize.Z) * 0.45)
    local sampleStep = math.max(0.2, math.min(castSize.X, castSize.Z) * 0.3)
    local sampleCount = math.max(1, math.ceil(dist / sampleStep))
    local footY = fromPos.Y - ((state and state.GroundOffset) or 1) + 0.25
    local highY = fromPos.Y + math.max(0.4, ((state and state.UnitHeight) or 2) * 0.25)

    for i = 0, sampleCount do
        local alpha = i / sampleCount
        local probePos = fromPos:Lerp(toPos, alpha)
        local probeFoot = Vector3.new(probePos.X, footY, probePos.Z)
        local probeHigh = Vector3.new(probePos.X, highY, probePos.Z)
        for _, wall in ipairs(wallParts) do
            if wall and wall.Parent and (
                pointInsideExpandedPartXZ(wall, probePos, horizontalRadius)
                or pointInsideExpandedPartXZ(wall, probeFoot, horizontalRadius)
                or pointInsideExpandedPartXZ(wall, probeHigh, horizontalRadius)
            ) then
                return true
            end
        end
    end

    local unitHeight = (state and state.UnitHeight) or 3
    local footY = fromPos.Y - ((state and state.GroundOffset) or 1) + 0.25
    local origins = {
        Vector3.new(fromPos.X, fromPos.Y, fromPos.Z),
        Vector3.new(fromPos.X, fromPos.Y + math.max(0.5, unitHeight * 0.28), fromPos.Z),
        Vector3.new(fromPos.X, fromPos.Y - math.max(0.4, unitHeight * 0.2), fromPos.Z),
        Vector3.new(fromPos.X, footY, fromPos.Z),
    }

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = wallParts
    local rayDir = flat.Unit * dist

    for _, origin in ipairs(origins) do
        local hit = workspace:Raycast(origin, rayDir, params)
        if hit and hit.Instance then
            return true
        end
    end

    return false
end

function module.canMoveTo(unit, fromPos, toPos, state)
    local dir = toPos - fromPos
    dir = Vector3.new(dir.X, 0, dir.Z)

    local dist = dir.Magnitude
    if dist < 0.05 then
        return true
    end

    local ownerName = unit:GetAttribute("Owner")
    local ownerPlayer = ownerName and Players:FindFirstChild(ownerName)
    local currentMap = workspace:FindFirstChild("CurrentMap")
    local buildingsFolder = currentMap and currentMap:FindFirstChild("PlayerBuildings")

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude

    local ignoreList = {unit}
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character then
            table.insert(ignoreList, p.Character)
        end
    end

    local army = currentMap and currentMap:FindFirstChild("Army")
    if army then
        table.insert(ignoreList, army)
    end
    params.FilterDescendantsInstances = ignoreList

    local function blocksHit(hitPart)
        if not hitPart then
            return false
        end
        if isWallPart(hitPart) then
            return true
        end

        if buildingsFolder and hitPart:IsDescendantOf(buildingsFolder) then
            local buildingOwner = getOwnerFromHitPart(hitPart)
            if buildingOwner == ownerName then
                return false
            end
            if areOwnersAllied(ownerPlayer, buildingOwner) then
                return false
            end
            -- Neutral/no-owner building parts should still block movement.
            return true
        end

        local hitOwner = getOwnerFromHitPart(hitPart)
        if hitOwner then
            if hitOwner == ownerName then
                return false
            end

            if areOwnersAllied(ownerPlayer, hitOwner) then
                return false
            end
            return true
        end

        if currentMap and hitPart:IsDescendantOf(currentMap) then
            if isWalkableGroundPart(hitPart) then
                return false
            end
            if hitPart.CanCollide then
                return true
            end
        end

        return isStaticMapBlocker(hitPart)
    end

    local unitHeight = (state and state.UnitHeight) or 3
    local centerY = fromPos.Y
    local footY = fromPos.Y - ((state and state.GroundOffset) or 1) + 0.25
    local rayDir = dir.Unit * dist

    local origins = {
        Vector3.new(fromPos.X, centerY, fromPos.Z),
        Vector3.new(fromPos.X, centerY + math.max(0.5, unitHeight * 0.28), fromPos.Z),
        Vector3.new(fromPos.X, centerY - math.max(0.4, unitHeight * 0.2), fromPos.Z),
        Vector3.new(fromPos.X, footY, fromPos.Z),
    }

    for _, rayOrigin in ipairs(origins) do
        local result = workspace:Raycast(rayOrigin, rayDir, params)
        if result and blocksHit(result.Instance) then
            return false
        end
    end

    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = ignoreList

    local castSize = (state and state.CollisionSize) or Vector3.new(1.5, 2, 1.5)
    local moveVector = toPos - fromPos

    local blockcastOk, blockcastResult = pcall(function()
        return workspace:Blockcast(CFrame.new(fromPos), castSize, moveVector, params)
    end)
    if blockcastOk and blockcastResult and blocksHit(blockcastResult.Instance) then
        return false
    end

    local activeRoots = getActiveBlockerRoots()
    if #activeRoots > 0 then
        local blockerParams = OverlapParams.new()
        blockerParams.FilterType = Enum.RaycastFilterType.Include
        blockerParams.FilterDescendantsInstances = activeRoots

        local sampleStep = math.max(0.2, math.min(castSize.X, castSize.Z) * 0.3)
        local sampleCount = math.max(1, math.ceil(dist / sampleStep))
        for i = 0, sampleCount do
            local alpha = i / sampleCount
            local probePos = fromPos:Lerp(toPos, alpha)
            local hits = workspace:GetPartBoundsInBox(CFrame.new(probePos), castSize, blockerParams)
            if #hits > 0 then
                return false
            end
        end

        local probeRadius = math.max(0.6, math.max(castSize.X, castSize.Z) * 0.5)
        local nearby = workspace:GetPartBoundsInRadius(toPos, probeRadius, blockerParams)
        if #nearby > 0 then
            return false
        end
    end

    local sampleStep = math.max(0.2, math.min(castSize.X, castSize.Z) * 0.35)
    local sampleCount = math.max(1, math.ceil(dist / sampleStep))
    for i = 0, sampleCount do
        local alpha = i / sampleCount
        local probePos = fromPos:Lerp(toPos, alpha)
        local overlaps = workspace:GetPartBoundsInBox(CFrame.new(probePos), castSize, overlapParams)
        for _, part in ipairs(overlaps) do
            if blocksHit(part) then
                return false
            end
        end
    end

    if intersectsKnownBlockers(fromPos, toPos, state) then
        return false
    end
    if intersectsLiveTowerWalls(fromPos, toPos, state) then
        return false
    end

    -- Pseudo-collision against units (kinematic movement): prevents stacking and
    -- disallows passing through enemy lines while still allowing movement away.
    if army then
        local myRadius = getUnitRadius(unit, state)
        local toXZ = Vector3.new(toPos.X, 0, toPos.Z)
        local fromXZ = Vector3.new(fromPos.X, 0, fromPos.Z)
        for _, other in ipairs(army:GetChildren()) do
            if other ~= unit and other.Parent and (other:GetAttribute("Health") or 0) > 0 then
                local otherRoot = resolveRoot(other)
                if otherRoot and otherRoot:IsA("BasePart") then
                    local otherOwner = other:GetAttribute("Owner")
                    local allied = (otherOwner == ownerName) or areOwnersAllied(ownerPlayer, otherOwner)
                    local otherRadius = getUnitRadius(other, nil)
                    local baseGap = myRadius + otherRadius + (C.UNIT_COLLISION_PADDING or 0.25)
                    local gap = baseGap * (allied and (C.ALLY_UNIT_COLLISION_MULT or 0.9) or (C.ENEMY_UNIT_COLLISION_MULT or 1.08))

                    local otherXZ = Vector3.new(otherRoot.Position.X, 0, otherRoot.Position.Z)
                    local fromDist = (fromXZ - otherXZ).Magnitude
                    local toDist = (toXZ - otherXZ).Magnitude

                    -- If currently overlapping, allow only movement that increases separation.
                    if toDist < gap then
                        if not (fromDist < gap and toDist > fromDist + 0.02) then
                            return false
                        end
                    end

                    -- Prevent tunneling through units during a single step.
                    local segDist = distPointToSegmentXZ(otherRoot.Position, fromPos, toPos)
                    if segDist < (gap * 0.96) then
                        if not (fromDist < gap and toDist > fromDist + 0.02) then
                            return false
                        end
                    end
                end
            end
        end
    end

    return true
end

function module.clampGroundTarget(unit, fromPos, desiredPos, state)
    local activeRoots = getActiveBlockerRoots()
    if #activeRoots == 0 then
        local snapY = module.getGroundSnapY(unit, desiredPos, state)
        return Vector3.new(desiredPos.X, snapY, desiredPos.Z)
    end

    local dir = desiredPos - fromPos
    local flat = Vector3.new(dir.X, 0, dir.Z)
    local dist = flat.Magnitude
    if dist < 0.05 then
        local snapY = module.getGroundSnapY(unit, desiredPos, state)
        return Vector3.new(desiredPos.X, snapY, desiredPos.Z)
    end

    local castDir = flat.Unit * dist
    local unitHeight = (state and state.UnitHeight) or 3
    local footY = fromPos.Y - ((state and state.GroundOffset) or 1) + 0.25

    local origins = {
        Vector3.new(fromPos.X, fromPos.Y, fromPos.Z),
        Vector3.new(fromPos.X, fromPos.Y + math.max(0.5, unitHeight * 0.28), fromPos.Z),
        Vector3.new(fromPos.X, fromPos.Y - math.max(0.4, unitHeight * 0.2), fromPos.Z),
        Vector3.new(fromPos.X, footY, fromPos.Z),
    }

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = activeRoots

    local bestHit = nil
    local bestFlatDist = math.huge
    for _, origin in ipairs(origins) do
        local hit = workspace:Raycast(origin, castDir, params)
        if hit then
            local d = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(fromPos.X, 0, fromPos.Z)).Magnitude
            if d < bestFlatDist then
                bestFlatDist = d
                bestHit = hit
            end
        end
    end

    local finalPos = desiredPos
    if bestHit then
        local width = (state and state.CollisionSize and math.max(state.CollisionSize.X, state.CollisionSize.Z)) or 1.5
        local stopMargin = math.max(0.8, width * 0.6)
        local hitFlat = Vector3.new(bestHit.Position.X, fromPos.Y, bestHit.Position.Z)
        finalPos = hitFlat - flat.Unit * stopMargin
    end

    local snapY = module.getGroundSnapY(unit, finalPos, state)
    return Vector3.new(finalPos.X, snapY, finalPos.Z)
end

local function getNearestBlockerHit(fromPos, toPos, state)
    local activeRoots = getActiveBlockerRoots()
    if #activeRoots == 0 then
        return nil
    end

    local flat = Vector3.new(toPos.X - fromPos.X, 0, toPos.Z - fromPos.Z)
    local dist = flat.Magnitude
    if dist < 0.05 then
        return nil
    end

    local castDir = flat.Unit * dist
    local unitHeight = (state and state.UnitHeight) or 3
    local footY = fromPos.Y - ((state and state.GroundOffset) or 1) + 0.25

    local origins = {
        Vector3.new(fromPos.X, fromPos.Y, fromPos.Z),
        Vector3.new(fromPos.X, fromPos.Y + math.max(0.5, unitHeight * 0.28), fromPos.Z),
        Vector3.new(fromPos.X, fromPos.Y - math.max(0.4, unitHeight * 0.2), fromPos.Z),
        Vector3.new(fromPos.X, footY, fromPos.Z),
    }

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = activeRoots

    local bestHit = nil
    local bestFlatDist = math.huge
    for _, origin in ipairs(origins) do
        local hit = workspace:Raycast(origin, castDir, params)
        if hit then
            local d = (Vector3.new(hit.Position.X, 0, hit.Position.Z) - Vector3.new(fromPos.X, 0, fromPos.Z)).Magnitude
            if d < bestFlatDist then
                bestFlatDist = d
                bestHit = hit
            end
        end
    end

    return bestHit
end

function module.getSlideDirection(fromPos, toPos, desiredDir, state)
    local hit = getNearestBlockerHit(fromPos, toPos, state)
    if not hit then
        return nil
    end

    local normal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
    if normal.Magnitude < 0.001 then
        return nil
    end
    normal = normal.Unit

    local tangent = desiredDir - normal * desiredDir:Dot(normal)
    tangent = Vector3.new(tangent.X, 0, tangent.Z)
    if tangent.Magnitude < 0.001 then
        tangent = Vector3.new(-normal.Z, 0, normal.X)
    end
    if tangent.Magnitude < 0.001 then
        return nil
    end
    tangent = tangent.Unit

    if tangent:Dot(desiredDir) < 0 then
        tangent = -tangent
    end

    return tangent
end

local function rotateFlatDirection(dir, angleRad)
    local c = math.cos(angleRad)
    local s = math.sin(angleRad)
    local x = dir.X * c - dir.Z * s
    local z = dir.X * s + dir.Z * c
    local out = Vector3.new(x, 0, z)
    if out.Magnitude < 0.001 then
        return nil
    end
    return out.Unit
end

function module.findSteeredMove(fromPos, targetPos, desiredDir, stepDist, state, unit)
    local currentDist = (Vector3.new(targetPos.X, fromPos.Y, targetPos.Z) - fromPos).Magnitude
    local bestPos = nil
    local bestDir = nil
    local bestScore = -math.huge

    for _, deg in ipairs(C.STEER_ANGLES_DEG) do
        local steerDir = rotateFlatDirection(desiredDir, math.rad(deg))
        if steerDir then
            local raw = fromPos + steerDir * (stepDist * C.SLIDE_STEP_SCALE)
            local y = module.getGroundSnapY(unit, raw, state)
            local pos = Vector3.new(raw.X, y, raw.Z)
            if module.canMoveTo(unit, fromPos, pos, state) then
                local newDist = (Vector3.new(targetPos.X, pos.Y, targetPos.Z) - pos).Magnitude
                local progress = currentDist - newDist
                local alignment = math.max(0, steerDir:Dot(desiredDir))
                local score = progress * 2 + alignment
                if score > bestScore then
                    bestScore = score
                    bestPos = pos
                    bestDir = steerDir
                end
            end
        end
    end

    return bestPos, bestDir
end

return module
