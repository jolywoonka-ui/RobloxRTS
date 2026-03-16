local UIStyle = {}

UIStyle.Theme = {
	Background = Color3.fromRGB(38, 39, 44),
	Panel = Color3.fromRGB(44, 45, 51),
	PanelAlt = Color3.fromRGB(33, 34, 39),
	PanelSoft = Color3.fromRGB(50, 52, 58),
	Card = Color3.fromRGB(35, 36, 41),
	CardAlt = Color3.fromRGB(42, 43, 49),
	CardSoft = Color3.fromRGB(28, 125, 228),
	Inset = Color3.fromRGB(28, 29, 34),
	Accent = Color3.fromRGB(28, 144, 255),
	AccentSoft = Color3.fromRGB(47, 89, 142),
	Highlight = Color3.fromRGB(28, 144, 255),
	Alert = Color3.fromRGB(150, 88, 88),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(242, 244, 247),
	MutedText = Color3.fromRGB(208, 212, 218),
	Positive = Color3.fromRGB(92, 152, 102),
	Negative = Color3.fromRGB(150, 88, 88),
	Warning = Color3.fromRGB(170, 132, 78),
	Amber = Color3.fromRGB(170, 132, 78),
	Green = Color3.fromRGB(92, 152, 102),
	Red = Color3.fromRGB(150, 88, 88),
	BlueWarm = Color3.fromRGB(118, 134, 158),
	Selection = Color3.fromRGB(255, 255, 255),
	Stroke = Color3.fromRGB(108, 112, 120),
	Divider = Color3.fromRGB(74, 77, 84),
	Shadow = Color3.fromRGB(4, 4, 6),
	Corner = UDim.new(0, 10),
	SmallCorner = UDim.new(0, 6),
	FontMain = Enum.Font.GothamBold,
	FontBody = Enum.Font.GothamBold,
	FontHeader = Enum.Font.GothamBold,
}

function UIStyle.addCorner(obj, radius)
	local existing = obj:FindFirstChildOfClass("UICorner")
	if existing then
		existing.CornerRadius = radius or UIStyle.Theme.Corner
		return existing
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UIStyle.Theme.Corner
	corner.Parent = obj
	return corner
end

function UIStyle.addStroke(obj, thickness, color, transparency)
	local stroke = obj:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = obj
	end
	stroke.Thickness = thickness or 1
	stroke.Color = color or UIStyle.Theme.Stroke
	if transparency ~= nil then
		stroke.Transparency = transparency
	else
		stroke.Transparency = 0
	end
	return stroke
end

function UIStyle.addPadding(obj, left, right, top, bottom)
	local padding = obj:FindFirstChildOfClass("UIPadding")
	if not padding then
		padding = Instance.new("UIPadding")
		padding.Parent = obj
	end
	padding.PaddingLeft = UDim.new(0, left or 0)
	padding.PaddingRight = UDim.new(0, right or left or 0)
	padding.PaddingTop = UDim.new(0, top or 0)
	padding.PaddingBottom = UDim.new(0, bottom or top or 0)
	return padding
end

function UIStyle.addShadow(obj, transparency)
	local shadow = obj:FindFirstChild("UISoftShadow")
	if shadow then
		shadow.ImageTransparency = transparency or 0.78
		return shadow
	end

	shadow = Instance.new("ImageLabel")
	shadow.Name = "UISoftShadow"
	shadow.BackgroundTransparency = 1
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 2)
	shadow.Size = UDim2.new(1, 12, 1, 12)
	shadow.ZIndex = math.max(0, obj.ZIndex - 1)
	shadow.Image = "rbxassetid://1316045217"
	shadow.ImageColor3 = UIStyle.Theme.Shadow
	shadow.ScaleType = Enum.ScaleType.Slice
	shadow.SliceCenter = Rect.new(10, 10, 118, 118)
	shadow.ImageTransparency = transparency or 0.78
	shadow.Parent = obj
	return shadow
end

function UIStyle.applyPanel(obj, variant)
	local theme = UIStyle.Theme
	local color = theme.Panel
	local strokeTransparency = 0.68
	if variant == "background" then
		color = theme.Background
		strokeTransparency = 0.5
	elseif variant == "card" then
		color = theme.Card
	elseif variant == "cardAlt" then
		color = theme.CardAlt
	elseif variant == "inset" then
		color = theme.Inset
		strokeTransparency = 0.6
	elseif variant == "panelAlt" then
		color = theme.PanelAlt
	elseif variant == "panelSoft" then
		color = theme.PanelSoft
	end
	obj.BackgroundColor3 = color
	obj.BorderSizePixel = 0
	UIStyle.addCorner(obj)
	UIStyle.addStroke(obj, 1, theme.Stroke, strokeTransparency)
	return obj
end

