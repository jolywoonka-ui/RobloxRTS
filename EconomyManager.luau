-- EconomyManager (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.BuildingConfig)

local EconomyManager = {}
EconomyManager.__index = EconomyManager

function EconomyManager.new(mapModel, hqManager)
	local self = setmetatable({}, EconomyManager)
	self.MapModel = mapModel
	self.HQManager = hqManager
	self.TickRate = Config.TickRate or 5
	self.BaseIncome = Config.BaseIncome or 10
	return self
end

function EconomyManager:start()
	task.spawn(function()
		while true do
			task.wait(self.TickRate)
			self:tick()
		end
	end)
end

function EconomyManager:tick()
	if not self.MapModel or not self.HQManager then return end
	local pBuildings = self.MapModel:FindFirstChild("PlayerBuildings", true)
	if not pBuildings then return end

	for i = 1, 6 do
		local owner = self.HQManager:getSlotOwnerName(i)
		local ownerPlayer = owner and Players:FindFirstChild(owner) or nil
		local ownerAlliance = ownerPlayer and ownerPlayer:GetAttribute("AllianceID") or self.HQManager:getSlotAllianceID(i)

		local totalIncome = self.BaseIncome

		for _, b in pairs(pBuildings:GetChildren()) do
			local bOwner = b:GetAttribute("Owner")
			if bOwner then
				local belongs = false
				if owner and bOwner == owner then
					belongs = true
				elseif ownerAlliance then
					local bOwnerPlayer = Players:FindFirstChild(bOwner)
					if bOwnerPlayer then
						local bAlliance = bOwnerPlayer:GetAttribute("AllianceID")
						if bAlliance and bAlliance == ownerAlliance then
							belongs = true
						end
					end
				end

				if belongs then
					local bData = Config.Buildings[b:GetAttribute("Type")]
					if bData and bData.Income then
						totalIncome += bData.Income
					end
				end
			end
		end

		if ownerPlayer then
			local stats = ownerPlayer:FindFirstChild("Stats")
			if stats then
				stats.Credits.Value += totalIncome
			end
		else
			self.HQManager:addToTreasury(i, totalIncome)
		end
	end
end

return EconomyManager
