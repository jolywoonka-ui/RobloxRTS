local module = {}

local player
local Config
local RunService
local UserInputService
local Training
local MissileSiloEvent

local missileTargetBuilding = nil
local missileTargetVisual = nil
local missileTargetConn = nil
local inspectorInputConn = nil

local function getMissileTargetGroundPoint()
	local mouse = player:GetMouse()
	local ray = mouse.UnitRay
	local targets = { workspace.Terrain }
	local map = workspace:FindFirstChild("CurrentMap")
	if map then
		local mapFolder = map:FindFirstChild("Map")
		if mapFolder then
			local function collectParts(container)
				for _, child in ipairs(container:GetChildren()) do
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

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets
	local result = workspace:Raycast(ray.Origin, ray.Direction * 2500, params)
	return result and result.Position or nil
end

function module.destroyMissileTargeting()
	if missileTargetConn then
		missileTargetConn:Disconnect()
		missileTargetConn = nil
	end
	if missileTargetVisual then
		missileTargetVisual:Destroy()
		missileTargetVisual = nil
	end
	missileTargetBuilding = nil
end

local function ensureMissileTargetVisual()
	if missileTargetVisual then
		return missileTargetVisual
	end

	local missileConfig = Config.SuperWeapons and Config.SuperWeapons.MissileSilo or {}
	local markerRadius = math.max(6, tonumber(missileConfig.ExplosionRadius) or 18)

	local marker = Instance.new("Part")
	marker.Name = "MissileTargetMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Material = Enum.Material.SmoothPlastic
	marker.Color = Color3.fromRGB(255, 120, 80)
	marker.Transparency = 1
	marker.Size = Vector3.new(markerRadius * 2, 0.06, markerRadius * 2)

	local function addFace(face)
		local gui = Instance.new("SurfaceGui")
		gui.Name = face.Name .. "Gui"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 18
		gui.LightInfluence = 0
		gui.AlwaysOnTop = true
		gui.Parent = marker

		local outerRing = Instance.new("Frame")
		outerRing.Name = "OuterRing"
		outerRing.AnchorPoint = Vector2.new(0.5, 0.5)
		outerRing.Position = UDim2.fromScale(0.5, 0.5)
		outerRing.Size = UDim2.fromScale(0.92, 0.92)
		outerRing.BackgroundTransparency = 1
		outerRing.Parent = gui
		local outerStroke = Instance.new("UIStroke")
		outerStroke.Color = Color3.fromRGB(255, 150, 90)
		outerStroke.Thickness = 3
		outerStroke.Transparency = 0.15
		outerStroke.Parent = outerRing
		local outerCorner = Instance.new("UICorner")
		outerCorner.CornerRadius = UDim.new(1, 0)
		outerCorner.Parent = outerRing

		local innerRing = Instance.new("Frame")
		innerRing.Name = "InnerRing"
		innerRing.AnchorPoint = Vector2.new(0.5, 0.5)
		innerRing.Position = UDim2.fromScale(0.5, 0.5)
		innerRing.Size = UDim2.fromScale(0.6, 0.6)
		innerRing.BackgroundTransparency = 1
		innerRing.Parent = gui
		local innerStroke = Instance.new("UIStroke")
		innerStroke.Color = Color3.fromRGB(255, 220, 170)
		innerStroke.Thickness = 2
		innerStroke.Transparency = 0.35
		innerStroke.Parent = innerRing
		local innerCorner = Instance.new("UICorner")
		innerCorner.CornerRadius = UDim.new(1, 0)
		innerCorner.Parent = innerRing

		for _, data in ipairs({
			{ name = "Top", position = UDim2.fromScale(0.5, 0.12), size = UDim2.fromScale(0.18, 0.025) },
			{ name = "Bottom", position = UDim2.fromScale(0.5, 0.88), size = UDim2.fromScale(0.18, 0.025) },
			{ name = "Left", position = UDim2.fromScale(0.12, 0.5), size = UDim2.fromScale(0.025, 0.18) },
			{ name = "Right", position = UDim2.fromScale(0.88, 0.5), size = UDim2.fromScale(0.025, 0.18) },
		}) do
			local tickMark = Instance.new("Frame")
			tickMark.Name = data.name .. "Tick"
			tickMark.AnchorPoint = Vector2.new(0.5, 0.5)
			tickMark.Position = data.position
			tickMark.Size = data.size
			tickMark.BackgroundColor3 = Color3.fromRGB(255, 140, 80)
			tickMark.BorderSizePixel = 0
			tickMark.Parent = gui
		end

		local centerDot = Instance.new("Frame")
		centerDot.Name = "CenterDot"
		centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
		centerDot.Position = UDim2.fromScale(0.5, 0.5)
		centerDot.Size = UDim2.fromScale(0.055, 0.055)
		centerDot.BackgroundColor3 = Color3.fromRGB(255, 235, 210)
		centerDot.BorderSizePixel = 0
		centerDot.Parent = gui
		local centerCorner = Instance.new("UICorner")
		centerCorner.CornerRadius = UDim.new(1, 0)
		centerCorner.Parent = centerDot

		local pulseRing = Instance.new("Frame")
		pulseRing.Name = "PulseRing"
		pulseRing.AnchorPoint = Vector2.new(0.5, 0.5)
		pulseRing.Position = UDim2.fromScale(0.5, 0.5)
		pulseRing.Size = UDim2.fromScale(0.72, 0.72)
		pulseRing.BackgroundTransparency = 1
		pulseRing.Parent = gui
		local pulseStroke = Instance.new("UIStroke")
		pulseStroke.Color = Color3.fromRGB(255, 193, 133)
		pulseStroke.Thickness = 2
		pulseStroke.Transparency = 0.25
		pulseStroke.Parent = pulseRing
		local pulseCorner = Instance.new("UICorner")
		pulseCorner.CornerRadius = UDim.new(1, 0)
		pulseCorner.Parent = pulseRing
	end

	addFace(Enum.NormalId.Top)
	addFace(Enum.NormalId.Bottom)
	marker.Parent = workspace
	missileTargetVisual = marker
	return marker
