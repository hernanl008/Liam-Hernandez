--!strict
-- Read-only client-side mirror of PlayerDataService's inventory, kept in
-- sync via Remotes.InventoryUpdate. Client-only (never required from
-- server code) — used by UI (including the Compendium and skill tree
-- screens, GDD.md §12) and by DialogueController's autoRoute checks
-- (e.g. "does the player have any ingredient" for Hinano's tutorial).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

export type DiscoveredSnapshot = {
	fish: { [string]: boolean },
	dishes: { [string]: boolean },
	crops: { [string]: boolean },
	junk: { [string]: boolean },
}

export type Snapshot = {
	gold: number,
	seeds: { [string]: number },
	crops: { [string]: number },
	fish: { [string]: number },
	dishes: { [string]: number },
	junk: { [string]: number },
	discovered: DiscoveredSnapshot,
	skillXp: { [string]: number },
	skillPoints: { [string]: number },
	unlockedPerks: { [string]: { [string]: boolean } },
}

local InventoryCache = {}

local snapshot: Snapshot = {
	gold = 0,
	seeds = {},
	crops = {},
	fish = {},
	dishes = {},
	junk = {},
	discovered = { fish = {}, dishes = {}, crops = {}, junk = {} },
	skillXp = { Farming = 0, Fishing = 0, Cooking = 0 },
	skillPoints = { Farming = 0, Fishing = 0, Cooking = 0 },
	unlockedPerks = { Farming = {}, Fishing = {}, Cooking = {} },
}

local initialized = false

local function init()
	if initialized then
		return
	end
	initialized = true
	Remotes.get("InventoryUpdate").OnClientEvent:Connect(function(data: Snapshot)
		snapshot = data
	end)
end

function InventoryCache.get(): Snapshot
	init()
	return snapshot
end

function InventoryCache.hasAnyIngredient(): boolean
	init()
	for _, count in snapshot.crops do
		if count > 0 then
			return true
		end
	end
	for _, count in snapshot.fish do
		if count > 0 then
			return true
		end
	end
	return false
end

return InventoryCache
