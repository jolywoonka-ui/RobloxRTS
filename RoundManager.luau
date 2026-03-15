-- RoundManager (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local PlayerStatsManager = require(ServerStorage:WaitForChild("PlayerStatsManager"))

local RoundManager = {}
RoundManager.__index = RoundManager

function RoundManager.new(gameState, mapInitializer, playerInitializer, hqManager, spawnManager, victoryChecker)
	local self = setmetatable({}, RoundManager)
	self.GameState = gameState
	self.MapInitializer = mapInitializer
	self.PlayerInitializer = playerInitializer
	self.HQManager = hqManager
	self.SpawnManager = spawnManager
	self.VictoryChecker = victoryChecker
	return self
end

function RoundManager:startRound(mapTemplateName)
	print("startRound called")
	self.GameState.StatusValue.Value = "LOADING MAP..."

	-- Destroy previous map if it exists
	local oldMap = self.MapInitializer:getCurrentMap()
	if oldMap then
		oldMap:Destroy()
	end

	-- Load new map
	local map = self.MapInitializer:loadMap(mapTemplateName or "IslandMap")
	if not map then return end

	-- Update managers with the new map
	self.HQManager.MapModel = map
	self.SpawnManager.MapModel = map
	self.VictoryChecker.MapModel = map

	task.wait(1)

	-- Get current players
	local players = Players:GetPlayers()

	-- Assign teams and spawns
	self.PlayerInitializer:assignTeamsAndSpawns(players)

	-- Set TeamColor for all players
	for _, p in ipairs(players) do
		if p.Team and p.Team.Name ~= "Lobby" then
			p:SetAttribute("TeamColor", p.Team.TeamColor.Color)
		else
			p:SetAttribute("TeamColor", Color3.fromRGB(128, 128, 128))
		end
	end

	-- Reset player stats
	for _, p in ipairs(players) do
		PlayerStatsManager.reset(p)
	end

	-- Initialize HQManager and assign HQs
	self.HQManager:scanHQs()
	self.HQManager:assignInitialHQs(self.PlayerInitializer.ActivePlayerData)

	-- Spawn two builders for each player at their HQ
	local pBuildings = self.MapInitializer:getPlayerBuildings()
	if pBuildings then
		for _, player in ipairs(players) do
			if player.Team and player.Team.Name ~= "Lobby" then
				for _, hq in pairs(pBuildings:GetChildren()) do
					if hq.Name:match("^Headquarter") and hq:GetAttribute("Owner") == player.Name then
						ServerStorage.SpawnUnitEvent:Fire(player, hq, "Builder")
						ServerStorage.SpawnUnitEvent:Fire(player, hq, "Builder")
						break
					end
				end
			end
		end
	end

	-- Start the game
	self.GameState:startRound(map)

	-- Spawn neutral builders for unclaimed HQs after a delay
	task.spawn(function()
		task.wait(8)
		local pBuildings = self.MapInitializer:getPlayerBuildings()
		if pBuildings then
			for _, hq in pairs(pBuildings:GetChildren()) do
				if hq.Name:match("^Headquarter") and not hq:GetAttribute("Owner") then
					ServerStorage.SpawnNeutralUnitEvent:Fire(hq, "Builder")
					task.wait(0.3)
					ServerStorage.SpawnNeutralUnitEvent:Fire(hq, "Builder")
				end
			end
		end
	end)
end

return RoundManager
