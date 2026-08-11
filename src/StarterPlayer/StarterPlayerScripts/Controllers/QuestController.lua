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

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local QuestConfig = require(Modules:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local SoundPlayer = require(Modules:WaitForChild("Client"):WaitForChild("SoundPlayer"))
local SoundIds = require(Modules:WaitForChild("Shared"):WaitForChild("SoundIds"))
local QuestTrackerUI = require(Modules:WaitForChild("UI"):WaitForChild("QuestTrackerUI"))
local QuestLogUI = require(Modules:WaitForChild("UI"):WaitForChild("QuestLogUI"))
local UiLock = require(Modules:WaitForChild("Client"):WaitForChild("UiLock"))
local PlayerFreeze = require(Modules:WaitForChild("Client"):WaitForChild("PlayerFreeze"))

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

local TOGGLE_KEY = Enum.KeyCode.J

function QuestController.init()
	InventoryCache.init()
	QuestTrackerUI.refresh()

	UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
		if gameProcessed then
			return
		end
		if PlayerFreeze.isActive() then
			return
		end
		if input.KeyCode == TOGGLE_KEY then
			-- Locked (opening cutscene): refuse to OPEN, but always allow
			-- closing, so a lock taken while the log is up cannot trap the
			-- player behind it.
			if UiLock.isLocked() and not QuestLogUI.isVisible() then
				return
			end
			QuestLogUI.toggle()
		end
	end)

	Remotes.get("InventoryUpdate").OnClientEvent:Connect(function()
		-- InventoryCache has its own listener on this remote. Deferring
		-- lets that land first, so the tracker reads the new snapshot
		-- rather than the previous one.
		task.defer(function()
			QuestTrackerUI.refresh()
			QuestLogUI.refreshIfVisible()
		end)
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
		task.defer(function()
			QuestTrackerUI.refresh()
			QuestLogUI.refreshIfVisible()
		end)
	end)
end

return QuestController
