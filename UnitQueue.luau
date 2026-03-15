local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))
local UnitEvent = ReplicatedStorage:WaitForChild("UnitEvent")
local UnitSpawner = require(ServerStorage:WaitForChild("UnitSpawner"))

local BuildingQueues = setmetatable({}, {__mode = "k"})
local QueueMutationLock = {}
local UnitQueue = {}

local function isResearchUnlockedForPlayer(player, researchId)
	if not researchId then
		return true
	end
	if not player then
		return false
	end
	return player:GetAttribute("Research_" .. tostring(researchId)) == true
end

local function getResearchDisplayName(researchId)
	local researchData = Config.Research[researchId]
	return tostring(researchData and researchData.DisplayName or researchId or "RESEARCH")
end

local function adjustCurrentUnits(player, delta)
	local ps = player and player:FindFirstChild("PlayerStats")
	if not ps then return end
	local currentUnits = ps:FindFirstChild("CurrentUnits")
	if not currentUnits then
		currentUnits = Instance.new("IntValue")
		currentUnits.Name = "CurrentUnits"
		currentUnits.Value = 0
		currentUnits.Parent = ps
	end
	currentUnits.Value = math.max(0, currentUnits.Value + delta)
end

local function adjustQueuedSupply(player, delta)
	local ps = player and player:FindFirstChild("PlayerStats")
	if not ps then return end
	local queuedSupply = ps:FindFirstChild("QueuedSupply")
	if not queuedSupply then
		queuedSupply = Instance.new("IntValue")
		queuedSupply.Name = "QueuedSupply"
		queuedSupply.Value = 0
		queuedSupply.Parent = ps
	end
	queuedSupply.Value = math.max(0, queuedSupply.Value + delta)
end

local function fireQueueFailed(player, building, message)
	UnitEvent:FireClient(player, "QueueFailed", building, message)
end

local function refundCost(player, unitName)
	local uData = Config.Units[unitName]
	if not uData then return end
	local stats = player:FindFirstChild("Stats")
	if stats then
		stats.Credits.Value += uData.Cost
	end
end

local function refundReservedSupply(player, unitName)
	local uData = Config.Units[unitName]
	if not uData then return end
	local supply = uData.Supply or 1
	adjustCurrentUnits(player, -supply)
	adjustQueuedSupply(player, -supply)
end

local function getQueuedPayloadCount(queueData, payloadType)
	if not queueData or not payloadType then
		return 0
	end
	local count = 0
	for _, queuedName in ipairs(queueData.Queue or {}) do
		local queuedData = Config.Units[queuedName]
		if queuedData and queuedData.IsPayload and queuedData.PayloadType == payloadType then
			count += 1
		end
	end
	return count
end

local function validateRecruitRequest(player, building, unitName)
	local bType = building:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	if not bData or not bData.CanRecruit then
		return false, "Cannot recruit here"
	end

	local canBuild = false
	for _, u in ipairs(bData.CanRecruit) do
		if u == unitName then
			canBuild = true
			break
		end
	end
	if not canBuild then
		return false, "Unit not available"
	end

	local uData = Config.Units[unitName]
	if not uData then
		return false, "Invalid unit"
	end
	if uData.ResearchRequired and not isResearchUnlockedForPlayer(player, uData.ResearchRequired) then
		return false, "Requires research: " .. getResearchDisplayName(uData.ResearchRequired)
	end

	local queueData = BuildingQueues[building]
	if uData.IsPayload then
		local capacity = building:GetAttribute("MissileCapacity") or 1
		local stored = building:GetAttribute("StoredMissiles") or 0
		local queuedPayloads = getQueuedPayloadCount(queueData, uData.PayloadType)
		if stored + queuedPayloads >= capacity then
			return false, "Missile silo already has a missile ready"
		end
	end

	local ls = player:FindFirstChild("Stats")
	local ps = player:FindFirstChild("PlayerStats")
	if not ls or not ps then
		return false, "No stats"
	end
	if building:GetAttribute("Owner") ~= player.Name then
		return false, "Not your building"
	end
	if ls.Credits.Value < uData.Cost then
		return false, "Not enough credits"
	end
	if ps.Energy.Value > ps.MaxEnergy.Value then
		return false, "Low power"
	end

	local currentUnits = ps:FindFirstChild("CurrentUnits")
	local unitLimit = ps:FindFirstChild("UnitLimit")
	if not currentUnits or not unitLimit then
		return false, "No stats"
	end
	local usedSupply = currentUnits.Value
	if usedSupply + (uData.Supply or 1) > unitLimit.Value then
		return false, "Not enough houses for units"
	end

	return true, nil
