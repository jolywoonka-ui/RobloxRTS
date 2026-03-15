-- DebugServer (Script, ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remoteName = "Debug_KillEnemyHQs"
local remote = ReplicatedStorage:FindFirstChild(remoteName)
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = remoteName
	remote.Parent = ReplicatedStorage
end

remote.OnServerEvent:Connect(function(player)
	print("DEBUG: Kill Command from", player.Name)
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return end

	local buildings = map:FindFirstChild("PlayerBuildings", true)
	if not buildings then return end

	for _, b in pairs(buildings:GetChildren()) do
		-- Only kill HQs not owned by the player
		if b.Name:match("^Headquarter") and b:GetAttribute("Owner") ~= player.Name then
			local hum = b:FindFirstChild("Humanoid")
			if hum then
				b:SetAttribute("Health", 0) -- Sync attribute
				hum.Health = 0 -- Sync humanoid (Triggers Died event)
			else
				b:Destroy() -- Fallback
			end
		end
	end
end)