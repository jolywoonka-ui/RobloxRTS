-- UnitPhysics (ModuleScript, ServerStorage)
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local UnitPhysics = {}

function UnitPhysics.createHealthBar(unit, maxHealth)
	local bg = Instance.new("BillboardGui", unit)
	bg.Name = "HP_Gui"
	bg.Size = UDim2.new(4, 0, 0.5, 0)
	bg.StudsOffset = Vector3.new(0, 4, 0)
	bg.AlwaysOnTop = true
	bg.MaxDistance = 200
	bg.Enabled = false

	local barBg = Instance.new("Frame", bg)
	barBg.Size = UDim2.new(1, 0, 1, 0)
	barBg.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
	barBg.BorderSizePixel = 0
	Instance.new("UICorner", barBg).CornerRadius = UDim.new(0, 4)

	local stroke = Instance.new("UIStroke", barBg)
	stroke.Color = Color3.new(0.3, 0.3, 0.3)
	stroke.Thickness = 1

	local fill = Instance.new("Frame", barBg)
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.new(0, 1, 0)
	fill.BorderSizePixel = 0
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local gradient = Instance.new("UIGradient", fill)
	gradient.Color = ColorSequence.new{
		ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 200, 0))
	}
	gradient.Rotation = 90

	return bg, fill, gradient
end

return UnitPhysics