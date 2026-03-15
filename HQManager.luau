-- HQManager (ModuleScript, ServerStorage)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local HQManager = {}
HQManager.__index = HQManager

local MAX_HQS = 6

local function applyTeamColor(model, player)
	if not player then return end
	local teamColor = player:GetAttribute("TeamColor")
	if not teamColor then return end
	for _, part in pairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "TeamPaint" then
			part.Color = teamColor
		end
	end
end

local function getObjectPosition(obj)
	if not obj then return nil end
	if obj:IsA("Model") then
		return obj:GetPivot().Position
	elseif obj:IsA("BasePart") then
		return obj.Position
	end
	return nil
end

local function removeIndex(list, target)
	for i = #list, 1, -1 do
		if list[i] == target then
			table.remove(list, i)
		end
	end
end

local function addIndexSortedUnique(list, target)
	if table.find(list, target) then return end
	table.insert(list, target)
	table.sort(list)
end

function HQManager.new(mapModel, setupBuildingFunc)
	local self = setmetatable({}, HQManager)
	self.MapModel = mapModel
	self.SetupBuildingFunc = setupBuildingFunc
	self.PlayerBuildings = nil
	self.Army = nil
	self.AvailableIndices = {}
	self.DestroyedIndices = {}
	self.HQByIndex = {}
	self.HQData = {}
	self.ActiveSlotByUserId = {}
	return self
end

function HQManager:_ensureData(index)
	self.HQData[index] = self.HQData[index] or {}
	local data = self.HQData[index]
	if data.treasury == nil then
		data.treasury = 0
	end
	return data
end

function HQManager:_removeFromPools(index)
	removeIndex(self.AvailableIndices, index)
	removeIndex(self.DestroyedIndices, index)
end

function HQManager:_markUnclaimed(index)
	self:_removeFromPools(index)
	if self.HQByIndex[index] then
		addIndexSortedUnique(self.AvailableIndices, index)
	else
		addIndexSortedUnique(self.DestroyedIndices, index)
	end
end

function HQManager:_isIndexClaimedByOther(index, player)
	local data = self.HQData[index]
	local hq = self.HQByIndex[index]
	local hqOwner = hq and hq:GetAttribute("Owner") or nil
	if hqOwner and hqOwner ~= player.Name and Players:FindFirstChild(hqOwner) then
		return true
	end
	local currentOwner = data and data.currentOwnerName or nil
	if currentOwner and currentOwner ~= player.Name and Players:FindFirstChild(currentOwner) then
		return true
	end
	return false
end

function HQManager:getSlotOwnerName(index)
	local data = self.HQData[index]
	if data and data.currentOwnerName then
		local ownerPlayer = Players:FindFirstChild(data.currentOwnerName)
		if ownerPlayer then
			data.currentOwnerUserId = ownerPlayer.UserId
			data.lastOwner = ownerPlayer.Name
			data.lastUserId = ownerPlayer.UserId
			data.allianceID = ownerPlayer:GetAttribute("AllianceID")
			return ownerPlayer.Name
		end
		data.currentOwnerName = nil
		data.currentOwnerUserId = nil
		self:_markUnclaimed(index)
	end

	local hq = self.HQByIndex[index]
	if hq then
		local ownerName = hq:GetAttribute("Owner")
		if ownerName then
			local ownerPlayer = Players:FindFirstChild(ownerName)
			if ownerPlayer then
				local slotData = self:_ensureData(index)
				slotData.currentOwnerName = ownerName
				slotData.currentOwnerUserId = ownerPlayer.UserId
				slotData.lastOwner = ownerName
				slotData.lastUserId = ownerPlayer.UserId
				slotData.allianceID = ownerPlayer:GetAttribute("AllianceID")
				self.ActiveSlotByUserId[ownerPlayer.UserId] = index
				return ownerName
			end

			local slotData = self:_ensureData(index)
			slotData.lastOwner = ownerName
			hq:SetAttribute("Owner", nil)
			self:_markUnclaimed(index)
		end
	end

	return nil
end

function HQManager:getSlotAllianceID(index)
	local ownerName = self:getSlotOwnerName(index)
	if ownerName then
		local ownerPlayer = Players:FindFirstChild(ownerName)
		if ownerPlayer then
			return ownerPlayer:GetAttribute("AllianceID")
		end
	end
	local data = self.HQData[index]
	return data and data.allianceID or nil
