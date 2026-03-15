-- SettingsServer (Script, ServerScriptService)
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local settingsStore = DataStoreService:GetDataStore("PlayerSettings")

local RemoteFunction = Instance.new("RemoteFunction")
RemoteFunction.Name = "GetSettings"
RemoteFunction.Parent = ReplicatedStorage

local RemoteEvent = Instance.new("RemoteEvent")
RemoteEvent.Name = "SaveSettings"
RemoteEvent.Parent = ReplicatedStorage

-- Default settings
local DEFAULT_SETTINGS = {
	TeleportKey = "T",
	HighlightKey = "Z",
	PingKey = "C",
	ShowDetailedSquads = true,
}

-- Load settings for a player
local function loadSettings(userId)
	local success, data = pcall(function()
		return settingsStore:GetAsync(userId)
	end)
	if success and data then
		local merged = {}
		for key, value in pairs(DEFAULT_SETTINGS) do
			if data[key] ~= nil then
				merged[key] = data[key]
			else
				merged[key] = value
			end
		end
		return merged
	else
		return DEFAULT_SETTINGS
	end
end

-- Save settings for a player
local function saveSettings(userId, data)
	pcall(function()
		settingsStore:SetAsync(userId, data)
	end)
end

-- Handle client requests
RemoteFunction.OnServerInvoke = function(player)
	return loadSettings(player.UserId)
end

RemoteEvent.OnServerEvent:Connect(function(player, newSettings)
	saveSettings(player.UserId, newSettings)
end)
