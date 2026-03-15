-- GameState (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")

local GameState = {}
GameState.__index = GameState

-- Constants
local MIN_PLAYERS = 1
local INTERMISSION_TIME = 5
local ROUND_TIME = 7200 -- 2 hours

-- Replicated values
local GameActive = ReplicatedStorage:FindFirstChild("GameActive")
local StatusValue = ReplicatedStorage:FindFirstChild("GameStatus")
local TimerValue = ReplicatedStorage:FindFirstChild("GameTimer")

-- Events
local RoundStartEvent = ServerStorage:WaitForChild("RoundStartEvent")
local CheckVictoryEvent = ServerStorage:WaitForChild("CheckVictoryEvent")

function GameState.new()
	local self = setmetatable({}, GameState)
	self.GameActive = GameActive
	self.StatusValue = StatusValue
	self.TimerValue = TimerValue
	self.RoundStartEvent = RoundStartEvent
	self.CheckVictoryEvent = CheckVictoryEvent
	self.Active = false
	self.RoundStartTime = nil
	self.RoundEndTime = nil
	self.IntermissionTimer = nil
	return self
end

function GameState:startRound(mapModel)
	self.Active = true
	self.GameActive.Value = true
	self.RoundStartTime = tick()
	self.RoundEndTime = self.RoundStartTime + ROUND_TIME
	self.StatusValue.Value = "GAME ACTIVE"
	self.RoundStartEvent:Fire(mapModel)
end

function GameState:endRound()
	self.Active = false
	self.GameActive.Value = false
	self.StatusValue.Value = "GAME OVER"

	-- Move all players to lobby
	for _, p in ipairs(Players:GetPlayers()) do
		p.Team = Teams["Lobby"]
		task.spawn(function() p:LoadCharacter() end)
	end
end

function GameState:updateTimer()
	if not self.Active then return end
	local remaining = math.max(0, self.RoundEndTime - tick())
	local h = math.floor(remaining / 3600)
	local m = math.floor((remaining % 3600) / 60)
	local s = remaining % 60
	self.TimerValue.Value = string.format("%02d:%02d:%02d", h, m, s)

	if remaining <= 0 then
		self.StatusValue.Value = "DRAW - TIME LIMIT"
		local hint = Instance.new("Hint", workspace)
		hint.Text = "TIME LIMIT! DRAW!"
		Debris:AddItem(hint, 10)
		task.wait(5)
		self:endRound()
	end
end

function GameState:runIntermission()
	local players = Players:GetPlayers()
	if #players < MIN_PLAYERS then
		self.StatusValue.Value = "WAITING FOR PLAYERS..."
		return false
	end

	for i = INTERMISSION_TIME, 0, -1 do
		self.StatusValue.Value = "STARTING IN: " .. i
		task.wait(1)
		if #Players:GetPlayers() < MIN_PLAYERS then
			self.StatusValue.Value = "WAITING FOR PLAYERS..."
			return false
		end
	end
	return true
end

return GameState