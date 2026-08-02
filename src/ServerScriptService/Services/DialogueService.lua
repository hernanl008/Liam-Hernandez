--!strict
-- Dialogue trees themselves are pure flavor text and live entirely
-- client-side (DialogueData.lua, rendered by DialogueController) since
-- none of it is sensitive state. This service only handles the small set
-- of dialogue choices that have an actual gameplay consequence, sent as
-- named actions over Remotes.DialogueAction — see docs/DIALOGUE_ACT1.md
-- for which lines trigger which action.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local DialogueService = {}

-- Actions that just set a one-time flag (tutorial highlights, story
-- beats). Anything needing more than "remember this happened" gets its
-- own branch below instead of living in this table.
local FLAG_ONLY_ACTIONS = {
	StartFarmingTutorial = true,
	StartFishingTutorial = true,
	StartCookingTutorial = true,
	FoundingMythIntroduced = true,
	UnlockKalebShop = true,
}

function DialogueService.init()
	Remotes.get("DialogueAction").OnServerEvent:Connect(function(player: Player, action: string)
		if action == "GrantStarterFarm" then
			if PlayerDataService.hasFlag(player, "GrantStarterFarm") then
				return -- one-time grant, ignore repeats (e.g. from a rejoined conversation)
			end
			PlayerDataService.setFlag(player, "GrantStarterFarm", true)
			PlayerDataService.setFlag(player, "HasFarm", true)
			return
		end

		if FLAG_ONLY_ACTIONS[action] then
			PlayerDataService.setFlag(player, action, true)
			return
		end

		warn(`Unknown dialogue action "{action}" from {player.Name}`)
	end)
end

return DialogueService
