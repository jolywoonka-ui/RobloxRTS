-- ServerStorage.Modules.ServerEvents (ModuleScript)
local ServerStorage = game:GetService("ServerStorage")

local ServerEvents = {}

local function ensureEvent(name)
	local ev = ServerStorage:FindFirstChild(name)
	if not ev then
		ev = Instance.new("BindableEvent")
		ev.Name = name
		ev.Parent = ServerStorage
	end
	return ev
end

ServerEvents.RoundStartEvent = ensureEvent("RoundStartEvent")
ServerEvents.SpawnUnitEvent = ensureEvent("SpawnUnitEvent")
ServerEvents.SpawnNeutralUnitEvent = ensureEvent("SpawnNeutralUnitEvent")
ServerEvents.ForceBuildEvent = ensureEvent("ForceBuildEvent")
ServerEvents.CheckVictoryEvent = ensureEvent("CheckVictoryEvent")

return ServerEvents