--!strict
-- Cast -> bite -> reel arc (GDD.md §3). The reel-in is a short procedurally
-- generated rhythm chart scored by the same RhythmScoring module the
-- cooking system uses (GDD.md §10 — deliberate shared implementation).
--
-- Zones are level-gated via the Fishing skill (GDD.md §12); Shallows and
-- MidReef both have fish configured. Weight/quality-driven sell pricing
-- is still a TODO for Phase 3 — catching a fish here just adds it to
-- inventory; selling is the Trade Exchange's job (GDD.md §7).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmScoring = require(Modules:WaitForChild("Shared"):WaitForChild("RhythmScoring"))
local FishingConfig = require(Modules:WaitForChild("Fishing"):WaitForChild("FishingConfig"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local DayCycleService = require(script.Parent:WaitForChild("DayCycleService"))

local FishingService = {}

local BASE_HOOK_WINDOW_SECONDS = 1.2
local MIN_CATCH_QUALITY = 15 -- below this, the fish gets away even if hooked

-- Rain (DayCycleService.getCurrentWeather) — see the RequestCast handler.
local RAIN_WEIGHT_BONUS = 0.15
local RAIN_PATIENCE_MULTIPLIER = 0.85

-- Fishing-wiki-informed tightening pass: real angling games (bite time
-- scaling with skill, a distinct "Perfect!" catch tier with its own XP
-- multiplier) adapted to our rhythm-chart reel-in rather than a bobber
-- minigame — see the RequestCast/ReelResult handlers below for where
-- each of these actually apply.
local BITE_TIME_REDUCTION_PER_LEVEL = 0.02 -- multiplicative, not flat seconds — our patience ranges are already small (1-10s)
local MAX_BITE_TIME_REDUCTION = 0.5 -- floor: patience can never drop below 50% of its rolled value from skill alone
local PERFECT_CATCH_QUALITY_THRESHOLD = 95
local PERFECT_CATCH_XP_MULTIPLIER = 2.4

type PendingBite = {
	kind: "Fish",
	fish: FishingConfig.FishDef,
} | {
	kind: "Pull",
	pull: FishingConfig.PullDef,
}

type PendingReel = {
	fish: FishingConfig.FishDef,
	chart: { RhythmScoring.Note },
}

local pendingBites: { [Player]: PendingBite } = {}
local pendingReels: { [Player]: PendingReel } = {}

local function fishForZone(zoneId: string): { FishingConfig.FishDef }
	local isNight = DayCycleService.isNight()
	local matches = {}
	for _, fish in FishingConfig.Fish do
		if table.find(fish.zones, zoneId) and (not fish.nightOnly or isNight) then
			table.insert(matches, fish)
		end
	end
	return matches
end

-- Cast-power meter (GDD.md §3): `castPower` (0-1, from CastMeterUI.lua)
-- biases which fish in the zone gets picked, interpolating each rarity's
-- weight from FishingConfig.RarityWeight (castPower = 0) toward
-- RarityWeight * (1 + RarityPowerBonus) (castPower = 1). A weak/whiffed
-- cast still can land anything in the zone — it's a bias, not a gate.
local function pickRandomFish(zoneId: string, castPower: number): FishingConfig.FishDef?
	local candidates = fishForZone(zoneId)
	if #candidates == 0 then
		return nil
	end

	local totalWeight = 0
	local weights: { number } = {}
	for i, fish in candidates do
		local baseWeight = FishingConfig.RarityWeight[fish.rarity] or 1
		local bonus = FishingConfig.RarityPowerBonus[fish.rarity] or 0
		local weight = math.max(baseWeight * (1 + bonus * castPower), 0.01)
		weights[i] = weight
		totalWeight += weight
	end

	local roll = math.random() * totalWeight
	local cumulative = 0
	for i, weight in weights do
		cumulative += weight
		if roll <= cumulative then
			return candidates[i]
		end
	end
	return candidates[#candidates]
end

-- TreasureHunter perk doubles the odds a pull is treasure rather than junk.
local function pickRandomPull(player: Player): FishingConfig.PullDef
	local treasureShare = FishingConfig.TreasureShare
	if PlayerDataService.hasPerk(player, "Fishing", "TreasureHunter") then
		treasureShare = math.min(treasureShare * 2, 1)
	end

	local isTreasure = math.random() < treasureShare
	local candidates = {}
	for _, pull in FishingConfig.Pulls do
		if (pull.pullType == "Treasure") == isTreasure then
			table.insert(candidates, pull)
		end
	end
	return candidates[math.random(1, #candidates)]
end

-- QuickHands perk gives 50% longer to hit the hook window after a bite.
local function hookWindowFor(player: Player): number
	if PlayerDataService.hasPerk(player, "Fishing", "QuickHands") then
		return BASE_HOOK_WINDOW_SECONDS * 1.5
	end
	return BASE_HOOK_WINDOW_SECONDS
end

-- SteadyHands (SkillTreeConfig.lua): the chart generates as if the fish
-- were putting up less of a fight — fewer/slower notes, same as a lower-
-- struggleDifficulty fish would produce. Applied here rather than as a
-- flat scoring bonus so it actually makes the minigame itself easier to
-- play, not just more forgiving to grade.
local STEADY_HANDS_DIFFICULTY_REDUCTION = 2

local function generateReelChart(struggleDifficulty: number, player: Player): { RhythmScoring.Note }
	local effectiveDifficulty = struggleDifficulty
	if PlayerDataService.hasPerk(player, "Fishing", "SteadyHands") then
		effectiveDifficulty = math.max(1, struggleDifficulty - STEADY_HANDS_DIFFICULTY_REDUCTION)
	end
	local noteCount = 4 + math.floor(effectiveDifficulty / 2)
	local tempo = math.max(0.9 - effectiveDifficulty * 0.05, 0.35)
	local notes = {}
	for i = 1, noteCount do
		table.insert(notes, { time = i * tempo, lane = math.random(1, 3) })
	end
	return notes
end

function FishingService.init()
	Remotes.get("RequestCast").OnServerEvent:Connect(function(player: Player, zoneId: string, rawCastPower: number?)
		local zone: FishingConfig.DepthZone? = nil
		for _, z in FishingConfig.DepthZones do
			if z.id == zoneId then
				zone = z
				break
			end
		end
		if not zone then
			return
		end

		local skillLevel = PlayerDataService.getSkillLevel(player, "Fishing")
		if skillLevel < zone.unlockLevel then
			Remotes.get("CatchResult"):FireClient(player, { outcome = "ZoneLocked", zoneId = zoneId })
			return
		end

		-- Trust nothing from the client past clamping — CastMeterUI.lua
		-- only ever sends 0-1, but a modified client could send anything.
		local castPower = math.clamp(typeof(rawCastPower) == "number" and rawCastPower or 0, 0, 1)

		-- GDD.md §3's "broader weather effects on fish spawns": rain folds
		-- into the same rarity-weighting bias as a strong cast (a rainy
		-- Shallows is a better bite regardless of how well-timed the cast
		-- was) and independently speeds bites up a little, same idea as
		-- real angling advice that fish bite more in the rain.
		local isRaining = DayCycleService.getCurrentWeather() == "Rainy"
		local weightingPower = math.min(castPower + (isRaining and RAIN_WEIGHT_BONUS or 0), 1)

		-- Deeper zones thin out junk pulls (fishing-wiki-informed: "distance
		-- from land" reducing trash odds), same spirit as junkChanceMultiplier
		-- says on FishingConfig.DepthZone.
		local isPull = math.random() < FishingConfig.PullChance * zone.junkChanceMultiplier
		local patienceSeconds: number

		if isPull then
			pendingBites[player] = { kind = "Pull", pull = pickRandomPull(player) }
			patienceSeconds = math.random() * 1.5 + 0.5
		else
			local fish = pickRandomFish(zoneId, weightingPower)
			if not fish then
				return -- no fish configured for this zone yet
			end
			pendingBites[player] = { kind = "Fish", fish = fish }
			patienceSeconds = fish.bitePatience.Min + math.random() * (fish.bitePatience.Max - fish.bitePatience.Min)
			-- A strong cast also bites a bit faster (up to 15% sooner at
			-- castPower = 1), on top of the species-weighting above — a
			-- weak cast isn't punished, a good one is just extra rewarding.
			patienceSeconds *= 1 - castPower * 0.15
			if isRaining then
				patienceSeconds *= RAIN_PATIENCE_MULTIPLIER
			end
			-- Higher Fishing level bites faster too — the skill itself
			-- mattering for bite speed, not just zone access/perks.
			local skillReduction = math.min(skillLevel * BITE_TIME_REDUCTION_PER_LEVEL, MAX_BITE_TIME_REDUCTION)
			patienceSeconds *= 1 - skillReduction
		end

		task.delay(patienceSeconds, function()
			if pendingBites[player] then
				Remotes.get("FishBite"):FireClient(player)
				task.delay(hookWindowFor(player), function()
					-- window expired without a successful hook attempt
					if pendingBites[player] then
						pendingBites[player] = nil
						Remotes.get("CatchResult"):FireClient(player, { outcome = "GotAway" })
					end
				end)
			end
		end)
	end)

	Remotes.get("HookAttempt").OnServerEvent:Connect(function(player: Player)
		local bite = pendingBites[player]
		if not bite then
			return
		end
		pendingBites[player] = nil

		if bite.kind == "Pull" then
			local isNewDiscovery = PlayerDataService.addItem(player, "junk", bite.pull.id, 1)
			Remotes.get("CatchResult"):FireClient(player, {
				outcome = "Pull",
				pullId = bite.pull.id,
				displayName = bite.pull.displayName,
				newDiscovery = isNewDiscovery,
			})
			return
		end

		local chart = generateReelChart(bite.fish.struggleDifficulty, player)
		pendingReels[player] = { fish = bite.fish, chart = chart }
		Remotes.get("ReelStart"):FireClient(player, { fishId = bite.fish.id, notes = chart })
	end)

	Remotes.get("ReelResult").OnServerEvent:Connect(function(player: Player, hits: { RhythmScoring.Hit })
		local reel = pendingReels[player]
		if not reel then
			return
		end
		pendingReels[player] = nil

		local data = PlayerDataService.get(player)
		local assistMode = data ~= nil and data.assistMode or false
		local result = RhythmScoring.evaluate(reel.chart, hits, RhythmGameConfig.TimingWindows, assistMode)

		if result.quality < MIN_CATCH_QUALITY then
			Remotes.get("CatchResult"):FireClient(player, { outcome = "GotAway", fishId = reel.fish.id })
			return
		end

		local isNewDiscovery = PlayerDataService.addItem(player, "fish", reel.fish.id, 1)

		-- Quality-scaled XP: a barely-passing reel (near MIN_CATCH_QUALITY)
		-- earns ~0.65x the base rarity XP, a flawless one ~1.5x, and a
		-- near-perfect chart (>= PERFECT_CATCH_QUALITY_THRESHOLD) gets an
		-- extra 2.4x on top — the exact "perfect catch" XP multiplier real
		-- fishing games use, adapted here to our combo-scored quality
		-- instead of a bobber minigame's in-bar-the-whole-time check.
		local baseXp = FishingConfig.RarityXp[reel.fish.rarity] or 10
		local isPerfectCatch = result.quality >= PERFECT_CATCH_QUALITY_THRESHOLD
		local qualityMultiplier = 0.5 + (result.quality / 100)
		local xpAward = math.floor(baseXp * qualityMultiplier)
		if isPerfectCatch then
			xpAward = math.floor(xpAward * PERFECT_CATCH_XP_MULTIPLIER)
		end
		local xpResult = PlayerDataService.addSkillXp(player, "Fishing", xpAward)

		-- LORE_BIBLE.md §5 (Ren Amakusa): the Moonlit Serpent is his "one
		-- that got away" made literal — landing it (first time only) flags
		-- his postgame closure conversation as available. DialogueData.lua's
		-- ren_check_serpent_root autoRoute reads this to branch to
		-- ren_closure_1 instead of the usual short return greeting.
		if reel.fish.id == "MoonlitSerpent" then
			PlayerDataService.setFlag(player, "CaughtMoonlitSerpent", true)
		end

		Remotes.get("CatchResult"):FireClient(player, {
			outcome = "Caught",
			fishId = reel.fish.id,
			displayName = reel.fish.displayName,
			rarity = reel.fish.rarity,
			quality = result.quality,
			maxCombo = result.maxCombo,
			newDiscovery = isNewDiscovery,
			leveledUp = xpResult.leveledUp,
			newLevel = xpResult.newLevel,
			perfect = isPerfectCatch,
			-- GDD.md §11: a fish flagged `spectacle` (or a big combo on any
			-- fish) triggers FishingController's celebratory banner/shake.
			-- A perfect catch is spectacle-worthy on its own now too.
			spectacle = reel.fish.spectacle == true or result.maxCombo >= 5 or isPerfectCatch,
		})
	end)
end

return FishingService
