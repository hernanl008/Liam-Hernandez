--!strict
-- Binds the "B" key (for "Book") to open/close the Compendium (GDD.md §12).

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompendiumUI = require(Modules:WaitForChild("UI"):WaitForChild("CompendiumUI"))
local CastMeterUI = require(Modules:WaitForChild("UI"):WaitForChild("CastMeterUI"))

local CompendiumController = {}

local TOGGLE_KEY = Enum.KeyCode.B

function CompendiumController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		-- Don't let another full-screen panel open on top of the cast
		-- meter (GDD.md §3) while it's aiming a cast.
		if CastMeterUI.isActive() then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			CompendiumUI.toggle()
		end
	end)
end

return CompendiumController
