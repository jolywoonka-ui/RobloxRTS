-- BunkerManager (ModuleScript, ServerStorage)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")
local Config = require(ReplicatedStorage:WaitForChild("BuildingConfig"))

local BunkerManager = {}
BunkerManager.__index = BunkerManager

function BunkerManager.new(mapModel)
	local self = setmetatable({}, BunkerManager)
	self.MapModel = mapModel
	self.OccupiedBunkers = {} -- building -> {garrison = {unit objects references?} но мы будем хранить JSON}
	return self
end

function BunkerManager:toggle(bunker, player)
	if not bunker or not bunker.Parent then return end
	if bunker:GetAttribute("Owner") ~= player.Name then return end

	local bType = bunker:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	if not bData or not bData.Capacity then return end

	local garrisonJson = bunker:GetAttribute("Garrison") or "[]"
	local success, garrison = pcall(HttpService.JSONDecode, HttpService, garrisonJson)
	if not success or type(garrison) ~= "table" then garrison = {} end

	local pos = bunker:GetPivot().Position
	local range = 6
	local army = self.MapModel and self.MapModel:FindFirstChild("Army")

	if #garrison == 0 then
		-- Загрузка: ищем пехоту рядом
		local nearby = {}
		if army then
			for _, unit in pairs(army:GetChildren()) do
				if unit:GetAttribute("Owner") == player.Name and unit:GetAttribute("Class") == "Infantry" then
					local dist = (unit:GetPivot().Position - pos).Magnitude
					if dist <= range then
						table.insert(nearby, unit)
					end
				end
			end
		end
		if #nearby > 0 then
			local toLoad = {}
			for i = 1, math.min(#nearby, bData.Capacity) do
				table.insert(toLoad, nearby[i])
			end
			for _, unit in ipairs(toLoad) do
				local info = {
					Name = unit.Name,
					Health = unit:GetAttribute("Health") or 100,
					MaxHealth = unit:GetAttribute("MaxHealth") or 100,
					Supply = unit:GetAttribute("Supply") or 1,
				}
				table.insert(garrison, info)
				unit.Parent = nil
				task.spawn(function() unit:Destroy() end)
			end
			local newJson = HttpService:JSONEncode(garrison)
			bunker:SetAttribute("Garrison", newJson)
			bunker:SetAttribute("GarrisonCount", #garrison)

			-- Обновляем радиус и урон
			self:updateBunkerStats(bunker, bData, #garrison)
		end
	else
		-- Выгрузка: ищем место для высадки (используем findGroundNearby из UnitTransport, можно вынести общую функцию)
		-- Для простоты используем UnitSpawner.findSafeSpawnPosition
		local spawnPos = pos + Vector3.new(0, 2, 0)
		for _, info in ipairs(garrison) do
			local template = ReplicatedStorage.Units:FindFirstChild(info.Name)
			if template then
				local newUnit = template:Clone()
				newUnit.Name = info.Name
				local safeCFrame = UnitSpawner.findSafeSpawnPosition(CFrame.new(spawnPos), newUnit, 5, 0)
				newUnit:PivotTo(safeCFrame)
				-- ... установка атрибутов (как в UnitSpawner) – можно вынести в отдельную функцию
				-- Упрощённо:
				newUnit:SetAttribute("Owner", player.Name)
				newUnit:SetAttribute("IsUnit", true)
				newUnit:SetAttribute("Health", info.Health)
				newUnit:SetAttribute("MaxHealth", info.MaxHealth)
				-- остальные атрибуты...
				newUnit.Parent = army
			end
		end
		bunker:SetAttribute("Garrison", HttpService:JSONEncode({}))
		bunker:SetAttribute("GarrisonCount", 0)
		self:updateBunkerStats(bunker, bData, 0)
	end
end

function BunkerManager:updateBunkerStats(bunker, bData, count)
	if count > 0 then
		bunker:SetAttribute("Range", bData.RangeGarrisoned)
		bunker:SetAttribute("Damage", count * bData.DamagePerSoldier)
	else
		bunker:SetAttribute("Range", bData.RangeEmpty or 0)
		bunker:SetAttribute("Damage", 0)
	end
end

-- При уничтожении бункера убиваем гарнизон
function BunkerManager:onBunkerDestroyed(bunker)
	local garrisonJson = bunker:GetAttribute("Garrison") or "[]"
	local success, garrison = pcall(HttpService.JSONDecode, HttpService, garrisonJson)
	if success and #garrison > 0 then
		local ownerName = bunker:GetAttribute("Owner")
		local player = ownerName and Players:FindFirstChild(ownerName)
		if player then
			local ps = player:FindFirstChild("PlayerStats")
			if ps and ps:FindFirstChild("CurrentUnits") then
				local totalSupply = 0
				for _, info in ipairs(garrison) do
					totalSupply = totalSupply + (info.Supply or 1)
				end
				ps.CurrentUnits.Value = math.max(0, ps.CurrentUnits.Value - totalSupply)
			end
		end
	end
end

return BunkerManager