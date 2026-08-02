--!strict
-- Read-only client-side mirror of PlayerDataService's inventory, kept in
-- sync via Remotes.InventoryUpdate. Client-only (never required from
-- server code) — used by UI and by DialogueController's autoRoute checks
-- (e.g. "does the player have any ingredient" for Hinano's tutorial).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))

export type Snapshot = {
	gold: number,
	seeds: { [string]: number },
	crops: { [string]: number },
	fish: { [string]: number },
	dishes: { [string]: number },
	junk: { [string]: number },
}

local InventoryCache = {}

local snapshot: Snapshot = {
	gold = 0,
	seeds = {},
	crops = {},
	fish = {},
	dishes = {},
	junk = {},
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
