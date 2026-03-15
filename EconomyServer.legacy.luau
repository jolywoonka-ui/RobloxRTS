-- EconomyServer (Script, ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local BuildEvent = ReplicatedStorage:WaitForChild("BuildEvent")
local SellEvent = ReplicatedStorage:WaitForChild("SellEvent")
local PingEvent = ReplicatedStorage:WaitForChild("PingEvent")
local MissileSiloEvent = ReplicatedStorage:WaitForChild("MissileSiloEvent")
local HeadquartersControlEvent = ReplicatedStorage:FindFirstChild("HeadquartersControlEvent")
local ResearchEvent = ReplicatedStorage:FindFirstChild("ResearchEvent")
local RoundStartEvent = ServerStorage:WaitForChild("RoundStartEvent")
local ForceBuildEvent = ServerStorage:WaitForChild("ForceBuildEvent")

local function findModule(container: Instance?, name: string): ModuleScript?
	if not container then
		return nil
	end
	local directChild = container:FindFirstChild(name)
	if directChild and directChild:IsA("ModuleScript") then
		return directChild
	end
	local nestedChild = container:FindFirstChild(name, true)
	if nestedChild and nestedChild:IsA("ModuleScript") then
		return nestedChild
	end
	return nil
end

local function requireServerModule(name, optional)
	local moduleScript = findModule(ServerStorage, name)
		or findModule(script.Parent, name)
		or findModule(ReplicatedStorage, name)
	if not moduleScript then
		if optional then
			return nil
		end
		assert(false, "Missing server module: " .. name)
	end
	return require(moduleScript)
end

local NodeManager = requireServerModule("NodeManager")
local BuildingSpawner = requireServerModule("BuildingSpawner")
local BuildingDeathHandler = requireServerModule("BuildingDeathHandler")
local BuildingSellHandler = requireServerModule("BuildingSellHandler")
local EconomyManager = requireServerModule("EconomyManager")
local UpgradeManager = requireServerModule("UpgradeManager")
local BunkerManager = requireServerModule("BunkerManager")
local ResearchManager = requireServerModule("ResearchManager")
local SuperWeaponManager = requireServerModule("SuperWeaponManager", true)
if not SuperWeaponManager then
	SuperWeaponManager = {}
	function SuperWeaponManager.new()
		return {
			broadcastPing = function() end,
			launchMissile = function()
				return false, "Superweapon system unavailable"
			end,
			tick = function() end,
		}
	end
	warn("EconomyServer: SuperWeaponManager module not found, disabling pings and missile silo")
end

local CurrentMap = nil
local nodeManager = nil
local buildingSpawner = nil
local deathHandler = nil
local sellHandler = nil
local economyManager = nil
local upgradeManager = nil
local bunkerManager = nil
local superWeaponManager = nil
local hqManager = nil
local researchManager = nil

local playerBuildingsCount = {}

Players.PlayerAdded:Connect(function(player)
	playerBuildingsCount[player.UserId] = {}
end)

Players.PlayerRemoving:Connect(function(player)
	playerBuildingsCount[player.UserId] = nil
end)

local UpgradeEvent = ReplicatedStorage:FindFirstChild("UpgradeEvent")
if not UpgradeEvent then
	UpgradeEvent = Instance.new("RemoteEvent")
	UpgradeEvent.Name = "UpgradeEvent"
	UpgradeEvent.Parent = ReplicatedStorage
end

local BunkerEvent = ReplicatedStorage:FindFirstChild("BunkerEvent")
if not BunkerEvent then
	BunkerEvent = Instance.new("RemoteEvent")
	BunkerEvent.Name = "BunkerEvent"
	BunkerEvent.Parent = ReplicatedStorage
end

local WallMessage = ReplicatedStorage:FindFirstChild("WallMessage")
if not WallMessage then
	WallMessage = Instance.new("RemoteEvent")
	WallMessage.Name = "WallMessage"
	WallMessage.Parent = ReplicatedStorage
end

if not HeadquartersControlEvent then
	HeadquartersControlEvent = Instance.new("RemoteEvent")
	HeadquartersControlEvent.Name = "HeadquartersControlEvent"
	HeadquartersControlEvent.Parent = ReplicatedStorage
end

if not ResearchEvent then
	ResearchEvent = Instance.new("RemoteEvent")
	ResearchEvent.Name = "ResearchEvent"
	ResearchEvent.Parent = ReplicatedStorage
end

local HQ_RANGE_MODES = {
	Close = {Range = 6, Damage = 20},
	Balanced = {Range = 8, Damage = 15},
	Long = {Range = 10, Damage = 10},
}

local HQ_RANGE_MODE_NAMES = {
	Close = true,
	Balanced = true,
	Long = true,
}

local HQ_RANGE_COOLDOWN = 180

local function applyHQRangeMode(building, modeName)
	local bType = building:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	if not bData then
		return false, "Invalid headquarters"
	end

	local modeData = HQ_RANGE_MODES[modeName]
	if not modeData then
		return false, "Invalid range mode"
	end

	local currentMode = tostring(building:GetAttribute("HQRangeMode") or "Balanced")
	if currentMode == modeName then
		return false, "That mode is already active"
	end

	building:SetAttribute("Range", modeData.Range)
	building:SetAttribute("Damage", modeData.Damage)
	building:SetAttribute("HQRangeMode", modeName)
	building:SetAttribute("HQRangeCooldownUntil", workspace:GetServerTimeNow() + HQ_RANGE_COOLDOWN)

	return true
end

RoundStartEvent.Event:Connect(function(map)
	CurrentMap = map
	hqManager = _G.hqManager

	nodeManager = NodeManager.new(map)
	nodeManager:scanNodes()

	buildingSpawner = BuildingSpawner.new(map, nodeManager)
	deathHandler = BuildingDeathHandler.new(nodeManager)
	sellHandler = BuildingSellHandler.new(nodeManager, playerBuildingsCount)
	economyManager = EconomyManager.new(map, hqManager)
	economyManager:start()

	upgradeManager = UpgradeManager.new(map)
	bunkerManager = BunkerManager.new(map)
	superWeaponManager = SuperWeaponManager.new(map)
	researchManager = ResearchManager.new(hqManager, ResearchEvent)
	researchManager:beginRound(hqManager)

	for _, p in ipairs(Players:GetPlayers()) do
		playerBuildingsCount[p.UserId] = {}
		local ls = p:FindFirstChild("Stats")
		local ps = p:FindFirstChild("PlayerStats")
		if ls and ps then
			ls.Credits.Value = 2000
			ps.Income.Value = Config.BaseIncome or 10
			ps.Energy.Value = 0
			ps.MaxEnergy.Value = Config.BaseEnergy or 100
			ps.UnitLimit.Value = Config.BaseUnitLimit or 10
			ps.CanBuild.Value = 1
		end
	end

	print("EconomyServer initialized for round")
end)

BuildEvent.OnServerEvent:Connect(function(player, action, name, cframe)
	if type(name) ~= "string" or typeof(cframe) ~= "CFrame" then return end
	if action == "Build" then
		local result = buildingSpawner:spawn(player, name, cframe, false)
		if result == "Success" then
			if not playerBuildingsCount[player.UserId][name] then
				playerBuildingsCount[player.UserId][name] = 0
			end
			playerBuildingsCount[player.UserId][name] += 1
		else
			warn("Build failed:", result)
			if WallMessage then
				WallMessage:FireClient(player, result)
			end
		end
	end
end)

ForceBuildEvent.Event:Connect(function(player, name, cframe)
	local result = buildingSpawner:spawn(player, name, cframe, true)
	if result == "Success" then
		if not playerBuildingsCount[player.UserId][name] then
			playerBuildingsCount[player.UserId][name] = 0
		end
		playerBuildingsCount[player.UserId][name] += 1
	end
end)

SellEvent.OnServerEvent:Connect(function(player, building)
	if typeof(building) ~= "Instance" then return end
	sellHandler:sell(player, building)
end)

UpgradeEvent.OnServerEvent:Connect(function(player, buildingOrList)
	if not upgradeManager then return end
	if typeof(buildingOrList) ~= "Instance" and type(buildingOrList) ~= "table" then return end

	local function tryUpgradeOne(building)
		if typeof(building) ~= "Instance" then
			return false, "Invalid building"
		end
		local result = upgradeManager:startUpgrade(player, building)
		return result == "Success", result
	end

	if typeof(buildingOrList) == "table" then
		if #buildingOrList > 100 then return end
		local anySuccess = false
		local lastError = nil
		for _, building in ipairs(buildingOrList) do
			if typeof(building) ~= "Instance" then continue end
			local ok, result = tryUpgradeOne(building)
			if ok then
				anySuccess = true
			else
				lastError = result
			end
		end
		if not anySuccess and lastError and WallMessage then
			WallMessage:FireClient(player, lastError)
		end
		return
	end

	local ok, result = tryUpgradeOne(buildingOrList)
	if not ok and WallMessage then
		WallMessage:FireClient(player, result)
	end
end)

BunkerEvent.OnServerEvent:Connect(function(player, bunker, action)
	if typeof(bunker) ~= "Instance" then return end
	if type(action) ~= "string" and action ~= nil then return end
	bunkerManager:toggle(bunker, player)
end)

PingEvent.OnServerEvent:Connect(function(player, worldPos)
	if typeof(worldPos) ~= "Vector3" then return end
	if superWeaponManager then
		superWeaponManager:broadcastPing(player, worldPos)
	end
end)

MissileSiloEvent.OnServerEvent:Connect(function(player, action, silo, targetPos)
	if typeof(silo) ~= "Instance" or typeof(targetPos) ~= "Vector3" then return end
	if action ~= "Launch" or not superWeaponManager then
		return
	end
	local ok, result = superWeaponManager:launchMissile(player, silo, targetPos)
	if not ok and WallMessage then
		WallMessage:FireClient(player, result)
	end
end)

HeadquartersControlEvent.OnServerEvent:Connect(function(player, action, building, payload)
	if action ~= "SetRangeMode" then
		return
	end
	if typeof(building) ~= "Instance" or not building.Parent then
		return
	end
	if building:GetAttribute("Owner") ~= player.Name then
		if WallMessage then
			WallMessage:FireClient(player, "Not your headquarters")
		end
		return
	end

	local bType = building:GetAttribute("Type")
	if bType ~= "Headquarters" and bType ~= "HeadquartersL2" then
		if WallMessage then
			WallMessage:FireClient(player, "This building cannot tune command range")
		end
		return
	end
	if building:GetAttribute("IsUnderConstruction") or building:GetAttribute("IsUpgrading") then
		if WallMessage then
			WallMessage:FireClient(player, "Headquarters is not ready")
		end
		return
	end

	local modeName = tostring(payload or "")
	if not HQ_RANGE_MODE_NAMES[modeName] then
		if WallMessage then
			WallMessage:FireClient(player, "Unknown command range mode")
		end
		return
	end

	local cooldownUntil = tonumber(building:GetAttribute("HQRangeCooldownUntil") or 0) or 0
	local now = workspace:GetServerTimeNow()
	if cooldownUntil > now then
		if WallMessage then
			WallMessage:FireClient(player, "Headquarters retuning is on cooldown")
		end
		return
	end

	local ok, reason = applyHQRangeMode(building, modeName)
	if not ok and WallMessage then
		WallMessage:FireClient(player, reason)
	end
end)

ResearchEvent.OnServerEvent:Connect(function(player, action, building, researchId)
	if typeof(building) ~= "Instance" then return end
	if action ~= "Start" or not researchManager then
		return
	end
	if type(researchId) ~= "string" and type(researchId) ~= "number" then return end

	local ok, result = researchManager:startResearch(player, building, researchId)
	if not ok then
		ResearchEvent:FireClient(player, "Error", result)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		if upgradeManager then
			upgradeManager:tick(0.1)
		end
		if researchManager then
			researchManager:tick()
		end
		if superWeaponManager then
			superWeaponManager:tick()
		end
	end
end)

local function onBuildingAdded(building)
	local hum = building:FindFirstChild("Humanoid")
	if hum then
		hum.Died:Once(function()
			local ownerName = building:GetAttribute("Owner")
			local ownerPlayer = ownerName and Players:FindFirstChild(ownerName)
			local playerCounts = ownerPlayer and playerBuildingsCount[ownerPlayer.UserId]
			deathHandler:handleDeath(building, playerCounts)
		end)
		building:GetAttributeChangedSignal("Health"):Connect(function()
			local health = building:GetAttribute("Health")
			if health and health <= 0 and building.Parent then
				if hum and hum.Health > 0 then
					hum.Health = 0
				else
					local ownerName = building:GetAttribute("Owner")
					local ownerPlayer = ownerName and Players:FindFirstChild(ownerName)
					local playerCounts = ownerPlayer and playerBuildingsCount[ownerPlayer.UserId]
					deathHandler:handleDeath(building, playerCounts)
				end
			end
		end)
	end
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == "CurrentMap" then
		task.wait(1)
		local pBuildings = child:FindFirstChild("PlayerBuildings", true)
		if pBuildings then
			pBuildings.ChildAdded:Connect(onBuildingAdded)
			for _, b in pairs(pBuildings:GetChildren()) do
				onBuildingAdded(b)
			end
		end
	end
end)


