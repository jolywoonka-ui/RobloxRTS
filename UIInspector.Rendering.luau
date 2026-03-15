-- UIInspector.Rendering (ModuleScript, ReplicatedStorage)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local module = {}

local theme
local unitsFolder
local createText
local addCorner
local addStroke
local runService
local userInputService

local unitTooltipFrame
local unitTooltipTitle
local unitTooltipBody
local tooltipConn

local function getUnitCode(name)
	local cleaned = string.gsub(name or "U", "[^%a]", "")
	if #cleaned >= 2 then
		return string.upper(string.sub(cleaned, 1, 2))
	elseif #cleaned == 1 then
		return string.upper(cleaned) .. "U"
	end
	return "UN"
end

function module.init(options)
	theme = options.theme
	unitsFolder = options.unitsFolder
	createText = options.createText
	addCorner = options.addCorner
	addStroke = options.addStroke
	runService = options.runService
	userInputService = options.userInputService

	if not unitTooltipFrame then
		unitTooltipFrame = Instance.new("Frame", options.mainScreen)
		unitTooltipFrame.Size = UDim2.new(0, 250, 0, 170)
		unitTooltipFrame.BackgroundColor3 = UIStyle.Theme.Background
		unitTooltipFrame.BorderSizePixel = 0
		unitTooltipFrame.Visible = false
		unitTooltipFrame.ZIndex = 60
		addCorner(unitTooltipFrame, UDim.new(0, 4))
		addStroke(unitTooltipFrame, 1, theme.Stroke)

		unitTooltipTitle = createText(unitTooltipFrame, "UNIT", UDim2.new(1, -16, 0, 24), UDim2.new(0, 8, 0, 6), Enum.Font.GothamBold, theme.Text, Enum.TextXAlignment.Left, theme)
		unitTooltipTitle.TextSize = 14
		unitTooltipTitle.ZIndex = 61

unitTooltipBody = createText(unitTooltipFrame, "", UDim2.new(1, -16, 1, -36), UDim2.new(0, 8, 0, 30), Enum.Font.GothamMedium, theme.SubText, Enum.TextXAlignment.Left, theme)
		unitTooltipBody.TextSize = 12
		unitTooltipBody.TextYAlignment = Enum.TextYAlignment.Top
		unitTooltipBody.ZIndex = 61
	end

	if not tooltipConn then
		tooltipConn = runService.RenderStepped:Connect(function()
			if not unitTooltipFrame or not unitTooltipFrame.Visible then
				return
			end
			local mousePos = userInputService:GetMouseLocation()
			local cam = workspace.CurrentCamera
			local viewport = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			local tooltipSize = unitTooltipFrame.AbsoluteSize
			local x = math.clamp(mousePos.X + 14, 0, viewport.X - tooltipSize.X - 6)
			local y = math.clamp(mousePos.Y + 14, 0, viewport.Y - tooltipSize.Y - 6)
			unitTooltipFrame.Position = UDim2.fromOffset(x, y)
		end)
	end
end

function module.getClassColor(className)
	if className == "Infantry" then
		return Color3.fromRGB(77, 186, 255)
	elseif className == "Vehicle" then
		return Color3.fromRGB(255, 179, 76)
	elseif className == "Air" then
		return Color3.fromRGB(147, 135, 255)
	end
	return theme and theme.Accent or Color3.fromRGB(0, 140, 255)
end

function module.getUnitRoleText(unitName, uData)
	local roles = {
		Militia = "Cheap line infantry",
		Soldier = "Line infantry",
		EliteSoldier = "Veteran frontline infantry",
		AASoldier = "Portable air denial",
		LightTank = "Fast light armor",
		Tank = "Frontline armor",
		Transport = "Rapid troop carrier",
		AATank = "Sky denial vehicle",
		Artillery = "Siege platform",
		Fighter = "Air superiority",
		CAS = "Ground strike",
		AttackHelicopter = "Hunter-killer gunship",
		TransportHelicopter = "Airlift support",
	}
	return roles[unitName] or tostring(uData and uData.Description or "Combat unit")
end

function module.formatUnitDisplayName(unitName)
	local name = tostring(unitName or "UNIT")
	name = name:gsub("([a-z])([A-Z])", "%1 %2")
	name = name:gsub("AA(%u)", "AA %1")
	return string.upper(name)
end

