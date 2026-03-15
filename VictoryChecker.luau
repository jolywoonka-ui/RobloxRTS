-- VictoryChecker (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VictoryChecker = {}
VictoryChecker.__index = VictoryChecker

function VictoryChecker.new(mapModel, gameState)
	local self = setmetatable({}, VictoryChecker)
	self.MapModel = mapModel
	self.GameState = gameState
	self.ShowVictoryStats = ReplicatedStorage:FindFirstChild("ShowVictoryStats")
	return self
end

function VictoryChecker:check()
	if not self.GameState.Active then 
		print("Victory check skipped: game not active")
		return 
	end

	print("=== VICTORY CHECK START ===")
	local groupCounts = {}
	local groupPlayers = {}
	local neutralCount = 0

	local pBuildings = self.MapModel and self.MapModel:FindFirstChild("PlayerBuildings", true)
	if not pBuildings then 
		print("No PlayerBuildings folder")
		return 
	end

	for _, b in pairs(pBuildings:GetChildren()) do
		if b.Name:match("^Headquarter") then
			local health = b:GetAttribute("Health")
			if not health then
				local hum = b:FindFirstChild("Humanoid")
				health = hum and hum.Health or 0
			end
			print("Found HQ:", b.Name, "Health:", health, "Owner:", b:GetAttribute("Owner"))
			if health and health > 0 then
				local owner = b:GetAttribute("Owner")
				if owner then
					local player = Players:FindFirstChild(owner)
					if player then
						local allianceID = player:GetAttribute("AllianceID")
						local groupKey = allianceID or ("player_" .. player.UserId)
						groupCounts[groupKey] = (groupCounts[groupKey] or 0) + 1
						if not groupPlayers[groupKey] then
							groupPlayers[groupKey] = {}
						end
						table.insert(groupPlayers[groupKey], player.Name)
						print("  -> belongs to group:", groupKey)
					else
						print("  -> owner player not found, treating as neutral")
						neutralCount += 1
					end
				else
					print("  -> no owner, neutral")
					neutralCount += 1
				end
			else
				print("  -> health <= 0, ignoring")
			end
		end
	end

	local totalAlive = neutralCount
	local groupsAlive = 0
	local lastGroup = nil
	print("Group counts:")
	for group, count in pairs(groupCounts) do
		print("  Group", group, "has", count, "HQs, players:", table.concat(groupPlayers[group], ", "))
		totalAlive += count
		groupsAlive += 1
		lastGroup = group
	end
	print("Neutral HQs alive:", neutralCount)
	print("Total alive HQs:", totalAlive)
	print("Number of groups with HQs:", groupsAlive)

	if totalAlive == 0 and #Players:GetPlayers() > 0 then
		print("No HQs left, draw")
		self.GameState.StatusValue.Value = "DRAW - NO SURVIVORS"
		task.wait(5)
		self.GameState:endRound()
		return
	elseif groupsAlive == 1 and neutralCount == 0 then
		print("Only one group remains and no neutrals, victory!")
		local winnerNames = groupPlayers[lastGroup] or {}
		local winnerText = table.concat(winnerNames, ", ")
		self.GameState.StatusValue.Value = "WINNER: " .. winnerText

		local allPlayers = Players:GetPlayers()
		local personalStats = {}
		local globalMost = {
			moneySpent = {player = "", value = -1},
			unitsRecruited = {player = "", value = -1},
			damageDealt = {player = "", value = -1}
		}

		for _, p in ipairs(allPlayers) do
			local ps = p:FindFirstChild("PlayerStats")
			if ps then
				local money = ps:FindFirstChild("MoneySpent") and ps.MoneySpent.Value or 0
				local units = ps:FindFirstChild("UnitsRecruited") and ps.UnitsRecruited.Value or 0
				local damage = ps:FindFirstChild("DamageDealt") and ps.DamageDealt.Value or 0

				table.insert(personalStats, {
					name = p.Name,
					moneySpent = money,
					unitsRecruited = units,
					damageDealt = damage
				})

				if money > globalMost.moneySpent.value then
					globalMost.moneySpent.player = p.Name
					globalMost.moneySpent.value = money
				end
				if units > globalMost.unitsRecruited.value then
					globalMost.unitsRecruited.player = p.Name
					globalMost.unitsRecruited.value = units
				end
				if damage > globalMost.damageDealt.value then
					globalMost.damageDealt.player = p.Name
					globalMost.damageDealt.value = damage
				end
			end
		end

		self.ShowVictoryStats:FireAllClients({
			winners = winnerText,
			personalStats = personalStats,
			globalMost = globalMost
		})

		task.wait(8)
		self.GameState:endRound()
	else
		print("Victory condition not met: groupsAlive=", groupsAlive, "neutralCount=", neutralCount)
	end
	print("=== VICTORY CHECK END ===")
end

return VictoryChecker