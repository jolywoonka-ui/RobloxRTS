-- UnitController_Main (LocalScript, StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local Selection = require(ReplicatedStorage:WaitForChild("UnitSelection"))
local PathVisuals = require(ReplicatedStorage:WaitForChild("UnitPathVisuals"))
local SquadManager = require(ReplicatedStorage:WaitForChild("UnitSquadManager"))
local InputHandler = require(ReplicatedStorage:WaitForChild("UnitInputHandler"))
local UIUnitInspector = require(ReplicatedStorage:WaitForChild("UIUnitInspector"))
local KeybindConfig = require(ReplicatedStorage:WaitForChild("KeybindConfig"))

local BASE_SQUAD_LIMIT = 5

-- Formation types
local FORMATIONS = {"none", "circle", "line", "grid", "wedge", "column"}
local currentFormationIndex = 1
local previewEnabled = false
local tooltipVisible = true
local ghostFolder = nil
local ghostUnits = {}
local ghostGroundOffsets = {}
local previewConnection = nil

local FORMATION_SPACING = 3.2
local FORMATION_DEPTH_SPACING = 2.7
local THEME = UIStyle.Theme

-- Remote events
local AttackEffect = ReplicatedStorage:WaitForChild("AttackEffect")
local MoveCommand = ReplicatedStorage:WaitForChild("MoveCommand")
local PingEvent = ReplicatedStorage:WaitForChild("PingEvent")
local WorldEffectEvent = ReplicatedStorage:WaitForChild("WorldEffectEvent")
local visualRotationOffsets = setmetatable({}, { __mode = "k" })
local cachedProjectileTemplates = {}

-- Load tooltip preference
local function loadTooltipPreference()
	local success, value = pcall(function()
		return player:GetAttribute("TooltipVisible")
	end)
	if success and value ~= nil then
		tooltipVisible = value
	end
end
loadTooltipPreference()

local function saveTooltipPreference()
	player:SetAttribute("TooltipVisible", tooltipVisible)
end

-- ==================== ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂºÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ/ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ (ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ "GUN") ====================
-- ==================== ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂºÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â£ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â§ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ/ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¹ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ (ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã¢â‚¬Å“ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ "GUN") ====================
local activeLasers = {}
local LASER_TIMEOUT = 0.3

local function getObjectPosition(obj)
	if obj and obj:IsA("BasePart") then return obj.Position end
	if obj and obj:IsA("Model") then
		local root = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
		if root then return root.Position end
		local ok, pivot = pcall(function()
			return obj:GetPivot()
		end)
		if ok then
			return pivot.Position
		end
	end
	return Vector3.zero
end

local function findAllGunParts(model)
	local guns = {}
	local function search(obj)
		if obj and obj:IsA("BasePart") and obj.Name == "Gun" then
			table.insert(guns, obj)
		end
		if obj then
			for _, child in pairs(obj:GetChildren()) do
				search(child)
			end
		end
	end
	if model and model:IsA("Model") then
		search(model)
	end
	return guns
end

local function getLaserStartPositions(unit)
	if not unit or not unit.Parent then return {} end
	local guns = findAllGunParts(unit)
	if #guns > 0 then
		local positions = {}
		for _, gun in ipairs(guns) do
			if gun and gun:IsA("BasePart") then
				table.insert(positions, gun.Position)
			end
		end
		return positions
	end
	if unit:IsA("BasePart") then
		return {unit.Position}
	end
	if unit:IsA("Model") then
		local root = unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
		if root and root:IsA("BasePart") then
			return {root.Position}
		end
		-- Fallback for models that streamed in without parts yet.
		return {getObjectPosition(unit)}
	end
	return {getObjectPosition(unit)}
end

local visualsFolder = workspace:FindFirstChild("LocalVisuals")
if not visualsFolder then
	visualsFolder = Instance.new("Folder")
	visualsFolder.Name = "LocalVisuals"
	visualsFolder.Parent = workspace
end

local randomGen = Random.new()

local function createLaser(profile, effectType)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = effectType == "Heal"
		and Color3.fromRGB(0, 255, 0)
		or ((profile and profile.laserColor) or Color3.fromRGB(255, 220, 50))
	part.Transparency = 0.3
	part.Size = Vector3.new((profile and profile.laserWidth) or 0.1, 0.1, (profile and profile.laserWidth) or 0.1)
	part.Parent = visualsFolder
	return part
end

local function updateLaser(part, startPos, endPos, width)
	local dir = endPos - startPos
	local length = dir.Magnitude
	if length < 0.5 then
		part.Transparency = 1
		return
	end
	part.Transparency = 0.3
	part.Size = Vector3.new(width or 0.1, length, width or 0.1)
	local mid = (startPos + endPos) / 2
	part.CFrame = CFrame.lookAt(mid, endPos) * CFrame.Angles(math.pi/2, 0, 0)
end

local function createPulseSphere(center, color, startRadius, endRadius, duration, startTransparency, endTransparency)
	local pulse = Instance.new("Part")
	pulse.Shape = Enum.PartType.Ball
	pulse.Anchored = true
	pulse.CanCollide = false
	pulse.CanQuery = false
	pulse.CastShadow = false
	pulse.Material = Enum.Material.Neon
	pulse.Color = color
	pulse.Transparency = startTransparency or 0.2
	pulse.Size = Vector3.new(startRadius * 2, startRadius * 2, startRadius * 2)
	pulse.CFrame = CFrame.new(center)
	pulse.Parent = visualsFolder

	task.spawn(function()
		local started = tick()
		while pulse.Parent do
			local alpha = math.clamp((tick() - started) / duration, 0, 1)
			local radius = startRadius + ((endRadius - startRadius) * alpha)
			pulse.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
			pulse.Transparency = (startTransparency or 0.2) + (((endTransparency or 1) - (startTransparency or 0.2)) * alpha)
			if alpha >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		pulse:Destroy()
	end)
end

local function spawnImpactStreaks(center, color, count, scale, lifetime)
	for _ = 1, count do
		local streak = Instance.new("Part")
		streak.Anchored = true
		streak.CanCollide = false
		streak.CanQuery = false
		streak.CastShadow = false
		streak.Material = Enum.Material.Neon
		streak.Color = color
		streak.Transparency = 0.1
		streak.Size = Vector3.new(0.12 * scale, 0.12 * scale, randomGen:NextNumber(0.8, 1.6) * scale)
		local yaw = randomGen:NextNumber(0, math.pi * 2)
		local pitch = randomGen:NextNumber(math.rad(15), math.rad(70))
		local dir = Vector3.new(math.cos(yaw) * math.cos(pitch), math.sin(pitch), math.sin(yaw) * math.cos(pitch))
		streak.CFrame = CFrame.lookAt(center, center + dir)
		streak.Parent = visualsFolder

		task.spawn(function()
			local started = tick()
			local origin = center
			local distance = randomGen:NextNumber(1.6, 3.2) * scale
			while streak.Parent do
				local alpha = math.clamp((tick() - started) / lifetime, 0, 1)
				local pos = origin:Lerp(origin + (dir * distance), alpha)
				streak.CFrame = CFrame.lookAt(pos, pos + dir)
				streak.Transparency = 0.1 + (alpha * 0.9)
				if alpha >= 1 then
					break
				end
				RunService.RenderStepped:Wait()
			end
			streak:Destroy()
		end)
	end
end

local function getAttackProfile(attacker, target, effectType)
	local isBuilding = target and not target:GetAttribute("IsUnit")
	if effectType == "Heal" then
		return {
			laserColor = Color3.fromRGB(120, 255, 140),
			laserWidth = 0.12,
			muzzleColor = Color3.fromRGB(120, 255, 140),
			impactColor = Color3.fromRGB(120, 255, 140),
			muzzleRadius = 0.45,
			impactRadius = 0.6,
			streakCount = 0,
		}
	end

	local profile = {
		laserColor = Color3.fromRGB(255, 224, 120),
		laserWidth = 0.12,
		muzzleColor = Color3.fromRGB(255, 210, 90),
		impactColor = isBuilding and Color3.fromRGB(255, 165, 95) or Color3.fromRGB(255, 220, 120),
		muzzleRadius = 0.45,
		impactRadius = isBuilding and 0.95 or 0.65,
		streakCount = isBuilding and 3 or 1,
		streakScale = isBuilding and 0.9 or 0.65,
	}

	local unitName = attacker and attacker.Name or ""
	if unitName == "LightTank" then
		profile.laserColor = Color3.fromRGB(255, 218, 128)
		profile.laserWidth = 0.14
		profile.muzzleRadius = 0.55
		profile.impactRadius = isBuilding and 1.05 or 0.8
		profile.streakCount = isBuilding and 4 or 2
	elseif unitName == "Tank" then
		profile.laserColor = Color3.fromRGB(255, 174, 92)
		profile.laserWidth = 0.18
		profile.muzzleColor = Color3.fromRGB(255, 152, 78)
		profile.impactColor = isBuilding and Color3.fromRGB(255, 128, 72) or Color3.fromRGB(255, 176, 96)
		profile.muzzleRadius = 0.8
		profile.impactRadius = isBuilding and 1.45 or 1.05
		profile.streakCount = isBuilding and 6 or 3
		profile.streakScale = isBuilding and 1.15 or 0.9
	elseif unitName == "CAS" then
		profile.laserColor = Color3.fromRGB(255, 190, 96)
		profile.laserWidth = 0.16
		profile.muzzleRadius = 0.65
		profile.impactRadius = isBuilding and 1.25 or 0.95
		profile.streakCount = isBuilding and 5 or 3
		profile.streakScale = 0.95
	elseif unitName == "AttackHelicopter" then
		profile.laserColor = Color3.fromRGB(255, 208, 104)
		profile.laserWidth = 0.14
		profile.muzzleRadius = 0.55
		profile.impactRadius = isBuilding and 1.1 or 0.85
		profile.streakCount = isBuilding and 4 or 2
	end

	return profile
end

local function emitDirectShotFX(attacker, target, profile, impactPosOverride)
	local targetPos = impactPosOverride or getObjectPosition(target)
	if not targetPos then
		return
	end

	for _, startPos in ipairs(getLaserStartPositions(attacker)) do
		createPulseSphere(startPos, profile.muzzleColor, profile.muzzleRadius * 0.55, profile.muzzleRadius, 0.12, 0.18, 0.95)
	end

	local impactCenter = targetPos + Vector3.new(0, 0.2, 0)
	createPulseSphere(impactCenter, profile.impactColor, profile.impactRadius * 0.35, profile.impactRadius, 0.16, 0.16, 0.96)
	createPulseSphere(impactCenter, profile.impactColor:Lerp(Color3.new(1, 1, 1), 0.35), profile.impactRadius * 0.18, profile.impactRadius * 0.55, 0.1, 0.05, 1)
	if (profile.streakCount or 0) > 0 then
		spawnImpactStreaks(impactCenter, profile.impactColor, profile.streakCount, profile.streakScale or 0.75, 0.18)
	end
end

AttackEffect.OnClientEvent:Connect(function(attacker, target, effectType, impactPos)
	if not attacker then return end
	if not attacker.Parent then return end
	if not target and typeof(impactPos) ~= "Vector3" then return end
	local now = tick()
	local data = activeLasers[attacker]
	local profile = getAttackProfile(attacker, target, effectType)
	local liveTarget = target and target.Parent

	if liveTarget and data then
		data.lastUpdate = now
		data.target = target
		data.effectType = effectType
		data.profile = profile
	elseif liveTarget then
		local startPositions = getLaserStartPositions(attacker)
		local parts = {}
		for _ = 1, #startPositions do
			local part = createLaser(profile, effectType)
			table.insert(parts, part)
		end
		activeLasers[attacker] = {
			parts = parts,
			target = target,
			effectType = effectType,
			lastUpdate = now,
			profile = profile,
		}
	end

	emitDirectShotFX(attacker, target, profile, impactPos)
end)

RunService.Heartbeat:Connect(function()
	local now = tick()
	for unit, data in pairs(activeLasers) do
		if not unit or not unit.Parent then
			for _, part in ipairs(data.parts) do
				if part then part:Destroy() end
			end
			activeLasers[unit] = nil
		elseif now - data.lastUpdate > LASER_TIMEOUT then
			for _, part in ipairs(data.parts) do
				if part then part:Destroy() end
			end
			activeLasers[unit] = nil
		else
			local startPositions = getLaserStartPositions(unit)
			local targetObj = data.target
			if not targetObj or not targetObj.Parent then
				for _, part in ipairs(data.parts) do
					if part then part:Destroy() end
				end
				activeLasers[unit] = nil
				return
			end
			local endPos
			if targetObj:IsA("BasePart") then
				endPos = targetObj.Position
			elseif targetObj:IsA("Model") then
				local root = targetObj.PrimaryPart or targetObj:FindFirstChildWhichIsA("BasePart")
				endPos = root and root.Position or getObjectPosition(targetObj)
			else
				endPos = getObjectPosition(targetObj)
			end
			if endPos then
				for i, part in ipairs(data.parts) do
					local startPos = startPositions[i] or (startPositions[1] or getObjectPosition(unit))
					updateLaser(part, startPos, endPos, data.profile and data.profile.laserWidth)
					if data.profile and data.profile.laserColor then
						part.Color = data.profile.laserColor
					end
				end
			end
		end
	end
end)

workspace.DescendantRemoving:Connect(function(desc)
	for unit, data in pairs(activeLasers) do
		if unit == desc or data.target == desc then
			for _, part in ipairs(data.parts) do
				if part then part:Destroy() end
			end
			activeLasers[unit] = nil
		end
	end
end)

local function quadraticArc(startPos, targetPos, arcHeight, t)
	local control = (startPos + targetPos) * 0.5 + Vector3.new(0, arcHeight, 0)
	local a = startPos:Lerp(control, t)
	local b = control:Lerp(targetPos, t)
	return a:Lerp(b, t)
end

local function makeTrailPart(color, size)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size or Vector3.new(0.6, 0.6, 2.4)
	part.Parent = visualsFolder
	return part
end

local function findEffectTemplate(name)
	local effectsFolder = ReplicatedStorage:FindFirstChild("Effects")
	return effectsFolder and effectsFolder:FindFirstChild(name)
end

local cachedProjectileTemplates = {}

local function getProcessedProjectileTemplate(templateName, teamColor)
	local cacheKey = tostring(templateName) .. "_" .. tostring(teamColor)
	if cachedProjectileTemplates[cacheKey] then
		return cachedProjectileTemplates[cacheKey]:Clone()
	end

	local baseTemplate = findEffectTemplate(templateName)
	if not baseTemplate then
		return nil
	end

	local clone = baseTemplate:Clone()

	if typeof(teamColor) == "Color3" and clone:IsA("BasePart") and clone.Name == "TeamPaint" then
		clone.Color = teamColor
	end

	for _, inst in ipairs(clone:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanQuery = false
			if inst.Name == "TeamPaint" and typeof(teamColor) == "Color3" then
				inst.Color = teamColor
			end
		elseif inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		end
	end

	cachedProjectileTemplates[cacheKey] = clone
	return clone:Clone()
end

local function createProjectileVisual(templateName, color, size, options)
	if templateName then
		local clone = getProcessedProjectileTemplate(templateName, options and options.teamColor)
		if clone then
			if clone:IsA("Model") then
				visualRotationOffsets[clone] = clone:GetPivot().Rotation
			end
			clone.Parent = visualsFolder
			return clone
		end
	end
	return makeTrailPart(color, size)
end

local function setVisualCFrame(visual, cf)
	if visual:IsA("Model") then
		if not visual.PrimaryPart then
			local primary = visual:FindFirstChildWhichIsA("BasePart", true)
			if primary then
				visual.PrimaryPart = primary
			end
		end
		if visual.PrimaryPart then
			local baseRotation = visualRotationOffsets[visual]
			visual:PivotTo(baseRotation and (cf * baseRotation) or cf)
		end
	else
		visual.CFrame = cf
	end
end

local function makeUpAlignedCFrame(pos, lookPos, planarHint)
	local direction = lookPos - pos
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 1, 0)
	else
		direction = direction.Unit
	end

	local heading = planarHint
	if typeof(heading) ~= "Vector3" or heading.Magnitude < 0.05 then
		heading = Vector3.new(direction.X, 0, direction.Z)
	end
	if heading.Magnitude < 0.05 then
		heading = Vector3.new(0, 0, -1)
	else
		heading = heading.Unit
	end

	local right = heading:Cross(direction)
	if right.Magnitude < 0.05 then
		right = Vector3.new(0, 1, 0):Cross(direction)
	end
	if right.Magnitude < 0.05 then
		right = Vector3.new(1, 0, 0):Cross(direction)
	end
	right = right.Unit

	local back = right:Cross(direction).Unit
	return CFrame.fromMatrix(pos, right, direction, back)
end

local function spawnTrailSegment(startPos, endPos, color)
	local length = (endPos - startPos).Magnitude
	if length <= 0.15 then
		return
	end

	local segment = Instance.new("Part")
	segment.Anchored = true
	segment.CanCollide = false
	segment.CanQuery = false
	segment.CastShadow = false
	segment.Material = Enum.Material.Neon
	segment.Color = color
	segment.Transparency = 0.18
	segment.Size = Vector3.new(0.35, 0.35, length)
	segment.CFrame = CFrame.lookAt((startPos + endPos) * 0.5, endPos)
	segment.Parent = visualsFolder

	task.spawn(function()
		local started = tick()
		local lifetime = 0.7
		while segment.Parent do
			local alpha = math.clamp((tick() - started) / lifetime, 0, 1)
			segment.Transparency = 0.18 + (alpha * 0.8)
			segment.Size = Vector3.new(0.35 + (alpha * 0.35), 0.35 + (alpha * 0.35), length)
			if alpha >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		segment:Destroy()
	end)
end

local function animateArcVisual(startPos, targetPos, travelTime, arcHeight, color, size, templateName, options)
	local visual = createProjectileVisual(templateName, color, size, options)
	local planarHint = Vector3.new(targetPos.X - startPos.X, 0, targetPos.Z - startPos.Z)
	task.spawn(function()
		local started = tick()
		local previousTrailPos = startPos
		local lastTrailAt = 0
		while visual and visual.Parent do
			local alpha = math.clamp((tick() - started) / travelTime, 0, 1)
			local pos = quadraticArc(startPos, targetPos, arcHeight, alpha)
			local nextAlpha = math.min(1, alpha + 0.02)
			local lookPos = quadraticArc(startPos, targetPos, arcHeight, nextAlpha)
			if (lookPos - pos).Magnitude < 0.1 then
				lookPos = targetPos
			end
			local cf = options and options.alignUp and makeUpAlignedCFrame(pos, lookPos, planarHint) or CFrame.lookAt(pos, lookPos)
			setVisualCFrame(visual, cf)
			if options and options.trailColor and (tick() - lastTrailAt) >= (options.trailInterval or 0.06) then
				spawnTrailSegment(previousTrailPos, pos, options.trailColor)
				previousTrailPos = pos
				lastTrailAt = tick()
			end
			if alpha >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		if visual then
			visual:Destroy()
		end
	end)
end

local function createExpandingSphere(center, duration, maxRadius, color)
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.CastShadow = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = color
	sphere.Transparency = 0.45
	sphere.Size = Vector3.new(2, 2, 2)
	sphere.CFrame = CFrame.new(center)
	sphere.Parent = visualsFolder

	task.spawn(function()
		local started = tick()
		while sphere.Parent do
			local alpha = math.clamp((tick() - started) / duration, 0, 1)
			local radius = math.max(1, maxRadius * alpha)
			sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
			sphere.Transparency = 0.35 + (alpha * 0.6)
			if alpha >= 1 then
				break
			end
			RunService.RenderStepped:Wait()
		end
		sphere:Destroy()
	end)
end

local function emitArtilleryImpactFX(center, radius)
	local blastColor = Color3.fromRGB(255, 155, 80)
	local visualRadius = math.max(1.8, radius * 0.58)
	createExpandingSphere(center, 0.38, visualRadius, blastColor)
	createPulseSphere(center + Vector3.new(0, 0.2, 0), Color3.fromRGB(255, 222, 170), 0.55, math.max(1.0, visualRadius * 0.45), 0.12, 0.08, 1)
	spawnImpactStreaks(center + Vector3.new(0, 0.2, 0), blastColor, 6, 0.9, 0.2)
end

local function emitMissileImpactFX(center, radius, duration)
	local outerColor = Color3.fromRGB(255, 110, 60)
	local innerColor = Color3.fromRGB(255, 220, 170)
	local coreRadius = math.max(2.6, radius * 0.38)
	local outerRadius = math.max(4, radius * 1.05)

	createPulseSphere(center + Vector3.new(0, 0.6, 0), innerColor, 1.4, coreRadius, 0.16, 0.04, 1)
	createExpandingSphere(center, duration, outerRadius, outerColor)
	task.delay(0.08, function()
		createExpandingSphere(center + Vector3.new(0, 0.3, 0), duration * 0.65, math.max(3, radius * 0.72), Color3.fromRGB(255, 150, 90))
	end)
	task.delay(0.16, function()
		createPulseSphere(center + Vector3.new(0, 0.4, 0), Color3.fromRGB(255, 245, 210), 0.8, math.max(2.2, radius * 0.3), 0.22, 0.08, 1)
	end)
	spawnImpactStreaks(center + Vector3.new(0, 0.5, 0), outerColor, 18, math.max(1.8, radius * 0.08), 0.42)
end

local function showPingMarker(senderName, worldPos)
	local marker = Instance.new("Part")
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CastShadow = false
	marker.Material = Enum.Material.Neon
	marker.Color = Color3.fromRGB(80, 220, 255)
	marker.Size = Vector3.new(1.2, 8, 1.2)
	marker.CFrame = CFrame.new(worldPos + Vector3.new(0, 4, 0))
	marker.Parent = visualsFolder

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 150, 0, 36)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.Parent = marker

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = string.upper(senderName .. " PING")
	label.TextColor3 = Color3.fromRGB(210, 250, 255)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Parent = gui

	Debris:AddItem(marker, 3)
