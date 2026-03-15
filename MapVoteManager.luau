local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapVoteManager = {}
MapVoteManager.__index = MapVoteManager

local function ensureRemote(name)
	local remote = ReplicatedStorage:FindFirstChild(name)
	if not remote then
		remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = ReplicatedStorage
	end
	return remote
end

local function cleanMapName(name)
	local trimmed = tostring(name or ""):gsub("Map$", "")
	if trimmed == "" then
		return "UNKNOWN MAP"
	end
	return trimmed:upper()
end

function MapVoteManager.new(serverStorage)
	local self = setmetatable({}, MapVoteManager)
	self.ServerStorage = serverStorage
	self.Remote = ensureRemote("MapVoteEvent")
	self.Active = false
	self.Candidates = {}
	self.VotesByUserId = {}
	self.VoteConnection = nil
	self.VoteEndsAt = 0

	Players.PlayerAdded:Connect(function()
		if self.Active then
			self:broadcastState(self.VoteEndsAt)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		if self.VotesByUserId[player.UserId] ~= nil then
			self.VotesByUserId[player.UserId] = nil
		end
		if self.Active then
			self:broadcastState(self.VoteEndsAt)
		end
	end)
	return self
end

function MapVoteManager:getAvailableMaps()
	local maps = {}
	local mapsFolder = self.ServerStorage:FindFirstChild("Maps")
	local source = (mapsFolder and mapsFolder:IsA("Folder")) and mapsFolder or self.ServerStorage

	for _, child in ipairs(source:GetChildren()) do
		local isCandidate = child:IsA("Model") or child:IsA("Folder")
		if source == self.ServerStorage then
			isCandidate = isCandidate and child.Name:match("Map$")
		end
		if isCandidate then
			table.insert(maps, child)
		end
	end
	table.sort(maps, function(a, b)
		return a.Name < b.Name
	end)
	return maps
end

function MapVoteManager:_buildCandidateData(mapTemplate, index)
	local sizeLabel = mapTemplate:GetAttribute("MapSizeLabel")
	if typeof(sizeLabel) ~= "string" or sizeLabel == "" then
		sizeLabel = "SIZE TBD"
	end
	return {
		id = index,
		templateName = mapTemplate.Name,
		displayName = mapTemplate:GetAttribute("MapDisplayName") or cleanMapName(mapTemplate.Name),
		sizeLabel = sizeLabel,
		image = mapTemplate:GetAttribute("MapImage") or "",
	}
end

function MapVoteManager:chooseCandidates()
	local available = self:getAvailableMaps()
	local chosen = {}
	for i = #available, 2, -1 do
		local j = math.random(1, i)
		available[i], available[j] = available[j], available[i]
	end

	for index = 1, math.min(3, #available) do
		table.insert(chosen, self:_buildCandidateData(available[index], index))
	end

	while #chosen < 3 do
		table.insert(chosen, {
			id = #chosen + 1,
			templateName = "",
			displayName = "COMING SOON",
			sizeLabel = "SIZE TBD",
			image = "",
			locked = true,
		})
	end

	self.Candidates = chosen
	return chosen
end

function MapVoteManager:_getVoteCounts()
	local counts = {}
	for _, candidate in ipairs(self.Candidates) do
		counts[candidate.templateName] = 0
	end
	for _, templateName in pairs(self.VotesByUserId) do
		if counts[templateName] ~= nil then
			counts[templateName] += 1
		end
	end
	return counts
end

function MapVoteManager:_buildStatePayload(endsAt)
	local counts = self:_getVoteCounts()
	local totalPlayers = math.max(1, #Players:GetPlayers())
	local options = {}

	for _, candidate in ipairs(self.Candidates) do
		local votes = counts[candidate.templateName] or 0
		local percent = math.floor(((votes / totalPlayers) * 100) + 0.5)
		table.insert(options, {
			id = candidate.id,
			templateName = candidate.templateName,
			displayName = candidate.displayName,
			sizeLabel = candidate.sizeLabel,
			image = candidate.image,
			locked = candidate.locked == true,
			votes = votes,
			percent = percent,
		})
	end

	return {
		options = options,
		endsAt = endsAt,
		totalPlayers = totalPlayers,
	}
end

function MapVoteManager:broadcastState(endsAt)
	self.Remote:FireAllClients("State", self:_buildStatePayload(endsAt))
end

function MapVoteManager:castVote(player, templateName, endsAt)
	if not self.Active or not player or typeof(templateName) ~= "string" then
		return
	end

	local isValid = false
	for _, candidate in ipairs(self.Candidates) do
		if candidate.templateName == templateName and candidate.locked ~= true then
			isValid = true
			break
		end
	end
	if not isValid then
		return
	end

	self.VotesByUserId[player.UserId] = templateName
	self:broadcastState(endsAt)
end

function MapVoteManager:_pickWinner()
	local counts = self:_getVoteCounts()
	local best = {}
	local bestVotes = -1

	for _, candidate in ipairs(self.Candidates) do
		if candidate.locked ~= true then
			local votes = counts[candidate.templateName] or 0
			if votes > bestVotes then
				bestVotes = votes
				best = {candidate}
			elseif votes == bestVotes then
				table.insert(best, candidate)
			end
		end
	end

	if #best == 0 then
		return {
			templateName = "IslandMap",
			displayName = "ISLAND",
		}
	end

	local winner = best[math.random(1, #best)]
	return {
		templateName = winner.templateName,
		displayName = winner.displayName,
	}
end

function MapVoteManager:runVote(duration)
	duration = duration or 10
	self.Active = true
	self.VotesByUserId = {}
	self:chooseCandidates()

	local endsAt = workspace:GetServerTimeNow() + duration
	self.VoteEndsAt = endsAt

	if self.VoteConnection then
		self.VoteConnection:Disconnect()
	end
	self.VoteConnection = self.Remote.OnServerEvent:Connect(function(player, action, templateName)
		if action == "Vote" then
			self:castVote(player, templateName, endsAt)
		end
	end)

	self.Remote:FireAllClients("Start", self:_buildStatePayload(endsAt))

	local started = tick()
	while tick() - started < duration do
		task.wait(0.25)
	end

	local winner = self:_pickWinner()
	self.Active = false
	self.VoteEndsAt = 0

	if self.VoteConnection then
		self.VoteConnection:Disconnect()
		self.VoteConnection = nil
	end

	self.Remote:FireAllClients("End", {
		winnerTemplateName = winner.templateName,
		winnerDisplayName = winner.displayName,
	})

	return winner.templateName, winner.displayName
end

return MapVoteManager
