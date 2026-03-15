local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local ResearchManager = {}
ResearchManager.__index = ResearchManager

local ACTIVE_RESEARCH_ATTR = "ActiveResearchId"
local ACTIVE_START_ATTR = "ActiveResearchStartedAt"
local ACTIVE_END_ATTR = "ActiveResearchEndsAt"
local ACTIVE_SLOT_ATTR = "ResearchSlotIndex"

local function getResearchAttrName(researchId)
	return "Research_" .. tostring(researchId)
end

local function getResearchDisplayName(researchId)
	local data = Config.Research[researchId]
	if not data then
		return tostring(researchId or "RESEARCH")
	end
	return tostring(data.DisplayName or researchId)
end

function ResearchManager.new(hqManager, remote)
	local self = setmetatable({}, ResearchManager)
	self.HQManager = hqManager
	self.Remote = remote
	self.LastSyncAt = 0
	return self
end

function ResearchManager:_getPlayerSlotIndex(player)
	if not self.HQManager or not player then
		return nil
	end

	local mapped = self.HQManager.ActiveSlotByUserId and self.HQManager.ActiveSlotByUserId[player.UserId]
	if type(mapped) == "number" then
		return mapped
	end

	for index, data in pairs(self.HQManager.HQData or {}) do
		if data.currentOwnerUserId == player.UserId or data.currentOwnerName == player.Name then
			return index
		end
	end

	return nil
end

function ResearchManager:_getStateForSlot(index)
	if not self.HQManager or type(index) ~= "number" then
		return nil
	end

	local slotData = self.HQManager:_ensureData(index)
	slotData.researchState = slotData.researchState or {
		Completed = {},
		ActiveId = nil,
		StartedAt = 0,
		EndsAt = 0,
	}

	slotData.researchState.Completed = slotData.researchState.Completed or {}
	return slotData.researchState
end

function ResearchManager:_clearPlayerAttributes(player)
	if not player then
		return
	end

	for researchId in pairs(Config.Research) do
		player:SetAttribute(getResearchAttrName(researchId), false)
	end
	player:SetAttribute(ACTIVE_RESEARCH_ATTR, "")
	player:SetAttribute(ACTIVE_START_ATTR, 0)
	player:SetAttribute(ACTIVE_END_ATTR, 0)
	player:SetAttribute(ACTIVE_SLOT_ATTR, 0)
end

function ResearchManager:_applyStateToPlayer(player, state, slotIndex)
	if not player then
		return
	end

	for researchId in pairs(Config.Research) do
		local completed = state and state.Completed and state.Completed[researchId] == true or false
		player:SetAttribute(getResearchAttrName(researchId), completed)
	end

	player:SetAttribute(ACTIVE_RESEARCH_ATTR, state and state.ActiveId or "")
	player:SetAttribute(ACTIVE_START_ATTR, state and state.StartedAt or 0)
	player:SetAttribute(ACTIVE_END_ATTR, state and state.EndsAt or 0)
	player:SetAttribute(ACTIVE_SLOT_ATTR, slotIndex or 0)
end

function ResearchManager:beginRound(hqManager)
	if hqManager then
		self.HQManager = hqManager
	end

	for _, player in ipairs(Players:GetPlayers()) do
		self:_clearPlayerAttributes(player)
	end

	self.LastSyncAt = 0
	self:syncAllPlayers(true)
end

function ResearchManager:syncAllPlayers(force)
	if not self.HQManager then
		return
	end

	local now = workspace:GetServerTimeNow()
	if not force and now - self.LastSyncAt < 0.25 then
		return
	end
	self.LastSyncAt = now

	for _, player in ipairs(Players:GetPlayers()) do
		local slotIndex = self:_getPlayerSlotIndex(player)
		if slotIndex then
			local state = self:_getStateForSlot(slotIndex)
			self:_applyStateToPlayer(player, state, slotIndex)
		else
			self:_clearPlayerAttributes(player)
		end
	end
end

function ResearchManager:startResearch(player, building, researchId)
	if not player or not building or not building.Parent then
		return false, "Invalid research request"
	end
	if building:GetAttribute("Owner") ~= player.Name then
		return false, "Not your research center"
	end
	if building:GetAttribute("Type") ~= "ResearchCenter" then
		return false, "This building cannot conduct research"
	end
	if building:GetAttribute("IsUnderConstruction") or building:GetAttribute("IsUpgrading") then
		return false, "Research center is not ready"
	end

	local researchData = Config.Research[researchId]
	if not researchData then
		return false, "Unknown research project"
	end

	local slotIndex = self:_getPlayerSlotIndex(player)
	if not slotIndex then
		return false, "No faction slot found"
	end

	local state = self:_getStateForSlot(slotIndex)
	if state.Completed[researchId] then
		return false, getResearchDisplayName(researchId) .. " is already complete"
	end
	if state.ActiveId then
		return false, getResearchDisplayName(state.ActiveId) .. " is already in progress"
	end

	local stats = player:FindFirstChild("Stats")
	local playerStats = player:FindFirstChild("PlayerStats")
	if not stats or not playerStats then
		return false, "Stats unavailable"
	end
	if stats:FindFirstChild("Credits") == nil or stats.Credits.Value < (researchData.Cost or 0) then
		return false, "Not enough credits"
	end
	if playerStats:FindFirstChild("Energy") and playerStats:FindFirstChild("MaxEnergy") then
		if playerStats.Energy.Value > playerStats.MaxEnergy.Value then
			return false, "Low power"
		end
	end

	stats.Credits.Value -= researchData.Cost or 0
	if playerStats:FindFirstChild("MoneySpent") then
		playerStats.MoneySpent.Value += researchData.Cost or 0
	end

	local now = workspace:GetServerTimeNow()
	state.ActiveId = researchId
	state.StartedAt = now
	state.EndsAt = now + (researchData.ResearchTime or 0)

	self:_applyStateToPlayer(player, state, slotIndex)
	return true
end

function ResearchManager:tick()
	if not self.HQManager then
		return
	end

	local now = workspace:GetServerTimeNow()
	for index in pairs(self.HQManager.HQData or {}) do
		local state = self:_getStateForSlot(index)
		if state and state.ActiveId and state.EndsAt > 0 and now >= state.EndsAt then
			local completedId = state.ActiveId
			state.Completed[completedId] = true
			state.ActiveId = nil
			state.StartedAt = 0
			state.EndsAt = 0

			local ownerName = self.HQManager:getSlotOwnerName(index)
			local ownerPlayer = ownerName and Players:FindFirstChild(ownerName)
			if ownerPlayer then
				self:_applyStateToPlayer(ownerPlayer, state, index)
				if self.Remote then
					self.Remote:FireClient(ownerPlayer, "Completed", getResearchDisplayName(completedId) .. " complete")
				end
			end
		end
	end

	self:syncAllPlayers(false)
end

return ResearchManager
