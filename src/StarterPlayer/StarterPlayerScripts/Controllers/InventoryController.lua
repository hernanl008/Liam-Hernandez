--!strict
-- Binds the "I" key to open/close the general Inventory grid
-- (InventoryUI.lua). Also refreshes it live while open, same pattern as
-- ShopController does for ShopUI, since picking up new items (fishing/
-- farming/cooking) or selling to Kaleb should update counts immediately
-- rather than only on next open.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local InventoryUI = require(Modules:WaitForChild("UI"):WaitForChild("InventoryUI"))
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

local InventoryController = {}

local TOGGLE_KEY = Enum.KeyCode.I

function InventoryController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			InventoryUI.toggle()
		end
	end)

	Remotes.get("InventoryUpdate").OnClientEvent:Connect(function()
		InventoryUI.refreshIfVisible()
	end)
end

return InventoryController
