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
	-- Fired once per NPC when a conversation starts (DialogueController),
	-- so their root node can autoRoute to a short return greeting instead
	-- of replaying the first-meeting intro every time (docs/ROADMAP.md
	-- Phase 3 "already met" branching) — see DialogueData.lua's *_root nodes.
	Met_Kaya = true,
	Met_ElderSouta = true,
	Met_Ren = true,
	Met_Hinano = true,
	Met_Kaleb = true,
}

-- Dialogue relationshipDelta values are small hand-authored numbers
-- (DialogueData.lua currently only ever uses -1/+1); clamp defensively so
-- a modified client can't FireServer arbitrary deltas.
local MAX_RELATIONSHIP_DELTA = 5

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

	Remotes.get("DialogueRelationshipDelta").OnServerEvent:Connect(function(player: Player, npcId: string, delta: number)
		if typeof(npcId) ~= "string" or typeof(delta) ~= "number" then
			return
		end
		local clamped = math.clamp(delta, -MAX_RELATIONSHIP_DELTA, MAX_RELATIONSHIP_DELTA)
		PlayerDataService.addRelationship(player, npcId, clamped)
	end)
end

return DialogueService