end

function HQManager:findReclaimIndex(player, preferredIndex)
	local function isCandidate(index)
		if type(index) ~= "number" then return false end
		if index < 1 or index > MAX_HQS then return false end
		if self:_isIndexClaimedByOther(index, player) then
			return false
		end

		local data = self.HQData[index] or {}
		local hq = self.HQByIndex[index]
		local hqOwner = hq and hq:GetAttribute("Owner") or nil

		if data.currentOwnerUserId == player.UserId then return true end
		if data.lastUserId == player.UserId then return true end
		if data.currentOwnerName == player.Name then return true end
		if data.lastOwner == player.Name then return true end
		if hqOwner == player.Name then return true end
		return false
	end

	local mapped = self.ActiveSlotByUserId[player.UserId]
	if isCandidate(mapped) then
		return mapped
	end
	if isCandidate(preferredIndex) then
		return preferredIndex
	end

	for index = 1, MAX_HQS do
		if isCandidate(index) then
			return index
		end
	end

	return nil
end

function HQManager:recalculateStats(player)
	local ps = player:FindFirstChild("PlayerStats")
	if not ps then return end

	ps.Income.Value = Config.BaseIncome
	ps.MaxEnergy.Value = Config.BaseEnergy
	ps.Energy.Value = 0
	ps.UnitLimit.Value = Config.BaseUnitLimit

	if not self.PlayerBuildings then return end
	for _, building in pairs(self.PlayerBuildings:GetChildren()) do
		if building:GetAttribute("Owner") == player.Name and not building:GetAttribute("IsUnderConstruction") then
			local bType = building:GetAttribute("Type")
			local data = Config.Buildings[bType]
			if data then
				if data.Income then
					ps.Income.Value += data.Income
				end
				if data.Energy then
					if data.Energy > 0 then
						ps.MaxEnergy.Value += data.Energy
					else
						ps.Energy.Value += math.abs(data.Energy)
					end
				end
				if data.UnitLimit then
					ps.UnitLimit.Value += data.UnitLimit
				end
			end
		end
	end

	ps.Energy.Value = math.min(ps.Energy.Value, ps.MaxEnergy.Value)
end

function HQManager:updatePlayerUnits(player, newAllianceID)
	if not self.Army then return end
	for _, unit in pairs(self.Army:GetChildren()) do
		if unit:GetAttribute("Owner") == player.Name then
			unit:SetAttribute("AllianceID", newAllianceID)
		end
	end
end

function HQManager:scanHQs()
	self.HQByIndex = {}
	self.AvailableIndices = {}
	self.DestroyedIndices = {}
	self.ActiveSlotByUserId = {}

	local oldTreasury = {}
	for i, data in pairs(self.HQData) do
		oldTreasury[i] = data.treasury or 0
	end

	self.HQData = {}
	if not self.MapModel then
		warn("HQManager: No map model to scan")
		return
	end

	self.PlayerBuildings = self.MapModel:FindFirstChild("PlayerBuildings", true)
	self.Army = self.MapModel:FindFirstChild("Army", true)
	if not self.PlayerBuildings then
		warn("HQManager: PlayerBuildings folder not found")
		return
	end

	for i = 1, MAX_HQS do
		local data = self:_ensureData(i)
		data.treasury = oldTreasury[i] or 0
		data.currentOwnerName = nil
		data.currentOwnerUserId = nil
		data.lastOwner = nil
		data.lastUserId = nil
		data.allianceID = nil

		local hqName = "Headquarter" .. i
		local hq = self.PlayerBuildings:FindFirstChild(hqName)
		if hq then
			self.HQByIndex[i] = hq
			data.originalCFrame = hq:GetPivot()

			local ownerName = hq:GetAttribute("Owner")
			if ownerName then
				local ownerPlayer = Players:FindFirstChild(ownerName)
				data.lastOwner = ownerName
				if ownerPlayer then
					data.currentOwnerName = ownerName
					data.currentOwnerUserId = ownerPlayer.UserId
					data.lastUserId = ownerPlayer.UserId
					data.allianceID = ownerPlayer:GetAttribute("AllianceID")
					self.ActiveSlotByUserId[ownerPlayer.UserId] = i
				else
					hq:SetAttribute("Owner", nil)
					addIndexSortedUnique(self.AvailableIndices, i)
				end
			else
				addIndexSortedUnique(self.AvailableIndices, i)
			end
		else
			addIndexSortedUnique(self.DestroyedIndices, i)
		end
	end