function UIStyle.applyButton(obj, kind)
	local theme = UIStyle.Theme
	local bg = theme.Panel
	local fg = theme.Text

	if kind == "primary" then
		bg = theme.PanelAlt
	elseif kind == "danger" then
		bg = theme.Negative
	elseif kind == "success" then
		bg = theme.Positive
	elseif kind == "secondary" then
		bg = theme.Panel
	elseif kind == "ghost" then
		bg = theme.Background
	elseif kind == "warning" then
		bg = theme.Warning
	elseif kind == "muted" then
		bg = theme.Inset
		fg = theme.SubText
	end

	obj.BackgroundColor3 = bg
	obj.BorderSizePixel = 0
	obj.TextColor3 = fg
	obj.TextTransparency = 0
	obj.AutoButtonColor = true
	UIStyle.addCorner(obj)
	UIStyle.addStroke(obj, 1, theme.Stroke, 0.72)
	return obj
end

function UIStyle.createLabel(parent, text, size, position, font, textSize, color, align)
	local theme = UIStyle.Theme
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextColor3 = color or theme.Text
	label.TextTransparency = 0
	label.Font = font or theme.FontBody
	label.TextSize = textSize or 14
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

function UIStyle.createButton(parent, text, size, position, kind)
	local theme = UIStyle.Theme
	local button = Instance.new("TextButton")
	button.Size = size
	button.Position = position
	button.Text = text
	button.Parent = parent
	UIStyle.applyButton(button, kind)
	button.Font = theme.FontBody
	button.TextSize = 13
	button.TextTransparency = 0
	return button
end

function UIStyle.applyHeaderLabel(label, size, align)
	local theme = UIStyle.Theme
	label.BackgroundTransparency = 1
	label.TextColor3 = theme.Text
	label.TextTransparency = 0
	label.Font = theme.FontHeader
	label.TextSize = size or 18
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	return label
end

function UIStyle.applyBodyLabel(label, size, color, align)
	local theme = UIStyle.Theme
	label.BackgroundTransparency = 1
	label.TextColor3 = color or theme.SubText
	label.TextTransparency = 0
	label.Font = theme.FontBody
	label.TextSize = size or 14
	label.TextXAlignment = align or Enum.TextXAlignment.Left
	return label
end

function UIStyle.createDivider(parent, yOffset, sizeX)
	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(sizeX or 1, 0, 0, 1)
	divider.Position = UDim2.new(0, 0, 0, yOffset or 0)
	divider.BackgroundColor3 = UIStyle.Theme.Divider
	divider.BorderSizePixel = 0
	divider.Parent = parent
	return divider
end

function UIStyle.darken(color, alpha)
	return color:Lerp(Color3.new(0, 0, 0), alpha or 0.18)
end



function UIStyle.applyButtonEffects(button)
	local TweenService = game:GetService("TweenService")

	local originalColor = button.BackgroundColor3
	local hoverColor = UIStyle.darken(originalColor, 0.15)
	local pressColor = UIStyle.darken(originalColor, 0.3)

	local hoverTween = TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = hoverColor})
	local resetTween = TweenService:Create(button, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = originalColor})
	local pressTween = TweenService:Create(button, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = pressColor})
	local releaseTween = TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = hoverColor})

	button.MouseEnter:Connect(function()
		hoverTween:Play()
	end)

	button.MouseLeave:Connect(function()
		resetTween:Play()
	end)

	button.MouseButton1Down:Connect(function()
		pressTween:Play()
	end)

	button.MouseButton1Up:Connect(function()
		releaseTween:Play()
	end)
end

function UIStyle.animateWindowOpen(frame)
	local TweenService = game:GetService("TweenService")
	local originalPosition = frame.Position
	frame.Position = UDim2.new(originalPosition.X.Scale, originalPosition.X.Offset, originalPosition.Y.Scale, originalPosition.Y.Offset + 20)
	frame.BackgroundTransparency = 1

	-- Fade children
	for _, child in ipairs(frame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			child.TextTransparency = 1
		elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
			child.ImageTransparency = 1
		elseif child:IsA("Frame") and child.Name ~= "UISoftShadow" then
			child.BackgroundTransparency = 1
		elseif child:IsA("UIStroke") then
			child.Transparency = 1
		end
	end

	frame.Visible = true

	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(frame, tweenInfo, {Position = originalPosition, BackgroundTransparency = 0}):Play()

	for _, child in ipairs(frame:GetDescendants()) do
		if child:IsA("TextLabel") or child:IsA("TextButton") then
			TweenService:Create(child, tweenInfo, {TextTransparency = 0}):Play()
			if child:IsA("TextButton") then
				TweenService:Create(child, tweenInfo, {BackgroundTransparency = 0}):Play()
			end
		elseif child:IsA("ImageLabel") or child:IsA("ImageButton") then
			TweenService:Create(child, tweenInfo, {ImageTransparency = 0}):Play()
		elseif child:IsA("Frame") and child.Name ~= "UISoftShadow" then
			TweenService:Create(child, tweenInfo, {BackgroundTransparency = 0}):Play()
		elseif child:IsA("UIStroke") then
			TweenService:Create(child, tweenInfo, {Transparency = 0}):Play()
		end
	end
end

return UIStyle
