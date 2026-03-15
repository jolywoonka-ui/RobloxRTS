-- DiplomacyManager (Script, ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

-- EVENTS
local Remotes = ReplicatedStorage
local evInvite = Instance.new("RemoteEvent", Remotes); evInvite.Name = "DiplomacyInvite" 
-- Client -> Server: FireServer(targetPlayer)
-- Server -> Client: FireClient(targetPlayer, senderPlayer)

local evRespond = Instance.new("RemoteEvent", Remotes); evRespond.Name = "DiplomacyRespond"
-- Client -> Server: FireServer(senderPlayer, boolAccepted)

local evUpdate = Instance.new("RemoteEvent", Remotes); evUpdate.Name = "DiplomacyUpdate"
-- Server -> Client: To refresh UI list

-- CONSTANTS
local MAX_ALLIANCE_SIZE = 3

-- HELPER: Update all units owned by player to the new alliance ID
local function updateUnitAlliance(player, newAllianceID)
	local map = workspace:FindFirstChild("CurrentMap")
	if not map then return end
	local army = map:FindFirstChild("Army")
	if army then
		for _, unit in pairs(army:GetChildren()) do
			if unit:GetAttribute("Owner") == player.Name then
				unit:SetAttribute("AllianceID", newAllianceID)
			end
		end
	end
end

-- HELPER: Get Alliance Info
local function getAllianceID(player)
	return player:GetAttribute("AllianceID")
end

local function getAllianceMembers(allianceID)
	if not allianceID then return {} end
	local members = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("AllianceID") == allianceID then
			table.insert(members, p)
		end
	end
	return members
end

-- LOGIC: Send Invite
evInvite.OnServerEvent:Connect(function(sender, target)
	if sender == target then return end

	-- Validation 1: Target must not be in an alliance (Strict "Can't Leave" rule)
	if target:GetAttribute("AllianceID") then
		return -- Target is already locked in an alliance
	end

	-- Validation 2: Sender's alliance must have space
	local senderID = getAllianceID(sender)
	if senderID then
		local members = getAllianceMembers(senderID)
		if #members >= MAX_ALLIANCE_SIZE then
			return -- Alliance full
		end
	end

	-- Send Invite to Target
	evInvite:FireClient(target, sender)
end)

-- LOGIC: Respond to Invite
evRespond.OnServerEvent:Connect(function(responder, sender, accepted)
	if not accepted then return end

	-- Re-Validate checks before forming
	if responder:GetAttribute("AllianceID") then return end -- Responder already joined one

	local senderID = getAllianceID(sender)

	if senderID then
		-- Case A: Joining existing alliance
		local members = getAllianceMembers(senderID)
		if #members >= MAX_ALLIANCE_SIZE then return end -- Full

		responder:SetAttribute("AllianceID", senderID)
		-- Update all responder's units
		updateUnitAlliance(responder, senderID)
	else
		-- Case B: Forming new alliance
		-- Check if sender joined one in the meantime
		if sender:GetAttribute("AllianceID") then
			-- Edge case: Sender joined someone else? 
			-- Simpler: Just generate a new ID if sender is nil
			local newID = HttpService:GenerateGUID(false)
			sender:SetAttribute("AllianceID", newID)
			responder:SetAttribute("AllianceID", newID)
			-- Update both players' units
			updateUnitAlliance(sender, newID)
			updateUnitAlliance(responder, newID)
		else
			local newID = HttpService:GenerateGUID(false)
			sender:SetAttribute("AllianceID", newID)
			responder:SetAttribute("AllianceID", newID)
			updateUnitAlliance(sender, newID)
			updateUnitAlliance(responder, newID)
		end
	end

	-- Notify everyone to update lists
	evUpdate:FireAllClients()
end)

-- LOGIC: Reset on Round Start
local roundStart = ServerStorage:WaitForChild("RoundStartEvent", 10)
if roundStart then
	roundStart.Event:Connect(function()
		for _, p in ipairs(Players:GetPlayers()) do
			p:SetAttribute("AllianceID", nil)
		end
		evUpdate:FireAllClients()
	end)
end

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(p)
	-- No specific cleanup needed as getAllianceMembers scans current players
end)