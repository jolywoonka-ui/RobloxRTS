-- UnitAI.Commands (ModuleScript, ServerStorage)
local module = {}

local State
local Blockers
local FORMATION_SPACING = 3.2
local FORMATION_DEPTH_SPACING = 2.7

function module.init(deps)
    deps = deps or {}
    State = deps.State
    Blockers = deps.Blockers
end

local function getAverageUnitPosition(units)
    local sum = Vector3.zero
    local count = 0
    for _, unit in ipairs(units) do
        sum += State.getPosition(unit)
        count += 1
    end
    return count > 0 and sum / count or Vector3.zero
end

local function getFormationPositions(targetPos, count, formation, forward, right)
    local spacing = FORMATION_SPACING
    local positions = {}

    if formation == "none" or count <= 1 then
        for _ = 1, count do
            table.insert(positions, targetPos)
        end
    elseif formation == "circle" then
        local radius = math.max(spacing * 0.85, (count * spacing * 0.92) / (2 * math.pi))
        for i = 1, count do
            local angle = ((i - 1) / count) * math.pi * 2
            local offset = right * math.cos(angle) * radius + forward * math.sin(angle) * radius
            table.insert(positions, targetPos + offset)
        end
    elseif formation == "line" then
        for i = 1, count do
            local offset = right * (i - (count + 1) / 2) * (spacing * 0.9)
            table.insert(positions, targetPos + offset)
        end
    elseif formation == "grid" then
        local cols = math.ceil(math.sqrt(count))
        local rows = math.ceil(count / cols)
        local colSpacing = spacing * 0.9
        local rowSpacing = FORMATION_DEPTH_SPACING
        local startX = -(cols - 1) * colSpacing / 2
        local startZ = -(rows - 1) * rowSpacing / 2
        for i = 1, count do
            local col = (i - 1) % cols
            local row = math.floor((i - 1) / cols)
            local offset = right * (startX + col * colSpacing) + forward * (startZ + row * rowSpacing)
            table.insert(positions, targetPos + offset)
        end
    elseif formation == "wedge" then
        local rows = math.ceil(math.sqrt(count))
        local idx = 1
        for row = 0, rows - 1 do
            local unitsInRow = row + 1
            for col = 1, unitsInRow do
                if idx > count then break end
                local offsetX = (col - (unitsInRow + 1) / 2) * (spacing * 0.9)
                local offsetZ = -row * (FORMATION_DEPTH_SPACING * 0.95)
                local offset = right * offsetX + forward * offsetZ
                table.insert(positions, targetPos + offset)
                idx += 1
            end
        end
    elseif formation == "column" then
        for i = 1, count do
            local sideOffset = (count > 3 and ((i % 2 == 0) and -1 or 1) or 0) * (spacing * 0.18)
            local offset = right * sideOffset + forward * (-(i - 1) * FORMATION_DEPTH_SPACING)
            table.insert(positions, targetPos + offset)
        end
    else
        local radius = math.max(spacing * 0.85, (count * spacing * 0.92) / (2 * math.pi))
        for i = 1, count do
            local angle = ((i - 1) / count) * math.pi * 2
            local offset = right * math.cos(angle) * radius + forward * math.sin(angle) * radius
            table.insert(positions, targetPos + offset)
        end
    end

    return positions
end

function module.handleMoveCommand(player, unitList, targetPos, isQueued, formation, moveCommand)
    if not unitList then
        return
    end

    local count = #unitList
    local pathData = {}

    if count <= 1 or formation == "none" then
        for _, unit in ipairs(unitList) do
            if unit and unit.Parent and unit:GetAttribute("Owner") == player.Name then
                local state = State.getState(unit)
                local pos = targetPos

                if unit:GetAttribute("Class") ~= "Air" then
                    if (not state.GroundOffset) or (not state.UnitHeight) then
                        Blockers.refreshGroundProfile(unit, state)
                    end
                    local fromPos = State.getPosition(unit)
                    pos = Blockers.clampGroundTarget(unit, fromPos, Vector3.new(targetPos.X, fromPos.Y, targetPos.Z), state)
                end

                if isQueued then
                    table.insert(state.Path, pos)
                else
                    state.Path = {pos}
                end
                state.State = "MOVING"
                pathData[unit] = state.Path
            end
        end
    else
        local avgPos = getAverageUnitPosition(unitList)
        local direction = (targetPos - avgPos) * Vector3.new(1, 0, 1)
        if direction.Magnitude < 0.1 then
            direction = Vector3.new(1, 0, 0)
        end

        local forward = direction.Unit
        local right = Vector3.new(forward.Z, 0, -forward.X)
        local positions = getFormationPositions(targetPos, count, formation, forward, right)

        for i, unit in ipairs(unitList) do
            if unit and unit.Parent and unit:GetAttribute("Owner") == player.Name then
                local state = State.getState(unit)
                local pos = positions[i] or targetPos

                if unit:GetAttribute("Class") ~= "Air" then
                    if (not state.GroundOffset) or (not state.UnitHeight) then
                        Blockers.refreshGroundProfile(unit, state)
                    end
                    local fromPos = State.getPosition(unit)
                    local flatPos = Vector3.new(pos.X, fromPos.Y, pos.Z)
                    pos = Blockers.clampGroundTarget(unit, fromPos, flatPos, state)
                end

                if isQueued then
                    table.insert(state.Path, pos)
                else
                    state.Path = {pos}
                end
                state.State = "MOVING"
                pathData[unit] = state.Path
            end
        end
    end

    local pathArray = {}
    for _, unit in ipairs(unitList) do
        table.insert(pathArray, pathData[unit] or {})
    end

    if moveCommand then
        moveCommand:FireClient(player, unitList, pathArray)
    end

    return pathArray
end

return module