function module.createChip(parent, text, color)
	local chip = Instance.new("Frame")
	chip.Size = UDim2.new(0, 0, 0, 18)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.BackgroundColor3 = color:Lerp(Color3.fromRGB(10, 10, 12), 0.72)
	chip.BorderSizePixel = 0
	chip.Parent = parent
	addCorner(chip, UDim.new(0, 2))
	addStroke(chip, 1, color:Lerp(Color3.new(1, 1, 1), 0.2))

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = chip

	local label = createText(chip, text, UDim2.new(1, 0, 1, 0), UDim2.new(0, 0, 0, 0), Enum.Font.GothamBold, color, Enum.TextXAlignment.Center, theme)
	label.TextSize = 11
	return chip
end

function module.renderUnitViewport(container, unitName)
	for _, child in ipairs(container:GetChildren()) do
		child:Destroy()
	end

	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, 0, 1, 0)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(180, 180, 180)
	viewport.LightColor = Color3.fromRGB(245, 245, 245)
	viewport.LightDirection = Vector3.new(-1, -1, -1)
	viewport.Parent = container

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local template = unitsFolder and unitsFolder:FindFirstChild(unitName)
	if not template then
		local fallback = createText(container, getUnitCode(unitName), UDim2.new(1, 0, 1, 0), UDim2.new(), Enum.Font.GothamBold, theme.Text, Enum.TextXAlignment.Center, theme)
		fallback.TextSize = 14
		return
	end

	local model = template:Clone()
	for _, inst in ipairs(model:GetDescendants()) do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
		elseif inst:IsA("Script") or inst:IsA("LocalScript") then
			inst:Destroy()
		end
	end

	if model:IsA("Model") and not model.PrimaryPart then
		local primary = model:FindFirstChildWhichIsA("BasePart")
		if primary then
			model.PrimaryPart = primary
		end
	end

	model.Parent = viewport
	local cf, size = model:GetBoundingBox()
	local radius = math.max(size.X, size.Y, size.Z)
	local focus = cf.Position
	camera.FieldOfView = 36
	camera.CFrame = CFrame.new(focus + Vector3.new(radius * 1.18, radius * 0.46, radius * 1.18), focus)
end

function module.createInfoRow(parent, labelText, valueText, valueColor)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -24, 0, 22)
	row.BackgroundColor3 = theme.PanelSoft
	row.BorderSizePixel = 0
	row.Parent = parent
	addCorner(row, UDim.new(0, 3))
	addStroke(row, 1, theme.Stroke)

	local lbl = createText(row, labelText, UDim2.new(0.55, -10, 1, 0), UDim2.new(0, 10, 0, 0), Enum.Font.GothamMedium, theme.SubText, Enum.TextXAlignment.Left, theme)
	lbl.TextSize = 12

	local val = createText(row, valueText, UDim2.new(0.45, -10, 1, 0), UDim2.new(0.55, 0, 0, 0), Enum.Font.GothamBold, valueColor or theme.Text, Enum.TextXAlignment.Right, theme)
	val.TextSize = 13

	return row
end

function module.hideUnitTooltip()
	if unitTooltipFrame then
		unitTooltipFrame.Visible = false
	end
end

function module.showUnitTooltip(unitName, uData, unlockDepth, isLocked, lockHint)
	if not unitTooltipFrame or not unitTooltipTitle or not unitTooltipBody or not uData then
		return
	end

	unitTooltipTitle.Text = string.upper(unitName or "UNIT")
	unitTooltipTitle.TextColor3 = isLocked and Color3.fromRGB(255, 180, 120) or theme.Text

	local lines = {
		"Class: " .. tostring(uData.Class or "Unit"),
		"Cost: $" .. tostring(uData.Cost or 0),
		"Training: " .. tostring(uData.TrainingTime or 0) .. "s",
		"Units: " .. tostring(uData.Supply or 1),
		"HP: " .. tostring(uData.Health or 0),
	}
	if (uData.Damage or 0) > 0 then
		table.insert(lines, "Damage: " .. tostring(uData.Damage))
	end
	if (uData.Range or 0) > 0 then
		table.insert(lines, "Range: " .. tostring(uData.Range))
	end

	if isLocked then
		table.insert(lines, lockHint or ("Locked: unlock after +" .. tostring(unlockDepth) .. " upgrade"))
	else
		table.insert(lines, "Click to train")
	end

	unitTooltipBody.Text = table.concat(lines, "\n")
	unitTooltipFrame.Visible = true
end

return module