end

function HQManager:transferOwnership(oldOwnerName, newPlayer)
	print("Transferring ownership from", oldOwnerName, "to", newPlayer.Name)
	local newAllianceID = newPlayer:GetAttribute("AllianceID")

	if self.PlayerBuildings then
		for _, b in pairs(self.PlayerBuildings:GetChildren()) do
			if b:GetAttribute("Owner") == oldOwnerName then
				b:SetAttribute("Owner", newPlayer.Name)
				b:SetAttribute("AllianceID", newAllianceID)
				applyTeamColor(b, newPlayer)
			end
		end
	end

	if self.Army then
		for _, u in pairs(self.Army:GetChildren()) do
			if u:GetAttribute("Owner") == oldOwnerName then
				u:SetAttribute("Owner", newPlayer.Name)
				u:SetAttribute("AllianceID", newAllianceID)
				applyTeamColor(u, newPlayer)
			end
		end
	end
end

function HQManager:retagOwnership(oldOwnerName, newOwnerName, allianceID)
	if not oldOwnerName or not newOwnerName or oldOwnerName == newOwnerName then return end

	if self.PlayerBuildings then
		for _, b in pairs(self.PlayerBuildings:GetChildren()) do
			if b:GetAttribute("Owner") == oldOwnerName then
				b:SetAttribute("Owner", newOwnerName)
				if allianceID ~= nil then
					b:SetAttribute("AllianceID", allianceID)
				end
			end
		end
	end

	if self.Army then
		for _, u in pairs(self.Army:GetChildren()) do
			if u:GetAttribute("Owner") == oldOwnerName then
				u:SetAttribute("Owner", newOwnerName)
				if allianceID ~= nil then
					u:SetAttribute("AllianceID", allianceID)
				end
			end
		end
	end
end

function HQManager:claimNeutralUnitsForSlot(index, player)
	if not self.Army then return 0, 0 end

	local data = self.HQData[index]
	local slotPos = nil
	if self.HQByIndex[index] then
		slotPos = getObjectPosition(self.HQByIndex[index])
	elseif data and data.originalCFrame then
		slotPos = data.originalCFrame.Position
	end

	local convertedUnits = 0
	local convertedSupply = 0

	for _, unit in pairs(self.Army:GetChildren()) do
		if unit:GetAttribute("Owner") == nil then
			local shouldConvert = false
			local spawnIndex = unit:GetAttribute("SpawnHQIndex")

			if spawnIndex == index then
				shouldConvert = true
			elseif slotPos then
				local uPos = getObjectPosition(unit)
				if uPos and unit.Name == "Builder" and (uPos - slotPos).Magnitude <= 45 then
					shouldConvert = true
				end
			end

			if shouldConvert then
				unit:SetAttribute("Owner", player.Name)
				unit:SetAttribute("AllianceID", player:GetAttribute("AllianceID"))
				applyTeamColor(unit, player)
				convertedUnits += 1
				convertedSupply += (unit:GetAttribute("Supply") or 1)
			end
		end
	end

	if convertedSupply > 0 then
		local ps = player:FindFirstChild("PlayerStats")
		local currentUnits = ps and ps:FindFirstChild("CurrentUnits")
		if currentUnits then
			currentUnits.Value += convertedSupply
		end
	end

	return convertedUnits, convertedSupply
end

function HQManager:storePlayerData(index, player)
	local stats = player:FindFirstChild("Stats")
	local playerStats = player:FindFirstChild("PlayerStats")
	if not stats or not playerStats then return end

	local data = self:_ensureData(index)
	data.credits = stats.Credits.Value
	data.income = playerStats.Income.Value
	data.energy = playerStats.Energy.Value
	data.maxEnergy = playerStats.MaxEnergy.Value
	data.unitLimit = playerStats.UnitLimit.Value
	data.lastOwner = player.Name
	data.lastUserId = player.UserId
	data.allianceID = player:GetAttribute("AllianceID")
	data.canBuild = playerStats.CanBuild.Value
	print("Stored data for HQ", index, "from player", player.Name)
end

