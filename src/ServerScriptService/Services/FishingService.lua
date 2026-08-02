--!strict
-- Cast -> bite -> reel arc (GDD.md §3). The reel-in is a short procedurally
-- generated rhythm chart scored by the same RhythmScoring module the
-- cooking system uses (GDD.md §10 — deliberate shared implementation).
--
-- Zones are level-gated via PlayerDataService.fishingLevel (GDD.md §11);
-- Shallows and MidReef both have fish configured. Weight/quality-driven
-- sell pricing is still a TODO for Phase 3 — catching a fish here just
-- adds it to inventory; selling is the Trade Exchange's job (GDD.md §7).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmScoring = require(Modules:WaitForChild("Shared"):WaitForChild("RhythmScoring"))
local FishingConfig = require(Modules:WaitForChild("Fishing"):WaitForChild("FishingConfig"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))
local DayCycleService = require(script.Parent:WaitForChild("DayCycleService"))

local FishingService = {}

local HOOK_WINDOW_SECONDS = 1.2
local MIN_CATCH_QUALITY = 15 -- below this, the fish gets away even if hooked

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

local function pickRandomFish(zoneId: string): FishingConfig.FishDef?
	local candidates = fishForZone(zoneId)
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

local function pickRandomPull(): FishingConfig.PullDef
	local isTreasure = math.random() < FishingConfig.TreasureShare
	local candidates = {}
	for _, pull in FishingConfig.Pulls do
		if (pull.pullType == "Treasure") == isTreasure then
			table.insert(candidates, pull)
		end
	end
	return candidates[math.random(1, #candidates)]
end

local function generateReelChart(struggleDifficulty: number): { RhythmScoring.Note }
	local noteCount = 4 + math.floor(struggleDifficulty / 2)
	local tempo = math.max(0.9 - struggleDifficulty * 0.05, 0.35)
	local notes = {}
	for i = 1, noteCount do
		table.insert(notes, { time = i * tempo, lane = math.random(1, 3) })
	end
	return notes
end

function FishingService.init()
	Remotes.get("RequestCast").OnServerEvent:Connect(function(player: Player, zoneId: string)
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

		if PlayerDataService.getFishingLevel(player) < zone.unlockLevel then
			Remotes.get("CatchResult"):FireClient(player, { outcome = "ZoneLocked", zoneId = zoneId })
			return
		end

		local isPull = math.random() < FishingConfig.PullChance
		local patienceSeconds: number

		if isPull then
			pendingBites[player] = { kind = "Pull", pull = pickRandomPull() }
			patienceSeconds = math.random() * 1.5 + 0.5
		else
			local fish = pickRandomFish(zoneId)
			if not fish then
				return -- no fish configured for this zone yet
			end
			pendingBites[player] = { kind = "Fish", fish = fish }
			patienceSeconds = fish.bitePatience.Min + math.random() * (fish.bitePatience.Max - fish.bitePatience.Min)
		end

		task.delay(patienceSeconds, function()
			if pendingBites[player] then
				Remotes.get("FishBite"):FireClient(player)
				task.delay(HOOK_WINDOW_SECONDS, function()
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
			PlayerDataService.addItem(player, "junk", bite.pull.id, 1)
			Remotes.get("CatchResult"):FireClient(player, {
				outcome = "Pull",
				pullId = bite.pull.id,
				displayName = bite.pull.displayName,
			})
			return
		end

		local chart = generateReelChart(bite.fish.struggleDifficulty)
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

		PlayerDataService.addItem(player, "fish", reel.fish.id, 1)
		PlayerDataService.registerCatch(player)
		Remotes.get("CatchResult"):FireClient(player, {
			outcome = "Caught",
			fishId = reel.fish.id,
			displayName = reel.fish.displayName,
			rarity = reel.fish.rarity,
			quality = result.quality,
			maxCombo = result.maxCombo,
			-- GDD.md §11: a fish flagged `spectacle` (or a big combo on any
			-- fish) triggers FishingController's celebratory banner/shake.
			spectacle = reel.fish.spectacle == true or result.maxCombo >= 5,
		})
	end)
end

return FishingService
