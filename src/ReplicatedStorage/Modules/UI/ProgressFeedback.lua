--!strict
-- Shared "you just leveled up / discovered something new" banner logic
-- (GDD.md §12), used by all three pillar controllers so the feedback is
-- consistent instead of three copy-pasted checks. Callers should only
-- call this when they're *not* already showing a bigger spectacle banner
-- (a Legendary catch, Gold dish, big combo) for the same event — level-up
-- takes priority over a plain discovery when both happen at once.

local SpectacleUI = require(script.Parent:WaitForChild("SpectacleUI"))

local ProgressFeedback = {}

export type Payload = {
	newDiscovery: boolean?,
	leveledUp: boolean?,
	newLevel: number?,
}

function ProgressFeedback.announce(skillName: string, payload: Payload)
	if payload.leveledUp then
		SpectacleUI.banner(`{skillName} LEVEL {payload.newLevel}!`, Color3.fromRGB(120, 200, 255), { holdSeconds = 1.8 })
	elseif payload.newDiscovery then
		SpectacleUI.banner("NEW DISCOVERY!", Color3.fromRGB(160, 255, 160), { holdSeconds = 1.4 })
	end
end

return ProgressFeedback