end

PingEvent.OnClientEvent:Connect(function(senderName, worldPos)
	if typeof(worldPos) == "Vector3" then
		showPingMarker(senderName or "ALLY", worldPos)
	end
end)

WorldEffectEvent.OnClientEvent:Connect(function(effectType, data)
	if type(data) ~= "table" then
		return
	end
	if effectType == "ArtilleryShot" then
		animateArcVisual(data.startPos, data.targetPos, data.travelTime or 1.5, data.arcHeight or 35, Color3.fromRGB(255, 210, 90), Vector3.new(0.6, 0.6, 2.6), nil)
		task.delay(data.travelTime or 1.5, function()
			emitArtilleryImpactFX(data.targetPos, data.explosionRadius or 10)
		end)
	elseif effectType == "MissileLaunch" then
		local teamColor = typeof(data.teamColor) == "Color3" and data.teamColor or Color3.fromRGB(255, 120, 80)
		local trailColor = teamColor:Lerp(Color3.fromRGB(255, 220, 180), 0.45)
		animateArcVisual(
			data.startPos,
			data.targetPos,
			data.travelTime or 4,
			data.arcHeight or 120,
			Color3.fromRGB(255, 120, 80),
			Vector3.new(1.2, 1.2, 4),
			"MissileRocket",
			{
				alignUp = true,
				teamColor = teamColor,
				trailColor = trailColor,
				trailInterval = 0.05,
			}
		)
		task.delay(data.travelTime or 4, function()
			emitMissileImpactFX(data.targetPos, data.explosionRadius or 60, data.explosionDuration or 7)
		end)
	end
end)

