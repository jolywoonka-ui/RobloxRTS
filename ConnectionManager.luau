-- ConnectionManager (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ServerStorage = game:GetService("ServerStorage")
local PlayerStatsManager = require(ServerStorage:WaitForChild("PlayerStatsManager"))

local ConnectionManager = {}
ConnectionManager.__index = ConnectionManager

function ConnectionManager.new(gameState, hqManager, spawnManager, victoryChecker, playerInitializer, factionColors, activePlayerData)
	local self = setmetatable({}, ConnectionManager)
	self.GameState = gameState
	self.HQManager = hqManager
	self.SpawnManager = spawnManager
	self.VictoryChecker = victoryChecker
	self.PlayerInitializer = playerInitializer
	self.FactionColors = factionColors
	self.ActivePlayerData = activePlayerData
	self.CurrentMapModel = nil
	self.onStartRound = nil
	self.MapVoteManager = nil
	return self
end

function ConnectionManager:setCurrentMap(mapModel)
	self.CurrentMapModel = mapModel
end

function ConnectionManager:setupTeams()
	for _, t in pairs(Teams:GetChildren()) do
		t:Destroy()
	end

	local lobby = Instance.new("Team")
	lobby.Name = "Lobby"
	lobby.AutoAssignable = true
	lobby.TeamColor = BrickColor.new("White")
	lobby.Parent = Teams

	for _, col in ipairs(self.FactionColors) do
		local t = Instance.new("Team")
		t.Name = col.Name
		t.AutoAssignable = false
		t.TeamColor = col
		t.Parent = Teams
	end
end

function ConnectionManager:connect()
	local function setLobbyState(player)
		player.Team = Teams["Lobby"]
		player:SetAttribute("AllianceID", nil)
		player:SetAttribute("TeamColor", Color3.fromRGB(128, 128, 128))
	end

	local function assignMidGameFaction(player)
		local index = self.HQManager:getNextAvailableIndex()
		if not index then
			setLobbyState(player)
			return
		end

		local teamColor = self.FactionColors[index] or self.FactionColors[((index - 1) % #self.FactionColors) + 1]
		local team = teamColor and Teams:FindFirstChild(teamColor.Name)
		if not teamColor or not team then
			setLobbyState(player)
			return
		end

		player.Team = team
		player:SetAttribute("AllianceID", teamColor.Name)
		player:SetAttribute("TeamColor", teamColor.Color)

		self.ActivePlayerData[player.UserId] = {
			Team = teamColor.Name,
			SpawnIndex = index,
			JoinedRound = false,
		}

		if not self.HQManager:claimFaction(index, player) then
			warn("Failed to claim faction for", player.Name)
			self.ActivePlayerData[player.UserId] = nil
			setLobbyState(player)
			return
		end

		local spawnPos = nil
		local hq = self.HQManager.HQByIndex[index]
		if not hq then
			spawnPos = self.HQManager:getSpawnPosition(index)
		end

		task.spawn(function()
			player:LoadCharacter()
			local char = player.CharacterAdded:Wait()
			self.SpawnManager:handleSpawn(player, char, spawnPos)
		end)
	end

	local function onPlayerAdded(player)
		PlayerStatsManager.setup(player)

		if self.GameState.Active and self.CurrentMapModel then
			assignMidGameFaction(player)
		else
			local saved = self.ActivePlayerData[player.UserId]
			if saved and saved.JoinedRound and Teams:FindFirstChild(saved.Team) then
				local savedTeam = Teams[saved.Team]
				player.Team = savedTeam
				player:SetAttribute("AllianceID", saved.Team)
				player:SetAttribute("TeamColor", savedTeam.TeamColor.Color)
			else
				player:SetAttribute("TeamColor", Color3.fromRGB(128, 128, 128))
			end
		end

		player.CharacterAdded:Connect(function(char)
			if self.SpawnManager then
				self.SpawnManager:handleSpawn(player, char)
			end
		end)
	end

	for _, p in ipairs(Players:GetPlayers()) do
		onPlayerAdded(p)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)

	Players.PlayerRemoving:Connect(function(player)
		if not self.GameState.Active or not self.CurrentMapModel or not self.HQManager then
			return
		end

		self.HQManager:releaseFaction(player)
		self.ActivePlayerData[player.UserId] = nil
	end)

	ServerStorage.CheckVictoryEvent.Event:Connect(function()
		print("CheckVictoryEvent fired")
		if self.VictoryChecker then
			self.VictoryChecker:check()
		else
			warn("victoryChecker is nil")
		end
	end)

	task.spawn(function()
		while true do
			if not self.GameState.Active then
				if self.GameState:runIntermission() then
					if self.onStartRound then
						local selectedMapTemplate = "IslandMap"
						local selectedMapDisplay = "ISLAND"
						if self.MapVoteManager then
							self.GameState.StatusValue.Value = "MAP VOTE STARTING..."
							local votedTemplate, votedDisplay = self.MapVoteManager:runVote(10)
							selectedMapTemplate = votedTemplate or selectedMapTemplate
							selectedMapDisplay = votedDisplay or selectedMapDisplay
							self.GameState.StatusValue.Value = "WINNER: " .. tostring(selectedMapDisplay)
							task.wait(2)
						end
						self.onStartRound(selectedMapTemplate)
					end
				else
					task.wait(1)
				end
			else
				task.wait(1)
				self.GameState:updateTimer()
			end
		end
	end)
end

return ConnectionManager
