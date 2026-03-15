-- UIInspector.Training (ModuleScript, ReplicatedStorage)

local module = {}

local Config
local UnitEvent
local RunService
local Theme

local getSelectedBuildingFn
local refreshSelectedQueueFn

local queueErrorLabel
local queueErrorToken = 0

local unitEventConn
local trainingUpdateConn

local TrainingQueues = setmetatable({}, { __mode = "k" })
local TrainingState = setmetatable({}, { __mode = "k" })

local function updateTrainingProgress(model, progress)
	if not model or not model.Parent then
		return
	end

	local gui = model:FindFirstChild("TrainingBarUI")
	if not gui then
		gui = Instance.new("BillboardGui", model)
		gui.Name = "TrainingBarUI"
		gui.Size = UDim2.new(6, 0, 0.5, 0)
		gui.StudsOffset = Vector3.new(0, 8, 0)
		gui.AlwaysOnTop = true

		local bg = Instance.new("Frame", gui)
		bg.Size = UDim2.new(1, 0, 1, 0)
		bg.BackgroundColor3 = Color3.new(0, 0, 0)
		bg.BorderSizePixel = 0

		local bgCorner = Instance.new("UICorner", bg)
		bgCorner.CornerRadius = UDim.new(0, 8)
		local bgStroke = Instance.new("UIStroke", bg)
		bgStroke.Thickness = 1
		bgStroke.Color = Color3.new(0.3, 0.3, 0.3)

		local fill = Instance.new("Frame", bg)
		fill.Name = "Fill"
		fill.Size = UDim2.new(0, 0, 1, 0)
		fill.BackgroundColor3 = Theme.BlueWarm
		fill.BorderSizePixel = 0

		local fillCorner = Instance.new("UICorner", fill)
		fillCorner.CornerRadius = UDim.new(0, 8)

		local grad = Instance.new("UIGradient", fill)
		grad.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(100, 200, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 150, 255)),
		})
		grad.Rotation = 90
	end

	local fill = gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Fill")
	if fill then
		fill.Size = UDim2.new(progress, 0, 1, 0)
	end
end

function module.init(options)
	Config = options.Config
	UnitEvent = options.UnitEvent
	RunService = options.RunService
	Theme = options.Theme
	getSelectedBuildingFn = options.getSelectedBuilding
	refreshSelectedQueueFn = options.refreshSelectedQueue
	queueErrorLabel = options.queueErrorLabel

	if not unitEventConn then
		unitEventConn = UnitEvent.OnClientEvent:Connect(function(action, building, data)
			if action == "UpdateQueue" then
				if not building then
					return
				end
				local queue = data or {}
				TrainingQueues[building] = {}
				for _, name in ipairs(queue) do
					table.insert(TrainingQueues[building], name)
				end
				if #queue > 0 and not TrainingState[building] then
					local unitData = Config.Units[queue[1]]
					if unitData and unitData.TrainingTime then
						TrainingState[building] = {
							StartTime = os.clock(),
							Duration = unitData.TrainingTime,
						}
					end
				end
				if getSelectedBuildingFn and getSelectedBuildingFn() == building and refreshSelectedQueueFn then
					refreshSelectedQueueFn()
				end
				if #queue == 0 then
					TrainingState[building] = nil
					local bar = building:FindFirstChild("TrainingBarUI")
					if bar then
						bar:Destroy()
					end
				end
			elseif action == "StartTraining" then
				if not building then
					return
				end
				local duration = data
				if type(duration) ~= "number" then
					return
				end
				TrainingState[building] = {
					StartTime = os.clock(),
					Duration = duration,
				}
				updateTrainingProgress(building, 0)
			elseif action == "TrainingCancelled" then
				if not building then
					return
				end
				TrainingState[building] = nil
				local bar = building:FindFirstChild("TrainingBarUI")
				if bar then
					bar:Destroy()
				end
			elseif action == "QueueFailed" then
				module.showQueueError(data or "Queue failed")
			end
		end)
	end

	if not trainingUpdateConn then
		trainingUpdateConn = RunService.Heartbeat:Connect(function()
			for building, state in pairs(TrainingState) do
				if not building or not building.Parent then
					TrainingState[building] = nil
					if building then
						local bar = building:FindFirstChild("TrainingBarUI")
						if bar then
							bar:Destroy()
						end
					end
				elseif state.Duration and state.Duration > 0 then
					local progress = math.clamp((os.clock() - state.StartTime) / state.Duration, 0, 1)
					updateTrainingProgress(building, progress)
				end
			end
		end)
	end
end