-- ==================== ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂºÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¾ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â (ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â±ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â· ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â·ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â½ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â½ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¹) ====================

-- Create formation tooltip UI
local playerGui = player:WaitForChild("PlayerGui")
local tooltipGui = Instance.new("ScreenGui")
tooltipGui.Name = "FormationTooltipGui"
tooltipGui.ResetOnSpawn = false
tooltipGui.IgnoreGuiInset = true
tooltipGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
tooltipGui.Parent = playerGui

local tooltip = Instance.new("Frame", tooltipGui)
tooltip.Name = "Tooltip"
tooltip.Size = UDim2.new(0, 332, 0, 132)
tooltip.Position = UDim2.new(0, 10, 0, 10)
tooltip.BorderSizePixel = 0
tooltip.Visible = false
UIStyle.applyPanel(tooltip, "background")
UIStyle.addShadow(tooltip, 0.82)

local tooltipHeader = Instance.new("TextLabel", tooltip)
tooltipHeader.Size = UDim2.new(1, -20, 0, 20)
tooltipHeader.Position = UDim2.new(0, 10, 0, 10)
tooltipHeader.BackgroundTransparency = 1
tooltipHeader.Text = "FORMATION CONTROL"
tooltipHeader.TextColor3 = THEME.SubText
tooltipHeader.Font = THEME.FontBody
tooltipHeader.TextSize = 11
tooltipHeader.TextXAlignment = Enum.TextXAlignment.Left

