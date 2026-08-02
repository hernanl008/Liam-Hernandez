--!strict
-- In-memory player data for the Act 1 vertical slice. No DataStore
-- persistence yet — that's a Phase 3/4 concern (see docs/ROADMAP.md);
-- for now this only needs to survive a single play session so the
-- other vertical-slice services have something to read/write.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))

export type ItemCounts = { [string]: number }
export type DiscoveredSet = { [string]: boolean }

export type PlayerData = {
	gold: number,
	seeds: ItemCounts,
	crops: ItemCounts,
	fish: ItemCounts,
	dishes: ItemCounts,
	junk: ItemCounts,
	flags: { [string]: boolean },
	assistMode: boolean,
	discovered: {
		fish: DiscoveredSet,
		dishes: DiscoveredSet,
		crops: DiscoveredSet,
		junk: DiscoveredSet,
	},
	skillXp: { [SkillTreeConfig.SkillId]: number },
	skillPoints: { [SkillTreeConfig.SkillId]: number },
	unlockedPerks: { [SkillTreeConfig.SkillId]: { [string]: boolean } },
}

-- fish/crops/junk use the same id in inventory and in the Compendium
-- (GDD.md §12), so addItem can auto-discover them. Seeds aren't a
-- discoverable "thing" on their own — they share an id with the crop
-- they grow into, discovered by harvesting instead. Dishes are also
-- excluded: inventory keys dishes by `{recipeId}_{tier}` (the tier
-- suffix set by CookingService) so Gold/Silver/etc. can stack
-- separately, but the Compendium discovers by *recipe*, not by
-- recipe+tier — so dishes go through PlayerDataService.discover
-- explicitly instead of this automatic path.
local AUTO_DISCOVERY_CATEGORIES: { [string]: boolean } = { fish = true, crops = true, junk = true }

local PlayerDataService = {}

local dataByPlayer: { [Player]: PlayerData } = {}