end

local function clearQueueAndRefund(building, player, reason)
	local d = BuildingQueues[building]
	if not d then return end

	for _, unitName in ipairs(d.Queue) do
		refundCost(player, unitName)
		refundReservedSupply(player, unitName)
	end

	d.Queue = {}
	d.IsTraining = false
	d.CancelCurrent = false
	d.ActiveUnit = nil

	UnitQueue._updateClientQueue(building, player)
	if reason then
		fireQueueFailed(player, building, reason)
	end
end

local function ensureBuildingQueue(player, building)
	if BuildingQueues[building] then
		return BuildingQueues[building]
	end

	local d = {
		Queue = {},
		IsTraining = false,
		CancelCurrent = false,
		ActiveUnit = nil,
		OwnerUserId = player.UserId,
	}
	BuildingQueues[building] = d

	building.AncestryChanged:Connect(function()
		if building.Parent then return end
		local owner = Players:GetPlayerByUserId(d.OwnerUserId)
		if owner then
			clearQueueAndRefund(building, owner, "Training cancelled")
		end
		BuildingQueues[building] = nil
	end)

	return d
end

function UnitQueue.addToQueue(player, building, unitName)
	while QueueMutationLock[player.UserId] do
		task.wait()
	end
	QueueMutationLock[player.UserId] = true

	local okResult = false
	local failReason = nil

	local ok, err = pcall(function()
		local okValidate, reason = validateRecruitRequest(player, building, unitName)
		if not okValidate then
			failReason = reason
			return
		end

		local d = ensureBuildingQueue(player, building)
		local uData = Config.Units[unitName]
		local stats = player:FindFirstChild("Stats")
		if not uData or not stats then
			failReason = "Queue failed"
			return
		end

		stats.Credits.Value -= uData.Cost
		local supply = uData.Supply or 1
		adjustCurrentUnits(player, supply)
		adjustQueuedSupply(player, supply)
		table.insert(d.Queue, unitName)

		UnitQueue._updateClientQueue(building, player)
		okResult = true
	end)

	QueueMutationLock[player.UserId] = nil

	if not ok then
		warn("UnitQueue.addToQueue failed:", err)
		fireQueueFailed(player, building, "Queue failed")
		return false
	end

	if not okResult then
		fireQueueFailed(player, building, failReason or "Queue failed")
		return false
	end
	UnitQueue._processQueue(building, player)
	return true
end

function UnitQueue.cancelTrain(player, building, index)
	while QueueMutationLock[player.UserId] do
		task.wait()
	end
	QueueMutationLock[player.UserId] = true

	local d = BuildingQueues[building]
	if not d then
		QueueMutationLock[player.UserId] = nil
		return
	end

	local idx = tonumber(index)
	if not idx or idx < 1 or idx > #d.Queue then
		QueueMutationLock[player.UserId] = nil
		return
	end

	if idx == 1 and d.IsTraining then
		-- Do not remove/refund immediately for the active training item.
		-- _processQueue handles single removal+refund once cancellation is observed.
		d.CancelCurrent = true
		UnitEvent:FireClient(player, "TrainingCancelled", building)
		QueueMutationLock[player.UserId] = nil
		return
	end

	local cancelledUnitName = table.remove(d.Queue, idx)
	if not cancelledUnitName then
		QueueMutationLock[player.UserId] = nil
		return
	end

	refundCost(player, cancelledUnitName)
	refundReservedSupply(player, cancelledUnitName)

	UnitQueue._updateClientQueue(building, player)
	QueueMutationLock[player.UserId] = nil
	if not d.IsTraining then
		UnitQueue._processQueue(building, player)
	end