local textLabel = Instance.new("TextLabel", tooltip)
textLabel.Size = UDim2.new(1, -20, 0, 28)
textLabel.Position = UDim2.new(0, 10, 0, 28)
textLabel.BackgroundTransparency = 1
textLabel.TextColor3 = THEME.Text
textLabel.Font = THEME.FontHeader
textLabel.TextSize = 19
textLabel.TextXAlignment = Enum.TextXAlignment.Left
textLabel.TextYAlignment = Enum.TextYAlignment.Top

local tooltipBody = Instance.new("TextLabel", tooltip)
tooltipBody.Size = UDim2.new(1, -20, 0, 64)
tooltipBody.Position = UDim2.new(0, 10, 0, 58)
tooltipBody.BackgroundTransparency = 1
tooltipBody.TextColor3 = THEME.SubText
tooltipBody.Font = THEME.FontBody
tooltipBody.TextSize = 12
tooltipBody.TextXAlignment = Enum.TextXAlignment.Left
tooltipBody.TextYAlignment = Enum.TextYAlignment.Top
tooltipBody.TextWrapped = true

local function updateTooltipText()
	if not tooltipVisible then
		tooltip.Visible = false
		return
	end
	local formation = FORMATIONS[currentFormationIndex]
	local previewState = previewEnabled and "ON" or "OFF"
	textLabel.Text = formation:upper()
	tooltipBody.Text = string.format(
		"Preview: %s\n[R] Cycle formation  [T] Toggle preview\n[E] Deselect units  [H] Hide tooltip",
		previewState
	)