function HQManager:loadPlayerData(index, player)
	local data = self.HQData[index]
	if not data then
		self:resetPlayerStats(player)
		return true
	end

	local stats = player:FindFirstChild("Stats")
	local playerStats = player:FindFirstChild("PlayerStats")
	if not stats or not playerStats then return false end

	stats.Credits.Value = data.credits or 2000
	playerStats.Income.Value = data.income or Config.BaseIncome
	playerStats.Energy.Value = data.energy or 0
	playerStats.MaxEnergy.Value = data.maxEnergy or Config.BaseEnergy
	playerStats.UnitLimit.Value = data.unitLimit or Config.BaseUnitLimit
	playerStats.MoneySpent.Value = 0
	playerStats.UnitsRecruited.Value = 0
	playerStats.DamageDealt.Value = 0
	playerStats.CanBuild.Value = (data.canBuild ~= nil) and data.canBuild or 1

	print("Loaded data for HQ", index, "into player", player.Name)
	return true
end

function HQManager:giveTreasuryToPlayer(index, player)
	local data = self.HQData[index]
	if not data then return end
	local treasury = data.treasury or 0
	if treasury > 0 then
		local stats = player:FindFirstChild("Stats")
		if stats then
			stats.Credits.Value += treasury
			print("Gave", treasury, "treasury to", player.Name, "for HQ", index)
		end
		data.treasury = 0
	end
end

function HQManager:addToTreasury(index, amount)
	local data = self:_ensureData(index)
	data.treasury = (data.treasury or 0) + amount
end

function HQManager:resetPlayerStats(player)
	local stats = player:FindFirstChild("Stats")
	local playerStats = player:FindFirstChild("PlayerStats")
	if stats and playerStats then
		stats.Credits.Value = 2000
		playerStats.Income.Value = Config.BaseIncome
		playerStats.Energy.Value = 0
		playerStats.MaxEnergy.Value = Config.BaseEnergy
		playerStats.UnitLimit.Value = Config.BaseUnitLimit
		playerStats.MoneySpent.Value = 0
		playerStats.UnitsRecruited.Value = 0
		playerStats.DamageDealt.Value = 0
		playerStats.CanBuild.Value = 1
	end
end

