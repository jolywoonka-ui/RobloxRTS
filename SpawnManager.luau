-- SpawnManager (ModuleScript, ServerStorage)
local SpawnManager = {}
SpawnManager.__index = SpawnManager

function SpawnManager.new(mapModel, activePlayerData)
	local self = setmetatable({}, SpawnManager)
	self.MapModel = mapModel
	self.ActivePlayerData = activePlayerData
	return self
end

function SpawnManager:handleSpawn(player, character, overridePosition)
	if not player.Team or player.Team.Name == "Lobby" then return end

	task.wait(0.2)
	if _G.setCollisionGroup then
		_G.setCollisionGroup(character, "Players")
	end

	local data = self.ActivePlayerData[player.UserId]
	if not data then return end

	local spawnIndex = data.SpawnIndex
	if not spawnIndex then return end

	-- Determine spawn position
	local spawnPos = nil
	if overridePosition then
		spawnPos = overridePosition
	else
		local mapInner = self.MapModel:FindFirstChild("Map")
		local spawns = mapInner and mapInner:FindFirstChild("Spawns")
		local spawnPart = spawns and spawns:FindFirstChild("Spawn" .. spawnIndex)

		if not spawnPart then
			for i = 1, 6 do
				local fallback = spawns and spawns:FindFirstChild("Spawn" .. i)
				if fallback then
					spawnPart = fallback
					break
				end
			end
		end

		if spawnPart then
			spawnPos = spawnPart.Position + Vector3.new(0, 5, 0)
		end
	end

	if spawnPos then
		local root = character:WaitForChild("HumanoidRootPart", 5)
		if root then
			root.CFrame = CFrame.new(spawnPos)
		end
	end

	data.JoinedRound = true
end

return SpawnManager