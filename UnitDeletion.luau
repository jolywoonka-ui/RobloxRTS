-- UnitDeletion (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local UnitDeletion = {}

local function killPassengers(transport, player)
	local passengerJson = transport:GetAttribute("Passengers")
	if passengerJson and passengerJson ~= "" then
		local success, passengers = pcall(HttpService.JSONDecode, HttpService, passengerJson)
		if success and type(passengers) == "table" then
			local totalSupply = 0
			for _, info in ipairs(passengers) do
				totalSupply = totalSupply + (info.Supply or 1)
			end
			local ps = player and player:FindFirstChild("PlayerStats")
			if ps and ps:FindFirstChild("CurrentUnits") then
				ps.CurrentUnits.Value = math.max(0, ps.CurrentUnits.Value - totalSupply)
			end
		end
	end
	local refFolder = transport:FindFirstChild("LoadedUnits")
	if refFolder then
		for _, ref in ipairs(refFolder:GetChildren()) do
			if ref:IsA("ObjectValue") and ref.Value then
				ref.Value:Destroy()
			end
		end
		refFolder:Destroy()
	end
	transport:SetAttribute("Passengers", HttpService:JSONEncode({}))
	transport:SetAttribute("PassengerCount", 0)
end

function UnitDeletion.deleteUnits(player, units)
	print("DeleteUnit called by", player.Name, "units:", units)
	if not units then return end
	local unitList = type(units) == "table" and units or {units}
	if #unitList > 100 then return end

	local ps = player:FindFirstChild("PlayerStats")
	local currentUnits = ps and ps:FindFirstChild("CurrentUnits")

	for _, unit in ipairs(unitList) do
		if typeof(unit) == "Instance" and unit.Parent and unit:GetAttribute("Owner") == player.Name then
			local supply = unit:GetAttribute("Supply") or 1

			local isTransport = (unit:GetAttribute("Capacity") ~= nil) and ((unit:GetAttribute("Damage") or 0) == 0)
			if isTransport then
				killPassengers(unit, player)
			end

			if currentUnits then
				currentUnits.Value = math.max(0, currentUnits.Value - supply)
				print("CurrentUnits decreased by", supply)
			end

			print("Deleting unit:", unit.Name)
			unit:Destroy()
		end
	end
end

return UnitDeletion
