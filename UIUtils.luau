-- UIUtils (ModuleScript, ReplicatedStorage)
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local UIUtils = {}

function UIUtils.isInteractiveGuiObject(guiObject)
	if not guiObject or not guiObject.Visible then
		return false
	end
	if guiObject:IsA("TextButton") or guiObject:IsA("ImageButton") or guiObject:IsA("TextBox") then
		return true
	end
	if guiObject:IsA("ScrollingFrame") then
		return true
	end
	if guiObject.Active then
		return true
	end
	return false
end

function UIUtils.isPointerOverGui()
	local player = Players.LocalPlayer
	if not player then return false end

	local playerGui = player:FindFirstChild("PlayerGui")
	if not playerGui then
		return false
	end
	local mousePos = UserInputService:GetMouseLocation()
	local guiObjects = playerGui:GetGuiObjectsAtPosition(mousePos.X, mousePos.Y)
	for _, guiObject in ipairs(guiObjects) do
		if UIUtils.isInteractiveGuiObject(guiObject) then
			return true
		end
	end
	return false
end

return UIUtils
