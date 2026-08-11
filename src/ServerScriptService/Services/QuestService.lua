--!strict
-- Tracks quest objectives and pays out rewards (GDD.md §12).
--
-- The design constraint that shapes this file: a quest must never need
-- its own hook into the world. Every objective is counted from an event
-- the game already produced — FarmingService awarding a crop,
-- FishingService landing a fish, ShopService taking a sale — and each of
-- those calls QuestService.report at the point it already had. One line
-- per service, and adding a quest becomes a data change in
-- QuestConfig.lua with no code change at all.
--
-- Server-authoritative for the obvious reason: progress converts into
-- gold, seeds and skill XP, so a client that could report its own
-- objectives could pay itself. The client is told the numbers only so it
-- can draw them.
--
-- Quests are auto-accepted the moment their prerequisite clears rather
-- than being handed out by an NPC. NPCs do not move or keep schedules
-- yet, so requiring the player to find a specific person before the game
-- would tell them what to do next is a worse experience than the giver
-- simply being flavour on the card.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local QuestConfig = require(Modules:WaitForChild("Shared"):WaitForChild("QuestConfig"))
local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local QuestService = {}

-- Ensures every currently-available quest has a progress row, and
-- returns whether anything changed. Called on join and after each
-- completion, which is when the set of available quests can move.
local function openAvailableQuests(player: Player): boolean
	local data = PlayerDataService.get(player)
	if not data then
		return false
	end
	local changed = false
	for _, quest in QuestConfig.availableFor(data.questsCompleted) do
		if data.questProgress[quest.id] == nil then
			local counters = {}
			for _ = 1, #quest.objectives do
				table.insert(counters, 0)
			end
			data.questProgress[quest.id] = counters
			changed = true
		end
	end
	return changed
end

local function payReward(player: Player, quest: QuestConfig.QuestDef)
	local reward = quest.reward
	if reward.gold then
		PlayerDataService.addGold(player, reward.gold)
	end
	if reward.seeds then
		PlayerDataService.addItem(player, "seeds", reward.seeds.id, reward.seeds.count)
	end
	if reward.skill then
		PlayerDataService.addSkillXp(player, reward.skill.id :: any, reward.skill.xp)
	end
end

-- True once every objective's counter has reached its target.
local function isComplete(quest: QuestConfig.QuestDef, counters: { number }): boolean
	for index, objective in quest.objectives do
		if (counters[index] or 0) < objective.count then
			return false
		end
	end
	return true
end

-- "Hold N gold at once" is a STATE, not an event, so it cannot be
-- counted by incrementing on a transaction: spending would never take it
-- back down, and a player who briefly crossed the line would keep credit
-- for it. Objectives of kind "earn" are instead SET to the current
-- balance every time anything is reported.
local function syncEarnObjectives(data: any): boolean
	local changed = false
	for questId, counters in data.questProgress do
		if data.questsCompleted[questId] then
			continue
		end
		local quest = QuestConfig.ById[questId]
		if not quest then
			continue
		end
		for index, objective in quest.objectives do
			if objective.kind == "earn" then
				local value = math.min(data.gold, objective.count)
				if counters[index] ~= value then
					counters[index] = value
					changed = true
				end
			end
		end
	end
	return changed
end

-- Records `amount` of `kind` (optionally carrying an `id`) against every
-- open quest that cares, then completes and pays out any that finished.
--
-- Safe to call for events no quest is watching — that is the normal case
-- and the point of the design.
function QuestService.report(player: Player, kind: QuestConfig.ObjectiveKind, id: string?, amount: number?)
	local data = PlayerDataService.get(player)
	if not data then
		return
	end
	local step = amount or 1
	-- Gold objectives are re-read on every report, so any event at all
	-- keeps them honest — including the reward payout below.
	local changed = syncEarnObjectives(data)
	local finished: { QuestConfig.QuestDef } = {}

	for questId, counters in data.questProgress do
		if data.questsCompleted[questId] then
			continue
		end
		local quest = QuestConfig.ById[questId]
		if not quest then
			continue -- a quest removed from the config since this save
		end
		for index, objective in quest.objectives do
			-- A nil target counts any event of that kind, which is what
			-- "catch 3 fish" wants; a set target matches exactly.
			if objective.kind == kind and (objective.target == nil or objective.target == id) then
				local current = counters[index] or 0
				if current < objective.count then
					counters[index] = math.min(current + step, objective.count)
					changed = true
				end
			end
		end
		if isComplete(quest, counters) then
			table.insert(finished, quest)
		end
	end

	for _, quest in finished do
		data.questsCompleted[quest.id] = true
		payReward(player, quest)
		Remotes.get("QuestCompleted"):FireClient(player, {
			id = quest.id,
			title = quest.title,
			reward = quest.reward,
		})
		changed = true
	end

	if #finished > 0 then
		-- Finishing one quest can make its successors available.
		openAvailableQuests(player)

		-- A reward can itself satisfy a gold threshold, so re-read the
		-- balance and sweep once more. Exactly one extra pass, not a loop:
		-- the second sweep cannot pay out again without another event, so
		-- this terminates by construction rather than by hoping the state
		-- settles.
		syncEarnObjectives(data)
		for questId, counters in data.questProgress do
			local quest = QuestConfig.ById[questId]
			if quest and not data.questsCompleted[questId] and isComplete(quest, counters) then
				data.questsCompleted[questId] = true
				payReward(player, quest)
				Remotes.get("QuestCompleted"):FireClient(player, {
					id = quest.id,
					title = quest.title,
					reward = quest.reward,
				})
			end
		end
		openAvailableQuests(player)
	end

	if changed then
		PlayerDataService.sync(player)
	end
end

-- Kept as a named entry point for callers that change gold without any
-- other event to report (ShopService's sale). It is just a report with
-- nothing to count — report already re-reads the balance.
function QuestService.refreshGold(player: Player)
	QuestService.report(player, "earn", nil, 0)
end

function QuestService.init()
	local function onPlayer(player: Player)
		-- PlayerDataService may still be loading this player's save; the
		-- first report or the join sync will open quests once it lands.
		task.defer(function()
			if openAvailableQuests(player) then
				PlayerDataService.sync(player)
			end
			QuestService.refreshGold(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return QuestService