local function newPlayerData(): PlayerData
	return {
		gold = 100, -- small starter cushion for seeds
		seeds = { MoonriceStalk = 3, SunpetalBerries = 2 },
		crops = {},
		fish = {},
		dishes = {},
		junk = {},
		flags = {},
		-- Default on for the vertical slice: no UI toggle for this exists
		-- yet, and the tight base timing windows (RhythmScoring.lua) are
		-- rough for a first-ever playthrough. Widens hit tolerance ~1.6x;
		-- revisit once a settings menu exists to let players choose.
		assistMode = true,
		discovered = { fish = {}, dishes = {}, crops = {}, junk = {} },
		skillXp = { Farming = 0, Fishing = 0, Cooking = 0 },
		skillPoints = { Farming = 0, Fishing = 0, Cooking = 0 },
		unlockedPerks = { Farming = {}, Fishing = {}, Cooking = {} },
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

	for skillId in SkillTreeConfig.Trees do
		local level = Instance.new("IntValue")
		level.Name = `{skillId}Lvl`
		level.Value = 1
		level.Parent = leaderstats
	end
end

function PlayerDataService.get(player: Player): PlayerData?
	return dataByPlayer[player]
end

-- Server-authoritative data mirrored to the client for HUD/inventory UI,
-- the Compendium (GDD.md §12), the skill tree UI, and dialogue autoRoute
-- checks like "does the player have any ingredient" (DialogueController).
local function syncToClient(player: Player, data: PlayerData)
	Remotes.get("InventoryUpdate"):FireClient(player, {
		gold = data.gold,
		seeds = data.seeds,
		crops = data.crops,
		fish = data.fish,
		dishes = data.dishes,
		junk = data.junk,
		discovered = data.discovered,
		skillXp = data.skillXp,
		skillPoints = data.skillPoints,
		unlockedPerks = data.unlockedPerks,
	})
end

-- Marks `id` (a recipe/species/crop id — NOT an inventory key, see the
-- AUTO_DISCOVERY_CATEGORIES comment above re: dishes) as seen in the
-- Compendium. Returns true if this was the first time. Syncs on its own
-- since callers like CookingService use this independently of addItem.
function PlayerDataService.discover(player: Player, category: "fish" | "dishes" | "crops" | "junk", id: string): boolean
	local data = dataByPlayer[player]
	if not data then
		return false
	end
	local discoveredBucket = data.discovered[category]
	if discoveredBucket[id] then
		return false
	end
	discoveredBucket[id] = true
	syncToClient(player, data)
	return true
end

-- Returns true if this call discovered `id` in `category` for the first
-- time (so callers can show a "New Discovery!" moment via SpectacleUI).
-- See AUTO_DISCOVERY_CATEGORIES for which categories this applies to.
function PlayerDataService.addItem(
	player: Player,
	category: "seeds" | "crops" | "fish" | "dishes" | "junk",
	id: string,
	amount: number
): boolean
	local data = dataByPlayer[player]
	if not data then
		return false
	end

	local bucket = data[category]
	bucket[id] = (bucket[id] or 0) + amount

	local isNewDiscovery = false
	if AUTO_DISCOVERY_CATEGORIES[category] then
		local discoveredBucket = (data.discovered :: any)[category] :: DiscoveredSet
		if not discoveredBucket[id] then
			discoveredBucket[id] = true
			isNewDiscovery = true
		end
	end

	syncToClient(player, data)
	return isNewDiscovery
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

function PlayerDataService.getSkillLevel(player: Player, skillId: SkillTreeConfig.SkillId): number
	local data = dataByPlayer[player]
	if not data then
		return 1
	end
	return 1 + math.floor(data.skillXp[skillId] / SkillTreeConfig.xpPerLevel)
end

export type SkillXpResult = { leveledUp: boolean, newLevel: number }

-- Awards XP toward one of the three pillar skills. A single big award
-- (e.g. a Legendary catch) can cross multiple level thresholds at once —
-- one skill point is granted per level gained, not just one per call.
function PlayerDataService.addSkillXp(player: Player, skillId: SkillTreeConfig.SkillId, amount: number): SkillXpResult
	local data = dataByPlayer[player]
	if not data then
		return { leveledUp = false, newLevel = 1 }
	end

	local levelBefore = PlayerDataService.getSkillLevel(player, skillId)
	data.skillXp[skillId] += amount
	local levelAfter = PlayerDataService.getSkillLevel(player, skillId)

	if levelAfter > levelBefore then
		data.skillPoints[skillId] += (levelAfter - levelBefore)
		local leaderstats = player:FindFirstChild("leaderstats")
		local levelValue = leaderstats and leaderstats:FindFirstChild(`{skillId}Lvl`)
		if levelValue then
			(levelValue :: IntValue).Value = levelAfter
		end
	end

	syncToClient(player, data)
	return { leveledUp = levelAfter > levelBefore, newLevel = levelAfter }
end

function PlayerDataService.hasPerk(player: Player, skillId: SkillTreeConfig.SkillId, perkId: string): boolean
	local data = dataByPlayer[player]
	return data ~= nil and data.unlockedPerks[skillId][perkId] == true
end

-- Validates level/prerequisite/point-cost and, if all satisfied, spends
-- the point and unlocks the perk. Returns false + a reason on failure so
-- the UI can explain why (SkillTreeController.lua).
function PlayerDataService.unlockPerk(player: Player, skillId: SkillTreeConfig.SkillId, perkId: string): (boolean, string?)
	local data = dataByPlayer[player]
	if not data then
		return false, "No player data"
	end

	local tree = SkillTreeConfig.Trees[skillId]
	if not tree then
		return false, "Unknown skill tree"
	end

	local perk = nil
	for _, candidate in tree.perks do
		if candidate.id == perkId then
			perk = candidate
			break
		end
	end
	if not perk then
		return false, "Unknown perk"
	end

	if data.unlockedPerks[skillId][perkId] then
		return false, "Already unlocked"
	end
	if PlayerDataService.getSkillLevel(player, skillId) < perk.requiredLevel then
		return false, "Level too low"
	end
	if perk.requires and not data.unlockedPerks[skillId][perk.requires] then
		return false, "Prerequisite perk not unlocked"
	end
	if data.skillPoints[skillId] < perk.cost then
		return false, "Not enough skill points"
	end

	data.skillPoints[skillId] -= perk.cost
	data.unlockedPerks[skillId][perkId] = true
	syncToClient(player, data)
	return true, nil
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
