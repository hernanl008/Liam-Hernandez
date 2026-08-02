--!strict
-- In-memory player data for the Act 1 vertical slice. No DataStore
-- persistence yet — that's a Phase 3/4 concern (see docs/ROADMAP.md);
-- for now this only needs to survive a single play session so the
-- other vertical-slice services have something to read/write.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Shared"):WaitForChild("Remotes"))

export type ItemCounts = { [string]: number }

export type PlayerData = {
	gold: number,
	seeds: ItemCounts,
	crops: ItemCounts,
	fish: ItemCounts,
	dishes: ItemCounts,
	junk: ItemCounts,
	flags: { [string]: boolean },
	assistMode: boolean,
}

local PlayerDataService = {}

local dataByPlayer: { [Player]: PlayerData } = {}

local function newPlayerData(): PlayerData
	return {
		gold = 100, -- small starter cushion for seeds
		seeds = { MoonriceStalk = 3 },
		crops = {},
		fish = {},
		dishes = {},
		junk = {},
		flags = {},
		assistMode = false,
	}
end

local function setupLeaderstats(player: Player, data: PlayerData)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	local gold = Instance.new("IntValue")
	gold.Name = "Gold"
	gold.Value = data.gold
	gold.Parent = leaderstats
end

function PlayerDataService.get(player: Player): PlayerData?
	return dataByPlayer[player]
end

-- Inventory counts are server-authoritative, but the client needs a
-- read-only mirror for HUD/inventory UI and for dialogue autoRoute
-- checks like "does the player have any ingredient" (DialogueController).
local function syncToClient(player: Player, data: PlayerData)
	Remotes.get("InventoryUpdate"):FireClient(player, {
		gold = data.gold,
		seeds = data.seeds,
		crops = data.crops,
		fish = data.fish,
		dishes = data.dishes,
		junk = data.junk,
	})
end

function PlayerDataService.addItem(player: Player, category: "seeds" | "crops" | "fish" | "dishes" | "junk", id: string, amount: number)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	local bucket = data[category]
	bucket[id] = (bucket[id] or 0) + amount
	syncToClient(player, data)
end

function PlayerDataService.hasItem(player: Player, category: "seeds" | "crops" | "fish" | "dishes" | "junk", id: string, amount: number): boolean
	local data = dataByPlayer[player]
	if not data then
		return false
	end
	return (data[category][id] or 0) >= amount
end

function PlayerDataService.removeItem(player: Player, category: "seeds" | "crops" | "fish" | "dishes" | "junk", id: string, amount: number): boolean
	if not PlayerDataService.hasItem(player, category, id, amount) then
		return false
	end
	local data = dataByPlayer[player] :: PlayerData
	data[category][id] -= amount
	syncToClient(player, data)
	return true
end

function PlayerDataService.addGold(player: Player, amount: number)
	local data = dataByPlayer[player]
	if not data then
		return
	end
	data.gold += amount
	local leaderstats = player:FindFirstChild("leaderstats")
	local goldValue = leaderstats and leaderstats:FindFirstChild("Gold")
	if goldValue then
		(goldValue :: IntValue).Value = data.gold
	end
end

function PlayerDataService.setFlag(player: Player, flag: string, value: boolean)
	local data = dataByPlayer[player]
	if data then
		data.flags[flag] = value
	end
end

function PlayerDataService.hasFlag(player: Player, flag: string): boolean
	local data = dataByPlayer[player]
	return data ~= nil and data.flags[flag] == true
end

Players.PlayerAdded:Connect(function(player: Player)
	local data = newPlayerData()
	dataByPlayer[player] = data
	setupLeaderstats(player, data)
	task.defer(syncToClient, player, data) -- defer so PlayerGui exists for the client's own listener
end)

Players.PlayerRemoving:Connect(function(player: Player)
	dataByPlayer[player] = nil
end)

return PlayerDataService
