-- PhysicsManager (Script, ServerScriptService)
local PhysicsService = game:GetService("PhysicsService")
local Players = game:GetService("Players")

local function setupGroups()
	local groups = {"Units", "Buildings", "Players", "Walls", "AirUnits"}

	for _, g in ipairs(groups) do
		pcall(function() PhysicsService:RegisterCollisionGroup(g) end)
	end

	PhysicsService:CollisionGroupSetCollidable("Players", "Buildings", false)
	PhysicsService:CollisionGroupSetCollidable("Players", "Units", false)

	PhysicsService:CollisionGroupSetCollidable("Units", "Buildings", true)  -- был false
	PhysicsService:CollisionGroupSetCollidable("Units", "Units", false)

	PhysicsService:CollisionGroupSetCollidable("Walls", "Units", true)
	PhysicsService:CollisionGroupSetCollidable("Walls", "Players", true)
	PhysicsService:CollisionGroupSetCollidable("Walls", "Buildings", false)
	PhysicsService:CollisionGroupSetCollidable("Walls", "Walls", false)

	PhysicsService:CollisionGroupSetCollidable("AirUnits", "Units", false)
	PhysicsService:CollisionGroupSetCollidable("AirUnits", "Buildings", false)
	PhysicsService:CollisionGroupSetCollidable("AirUnits", "Players", false)
	PhysicsService:CollisionGroupSetCollidable("AirUnits", "Walls", false)
end

setupGroups()

local collisionPartsCache = setmetatable({}, { __mode = "k" })

function _G.setCollisionGroup(model, groupName)
	if not model then return end

	local parts = collisionPartsCache[model]
	if not parts then
		parts = {}
		for _, part in pairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
		collisionPartsCache[model] = parts
	end

	for _, part in ipairs(parts) do
		pcall(function() part.CollisionGroup = groupName end)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		char:WaitForChild("HumanoidRootPart")
		_G.setCollisionGroup(char, "Players")
		char.DescendantAdded:Connect(function(part)
			if part:IsA("BasePart") then
				pcall(function() part.CollisionGroup = "Players" end)
			end
		end)
	end)
end)