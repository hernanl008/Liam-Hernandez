--!strict
-- Binds the "P" key (for "Perks") to open/close the skill tree screen,
-- and refreshes it when a perk unlock request resolves (GDD.md §12).

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeUI = require(Modules:WaitForChild("UI"):WaitForChild("SkillTreeUI"))
local StatusToast = require(Modules:WaitForChild("UI"):WaitForChild("StatusToast"))
local PlayerFreeze = require(Modules:WaitForChild("Client"):WaitForChild("PlayerFreeze"))
local UiLock = require(Modules:WaitForChild("Client"):WaitForChild("UiLock"))

local SkillTreeController = {}

local TOGGLE_KEY = Enum.KeyCode.P

function SkillTreeController.init()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		if PlayerFreeze.isActive() then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			-- Locked (opening cutscene, etc): refuse to OPEN, but always
			-- allow closing, so a lock taken while a screen is up can
			-- never trap the player behind it.
			if UiLock.isLocked() and not SkillTreeUI.isVisible() then
				return
			end
			SkillTreeUI.toggle()
		end
	end)

	Remotes.get("UnlockPerkResult").OnClientEvent:Connect(function(payload: { success: boolean, reason: string? })
		if payload.success then
			SkillTreeUI.refreshIfVisible()
		else
			StatusToast.setTemporary(`Can't unlock that yet: {payload.reason or "unknown reason"}`, 2)
		end
	end)
end

return SkillTreeController
