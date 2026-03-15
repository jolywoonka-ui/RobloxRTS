-- KeybindHandler (LocalScript, StarterPlayerScripts)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local camera = workspace.CurrentCamera

local KeybindConfig = require(ReplicatedStorage:WaitForChild("KeybindConfig"))

-- State for highlight toggle
local highlightsActive = false
local highlightConnections = {}

-- Teleport function
local function teleportToMouse()
	local character = player.Character
	if not character then return end
	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	-- Raycast to find ground
	local ray = mouse.UnitRay
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {character}
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	if result then
		humanoidRootPart.CFrame = CFrame.new(result.Position + Vector3.new(0, 3, 0))
	end
end

-- Highlight all player's units
local function toggleHighlight()
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return end
	local army = map:FindFirstChild("Army")
	if not army then return end

	if highlightsActive then
		-- Remove all highlights
		for _, conn in ipairs(highlightConnections) do
			conn:Disconnect()
		end
		table.clear(highlightConnections)
		for _, unit in pairs(army:GetChildren()) do
			if unit:GetAttribute("Owner") == player.Name then
				local hl = unit:FindFirstChild("PlayerHighlight")
				if hl then hl:Destroy() end
			end
		end
		highlightsActive = false
	else
		-- Add highlights to all owned units, and watch for new units
		local function addHighlight(unit)
			if unit:GetAttribute("Owner") == player.Name then
				if not unit:FindFirstChild("PlayerHighlight") then
					local hl = Instance.new("Highlight")
					hl.Name = "PlayerHighlight"
					hl.Adornee = unit
					hl.FillColor = Color3.new(0, 1, 0) -- green
					hl.FillTransparency = 0.5
					hl.OutlineColor = Color3.new(1, 1, 1)
					hl.Parent = unit
				end
			end
		end

		-- Add to existing units
		for _, unit in pairs(army:GetChildren()) do
			addHighlight(unit)
		end

		-- Watch for new units
		local conn = army.ChildAdded:Connect(addHighlight)
		table.insert(highlightConnections, conn)

		-- Also watch for descendant removal to clean up if unit destroyed
		local cleanupConn = workspace.DescendantRemoving:Connect(function(desc)
			if desc:GetAttribute("Owner") == player.Name and desc:FindFirstChild("PlayerHighlight") then
				desc.PlayerHighlight:Destroy()
			end
		end)
		table.insert(highlightConnections, cleanupConn)

		highlightsActive = true
	end
end

-- Key press handler
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.UserInputType == Enum.UserInputType.Keyboard then
		local key = input.KeyCode.Name

		if key == KeybindConfig.TeleportKey then
			teleportToMouse()
		elseif key == KeybindConfig.HighlightKey then
			toggleHighlight()
		end
	end
end)