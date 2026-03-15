-- UnitAI.Movement (ModuleScript, ServerStorage)
local module = {}

local C
local State
local Blockers

function module.init(deps)
    deps = deps or {}
    C = deps.Constants
    State = deps.State
    Blockers = deps.Blockers
end

function module.enforceGroundKinematic(unit, root)
    if not root then
        return
    end

    for _, part in ipairs(unit:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.CollisionGroup = "Units"
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end

    local antiGravity = root:FindFirstChild("AntiGravity")
    if antiGravity and antiGravity:IsA("BodyForce") then
        antiGravity:Destroy()
    end
end

function module.updateUnitMovement(unit, state, dt)
    local root = State.getRoot(unit)
    if not root then
        return
    end

    local isAir = (unit:GetAttribute("Class") == "Air")
    if isAir then
        if state.State == "MOVING" and #state.Path > 0 then
            local targetPos = state.Path[1]
            local flightHeight = unit:GetAttribute("FlightHeight") or 10
            local targetY = Blockers.getAirTargetY(targetPos, unit, flightHeight)
            targetPos = Vector3.new(targetPos.X, targetY, targetPos.Z)

            local myPos = root.Position
            local dir = targetPos - myPos
            local dist = dir.Magnitude

            if dist <= C.STOP_DIST then
                table.remove(state.Path, 1)
                if #state.Path == 0 then
                    state.State = "IDLE"
                end
            else
                local speed = unit:GetAttribute("Speed") or 16
                local flatDir = Vector3.new(dir.X, 0, dir.Z)
                local flatDist = flatDir.Magnitude
                local moveXZ = Vector3.zero

                if flatDist > 0 then
                    local stepXZ = math.min(speed * dt, flatDist)
                    moveXZ = flatDir.Unit * stepXZ
                end

                local dy = dir.Y
                local maxDy = speed * dt * C.AIR_VERTICAL_MULT
                local stepY = 0
                if math.abs(dy) > 0.01 then
                    stepY = math.sign(dy) * math.min(math.abs(dy), maxDy)
                end

                local newPos = Vector3.new(myPos.X + moveXZ.X, myPos.Y + stepY, myPos.Z + moveXZ.Z)
                unit:PivotTo(CFrame.lookAt(newPos, newPos + dir.Unit) * CFrame.Angles(0, math.rad(90), 0))
            end
        end
        return
    end

    if (not state.GroundPrepared) or (not root.Anchored) then
        module.enforceGroundKinematic(unit, root)
        state.GroundPrepared = true
    end

    if (not state.GroundOffset) or (not state.UnitHeight) then
        Blockers.refreshGroundProfile(unit, state)
        local pos = root.Position
        local snapY = Blockers.getGroundSnapY(unit, pos, state)
        if math.abs(pos.Y - snapY) > 0.01 then
            local forward = root.CFrame.LookVector
            local flatForward = Vector3.new(forward.X, 0, forward.Z)
            if flatForward.Magnitude < 0.001 then
                flatForward = Vector3.new(1, 0, 0)
            end
            local snappedPos = Vector3.new(pos.X, snapY, pos.Z)
            unit:PivotTo(CFrame.lookAt(snappedPos, snappedPos + flatForward.Unit) * CFrame.Angles(0, math.rad(90), 0))
        end
    end

    if not (state.State == "MOVING" and #state.Path > 0) then
        return
    end

    local targetPos = state.Path[1]
    local myPos = root.Position
    local flatTarget = Vector3.new(targetPos.X, myPos.Y, targetPos.Z)
    local dir = flatTarget - myPos
    local dist = dir.Magnitude

    if dist <= C.STOP_DIST then
        table.remove(state.Path, 1)
        if #state.Path == 0 then
            state.State = "IDLE"
        end
        return
    end

    local speed = unit:GetAttribute("Speed") or 16
    local desiredDir = dir.Unit

    local stepDist = math.min(speed * dt, dist)
    local unsnappedPos = myPos + desiredDir * stepDist
    local snappedY = Blockers.getGroundSnapY(unit, unsnappedPos, state)
    local newPos = Vector3.new(unsnappedPos.X, snappedY, unsnappedPos.Z)

    if Blockers.canMoveTo(unit, myPos, newPos, state) then
        state.BlockedSince = nil
        unit:PivotTo(CFrame.lookAt(newPos, newPos + desiredDir) * CFrame.Angles(0, math.rad(90), 0))
        return
    end

    local movedBySlide = false

    local slideDir = Blockers.getSlideDirection(myPos, newPos, desiredDir, state)
    if slideDir then
        local slideRaw = myPos + slideDir * (stepDist * C.SLIDE_STEP_SCALE)
        local slideY = Blockers.getGroundSnapY(unit, slideRaw, state)
        local slidePos = Vector3.new(slideRaw.X, slideY, slideRaw.Z)
        if Blockers.canMoveTo(unit, myPos, slidePos, state) then
            state.BlockedSince = nil
            movedBySlide = true
            unit:PivotTo(CFrame.lookAt(slidePos, slidePos + slideDir) * CFrame.Angles(0, math.rad(90), 0))
        end
    end

    if not movedBySlide then
        local steerPos, steerDir = Blockers.findSteeredMove(myPos, targetPos, desiredDir, stepDist, state, unit)
        if steerPos and steerDir then
            state.BlockedSince = nil
            movedBySlide = true
            unit:PivotTo(CFrame.lookAt(steerPos, steerPos + steerDir) * CFrame.Angles(0, math.rad(90), 0))
        end
    end

    if not movedBySlide then
        local sideA = Vector3.new(-desiredDir.Z, 0, desiredDir.X)
        local sideB = -sideA
        local candidates = {
            myPos + sideA * (stepDist * C.SIDE_STEP_SCALE),
            myPos + sideB * (stepDist * C.SIDE_STEP_SCALE),
        }

        local bestPos = nil
        local bestDir = nil
        local bestDistToTarget = math.huge

        for i, raw in ipairs(candidates) do
            local sideDir = (i == 1) and sideA or sideB
            if sideDir.Magnitude > 0.001 then
                sideDir = sideDir.Unit
                local y = Blockers.getGroundSnapY(unit, raw, state)
                local pos = Vector3.new(raw.X, y, raw.Z)
                if Blockers.canMoveTo(unit, myPos, pos, state) then
                    local d2 = (Vector3.new(targetPos.X, pos.Y, targetPos.Z) - pos).Magnitude
                    if d2 < bestDistToTarget then
                        bestDistToTarget = d2
                        bestPos = pos
                        bestDir = sideDir
                    end
                end
            end
        end

        if bestPos and bestDir then
            state.BlockedSince = nil
            movedBySlide = true
            unit:PivotTo(CFrame.lookAt(bestPos, bestPos + bestDir) * CFrame.Angles(0, math.rad(90), 0))
        end
    end

    if not movedBySlide then
        local nowBlocked = tick()
        state.BlockedSince = state.BlockedSince or nowBlocked
        if nowBlocked - state.BlockedSince >= C.BLOCKED_ABORT_DELAY then
            state.Path = {}
            state.State = "IDLE"
            state.BlockedSince = nil
        end
    end
end

return module