function HQManager:getNextAvailableIndex()
	if #self.AvailableIndices > 0 then
		local rand = math.random(1, #self.AvailableIndices)
		return self.AvailableIndices[rand]
	end
	if #self.DestroyedIndices > 0 then
		local rand = math.random(1, #self.DestroyedIndices)
		return self.DestroyedIndices[rand]
	end
	return nil
end

function HQManager:releaseFaction(player)
	local toRelease = {}
	local seen = {}

	local function addIndex(index)
		if type(index) ~= "number" then return end
		if index < 1 or index > MAX_HQS then return end
		if seen[index] then return end
		seen[index] = true
		table.insert(toRelease, index)
	end

	addIndex(self.ActiveSlotByUserId[player.UserId])

	for index = 1, MAX_HQS do
		local data = self.HQData[index] or {}
		local hq = self.HQByIndex[index]
		local hqOwner = hq and hq:GetAttribute("Owner") or nil
		if hqOwner == player.Name
			or data.currentOwnerName == player.Name
			or data.currentOwnerUserId == player.UserId then
			addIndex(index)
		end
	end

	for _, index in ipairs(toRelease) do
		local data = self:_ensureData(index)
		self:storePlayerData(index, player)
		local orphanOwnerName = string.format("__ORPHAN_SLOT_%d", index)
		self:retagOwnership(player.Name, orphanOwnerName, data.allianceID or player:GetAttribute("AllianceID"))
		data.lastOwner = orphanOwnerName
		data.lastUserId = nil
		data.currentOwnerName = nil
		data.currentOwnerUserId = nil

		local hq = self.HQByIndex[index]
		if hq and hq.Parent then
			hq:SetAttribute("Owner", nil)
		end
		self:_markUnclaimed(index)
	end

	self.ActiveSlotByUserId[player.UserId] = nil
	return #toRelease
end

function HQManager:claimFaction(index, player)
	if not self.PlayerBuildings then
		warn("HQManager: PlayerBuildings not initialized")
		return false
	end
	if type(index) ~= "number" then return false end
	if index < 1 or index > MAX_HQS then return false end
	if self:_isIndexClaimedByOther(index, player) then
		return false
	end

	local existing = self.ActiveSlotByUserId[player.UserId]
	if existing and existing ~= index then
		local ownerName = self:getSlotOwnerName(existing)
		if ownerName == player.Name then
			return false
		end
	end

	local data = self:_ensureData(index)
	local hq = self.HQByIndex[index]
	local isDestroyed = (hq == nil)

	if data.allianceID then
		player:SetAttribute("AllianceID", data.allianceID)
	end

	local hqOwner = hq and hq:GetAttribute("Owner") or nil
	local previousOwner = nil
	if data.currentOwnerName and data.currentOwnerName ~= player.Name then
		previousOwner = data.currentOwnerName
	elseif hqOwner and hqOwner ~= player.Name then
		previousOwner = hqOwner
	elseif data.lastOwner and data.lastOwner ~= player.Name then
		previousOwner = data.lastOwner
	end

	if previousOwner then
		self:transferOwnership(previousOwner, player)
	end

	local neutralCount, neutralSupply = self:claimNeutralUnitsForSlot(index, player)

	self:loadPlayerData(index, player)
	self:giveTreasuryToPlayer(index, player)
	self:recalculateStats(player)

	if hq then
		hq:SetAttribute("Owner", player.Name)
		applyTeamColor(hq, player)
	end

	self:updatePlayerUnits(player, player:GetAttribute("AllianceID"))

	data.currentOwnerName = player.Name
	data.currentOwnerUserId = player.UserId
	data.lastOwner = player.Name
	data.lastUserId = player.UserId
	data.allianceID = player:GetAttribute("AllianceID")
	self.ActiveSlotByUserId[player.UserId] = index

	self:_removeFromPools(index)

	print("Faction", index, "claimed by", player.Name, isDestroyed and "(without HQ)" or "")
	if neutralCount > 0 then
		print("Converted neutral units for slot", index, ":", neutralCount, "units,", neutralSupply, "supply")
	end
	return true
end

function HQManager:onHQDestroyed(index)
	local hq = self.HQByIndex[index]
	if not hq then return end

	local data = self:_ensureData(index)
	data.originalCFrame = hq:GetPivot()

	local ownerName = hq:GetAttribute("Owner")
	if ownerName then
		data.lastOwner = ownerName
		local ownerPlayer = Players:FindFirstChild(ownerName)
		if ownerPlayer then
			data.currentOwnerName = ownerName
			data.currentOwnerUserId = ownerPlayer.UserId
			data.lastUserId = ownerPlayer.UserId
			data.allianceID = ownerPlayer:GetAttribute("AllianceID")
			self.ActiveSlotByUserId[ownerPlayer.UserId] = index
		else
			data.currentOwnerName = nil
			data.currentOwnerUserId = nil
		end
	else
		data.currentOwnerName = nil
		data.currentOwnerUserId = nil
	end

	self.HQByIndex[index] = nil
	removeIndex(self.AvailableIndices, index)

	if data.currentOwnerName then
		removeIndex(self.DestroyedIndices, index)
	else
		addIndexSortedUnique(self.DestroyedIndices, index)
	end

	print("HQ", index, "marked as destroyed")
end

function HQManager:assignInitialHQs(activePlayerData)
	if not self.PlayerBuildings then return end

	for i, hq in pairs(self.HQByIndex) do
		if not hq:GetAttribute("Owner") then
			local assignedPlayer = nil
			for userId, data in pairs(activePlayerData) do
				if data.SpawnIndex == i then
					local player = Players:GetPlayerByUserId(userId)
					if player then
						assignedPlayer = player
						break
					end
				end
			end

			if assignedPlayer then
				hq:SetAttribute("Owner", assignedPlayer.Name)
				applyTeamColor(hq, assignedPlayer)
				self:resetPlayerStats(assignedPlayer)

				local slotData = self:_ensureData(i)
				slotData.currentOwnerName = assignedPlayer.Name
				slotData.currentOwnerUserId = assignedPlayer.UserId
				slotData.lastOwner = assignedPlayer.Name
				slotData.lastUserId = assignedPlayer.UserId
				slotData.allianceID = assignedPlayer:GetAttribute("AllianceID")
				self.ActiveSlotByUserId[assignedPlayer.UserId] = i

				self:_removeFromPools(i)
				print("HQ", i, "assigned to", assignedPlayer.Name, "at round start")
			else
				self:_markUnclaimed(i)
			end
		end
	end
end

function HQManager:getSpawnPosition(index)
	local data = self.HQData[index]
	if data and data.originalCFrame then
		return data.originalCFrame.Position + Vector3.new(0, 3, 0)
	end
	return nil
end

return HQManager
