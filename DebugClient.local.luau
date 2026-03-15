-- DebugClient (LocalScript, StarterPlayerScripts)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui")

local remoteName = "Debug_KillEnemyHQs"
local remote = ReplicatedStorage:WaitForChild(remoteName, 10)

if remote then
	local screen = Instance.new("ScreenGui")
	screen.Name = "DebugScreen"
	screen.IgnoreGuiInset = true
	screen.ResetOnSpawn = false
	screen.Parent = gui

	local btn = Instance.new("TextButton")
	btn.Name = "KillBtn"
	btn.Size = UDim2.new(0, 200, 0, 50)
	btn.Position = UDim2.new(0.5, -100, 0, 10)
	btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	btn.Text = "DESTROY ENEMY HQS"
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.Parent = screen

	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)

	btn.MouseButton1Click:Connect(function()
		remote:FireServer()
		btn.Text = "TRIGGERED"
		task.wait(1)
		btn.Text = "DESTROY ENEMY HQS"
	end)
end