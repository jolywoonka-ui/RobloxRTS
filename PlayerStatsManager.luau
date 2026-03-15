-- PlayerStatsManager (ModuleScript, ServerStorage)
local Players = game:GetService("Players")

local PlayerStatsManager = {}

function PlayerStatsManager.setup(player)
	-- Stats folder with Credits
	local stats = player:FindFirstChild("Stats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "Stats"
		stats.Parent = player
	end
	local credits = stats:FindFirstChild("Credits")
	if not credits then
		credits = Instance.new("IntValue")
		credits.Name = "Credits"
		credits.Value = 150
		credits.Parent = stats
	end

	-- PlayerStats folder
	local ps = player:FindFirstChild("PlayerStats")
	if not ps then
		ps = Instance.new("Folder")
		ps.Name = "PlayerStats"
		ps.Parent = player
	end

	local function create(name, default)
		if not ps:FindFirstChild(name) then
			local v = Instance.new("IntValue")
			v.Name = name
			v.Value = default or 0
			v.Parent = ps
		end
	end

	create("DamageDealt", 0)
	create("MoneySpent", 0)
	create("UnitsRecruited", 0)
	create("Income", 3)
	create("Energy", 0)
	create("MaxEnergy", 25)
	create("CurrentUnits", 0)
	create("QueuedSupply", 0)
	create("UnitLimit", 6)
	create("CanBuild", 1)
end

function PlayerStatsManager.reset(player)
	local ps = player:FindFirstChild("PlayerStats")
	if ps then
		if ps:FindFirstChild("MoneySpent") then ps.MoneySpent.Value = 0 end
		if ps:FindFirstChild("UnitsRecruited") then ps.UnitsRecruited.Value = 0 end
		if ps:FindFirstChild("DamageDealt") then ps.DamageDealt.Value = 0 end
		if ps:FindFirstChild("QueuedSupply") then ps.QueuedSupply.Value = 0 end
		if ps:FindFirstChild("CanBuild") then ps.CanBuild.Value = 1 end
		if ps:FindFirstChild("CurrentUnits") then ps.CurrentUnits.Value = 0 end
	end
end

return PlayerStatsManager