end

function UnitQueue._updateClientQueue(building, player)
	local d = BuildingQueues[building]
	if not d then
		UnitEvent:FireClient(player, "UpdateQueue", building, {})
		return
	end
	UnitEvent:FireClient(player, "UpdateQueue", building, d.Queue)
end

function UnitQueue._processQueue(building, player)
	local d = BuildingQueues[building]
	if not d or d.IsTraining then return end

	d.IsTraining = true

	while d and #d.Queue > 0 do
		if not building or not building.Parent then
			clearQueueAndRefund(building, player, "Training cancelled")
			BuildingQueues[building] = nil
			return
		end

		local unitName = d.Queue[1]
		local uData = Config.Units[unitName]
		if not uData then
			table.remove(d.Queue, 1)
			UnitQueue._updateClientQueue(building, player)
			continue
		end

		-- Hard gate before training begins: if capacity changed meanwhile, fail immediately.
		local ps = player:FindFirstChild("PlayerStats")
		if ps then
			local currentUnits = ps:FindFirstChild("CurrentUnits")
			local unitLimit = ps:FindFirstChild("UnitLimit")
			local usedSupply = (currentUnits and currentUnits.Value or 0)
			if unitLimit and usedSupply > unitLimit.Value then
				table.remove(d.Queue, 1)
				refundCost(player, unitName)
				refundReservedSupply(player, unitName)
				UnitQueue._updateClientQueue(building, player)
				fireQueueFailed(player, building, "Not enough houses for units")
				continue
			end
		end

		d.ActiveUnit = unitName
		d.CancelCurrent = false

		local trainTime = uData.TrainingTime or 0
		UnitEvent:FireClient(player, "StartTraining", building, trainTime)
		UnitQueue._updateClientQueue(building, player)

		local elapsed = 0
		local interval = 0.1
		local cancelled = false
		while elapsed < trainTime do
			task.wait(interval)
			elapsed += interval
			if d.CancelCurrent then
				cancelled = true
				d.CancelCurrent = false
				break
			end
			if not building or not building.Parent then
				clearQueueAndRefund(building, player, "Training cancelled")
				BuildingQueues[building] = nil
				return
			end
		end

		if cancelled then
			if d.Queue[1] == unitName then
				table.remove(d.Queue, 1)
				refundCost(player, unitName)
				refundReservedSupply(player, unitName)
				UnitQueue._updateClientQueue(building, player)
			end
			UnitEvent:FireClient(player, "TrainingCancelled", building)
		else
			local ps = player:FindFirstChild("PlayerStats")
			local canSpawn = true
			local reason = nil
			if ps and ps.Energy.Value > ps.MaxEnergy.Value then
				canSpawn = false
				reason = "Low power"
			end

			local spawned = nil
			if canSpawn then
				if uData.IsPayload then
					local stored = building:GetAttribute("StoredMissiles") or 0
					local capacity = building:GetAttribute("MissileCapacity") or 1
					if stored < capacity then
						building:SetAttribute("StoredMissiles", stored + 1)
						spawned = true
					else
						canSpawn = false
						reason = "Missile silo already has a missile ready"
					end
				else
					spawned = UnitSpawner.spawnPlayer(player, building, unitName, true)
					if not spawned then
						canSpawn = false
						reason = "Spawn failed"
					end
				end
			end

			if spawned then
				local supply = uData.Supply or 1
				adjustQueuedSupply(player, -supply)
				if ps then
					ps.MoneySpent.Value += uData.Cost
					if not uData.IsPayload then
						ps.UnitsRecruited.Value += 1
					end
				end
			else
				refundCost(player, unitName)
				refundReservedSupply(player, unitName)
				fireQueueFailed(player, building, reason or "Queue failed")
			end

			if d.Queue[1] == unitName then
				table.remove(d.Queue, 1)
			end
			UnitQueue._updateClientQueue(building, player)
		end
	end

	if d then
		d.IsTraining = false
		d.ActiveUnit = nil
		d.CancelCurrent = false
	end
end

return UnitQueue

