-- UnitAI.State (ModuleScript, ServerStorage)
local module = {}

local unitState = setmetatable({}, {__mode = "k"})

function module.getState(unit)
    local state = unitState[unit]
    if not state then
        state = {
            Path = {},
            State = "IDLE",
            LastFire = 0,
            NextScan = 0,
            Target = nil,
            GroundPrepared = false,
        }
        unitState[unit] = state

        unit.AncestryChanged:Connect(function()
            if not unit.Parent then
                unitState[unit] = nil
            end
        end)
    end
    return state
end

function module.clearState(unit)
    unitState[unit] = nil
end

function module.getPosition(obj)
    if obj:IsA("BasePart") then
        return obj.Position
    end
    if obj:IsA("Model") then
        return obj:GetPivot().Position
    end
    return Vector3.zero
end

function module.getRoot(unit)
    if unit:IsA("Model") then
        return unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
    end
    return unit
end

return module
