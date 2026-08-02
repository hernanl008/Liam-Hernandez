--!strict
-- Handles spending a skill point on a perk (GDD.md §12). All the actual
-- validation (level/prerequisite/cost) lives in PlayerDataService.unlockPerk
-- — this service is just the remote-facing wrapper, same pattern as
-- DialogueService for dialogue actions.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local SkillService = {}

function SkillService.init()
	Remotes.get("UnlockPerk").OnServerEvent:Connect(function(player: Player, skillId: string, perkId: string)
		if not SkillTreeConfig.Trees[skillId] then
			return
		end
		local success, reason = PlayerDataService.unlockPerk(player, skillId :: SkillTreeConfig.SkillId, perkId)
		Remotes.get("UnlockPerkResult"):FireClient(player, {
			skillId = skillId,
			perkId = perkId,
			success = success,
			reason = reason,
		})
	end)
end

return SkillService