function module.showQueueError(message)
	if not queueErrorLabel then
		return
	end
	queueErrorToken += 1
	local token = queueErrorToken
	queueErrorLabel.Text = tostring(message or "Queue failed")
	queueErrorLabel.Visible = true
	task.delay(2.5, function()
		if queueErrorToken == token and queueErrorLabel then
			queueErrorLabel.Visible = false
		end
	end)
end

function module.hideQueueError()
	if queueErrorLabel then
		queueErrorLabel.Visible = false
	end
end

function module.getSellRefund(building)
	if not building then
		return 0
	end
	local bType = building:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	if not bData then
		return 0
	end
	local ratio = building:GetAttribute("IsUnderConstruction") and 0.75 or 0.5
	return math.floor((bData.Cost or 0) * ratio)
end

function module.canUpgradeBuilding(building)
	if not building then
		return false
	end
	if building:GetAttribute("IsUnderConstruction") or building:GetAttribute("IsUpgrading") then
		return false
	end
	local bType = building:GetAttribute("Type")
	local bData = Config.Buildings[bType]
	return bData and bData.CanUpgrade and bData.UpgradeCost and bData.UpgradesTo
end

function module.getRecruitOptionsForBuilding(buildingType)
	local ordered = {}
	local seenDepth = {}
	local currentType = buildingType
	local depth = 0
	local guard = 0

	while currentType and guard < 10 do
		guard += 1
		local bData = Config.Buildings[currentType]
		if not bData then
			break
		end
		for _, unitName in ipairs(bData.CanRecruit or {}) do
			local prevDepth = seenDepth[unitName]
			if not prevDepth or depth < prevDepth then
				seenDepth[unitName] = depth
				if not prevDepth then
					table.insert(ordered, unitName)
				end
			end
		end
		currentType = bData.UpgradesTo
		depth += 1
	end

	local result = {}
	for _, unitName in ipairs(ordered) do
		table.insert(result, {
			Name = unitName,
			UnlockDepth = seenDepth[unitName] or 0,
		})
	end
	return result
end

function module.ensureQueue(building)
	if not TrainingQueues[building] then
		TrainingQueues[building] = {}
	end
end

function module.getQueue(building)
	return TrainingQueues[building]
end

function module.getTrainingSnapshot(building)
	local state = TrainingState[building]
	if not state or not state.Duration or state.Duration <= 0 then
		return nil
	end

	local elapsed = math.max(0, os.clock() - state.StartTime)
	local progress = math.clamp(elapsed / state.Duration, 0, 1)
	return {
		Progress = progress,
		Elapsed = elapsed,
		Duration = state.Duration,
		Remaining = math.max(0, state.Duration - elapsed),
	}
end

function module.refreshQueueUI(queueScroll, building, helpers)
	if not queueScroll then
		return
	end
	for _, child in ipairs(queueScroll:GetChildren()) do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	if not building or not TrainingQueues[building] then
		return
	end

	for i, item in ipairs(TrainingQueues[building]) do
		local name = typeof(item) == "table" and item.Name or item
		local btn = Instance.new("TextButton", queueScroll)
		btn.Size = UDim2.new(0, 50, 0, 50)
		btn.BackgroundColor3 = helpers.theme.Panel
		btn.Text = ""
		helpers.addCorner(btn)
		helpers.addStroke(btn, 1, helpers.theme.BlueWarm)

		local icon = Instance.new("Frame", btn)
		icon.Size = UDim2.new(0, 36, 0, 36)
		icon.Position = UDim2.new(0, 7, 0, 7)
		icon.BackgroundColor3 = Color3.fromRGB(22, 22, 26)
		icon.BorderSizePixel = 0
		helpers.addCorner(icon, UDim.new(0, 8))
		helpers.addStroke(icon, 1, helpers.theme.Stroke)
		helpers.renderUnitViewport(icon, name)

		local idxLbl = helpers.createText(btn, tostring(i), UDim2.new(0, 12, 0, 12), UDim2.new(1, -14, 0, 2), Enum.Font.GothamBlack, helpers.theme.SubText, Enum.TextXAlignment.Center, helpers.theme)
		idxLbl.TextSize = 11

		btn.MouseButton1Click:Connect(function()
			table.remove(TrainingQueues[building], i)
			module.refreshQueueUI(queueScroll, building, helpers)
			UnitEvent:FireServer("CancelTrain", building, i)
			if i == 1 then
				local bar = building:FindFirstChild("TrainingBarUI")
				if bar then
					bar:Destroy()
				end
			end
		end)
	end
end

return module

