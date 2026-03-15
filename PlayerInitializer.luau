-- PlayerInitializer (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

local PlayerInitializer = {}
PlayerInitializer.__index = PlayerInitializer

function PlayerInitializer.new(factionColors, activePlayerData)
	local self = setmetatable({}, PlayerInitializer)
	self.FactionColors = factionColors
	self.ActivePlayerData = activePlayerData
	return self
end

function PlayerInitializer:shuffleArray(arr)
	local result = {}
	for i = 1, #arr do
		result[i] = arr[i]
	end
	for i = #result, 2, -1 do
		local j = math.random(i)
		result[i], result[j] = result[j], result[i]
	end
	return result
end

function PlayerInitializer:assignTeamsAndSpawns(players)
	local availableSpawns = {}
	for i = 1, math.min(#self.FactionColors, 6) do
		table.insert(availableSpawns, i)
	end
	availableSpawns = self:shuffleArray(availableSpawns)

	for i, p in ipairs(players) do
		if i <= #self.FactionColors then
			local spawnIndex = availableSpawns[i] or (i % 6) + 1
			local teamColor = self.FactionColors[spawnIndex]
			p.Team = Teams[teamColor.Name]

			self.ActivePlayerData[p.UserId] = {
				Team = teamColor.Name,
				SpawnIndex = spawnIndex,
				JoinedRound = false
			}
			task.spawn(function() p:LoadCharacter() end)
		else
			p.Team = Teams["Lobby"]
		end
	end
end

function PlayerInitializer:getSpawnIndexForPlayer(player)
	local data = self.ActivePlayerData[player.UserId]
	return data and data.SpawnIndex
end

return PlayerInitializer