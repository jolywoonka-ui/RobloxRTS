-- GameManager (Script, ServerScriptService)
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local Teams = game:GetService("Teams")

-- Ensure remotes
local function ensureRemote(name, className, parent)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

ensureRemote("MoveCommand", "RemoteEvent", ReplicatedStorage)
ensureRemote("AttackEffect", "RemoteEvent", ReplicatedStorage)
ensureRemote("BuildEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("SellEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("UnitEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("StartBuild", "BindableEvent", ReplicatedStorage)
ensureRemote("GameActive", "BoolValue", ReplicatedStorage)
ensureRemote("GameStatus", "StringValue", ReplicatedStorage)
ensureRemote("GameTimer", "StringValue", ReplicatedStorage)
ensureRemote("ShowVictory", "RemoteEvent", ReplicatedStorage)
ensureRemote("RoundStartEvent", "BindableEvent", ServerStorage)
ensureRemote("ForceBuildEvent", "BindableEvent", ServerStorage)
ensureRemote("SpawnUnitEvent", "BindableEvent", ServerStorage)
ensureRemote("SpawnNeutralUnitEvent", "BindableEvent", ServerStorage)
ensureRemote("CheckVictoryEvent", "BindableEvent", ServerStorage)
ensureRemote("ShowVictoryStats", "RemoteEvent", ReplicatedStorage)
ensureRemote("BuildWall", "RemoteEvent", ReplicatedStorage)
ensureRemote("WallMessage", "RemoteEvent", ReplicatedStorage)
ensureRemote("DeleteUnit", "RemoteEvent", ReplicatedStorage)
ensureRemote("LoadTransport", "RemoteEvent", ReplicatedStorage)
ensureRemote("UpgradeEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("BunkerEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("PingEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("WorldEffectEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("MissileSiloEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("HeadquartersControlEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("MapVoteEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("ResearchEvent", "RemoteEvent", ReplicatedStorage)
ensureRemote("ChangeHQDefenseMode", "RemoteEvent", ReplicatedStorage)
ensureRemote("QueueBuilder", "RemoteEvent", ReplicatedStorage)
ensureRemote("StartResearch", "RemoteEvent", ReplicatedStorage)
ensureRemote("DiplomacyInvite", "RemoteEvent", ReplicatedStorage)
ensureRemote("DiplomacyRespond", "RemoteEvent", ReplicatedStorage)
ensureRemote("DiplomacyUpdate", "RemoteEvent", ReplicatedStorage)

-- Require modules
local GameStateModule = require(ServerStorage:WaitForChild("GameState"))
local HQManagerModule = require(ServerStorage:WaitForChild("HQManager"))
local VictoryCheckerModule = require(ServerStorage:WaitForChild("VictoryChecker"))
local SpawnManagerModule = require(ServerStorage:WaitForChild("SpawnManager"))
local PlayerStatsManager = require(ServerStorage:WaitForChild("PlayerStatsManager"))
local MapInitializer = require(ServerStorage:WaitForChild("MapInitializer"))
local PlayerInitializer = require(ServerStorage:WaitForChild("PlayerInitializer"))
local RoundManager = require(ServerStorage:WaitForChild("RoundManager"))
local ConnectionManager = require(ServerStorage:WaitForChild("ConnectionManager"))
local WallManager = require(ServerStorage:WaitForChild("WallManager"))
local MapVoteManager = require(ServerStorage:WaitForChild("MapVoteManager"))

-- Constants
local factionColors = {
	BrickColor.new("Bright red"),
	BrickColor.new("Bright blue"),
	BrickColor.new("Earth green"),
	BrickColor.new("Bright yellow"),
	BrickColor.new("Cyan"),
	BrickColor.new("Magenta")
}

-- State
local gameState = GameStateModule.new()
_G.gameState = gameState
local activePlayerData = {}
local currentMapModel = nil
local hqManager = nil
local spawnManager = nil
local victoryChecker = nil
local mapInitializer = nil
local playerInitializer = nil
local roundManager = nil
local connectionManager = nil
local mapVoteManager = nil

-- Helper functions (addHealthBar, destroyHQ, setupDeathHandler, setupBuilding)
local function addHealthBar(building)
	local hum = building:FindFirstChild("Humanoid")
	if not hum then return end

	local old = building:FindFirstChild("HealthBar")
	if old then old:Destroy() end

	local bg = Instance.new("BillboardGui", building)
	bg.Name = "HealthBar"
	bg.Size = UDim2.new(4, 0, 0.5, 0)
	bg.StudsOffset = Vector3.new(0, 4, 0)
	bg.AlwaysOnTop = true
	bg.Enabled = false

	local barBg = Instance.new("Frame", bg)
	barBg.Size = UDim2.new(1, 0, 1, 0)
	barBg.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
	barBg.BorderSizePixel = 0

	local fill = Instance.new("Frame", barBg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.new(0, 1, 0)
	fill.BorderSizePixel = 0

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
			fill.BackgroundColor3 = Color3.new(1, 0, 0)
		elseif p < 0.6 then
			fill.BackgroundColor3 = Color3.fromRGB(255, 200, 50)
		else
			fill.BackgroundColor3 = Color3.new(0, 1, 0)
		end
	end)

	if hum.Health < hum.MaxHealth then
		bg.Enabled = true
	end
end

local function destroyHQ(hq)
	if not hq.Parent or hq:GetAttribute("Selling") then return end
	print("destroyHQ called for", hq.Name)

	local owner = hq:GetAttribute("Owner")
	if owner then
		local player = Players:FindFirstChild(owner)
		if player then
			local ps = player:FindFirstChild("PlayerStats")
			if ps then ps.CanBuild.Value = 0 end
			print(owner, "lost HQ")
		end
	end

	local index = tonumber(hq.Name:match("%d+$"))
	if index and hqManager then
		hqManager:onHQDestroyed(index)
	end

	local exp = Instance.new("Explosion")
	exp.Position = hq:GetPivot().Position
	exp.BlastRadius = 0
	exp.Parent = workspace

	task.wait(0.2)
	hq:Destroy()
	print("HQ destroyed:", hq.Name)
	ServerStorage.CheckVictoryEvent:Fire()
end

local function setupDeathHandler(building)
	local hum = building:FindFirstChild("Humanoid")
	if not hum then return end

	hum.Died:Once(function()
		print("Humanoid Died event for", building.Name)
		destroyHQ(building)
	end)

	building:GetAttributeChangedSignal("Health"):Connect(function()
		local health = building:GetAttribute("Health")
		if health and health <= 0 and building.Parent then
			print("Health attribute <= 0 for", building.Name)
			if hum and hum.Health > 0 then
				hum.Health = 0
			else
				destroyHQ(building)
			end
		end
	end)
end

local function setupBuilding(building)
	addHealthBar(building)
	setupDeathHandler(building)
end

-- Initialize modules
mapInitializer = MapInitializer.new(ServerStorage, setupBuilding)
playerInitializer = PlayerInitializer.new(factionColors, activePlayerData)

hqManager = HQManagerModule.new(nil, setupBuilding)
_G.hqManager = hqManager   -- ÃƒÂ¢Ã…â€œÃ¢â‚¬Â¦ now set after creation

spawnManager = SpawnManagerModule.new(nil, activePlayerData)
victoryChecker = VictoryCheckerModule.new(nil, gameState)

roundManager = RoundManager.new(gameState, mapInitializer, playerInitializer, hqManager, spawnManager, victoryChecker)
mapVoteManager = MapVoteManager.new(ServerStorage)
connectionManager = ConnectionManager.new(gameState, hqManager, spawnManager, victoryChecker, playerInitializer, factionColors, activePlayerData)
connectionManager.MapVoteManager = mapVoteManager

-- Set up connection manager with a callback to start round
connectionManager.onStartRound = function(selectedMapTemplate)
	roundManager:startRound(selectedMapTemplate)
	local map = mapInitializer:getCurrentMap()
	connectionManager:setCurrentMap(map)

	-- Connect BuildWall remote (now using the WallManager)
	-- Inside GameManager, after connectionManager.onStartRound = function()
	ReplicatedStorage.BuildWall.OnServerEvent:Connect(function(player, towerA, towerB)
		if not towerA or not towerB then return end
		if towerA:GetAttribute("Owner") ~= player.Name or towerB:GetAttribute("Owner") ~= player.Name then
			ReplicatedStorage.WallMessage:FireClient(player, "You don't own both towers")
			return
		end
		-- NEW: Check if either tower is under construction
		if towerA:GetAttribute("IsUnderConstruction") or towerB:GetAttribute("IsUnderConstruction") then
			ReplicatedStorage.WallMessage:FireClient(player, "Towers must be fully built")
			return
		end
		if WallManager.hasWall(towerA, towerB) then
			WallManager.removeWall(towerA, towerB)
			ReplicatedStorage.WallMessage:FireClient(player, "Wall removed")
		else
			local success, msg = WallManager.createWall(towerA, towerB, player)
			if success then
				ReplicatedStorage.WallMessage:FireClient(player, "Wall created")
			else
				ReplicatedStorage.WallMessage:FireClient(player, msg or "Cannot create wall")
			end
		end
	end)
end

connectionManager:setupTeams()
connectionManager:connect()
