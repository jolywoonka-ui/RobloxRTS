-- BuildingSpawner (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local BuildingsFolder = ReplicatedStorage:WaitForChild("Buildings")
local NodeManager = require(script.Parent:WaitForChild("NodeManager"))

local BuildingSpawner = {}
BuildingSpawner.__index = BuildingSpawner

local function isResearchUnlockedForPlayer(player, researchId)
	if not researchId then
		return true
	end
	if not player then
		return false
	end
	return player:GetAttribute("Research_" .. tostring(researchId)) == true
end

local function getResearchDisplayName(researchId)
	local researchData = Config.Research[researchId]
	return tostring(researchData and researchData.DisplayName or researchId or "RESEARCH")
end

local BLACKLISTED_MATERIALS = {
	[Enum.Material.Rock] = true,
	[Enum.Material.Slate] = true,
	[Enum.Material.Concrete] = true,
	[Enum.Material.Brick] = true,
	[Enum.Material.Glacier] = true,
	[Enum.Material.Sandstone] = true,
	[Enum.Material.ForceField] = true,
}

-- ÃÂ¤Ã‘Æ’ÃÂ½ÃÂºÃ‘â€ ÃÂ¸Ã‘Â ÃÂ¿ÃÂ¾ÃÂºÃ‘â‚¬ÃÂ°Ã‘ÂÃÂºÃÂ¸ ÃÂ² Ã‘â€ ÃÂ²ÃÂµÃ‘â€š ÃÂºÃÂ¾ÃÂ¼ÃÂ°ÃÂ½ÃÂ´Ã‘â€¹
local function applyTeamColor(model, player, baseParts)
	if not player then return end
	local teamColor = player:GetAttribute("TeamColor")
	if not teamColor then return end

	if baseParts then
		for _, part in ipairs(baseParts) do
			if part.Name == "TeamPaint" then
				part.Color = teamColor
			end
		end
	else
		for _, part in pairs(model:GetDescendants()) do
			if part:IsA("BasePart") and part.Name == "TeamPaint" then
				part.Color = teamColor
			end
		end
	end
end

-- ÃÂ¡Ã‘â€šÃÂ°Ã‘â€šÃÂ¸Ã‘â€¡ÃÂµÃ‘ÂÃÂºÃÂ¸ÃÂµ Ã‘â€žÃ‘Æ’ÃÂ½ÃÂºÃ‘â€ ÃÂ¸ÃÂ¸ ÃÂ´ÃÂ»Ã‘Â ÃÂ¸Ã‘ÂÃÂ¿ÃÂ¾ÃÂ»Ã‘Å’ÃÂ·ÃÂ¾ÃÂ²ÃÂ°ÃÂ½ÃÂ¸Ã‘Â ÃÂ² ÃÂ´Ã‘â‚¬Ã‘Æ’ÃÂ³ÃÂ¸Ã‘â€¦ ÃÂ¼ÃÂ¾ÃÂ´Ã‘Æ’ÃÂ»Ã‘ÂÃ‘â€¦
function BuildingSpawner.getGroundHeightStatic(pos)
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
	if #targets == 0 then return pos.Y - 1 end

	local rayOrigin = pos + Vector3.new(0, 200, 0)
	local rayDir = Vector3.new(0, -400, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = targets
	local result = workspace:Raycast(rayOrigin, rayDir, params)
	if result then
		return result.Position.Y
	end
	return pos.Y - 1
end

function BuildingSpawner.getModelLowestYStatic(model)
	local bboxCFrame, bboxSize = model:GetBoundingBox()
	return bboxCFrame.Position.Y - (bboxSize.Y / 2)
end

function BuildingSpawner.getModelBottomOffsetStatic(model)
	local pivotY = model:GetPivot().Position.Y
	local lowestY = BuildingSpawner.getModelLowestYStatic(model)
	return pivotY - lowestY
end

function BuildingSpawner.new(mapModel, nodeManager)
	local self = setmetatable({}, BuildingSpawner)
	self.MapModel = mapModel
	self.NodeManager = nodeManager
	self.PlayerBuildings = mapModel:FindFirstChild("PlayerBuildings", true)
	if not self.PlayerBuildings then
		self.PlayerBuildings = Instance.new("Folder", mapModel)
		self.PlayerBuildings.Name = "PlayerBuildings"
	end
	return self
end

-- Helper: get ground height (ÃÂ¼ÃÂµÃ‘â€šÃÂ¾ÃÂ´ Ã‘ÂÃÂºÃÂ·ÃÂµÃÂ¼ÃÂ¿ÃÂ»Ã‘ÂÃ‘â‚¬ÃÂ°)
function BuildingSpawner:getGroundHeight(pos)
	return BuildingSpawner.getGroundHeightStatic(pos)
end

-- Helper: get lowest Y of a model (ÃÂ¼ÃÂµÃ‘â€šÃÂ¾ÃÂ´ Ã‘ÂÃÂºÃÂ·ÃÂµÃÂ¼ÃÂ¿ÃÂ»Ã‘ÂÃ‘â‚¬ÃÂ°)
function BuildingSpawner:getModelLowestY(model)
	return BuildingSpawner.getModelLowestYStatic(model)
end

function BuildingSpawner:getModelBottomOffset(model)
	return BuildingSpawner.getModelBottomOffsetStatic(model)
end

-- Helper: add health bar to building (Ã‘ÂÃ‘â€šÃÂ°Ã‘â€šÃÂ¸Ã‘â€¡ÃÂµÃ‘ÂÃÂºÃÂ°Ã‘Â)
function BuildingSpawner.addHealthBar(building)
	local hum = building:FindFirstChild("Humanoid")
	if not hum then return end

	local bg = Instance.new("BillboardGui", building)
	bg.Name = "HealthBar"
	bg.Size = UDim2.new(4, 0, 0.5, 0)
	bg.StudsOffset = Vector3.new(0, 4, 0)
	bg.AlwaysOnTop = true
	bg.Enabled = false

	local barBg = Instance.new("Frame", bg)
	barBg.Size = UDim2.new(1, 0, 1, 0)
	barBg.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	barBg.BorderSizePixel = 0
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)

	local stroke = Instance.new("UIStroke", barBg)
	stroke.Color = Color3.new(0.3, 0.3, 0.3)
	stroke.Thickness = 1

	local fill = Instance.new("Frame", barBg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.new(0, 1, 0)
	fill.BorderSizePixel = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local gradient = Instance.new("UIGradient", fill)
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 0))
	}
	gradient.Rotation = 90

	hum.HealthChanged:Connect(function()
		local hp = hum.Health
		local max = hum.MaxHealth
		local p = hp / max
		if hp < max then
			bg.Enabled = true
		else
			bg.Enabled = false
		end
		fill.Size = UDim2.new(p, 0, 1, 0)

		if p < 0.3 then
			gradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 0, 0))
			}
		elseif p < 0.6 then
			gradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 150, 0))
			}
		else
			gradient.Color = ColorSequence.new{
				ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 0))
			}
		end
	end)

	if hum.Health < hum.MaxHealth then
		bg.Enabled = true
	end
