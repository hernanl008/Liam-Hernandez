--!strict
-- Player data for the Act 1 vertical slice, persisted via DataStoreService
-- (docs/ROADMAP.md Phase 3). Loaded on join, saved on leave and on server
-- shutdown. Every DataStore call is pcall-wrapped and falls back to fresh
-- in-memory defaults on failure — a DataStore outage (or, in Studio,
-- forgetting to enable "Studio Access to API Services" under Game
-- Settings > Security) degrades to "progress doesn't save this session"
-- rather than an error.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local SkillTreeConfig = require(Modules:WaitForChild("Shared"):WaitForChild("SkillTreeConfig"))

-- Bump the suffix (v2, v3, ...) if a future PlayerData shape change should
-- start everyone fresh instead of merging onto old saves.
local playerStore = DataStoreService:GetDataStore("AnimeFarmLifePlayerData_v1")

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
	relationships: { [string]: number }, -- keyed by NpcId (DialogueData.lua)
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
		-- Both plantable on Day 1 (Spring) now that FarmingConfig.lua's
		-- season field is actually enforced (FarmingService.PlantSeed) —
		-- MoonriceStalk is Summer-only, so it can't be a starter seed
		-- without breaking Kaya's tutorial for every new player.
		seeds = { SpringrootOnion = 3, SunpetalBerries = 2 },
		crops = {},
		fish = {},
		dishes = {},
		junk = {},
		flags = {},
		relationships = {},
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
		-- Computed from loaded skillXp, not hardcoded to 1 — a returning
		-- player's leaderstat would otherwise show level 1 until their next
		-- level-up recalculates it (PlayerDataService.addSkillXp only
		-- updates this value when a level-up happens on that call).
		level.Value = 1 + math.floor(data.skillXp[skillId] / SkillTreeConfig.xpPerLevel)
		level.Parent = leaderstats
	end
end

-- Starts from fresh defaults and overlays whatever the save has for each
-- top-level field, so a schema change (a new field added since the save
-- was written) fills in with a sane default instead of erroring or leaving
-- the field nil. Doesn't merge *within* a field — if `saved.crops` exists
-- it fully replaces the default's `crops`, it's not merged key-by-key.
local function mergeIntoDefaults(saved: any): PlayerData
	local data = newPlayerData()
	if typeof(saved) ~= "table" then
		return data
	end
	for key, defaultValue in data :: any do
		local savedValue = (saved :: any)[key]
		if savedValue ~= nil and typeof(savedValue) == typeof(defaultValue) then
			(data :: any)[key] = savedValue
		end
	end
	return data
end

local function storeKeyFor(player: Player): string
	return `Player_{player.UserId}`
end

local function loadPlayerData(player: Player): PlayerData
	local ok, result = pcall(function()
		return playerStore:GetAsync(storeKeyFor(player))
	end)
	if not ok then
		warn(`[PlayerDataService] Failed to load save data for {player.Name}: {result} — starting fresh this session.`)
		return newPlayerData()
	end
	if result == nil then
		return newPlayerData() -- first time this player has ever joined
	end
	return mergeIntoDefaults(result)
end

local function savePlayerData(player: Player, data: PlayerData)
	local ok, err = pcall(function()
		playerStore:SetAsync(storeKeyFor(player), data)
	end)
	if not ok then
		warn(`[PlayerDataService] Failed to save data for {player.Name}: {err}`)
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
		flags = data.flags,
		relationships = data.relationships,
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

-- Syncs so client-side dialogue autoRoute checks (e.g. "already met this
-- NPC") see the change without a separate round trip.
function PlayerDataService.setFlag(player: Player, flag: string, value: boolean)
	local data = dataByPlayer[player]
	if data then
		data.flags[flag] = value
		syncToClient(player, data)
	end
end

function PlayerDataService.hasFlag(player: Player, flag: string): boolean
	local data = dataByPlayer[player]
	return data ~= nil and data.flags[flag] == true
end

-- Dialogue choices with a relationshipDelta (DialogueData.lua) round-trip
-- here instead of just being logged client-side (docs/ROADMAP.md Phase 3).
-- Callers should clamp delta themselves (DialogueService.lua does, since
-- it's the one exposed to a client-fired remote) — this function trusts
-- whatever it's given.
function PlayerDataService.addRelationship(player: Player, npcId: string, delta: number): number
	local data = dataByPlayer[player]
	if not data then
		return 0
	end
	local newValue = (data.relationships[npcId] or 0) + delta
	data.relationships[npcId] = newValue
	syncToClient(player, data)
	return newValue
end

function PlayerDataService.getRelationship(player: Player, npcId: string): number
	local data = dataByPlayer[player]
	if not data then
		return 0
	end
	return data.relationships[npcId] or 0
end

Players.PlayerAdded:Connect(function(player: Player)
	local data = loadPlayerData(player) -- yields (GetAsync); fine here, PlayerAdded doesn't need to return quickly
	dataByPlayer[player] = data
	setupLeaderstats(player, data)
	task.defer(syncToClient, player, data) -- defer so PlayerGui exists for the client's own listener
end)

Players.PlayerRemoving:Connect(function(player: Player)
	local data = dataByPlayer[player]
	if data then
		savePlayerData(player, data)
	end
	dataByPlayer[player] = nil
end)

-- PlayerRemoving isn't guaranteed to fire (in time) for everyone during a
-- server shutdown, so save whoever's still connected here too.
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		local data = dataByPlayer[player]
		if data then
			savePlayerData(player, data)
		end
	end
end)

return PlayerDataService