end

local function updateTooltip()
	if not tooltipVisible then
		tooltip.Visible = false
		return
	end
	local selected = Selection.getSelected()
	if #selected <= 1 then
		tooltip.Visible = false
		return
	end
	tooltip.Visible = true
	local mousePos = UserInputService:GetMouseLocation()
	local screenSize = workspace.CurrentCamera.ViewportSize
	local newX = math.min(mousePos.X + 20, screenSize.X - tooltip.AbsoluteSize.X - 10)
	local newY = math.min(mousePos.Y - 70, screenSize.Y - tooltip.AbsoluteSize.Y - 10)
	newY = math.max(newY, 10)
	tooltip.Position = UDim2.new(0, newX, 0, newY)
	updateTooltipText()
end

-- ==================== GHOST PREVIEW SYSTEM ====================
local function getAverageUnitPosition()
	local selected = Selection.getSelected()
	if #selected == 0 then return Vector3.zero end
	local sum = Vector3.zero
	local count = 0
	for _, unit in ipairs(selected) do
		local root = unit:IsA("Model") and (unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")) or unit
		if root then
			sum += root.Position
			count += 1
		end
	end
	return count > 0 and sum / count or Vector3.zero
end

local function getMouseGroundPos()
	local ray = player:GetMouse().UnitRay
	local params = RaycastParams.new()
	local ignoreList = {player.Character}
	if ghostFolder then
		table.insert(ignoreList, ghostFolder)
	end
	local map = workspace:FindFirstChild("CurrentMap")
	if map then
		local army = map:FindFirstChild("Army")
		local buildings = map:FindFirstChild("PlayerBuildings")
		local walls = map:FindFirstChild("Walls")
		if army then table.insert(ignoreList, army) end
		if buildings then table.insert(ignoreList, buildings) end
		if walls then table.insert(ignoreList, walls) end
	end
	params.FilterDescendantsInstances = ignoreList
	params.FilterType = Enum.RaycastFilterType.Exclude
	local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
	if result then
		return result.Position
	end
	return ray.Origin + ray.Direction * 1000
end

local function getGroundAtXZ(x, z, fallbackY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignoreList = {player.Character}
	if ghostFolder then
		table.insert(ignoreList, ghostFolder)
	end
	local map = workspace:FindFirstChild("CurrentMap")
	if map then
		local army = map:FindFirstChild("Army")
		local buildings = map:FindFirstChild("PlayerBuildings")
		local walls = map:FindFirstChild("Walls")
		if army then table.insert(ignoreList, army) end
		if buildings then table.insert(ignoreList, buildings) end
		if walls then table.insert(ignoreList, walls) end
	end
	params.FilterDescendantsInstances = ignoreList
	local originY = (fallbackY or 0) + 220
	local result = workspace:Raycast(Vector3.new(x, originY, z), Vector3.new(0, -520, 0), params)
	if result then
		return result.Position.Y
	end
	return fallbackY or 0
end

local function getFormationPositions(targetPos, count, formation, direction)
	local spacing = FORMATION_SPACING
	local positions = {}
	local forward = direction.Unit
	local right = Vector3.new(forward.Z, 0, -forward.X)

	if formation == "none" then
		for i = 1, count do
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
			local offset = right * (i - (count+1)/2) * (spacing * 0.9)
			table.insert(positions, targetPos + offset)
		end
	elseif formation == "grid" then
		local cols = math.ceil(math.sqrt(count))
		local rows = math.ceil(count / cols)
		local colSpacing = spacing * 0.9
		local rowSpacing = FORMATION_DEPTH_SPACING
		local startX = -(cols-1) * colSpacing / 2
		local startZ = -(rows-1) * rowSpacing / 2
		for i = 1, count do
			local col = (i-1) % cols
			local row = math.floor((i-1) / cols)
			local offset = right * (startX + col * colSpacing) + forward * (startZ + row * rowSpacing)
			table.insert(positions, targetPos + offset)
		end
	elseif formation == "wedge" then
		local rows = math.ceil(math.sqrt(count))
		local idx = 1
		for row = 0, rows-1 do
			local unitsInRow = row + 1
			for col = 1, unitsInRow do
				if idx > count then break end
				local offsetX = (col - (unitsInRow+1)/2) * (spacing * 0.9)
				local offsetZ = -row * (FORMATION_DEPTH_SPACING * 0.95)
				local offset = right * offsetX + forward * offsetZ
				table.insert(positions, targetPos + offset)
				idx = idx + 1
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

local function createGhosts()
	if ghostFolder then
		ghostFolder:Destroy()
	end
	ghostFolder = Instance.new("Folder")
	ghostFolder.Name = "FormationGhosts"
	ghostFolder.Parent = workspace

	local selected = Selection.getSelected()
	ghostUnits = {}
	table.clear(ghostGroundOffsets)

	local function computeGroundOffset(unit)
		if unit:IsA("Model") then
			local ok, boxCFrame, size = pcall(function()
				local cf, s = unit:GetBoundingBox()
				return cf, s
			end)
			if ok and boxCFrame and size then
				local pivotY = unit:GetPivot().Position.Y
				local bottomY = boxCFrame.Position.Y - (size.Y * 0.5)
				return math.max(0.15, pivotY - bottomY)
			end
			local root = unit.PrimaryPart or unit:FindFirstChildWhichIsA("BasePart")
			if root then
				return math.max(0.15, root.Size.Y * 0.5)
			end
		elseif unit:IsA("BasePart") then
			return math.max(0.15, unit.Size.Y * 0.5)
		end
		return 0.5
	end

	for _, unit in ipairs(selected) do
		local ghost = unit:Clone()
		ghost.Name = "Ghost_" .. unit.Name
		for _, part in ipairs(ghost:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0.7
				part.Material = Enum.Material.Neon
				part.Color = Color3.fromRGB(0, 200, 255)
				part.CanCollide = false
				part.Anchored = true
				part.CanQuery = false
			elseif part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 0.7
			end
		end
		local hum = ghost:FindFirstChildOfClass("Humanoid")
		if hum then hum:Destroy() end
		ghost.Parent = ghostFolder
		table.insert(ghostUnits, ghost)
		ghostGroundOffsets[ghost] = computeGroundOffset(ghost)
	end
end

local function destroyGhosts()
	if ghostFolder then
		ghostFolder:Destroy()
		ghostFolder = nil
	end
	ghostUnits = {}
	table.clear(ghostGroundOffsets)
end

local function startGhostPreview()
	if previewConnection then previewConnection:Disconnect() end
	previewConnection = RunService.RenderStepped:Connect(function()
		if not ghostFolder or not previewEnabled then return end
		local targetPos = getMouseGroundPos()
		local avgPos = getAverageUnitPosition()
		local direction = (targetPos - avgPos) * Vector3.new(1, 0, 1)
		if direction.Magnitude < 0.1 then
			direction = Vector3.new(1, 0, 0)
		end
		local count = #ghostUnits
		if count == 0 then return end
		local formation = FORMATIONS[currentFormationIndex]
		local positions = getFormationPositions(targetPos, count, formation, direction)
		for i, ghost in ipairs(ghostUnits) do
			if ghost and ghost.Parent then
				local pos = positions[i] or targetPos
				local groundY = getGroundAtXZ(pos.X, pos.Z, targetPos.Y)
				local offsetY = ghostGroundOffsets[ghost] or 0.5
				pos = Vector3.new(pos.X, groundY + offsetY - 0.03, pos.Z)
				ghost:PivotTo(CFrame.lookAt(pos, pos + direction) * CFrame.Angles(0, math.rad(90), 0))
			end
		end
	end)
end

-- ==================== INPUT HANDLING ====================
local function updateInputHandlerFormation()
	InputHandler.setFormation(FORMATIONS[currentFormationIndex])
end
updateInputHandlerFormation()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.R then
		local selected = Selection.getSelected()
		if #selected > 1 then
			currentFormationIndex = currentFormationIndex % #FORMATIONS + 1
			updateInputHandlerFormation()
			updateTooltip()
		end
	elseif input.KeyCode == Enum.KeyCode.E then
		Selection.deselectAll()
	elseif input.KeyCode == Enum.KeyCode.T then
		local selected = Selection.getSelected()
		if #selected > 1 then
			previewEnabled = not previewEnabled
			if previewEnabled then
				if not ghostFolder then createGhosts() end
				startGhostPreview()
			else
				destroyGhosts()
				if previewConnection then
					previewConnection:Disconnect()
					previewConnection = nil
				end
			end
			updateTooltip()
		end
	elseif input.KeyCode.Name == KeybindConfig.PingKey then
		local pingPos = getMouseGroundPos()
		if pingPos then
			PingEvent:FireServer(pingPos)
		end
	elseif input.KeyCode == Enum.KeyCode.H then
		tooltipVisible = not tooltipVisible
		saveTooltipPreference()
		if tooltipVisible then
			updateTooltip()
		else
			tooltip.Visible = false
		end
	end
end)

-- ==================== SQUAD CALLBACKS ====================
SquadManager.setCallbacks({
	onAddToSquad = function(squadData)
		local selected = Selection.getSelected()
		local space = squadData.Limit - #squadData.Units
		if space > 0 then
			local toAdd = {}
			for i = 1, math.min(#selected, space) do
				table.insert(toAdd, selected[i])
			end
			SquadManager.addToSquad(squadData, toAdd)
		end
	end,
	onSelectSquad = function(squadData)
		if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			Selection.deselectAll()
		end
		for _, u in ipairs(squadData.Units) do
			Selection.selectUnit(u)
		end
	end,
	onCreateSquad = function()
		local selected = Selection.getSelected()
		if #selected == 0 then return end
		local limit = BASE_SQUAD_LIMIT
		local squadUnits = {}
		for i = 1, math.min(#selected, limit) do
			table.insert(squadUnits, selected[i])
		end
		SquadManager.createSquad(squadUnits, limit)
	end,
	onSelectUnit = function(unit)
		if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
			Selection.deselectAll()
		end
		Selection.selectUnit(unit)
	end
})

-- ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¦ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â»ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â½ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Âµ ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¿ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â²ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¶ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â½ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â´ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â²ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¶ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â½ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¾ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â²ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂµÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â° ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¿ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â‚¬Å¾Ã‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Â¦Ãƒâ€šÃ‚Â¡ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ (ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¼ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â°ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¹Ã…â€œÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¸ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚ÂÃƒÆ’Ã†â€™ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â²)
MoveCommand.OnClientEvent:Connect(function(unitList, pathArray)
	if not pathArray then return end
	for i, unit in ipairs(unitList) do
		local waypoints = pathArray[i] or {}
		PathVisuals.updatePath(unit, waypoints)
	end
end)

-- InputHandler initialization
InputHandler.initialize(Selection, PathVisuals, SquadManager)

-- Selection change
Selection.onSelectionChanged(function(selected)
	if #selected == 0 then
		UIUnitInspector.hide()
		tooltip.Visible = false
		destroyGhosts()
		previewEnabled = false
	elseif #selected == 1 then
		if UIUnitInspector.showForUnit then
			UIUnitInspector.showForUnit(selected[1])
		else
			warn("UIUnitInspector.showForUnit is nil")
		end
		tooltip.Visible = false
		destroyGhosts()
		previewEnabled = false
	else
		if UIUnitInspector.showForMultiple then
			UIUnitInspector.showForMultiple(#selected)
		else
			warn("UIUnitInspector.showForMultiple is nil")
		end
		updateTooltip()
		if previewEnabled then
			createGhosts()
			startGhostPreview()
		end
	end
end)

-- Continuously update tooltip position to follow mouse
RunService.RenderStepped:Connect(function()
	if tooltip.Visible and tooltipVisible then
		local mousePos = UserInputService:GetMouseLocation()
		local screenSize = workspace.CurrentCamera.ViewportSize
		local newX = math.min(mousePos.X + 20, screenSize.X - tooltip.AbsoluteSize.X - 10)
		local newY = math.min(mousePos.Y - 70, screenSize.Y - tooltip.AbsoluteSize.Y - 10)
		newY = math.max(newY, 10)
		tooltip.Position = UDim2.new(0, newX, 0, newY)
	end
end)

-- Game state handling
local function updateGameState()
	local inGame = (player.Team and player.Team.Name ~= "Lobby")
	print("updateGameState called, inGame =", inGame)
	SquadManager.showUI(inGame)
	
end
player:GetPropertyChangedSignal("Team"):Connect(updateGameState)
updateGameState()

RunService.RenderStepped:Connect(function()
	InputHandler.updateHover()
end)

print("UnitController_Main loaded with optimized laser effects")








