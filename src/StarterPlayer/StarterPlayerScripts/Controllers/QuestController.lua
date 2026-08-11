--!strict
-- Drives QuestTrackerUI from the server's snapshots.
--
-- There is no client-side quest logic here on purpose. Objectives are
-- counted and paid out entirely by QuestService, and the client is told
-- the resulting numbers so it can draw them — a client that could report
-- its own progress could pay itself gold, seeds and skill XP.
--
-- The tracker refreshes off InventoryUpdate rather than a quest-specific
-- remote: quest counters ride in the same snapshot as everything else,
-- so any change that could move an objective already delivers one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local QuestConfig = require(Modules:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local SoundPlayer = require(Modules:WaitForChild("Client"):WaitForChild("SoundPlayer"))
local SoundIds = require(Modules:WaitForChild("Shared"):WaitForChild("SoundIds"))
local QuestTrackerUI = require(Modules:WaitForChild("UI"):WaitForChild("QuestTrackerUI"))

local QuestController = {}

local function describeReward(reward: QuestConfig.Reward): string
	local parts = {}
	if reward.gold then
		table.insert(parts, `{reward.gold}G`)
	end
	if reward.seeds then
		table.insert(parts, `{reward.seeds.count}x {reward.seeds.id} SEEDS`)
	end
	if reward.skill then
		table.insert(parts, `{reward.skill.xp} {reward.skill.id} XP`)
	end
	if #parts == 0 then
		return "NO REWARD"
	end
	return table.concat(parts, "   ")
end

function QuestController.init()
	InventoryCache.init()
	QuestTrackerUI.refresh()

	Remotes.get("InventoryUpdate").OnClientEvent:Connect(function()
		-- InventoryCache has its own listener on this remote. Deferring
		-- lets that land first, so the tracker reads the new snapshot
		-- rather than the previous one.
		task.defer(QuestTrackerUI.refresh)
	end)

	Remotes.get("QuestCompleted").OnClientEvent:Connect(function(payload: {
		id: string,
		title: string,
		reward: QuestConfig.Reward,
	})
		SoundPlayer.play(SoundIds.QuestComplete)
		QuestTrackerUI.announce(payload.title, describeReward(payload.reward))
		-- Refresh after the announcement so the tracker has already moved
		-- on to the next quest by the time the card slides away.
		task.defer(QuestTrackerUI.refresh)
	end)
end

return QuestController