end

-- Main spawn function
function BuildingSpawner:spawn(player, name, cframe, isFree)
	local data = Config.Buildings[name]
	if not data then return "Invalid building type" end
	if data.ResearchRequired and not isResearchUnlockedForPlayer(player, data.ResearchRequired) then
		return "Requires research: " .. getResearchDisplayName(data.ResearchRequired)
	end

	local BUILD_RADIUS = 15

	if not isFree and name ~= "Headquarters" then
		local hasAllyNearby = false
		local army = self.MapModel:FindFirstChild("Army")
		if army then
			for _, unit in pairs(army:GetChildren()) do
				if unit:GetAttribute("Owner") == player.Name then
					local dist = (unit:GetPivot().Position - cframe.Position).Magnitude
					if dist < BUILD_RADIUS then
						hasAllyNearby = true
						break
					end
				end
			end
		end
		if not hasAllyNearby then
			local pBuildings = self.MapModel:FindFirstChild("PlayerBuildings")
			if pBuildings then
				for _, b in pairs(pBuildings:GetChildren()) do
					if b:GetAttribute("Owner") == player.Name then
						local dist = (b:GetPivot().Position - cframe.Position).Magnitude
						if dist < BUILD_RADIUS then
							hasAllyNearby = true
							break
						end
					end
				end
			end
		end
		if not hasAllyNearby then
			warn(player.Name, "tried to build", name, "without any ally unit or building nearby")
			return "No ally unit or building nearby"
		end
	end

	-- Resource checks
	local ls = player:FindFirstChild("Stats")
	local ps = player:FindFirstChild("PlayerStats")
	if not ls then
		warn(string.format("BuildingSpawner: Stats folder missing for %s (UserId: %d)", player.Name, player.UserId))
		return "No stats"
	end
	if not ps then
		warn(string.format("BuildingSpawner: PlayerStats folder missing for %s (UserId: %d)", player.Name, player.UserId))
		return "No stats"
	end
	if not isFree and data.Energy < 0 and (ps.Energy.Value + math.abs(data.Energy) > ps.MaxEnergy.Value) then
		return "Not enough energy"
	end
	if not isFree and ls.Credits.Value < data.Cost then
		return "Not enough credits"
	end


	-- Node occupation
	local occupiedNode = nil
	if data.RestrictedNode then
		occupiedNode = self.NodeManager:occupyNode(data.RestrictedNode, player.Name, cframe.Position)
		if not occupiedNode then
			print("No available node for farm at", cframe.Position)
			return "No available node"
		end
	end

	-- Material check
	if not occupiedNode then
		local rayOrigin = cframe.Position + Vector3.new(0, 20, 0)
		local rayDir = Vector3.new(0, -50, 0)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = {}
		local result = workspace:Raycast(rayOrigin, rayDir, params)
		if result and BLACKLISTED_MATERIALS[result.Material] then
			return "Cannot build on " .. result.Material.Name
		end
	end

	-- Create building
	local template = BuildingsFolder:FindFirstChild(name)
	if not template then return "Template not found" end
	local b = template:Clone()
	b.Name = name

	if b:IsA("Model") and not b.PrimaryPart then
		local mainPart = b:FindFirstChildWhichIsA("BasePart")
		if mainPart then
			b.PrimaryPart = mainPart
		end
	end

	-- Determine final position
	local bottomOffset = self:getModelBottomOffset(b)

	local targetX, targetZ, targetY, targetRot
	if occupiedNode then
		targetX = occupiedNode.Position.X
		targetZ = occupiedNode.Position.Z
		local groundY = self:getGroundHeight(occupiedNode.Position)
		targetY = groundY + bottomOffset
		targetRot = cframe.Rotation
	else
		targetX = cframe.X
		targetZ = cframe.Z
		local groundY = self:getGroundHeight(cframe.Position)
		targetY = groundY + bottomOffset
		targetRot = cframe.Rotation
	end

	local finalPos = Vector3.new(targetX, targetY, targetZ)
	local modelRotation = b:GetPivot().Rotation
	local finalCF = CFrame.new(finalPos) * targetRot * modelRotation
	b:PivotTo(finalCF)

	local baseParts = {}
	for _, p in pairs(b:GetDescendants()) do
		if p:IsA("BasePart") then
			table.insert(baseParts, p)
		end
	end

	-- Apply team color
	applyTeamColor(b, player, baseParts)

	b:SetAttribute("Owner", player.Name)
	b:SetAttribute("Type", name)
	b:SetAttribute("MaxHealth", data.Health)
	b:SetAttribute("Selling", false)
	if occupiedNode then
		b:SetAttribute("OccupiedNodeID", occupiedNode:GetAttribute("NodeID"))
		b:SetAttribute("OccupiedNodeName", occupiedNode.Name)
		b:SetAttribute("OccupiedNodePos", occupiedNode.Position)
	end
	if data.Damage then b:SetAttribute("Damage", data.Damage) end
	if data.Range then b:SetAttribute("Range", data.Range) end
	if data.AttackCooldown then b:SetAttribute("AttackCooldown", data.AttackCooldown) end
	if name == "Headquarters" or name == "HeadquartersL2" then
		b:SetAttribute("BaseDamage", data.Damage or 0)
		b:SetAttribute("BaseRange", data.Range or 0)
		b:SetAttribute("HQRangeMode", "Balanced")
		b:SetAttribute("HQRangeCooldownUntil", 0)
	end
	b:SetAttribute("BuildRequiredProgress", data.BuildRequirement or 100)
	if data.MissileCapacity then
		b:SetAttribute("MissileCapacity", data.MissileCapacity)
		b:SetAttribute("StoredMissiles", 0)
	end
	if data.ConnectsWalls then
		b:SetAttribute("ConnectsWalls", true)
		b:SetAttribute("TowerID", HttpService:GenerateGUID(false))
	end

	local reservedEnergy = false
	if not isFree and data.Energy < 0 then
		ps.Energy.Value += math.abs(data.Energy)
		reservedEnergy = true
	end
	b:SetAttribute("EnergyReserved", reservedEnergy)

	local isInstant = (name == "Headquarters")
	if isInstant then
		b:SetAttribute("Health", data.Health)
		b:SetAttribute("Progress", 100)
		b:SetAttribute("IsUnderConstruction", false)
	else
		b:SetAttribute("Health", 100)
		b:SetAttribute("Progress", 0)
		b:SetAttribute("BuildRequiredProgress", data.BuildRequirement or 100)
		b:SetAttribute("IsUnderConstruction", true)
		b:SetAttribute("FinalY", b:GetPivot().Position.Y)
		for _, p in ipairs(baseParts) do
			p.Transparency = 0.8
			p.CanCollide = false
		end
	end

	local hum = b:FindFirstChild("Humanoid") or Instance.new("Humanoid", b)
	hum.MaxHealth = data.Health
	hum.Health = isInstant and data.Health or 100
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer

	for _, p in ipairs(baseParts) do
		p.Anchored = true
		if _G.setCollisionGroup then
			_G.setCollisionGroup(b, "Buildings")
		else
			p.CollisionGroup = "Default"
		end
	end

	BuildingSpawner.addHealthBar(b)

	if not isInstant then
		local _, sizeBox = b:GetBoundingBox()
		local bg = Instance.new("BillboardGui", b)
		bg.Name = "BuildProgressUI"
		bg.Size = UDim2.new(5, 0, 0.6, 0)
		bg.StudsOffset = Vector3.new(0, sizeBox.Y/2 + 2, 0)
		bg.MaxDistance = 80
		bg.AlwaysOnTop = true

		local barBg = Instance.new("Frame", bg)
		barBg.Size = UDim2.new(1, 0, 0.4, 0)
		barBg.BackgroundColor3 = Color3.new(0, 0, 0)
		barBg.BorderSizePixel = 0
		Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)

		local stroke = Instance.new("UIStroke", barBg)
		stroke.Color = Color3.new(0.3, 0.3, 0.3)
		stroke.Thickness = 1

		local bar = Instance.new("Frame", barBg)
		bar.Name = "Bar"
		bar.Size = UDim2.new(0, 0, 1, 0)
		bar.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
		bar.BorderSizePixel = 0
		Instance.new("UICorner", bar).CornerRadius = UDim.new(0, 4)

		local grad = Instance.new("UIGradient", bar)
		grad.Color = ColorSequence.new{
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 200, 100)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 0))
		}
		grad.Rotation = 90
	end

	b.Parent = self.PlayerBuildings

	if not isFree then
		ls.Credits.Value -= data.Cost
		ps.MoneySpent.Value = ps.MoneySpent.Value + data.Cost
	end

	if isInstant then
		if data.Income then ps.Income.Value += data.Income end
		if data.Energy > 0 then
			ps.MaxEnergy.Value += data.Energy
		elseif data.Energy < 0 then
			if not reservedEnergy then
				ps.Energy.Value += math.abs(data.Energy)
			end
		end
		if data.UnitLimit then ps.UnitLimit.Value += data.UnitLimit end
	end

	return "Success", b
end

return BuildingSpawner





