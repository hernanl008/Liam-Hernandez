--!strict
-- Wires HudUI to InventoryUpdate (gold/skill levels) and DayCycleUpdate
-- (day/time). No toggle — the HUD is always on.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local HudUI = require(Modules:WaitForChild("UI"):WaitForChild("HudUI"))

local HudController = {}

function HudController.init()
	HudUI.refreshInventory() -- also lazily initializes InventoryCache's own listener, see HudUI.lua

	Remotes.get("InventoryUpdate").OnClientEvent:Connect(function()
		HudUI.refreshInventory()
	end)

	Remotes.get("DayCycleUpdate").OnClientEvent:Connect(function(payload: { day: number, dayProgress: number })
		HudUI.setDay(payload.day, payload.dayProgress)
	end)
end

return HudController
