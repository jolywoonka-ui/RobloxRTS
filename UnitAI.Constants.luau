-- UnitAI.Constants (ModuleScript, ServerStorage)
local module = {
    STOP_DIST = 0.8,
    AVOIDANCE_RADIUS = 2.0,
    AVOIDANCE_FORCE = 0.3,
    RAY_HEIGHT = 0.5,
    GROUND_SNAP_BIAS = 0.05,
    AIR_GLIDE_OFFSET = 1.5,
    AIR_HEIGHT_FACTOR = 0.75,
    AIR_VERTICAL_MULT = 4,
    SLIDE_STEP_SCALE = 0.9,
    SIDE_STEP_SCALE = 0.6,
    BLOCKED_ABORT_DELAY = 0.55,
    UNIT_COLLISION_PADDING = 0.25,
    ALLY_UNIT_COLLISION_MULT = 0.9,
    ENEMY_UNIT_COLLISION_MULT = 1.08,
    STEER_ANGLES_DEG = {15, -15, 30, -30, 45, -45, 60, -60},
    NON_WALKABLE_MATERIALS = {
        [Enum.Material.Rock] = true,
        [Enum.Material.ForceField] = true,
    },
}

return module
