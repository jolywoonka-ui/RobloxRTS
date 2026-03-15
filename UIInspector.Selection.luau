-- UIInspector.Selection (ModuleScript, ReplicatedStorage)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local module = {}

local mapPartsCache = {}
local mapPartsSet = {}
local mapFolderAddedConn = nil
local mapFolderRemovingConn = nil
local currentMapAddedConn = nil
local currentMapRemovedConn = nil

local function clearMapPartsCache()
	table.clear(mapPartsCache)
	table.clear(mapPartsSet)
end

local function addMapPart(part)
	if not part or not part:IsA("BasePart") then
		return
	end
	if mapPartsSet[part] then
		return
	end
	mapPartsSet[part] = true
	table.insert(mapPartsCache, part)
end

local function removeMapPart(part)
	if not mapPartsSet[part] then
		return
	end
	mapPartsSet[part] = nil
	for i = #mapPartsCache, 1, -1 do
		if mapPartsCache[i] == part then
			table.remove(mapPartsCache, i)
			break
		end
	end
end

local function rebuildMapPartsCache()
	clearMapPartsCache()
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then
		return
	end
	local mapFolder = map:FindFirstChild("Map")
	if not mapFolder then
		return
	end
	for _, inst in ipairs(mapFolder:GetDescendants()) do
		if inst:IsA("BasePart") then
			addMapPart(inst)
		end
	end
end

local function disconnectMapCacheConnections()
	if mapFolderAddedConn then
		mapFolderAddedConn:Disconnect()
		mapFolderAddedConn = nil
	end
	if mapFolderRemovingConn then
		mapFolderRemovingConn:Disconnect()
		mapFolderRemovingConn = nil
	end
end

local function bindMapCacheSignals()
	disconnectMapCacheConnections()
	rebuildMapPartsCache()

	local currentMap = workspace:FindFirstChild("CurrentMap")
	if not currentMap then
		return
	end
	local mapFolder = currentMap:FindFirstChild("Map")
	if not mapFolder then
		return
	end

	mapFolderAddedConn = mapFolder.DescendantAdded:Connect(function(inst)
		if inst:IsA("BasePart") then
			addMapPart(inst)
		end
	end)

	mapFolderRemovingConn = mapFolder.DescendantRemoving:Connect(function(inst)
		if inst:IsA("BasePart") then
			removeMapPart(inst)
		end
	end)
end

bindMapCacheSignals()

currentMapAddedConn = workspace.ChildAdded:Connect(function(child)
	if child.Name == "CurrentMap" then
		bindMapCacheSignals()
	end
end)

currentMapRemovedConn = workspace.ChildRemoved:Connect(function(child)
	if child.Name == "CurrentMap" then
		disconnectMapCacheConnections()
		clearMapPartsCache()
	end
end)

function module.getGroundY(pos)
	local rayOrigin = pos + Vector3.new(0, 200, 0)
	local rayDir = Vector3.new(0, -400, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = mapPartsCache

	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then
		return result.Position.Y
	end

	params.FilterDescendantsInstances = {workspace.Terrain}
	result = workspace:Raycast(rayOrigin, rayDir, params)
	return result and result.Position.Y or pos.Y - 1
end

function module.isOwnerAllied(ownerName, model, player)
	if not ownerName or ownerName == "" then
		return false
	end
	if ownerName == player.Name then
		return true
	end
	local myAlliance = player:GetAttribute("AllianceID")
	if not myAlliance then
		return false
	end

	local ownerPlayer = Players:FindFirstChild(ownerName)
	if ownerPlayer then
		local ownerAlliance = ownerPlayer:GetAttribute("AllianceID")
		return ownerAlliance and ownerAlliance == myAlliance
	end

	local modelAlliance = model and model:GetAttribute("AllianceID")
	return modelAlliance and modelAlliance == myAlliance
end

local function addRingFace(rangePart)
	local function addFace(face)
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 28
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Parent = rangePart

		local ring = Instance.new("Frame")
		ring.Size = UDim2.fromScale(1, 1)
		ring.BackgroundColor3 = rangePart.Color
		ring.BackgroundTransparency = 0.86
		ring.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = ring

		local stroke = Instance.new("UIStroke")
		stroke.Color = rangePart.Color
		stroke.Thickness = 2
		stroke.Transparency = 0.2
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = ring
	end

	addFace(Enum.NormalId.Top)
	addFace(Enum.NormalId.Bottom)
end

function module.createSelectionVisuals(model, bData, selectedByMulti, relationColor, rangeColor)
	local visuals = {
		Highlight = nil,
		RangeIndicator = nil,
		RangeUpdateConn = nil,
	}

	if not selectedByMulti then
		local highlight = Instance.new("Highlight")
		highlight.Name = "BuildingHighlight"
		highlight.Adornee = model
		highlight.FillColor = relationColor
		highlight.FillTransparency = 0.5
		highlight.OutlineColor = Color3.new(1, 1, 1)
		highlight.Parent = model
		visuals.Highlight = highlight
	end

	local function getDynamicRange()
		local rangeAttr = tonumber(model:GetAttribute("Range") or 0) or 0
		local range = rangeAttr
		if range <= 0 then
			range = tonumber(bData and (bData.Range or bData.HealRange) or 0) or 0
		end
		if bData and bData.RangeGarrisoned and (model:GetAttribute("GarrisonCount") or 0) > 0 then
			range = bData.RangeGarrisoned
		elseif bData and bData.RangeEmpty then
			range = 0
		end
		return range
	end

	local range = getDynamicRange()
	if range > 0 and not selectedByMulti then
		local rangePart = Instance.new("Part")
		rangePart.Anchored = true
		rangePart.CanCollide = false
		rangePart.CanQuery = false
		rangePart.CastShadow = false
		rangePart.Material = Enum.Material.SmoothPlastic
		rangePart.Color = rangeColor or relationColor
		rangePart.Transparency = 1
		rangePart.Size = Vector3.new(range * 2, 0.05, range * 2)
		addRingFace(rangePart)

		local function updateRange()
			if not model or not model.Parent then
				return
			end
			local root = model:IsA("Model") and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")) or model
			if not root then
				return
			end
			local groundY = module.getGroundY(root.Position)
			local thickness = 0.05
			local diskY = groundY + thickness / 2 + 0.03
			local diameter = getDynamicRange() * 2
			rangePart.Size = Vector3.new(diameter, thickness, diameter)
			rangePart.CFrame = CFrame.new(root.Position.X, diskY, root.Position.Z)
			rangePart.Parent = workspace
		end

		updateRange()
		visuals.RangeIndicator = rangePart
		visuals.RangeUpdateConn = RunService.RenderStepped:Connect(updateRange)
	end

	return visuals
end

function module.destroySelectionVisuals(visuals)
	if not visuals then
		return
	end
	if visuals.Highlight then
		visuals.Highlight:Destroy()
		visuals.Highlight = nil
	end
	if visuals.RangeIndicator then
		visuals.RangeIndicator:Destroy()
		visuals.RangeIndicator = nil
	end
	if visuals.RangeUpdateConn then
		visuals.RangeUpdateConn:Disconnect()
		visuals.RangeUpdateConn = nil
	end
end

return module