end

function module.startMissileTargeting(building)
	if not building or not building.Parent then
		return
	end
	module.destroyMissileTargeting()
	missileTargetBuilding = building
	local marker = ensureMissileTargetVisual()
	missileTargetConn = RunService.RenderStepped:Connect(function()
		local pos = getMissileTargetGroundPoint()
		if pos and marker then
			marker.CFrame = CFrame.new(pos.X, pos.Y + 0.06, pos.Z)
			local pulse = 0.5 + 0.5 * math.sin(tick() * 3.2)
			for _, gui in ipairs(marker:GetChildren()) do
				if gui:IsA("SurfaceGui") then
					local pulseRing = gui:FindFirstChild("PulseRing")
					if pulseRing and pulseRing:IsA("Frame") then
						local scale = 0.68 + (pulse * 0.18)
						pulseRing.Size = UDim2.fromScale(scale, scale)
						local stroke = pulseRing:FindFirstChildOfClass("UIStroke")
						if stroke then
							stroke.Transparency = 0.25 + ((1 - pulse) * 0.45)
						end
					end
				end
			end
		end
	end)
	Training.showQueueError("Left-click to launch missile. Press E or Escape to cancel.")
end

function module.isMissileTargeting()
	return missileTargetBuilding ~= nil and missileTargetBuilding.Parent ~= nil
end

function module.init(options)
	player = options.player
	Config = options.Config
	RunService = options.RunService
	UserInputService = options.UserInputService
	Training = options.Training
	MissileSiloEvent = options.MissileSiloEvent

	if not inspectorInputConn then
		inspectorInputConn = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or not missileTargetBuilding then
				return
			end
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				local pos = getMissileTargetGroundPoint()
				if pos then
					MissileSiloEvent:FireServer("Launch", missileTargetBuilding, pos)
					module.destroyMissileTargeting()
				end
			elseif input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.E then
				module.destroyMissileTargeting()
			end
		end)
	end
end

return module
