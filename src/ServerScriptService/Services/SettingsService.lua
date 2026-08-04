--!strict
-- Small, dedicated home for player-facing settings toggles rather than
-- growing DialogueService.lua's FLAG_ONLY_ACTIONS table with something
-- that isn't a dialogue action. Currently just Assist Mode (GDD.md §10),
-- but a real settings menu is more likely to grow than shrink.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local SettingsService = {}

function SettingsService.init()
	Remotes.get("SetAssistMode").OnServerEvent:Connect(function(player: Player, enabled: boolean)
		if typeof(enabled) ~= "boolean" then
			return
		end
		PlayerDataService.setAssistMode(player, enabled)
	end)
end

return SettingsService
