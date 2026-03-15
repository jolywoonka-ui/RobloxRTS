-- UnitAI (Script, ServerScriptService)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local AttackEffect = ReplicatedStorage:FindFirstChild("AttackEffect")
if not AttackEffect then
    AttackEffect = Instance.new("RemoteEvent")
    AttackEffect.Name = "AttackEffect"
    AttackEffect.Parent = ReplicatedStorage
end

local MoveCommand = ReplicatedStorage:FindFirstChild("MoveCommand")
if not MoveCommand then
    MoveCommand = Instance.new("RemoteEvent")
    MoveCommand.Name = "MoveCommand"
    MoveCommand.Parent = ReplicatedStorage
end

local Config = require(ReplicatedStorage:FindFirstChild("BuildingConfig") or ReplicatedStorage.BuildingConfig)

local function requireUnitAIModule(shortName)
    local directName = "UnitAI." .. shortName
    local moduleScript = ServerStorage:FindFirstChild(directName)

    if not moduleScript then
        local folder = ServerStorage:FindFirstChild("UnitAI")
        if folder then
            moduleScript = folder:FindFirstChild(shortName) or folder:FindFirstChild(directName)
        end
    end

    assert(moduleScript and moduleScript:IsA("ModuleScript"), "Missing UnitAI module: " .. directName)
    return require(moduleScript)
end

local Constants = requireUnitAIModule("Constants")
local State = requireUnitAIModule("State")
local Blockers = requireUnitAIModule("Blockers")
local Movement = requireUnitAIModule("Movement")
local Combat = requireUnitAIModule("Combat")
local Builder = requireUnitAIModule("Builder")
local Commands = requireUnitAIModule("Commands")

Blockers.init({
    Players = Players,
    Constants = Constants,
    getRoot = State.getRoot,
})

Movement.init({
    Constants = Constants,
    State = State,
    Blockers = Blockers,
})

Combat.init({
    Players = Players,
    State = State,
})

Builder.init({
    Players = Players,
    State = State,
})

Commands.init({
    State = State,
    Blockers = Blockers,
})

RunService.Heartbeat:Connect(function(dt)
    Blockers.ensureMapQueryEnabled()
    Blockers.ensureBlockerPartsCache()

    local map = workspace:FindFirstChild("CurrentMap")
    if not map then
        return
    end

    local army = map:FindFirstChild("Army")
    if not army then
        return
    end

    local buildings = map:FindFirstChild("PlayerBuildings")
    local now = tick()

    for _, unit in pairs(army:GetChildren()) do
        local hp = unit:GetAttribute("Health")
        if not (hp and hp > 0 and unit.Parent) then
            State.clearState(unit)
            continue
        end

        local state = State.getState(unit)
        local root = State.getRoot(unit)
        if not root then
            continue
        end

        Movement.updateUnitMovement(unit, state, dt)

        if unit.Name == "Builder" then
            Builder.tryBuild(unit, dt, AttackEffect, Config)
        else
            Combat.updateCombat(unit, state, now, army, buildings, AttackEffect)
        end
    end
end)

MoveCommand.OnServerEvent:Connect(function(player, unitList, targetPos, isQueued, formation)
    if type(unitList) ~= "table" or typeof(targetPos) ~= "Vector3" then
        return
    end
    Commands.handleMoveCommand(player, unitList, targetPos, isQueued, formation, MoveCommand)
end)

print("UnitAI - modular movement/combat/commands loaded")
