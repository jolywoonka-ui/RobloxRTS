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

-- Helper to clone a simple table
local function cloneTable(t)
	local clone = {}
	for k, v in pairs(t) do
		clone[k] = v
	end
	return clone
end

-- Sanitize and validate settings data
local function sanitizeSettings(data)
	local sanitized = {}
	if type(data) ~= "table" then
		return cloneTable(DEFAULT_SETTINGS)
	end

	for key, defaultValue in pairs(DEFAULT_SETTINGS) do
		local value = data[key]
		if value == nil then
			sanitized[key] = defaultValue
			continue
		end

		local expectedType = type(defaultValue)
		if type(value) == expectedType then
			if expectedType == "string" then
				-- Enforce reasonable length limit for string settings (e.g. keybinds)
				if string.len(value) <= 32 then
					sanitized[key] = value
				else
					sanitized[key] = defaultValue
				end
			else
				sanitized[key] = value
			end
		else
			sanitized[key] = defaultValue
		end
	end

	return sanitized
end

-- Load settings for a player
local function loadSettings(userId)
	local success, data = pcall(function()
		return settingsStore:GetAsync(userId)
	end)
	if success and data then
		return sanitizeSettings(data)
	else
		return cloneTable(DEFAULT_SETTINGS)
	end
end

-- Save settings for a player
local function saveSettings(userId, data)
	local sanitized = sanitizeSettings(data)
	pcall(function()
		settingsStore:SetAsync(userId, sanitized)
	end)
end

-- Handle client requests
RemoteFunction.OnServerInvoke = function(player)
	return loadSettings(player.UserId)
end

RemoteEvent.OnServerEvent:Connect(function(player, newSettings)
	saveSettings(player.UserId, newSettings)
end)
