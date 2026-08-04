--!strict
-- Binds "O" to open/close SettingsUI.lua, and refreshes it live off
-- InventoryUpdate so toggling Assist Mode reflects the server's
-- confirmed value rather than assuming the click landed.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local SettingsUI = require(Modules:WaitForChild("UI"):WaitForChild("SettingsUI"))
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local PlayerFreeze = require(Modules:WaitForChild("Client"):WaitForChild("PlayerFreeze"))

local SettingsController = {}

local TOGGLE_KEY = Enum.KeyCode.O

function SettingsController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if PlayerFreeze.isActive() then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			SettingsUI.toggle()
		end
	end)

	Remotes.get("InventoryUpdate").OnClientEvent:Connect(function()
		SettingsUI.refreshIfVisible()
	end)
end

return SettingsController
