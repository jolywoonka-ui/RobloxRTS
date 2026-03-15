-- benchmark_mouse_handler.lua
-- We will simulate a workspace with a map and player buildings.
-- Then we will benchmark getOwnedBuildingsOfType before and after optimization.
local os = require("os")

-- Mock Roblox objects
local function createInstance(className, name)
	local attrs = {}
	local children = {}
	local obj = {
		Name = name,
		ClassName = className,
		IsA = function(self, cls) return self.ClassName == cls end,
		GetAttribute = function(self, key) return attrs[key] end,
		SetAttribute = function(self, key, value) attrs[key] = value end,
		GetDescendants = function(self)
			local result = {}
			local function traverse(node)
				for _, child in ipairs(node:GetChildren()) do
					table.insert(result, child)
					traverse(child)
				end
			end
			traverse(self)
			return result
		end,
		GetChildren = function(self) return children end,
		FindFirstChild = function(self, childName)
			for _, child in ipairs(children) do
				if child.Name == childName then return child end
			end
			return nil
		end,
		AddChild = function(self, child)
			table.insert(children, child)
			child.Parent = self
		end
	}
	return obj
end

local workspace = createInstance("Workspace", "Workspace")
local currentMap = createInstance("Folder", "CurrentMap")
workspace:AddChild(currentMap)
local playerBuildings = createInstance("Folder", "PlayerBuildings")
currentMap:AddChild(playerBuildings)

-- Add 5000 mock buildings
for i = 1, 5000 do
	local b = createInstance("Model", "Building" .. i)
	if i % 3 == 0 then
		b:SetAttribute("Type", "Barracks")
		b:SetAttribute("Owner", "Player1")
	elseif i % 3 == 1 then
		b:SetAttribute("Type", "PowerPlant")
		b:SetAttribute("Owner", "Player2")
	else
		b:SetAttribute("Type", "Barracks")
		b:SetAttribute("Owner", "Player2")
	end

	-- Add some nested parts to increase GetDescendants cost
	for j = 1, 5 do
		local p = createInstance("Part", "Part" .. j)
		b:AddChild(p)
	end

	playerBuildings:AddChild(b)
end

-- Mock player
local player = { Name = "Player1" }

-- Original implementation
local function getOwnedBuildingsOfType_Original(buildingType)
	local list = {}
	local map = workspace:FindFirstChild("CurrentMap")
	local container = map and map:FindFirstChild("PlayerBuildings")
	if not container then
		return list
	end

	for _, inst in ipairs(container:GetDescendants()) do
		if inst:IsA("Model") and inst:GetAttribute("Type") == buildingType and inst:GetAttribute("Owner") == player.Name then
			table.insert(list, inst)
		end
	end
	return list
end

-- Optimized implementation
-- Instead of GetDescendants, we just use GetChildren because playerBuildings directly contains the buildings.
local function getOwnedBuildingsOfType_Optimized(buildingType)
	local list = {}
	local map = workspace:FindFirstChild("CurrentMap")
	local container = map and map:FindFirstChild("PlayerBuildings")
	if not container then
		return list
	end

	-- Buildings are directly under container, no need for GetDescendants
	for _, inst in ipairs(container:GetChildren()) do
		if inst:IsA("Model") and inst:GetAttribute("Type") == buildingType and inst:GetAttribute("Owner") == player.Name then
			table.insert(list, inst)
		end
	end
	return list
end

print("Benchmarking Original...")
local start = os.clock()
for i = 1, 100 do
	getOwnedBuildingsOfType_Original("Barracks")
end
local time_orig = os.clock() - start
print("Original time: " .. tostring(time_orig))

print("Benchmarking Optimized...")
start = os.clock()
for i = 1, 100 do
	getOwnedBuildingsOfType_Optimized("Barracks")
end
local time_opt = os.clock() - start
print("Optimized time: " .. tostring(time_opt))

print("Improvement: " .. tostring(math.floor((time_orig - time_opt) / time_orig * 100)) .. "%")
