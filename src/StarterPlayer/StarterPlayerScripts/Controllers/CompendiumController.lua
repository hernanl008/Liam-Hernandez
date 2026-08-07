--!strict
-- Binds the "B" key (for "Book") to open/close the Compendium (GDD.md §12).

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local CompendiumUI = require(Modules:WaitForChild("UI"):WaitForChild("CompendiumUI"))
local PlayerFreeze = require(Modules:WaitForChild("Client"):WaitForChild("PlayerFreeze"))
local UiLock = require(Modules:WaitForChild("Client"):WaitForChild("UiLock"))

local CompendiumController = {}

local TOGGLE_KEY = Enum.KeyCode.B

function CompendiumController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		-- Don't let another full-screen panel open on top of a minigame
		-- (cast meter or reel-in/cooking chart) while it's active.
		if PlayerFreeze.isActive() then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			-- Locked (opening cutscene, etc): refuse to OPEN, but always
			-- allow closing, so a lock taken while a screen is up can
			-- never trap the player behind it.
			if UiLock.isLocked() and not CompendiumUI.isVisible() then
				return
			end
			CompendiumUI.toggle()
		end
	end)
end

return CompendiumController
