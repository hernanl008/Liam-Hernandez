--!strict
-- Cast -> bite -> reel, driven from a ProximityPrompt on Parts tagged
-- "FishingSpot" (attribute "ZoneId", e.g. "Shallows") placed at the
-- water's edge in Studio. Triggering the prompt starts CastMeterUI's
-- power meter (GDD.md §3); RequestCast only fires once the player locks
-- in a power by pressing Space, and FishingService.pickRandomFish uses
-- that value to bias which fish in the zone gets picked (see its comment
-- for the weighting math) — a whiffed cast isn't gated out, just biased
-- toward commoner fish.

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmUI = require(Modules:WaitForChild("UI"):WaitForChild("RhythmUI"))
local SpectacleUI = require(Modules:WaitForChild("UI"):WaitForChild("SpectacleUI"))
local ProgressFeedback = require(Modules:WaitForChild("UI"):WaitForChild("ProgressFeedback"))
local StatusToast = require(Modules:WaitForChild("UI"):WaitForChild("StatusToast"))
local CastMeterUI = require(Modules:WaitForChild("UI"):WaitForChild("CastMeterUI"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))
local FishingRig = require(Modules:WaitForChild("Client"):WaitForChild("FishingRig"))
local SoundIds = require(Modules:WaitForChild("Shared"):WaitForChild("SoundIds"))
local SoundPlayer = require(Modules:WaitForChild("Client"):WaitForChild("SoundPlayer"))

local FishingController = {}

local SPOT_TAG = "FishingSpot"
local HOOK_KEY = Enum.KeyCode.E

-- Rough length of the reel-in chart, so the placeholder fish (FishingRig)
-- physically arrives at the rod tip right as the minigame ends instead of
-- drifting in on its own unrelated timer. Mirrors RhythmUI's own
-- `endTime = lastNoteTime + HIT_TOLERANCE + 0.4` tail buffer approximately
-- — exact sync isn't the point, just close enough that the fish "shows up"
-- roughly when the chart resolves.
local function estimateReelDuration(notes: any): number
	local maxNoteTime = 0
	for _, note in notes :: { { time: number, lane: number } } do
		maxNoteTime = math.max(maxNoteTime, note.time)
	end
	return maxNoteTime + 0.75
end

-- Tints the reel-in minigame (RhythmUI's `accentColor` option) by the
-- fish's own rarity, so a Legendary fight visibly reads as a bigger deal
-- than a Common one before a single note is even hit — rivets, the catch
-- meter, the lane-cue flash, and the combo counter all pick this up.
local RARITY_ACCENT_COLOR: { [string]: Color3 } = {
	Common = Color3.fromRGB(198, 150, 78), -- Theme.RetroColors.Bronze
	Uncommon = Color3.fromRGB(122, 150, 88),
	Rare = Color3.fromRGB(90, 130, 168),
	Epic = Color3.fromRGB(150, 96, 168),
	Legendary = Color3.fromRGB(230, 178, 60),
}

function FishingController.init()
	local awaitingHook = false
	local hookConnection: RBXScriptConnection? = nil

	-- ProximityPrompts default to KeyCode.E, same key as HOOK_KEY below. If
	-- the "Cast" prompt is left enabled while a cast is already in flight,
	-- pressing E to hook the bite also re-triggers the prompt (the player
	-- never moved out of its range), firing a brand new RequestCast on top
	-- of the one already pending. Track the in-flight prompt so it can be
	-- disabled for the duration of a cast and re-enabled once it resolves.
	local isFishing = false
	local activePrompt: ProximityPrompt? = nil

	local function endFishing()
		isFishing = false
		if activePrompt then
			activePrompt.Enabled = true
			activePrompt = nil
		end
	end

	local function stopAwaitingHook()
		awaitingHook = false
		if hookConnection then
			hookConnection:Disconnect()
			hookConnection = nil
		end
	end

	Remotes.get("FishBite").OnClientEvent:Connect(function()
		awaitingHook = true
		FishingRig.bite()
		SoundPlayer.play(SoundIds.FishingBite)
		StatusToast.set("Something bites! Strike now — press E!", true)
		hookConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or not awaitingHook then
				return
			end
			if input.KeyCode == HOOK_KEY then
				stopAwaitingHook()
				StatusToast.set(nil)
				Remotes.get("HookAttempt"):FireServer()
			end
		end)
	end)

	Remotes.get("ReelStart").OnClientEvent:Connect(function(payload: { fishId: string, displayName: string, rarity: string, notes: any })
		stopAwaitingHook()
		StatusToast.set(nil)
		-- fishId picks the species' cell on the fish sheet, so the thing
		-- thrashing on the line (and later held overhead) is the actual
		-- fish being fought, not a generic stand-in.
		FishingRig.startReel(estimateReelDuration(payload.notes), payload.fishId)
		RhythmUI.play(payload.notes, function(hits)
			Remotes.get("ReelResult"):FireServer(hits)
		end, RhythmGameConfig.TimingWindows, {
			title = "REEL IT IN!",
			subtitle = `{payload.rarity} — {payload.displayName}`,
			retro = true,
			accentColor = RARITY_ACCENT_COLOR[payload.rarity],
		})
	end)

	Remotes.get("CatchResult").OnClientEvent:Connect(function(payload: {
		outcome: string,
		displayName: string?,
		rarity: string?,
		pullId: string?,
		pullType: string?,
		spectacle: boolean?,
		perfect: boolean?,
		newDiscovery: boolean?,
		leveledUp: boolean?,
		newLevel: number?,
	})
		stopAwaitingHook()
		endFishing()

		if payload.outcome == "Caught" then
			local accentColor = (payload.rarity and RARITY_ACCENT_COLOR[payload.rarity]) or RARITY_ACCENT_COLOR.Common

			-- The whole celebration fires from FishingRig's onHeld — the
			-- exact frame the fish reaches its held-up pose — so banner,
			-- toast, sound, sparkles and the fish itself are all on screen
			-- in the same moment, Stardew's "catch held overhead while the
			-- text shows" beat. It used to run after the fish had already
			-- popped, which is why it read as out of sync: the celebration
			-- was celebrating an empty patch of air.
			FishingRig.endReel(true, {
				onHeld = function()
					if payload.spectacle then
						-- Priority: a Legendary catch always reads as
						-- Legendary first; otherwise a near-flawless reel-in
						-- (PERFECT_CATCH_QUALITY_THRESHOLD) gets its own
						-- distinct banner rather than folding into the
						-- generic combo-triggered "AMAZING CATCH!".
						local label: string
						if payload.rarity == "Legendary" then
							label = "LEGENDARY CATCH!"
						elseif payload.perfect then
							label = "PERFECT CATCH!"
						else
							label = "AMAZING CATCH!"
						end
						SpectacleUI.banner(label, accentColor, { shake = true, retro = true })
					else
						ProgressFeedback.announce("FISHING", payload)
						-- Ordinary catches: a small rarity ring near the held
						-- fish (screen center-ish under the locked camera —
						-- NOT the old 0.88 bottom-of-screen spot, which was
						-- nowhere near the fish) + a tiny shake. Spectacle
						-- catches skip it; the ribbon banner is already a lot.
						SpectacleUI.burst(UDim2.fromScale(0.5, 0.42), accentColor)
						pcall(SpectacleUI.shake, 0.05, 0.12)
					end
					SoundPlayer.play(SoundIds.CatchSuccess)
					-- Toast trails the banner pop by one beat so it reads as
					-- BANG-then-confirmation, still while the fish is up
					-- (the hold lasts 1.4s).
					task.delay(0.15, function()
						StatusToast.setTemporary(`Landed! A {payload.displayName} breaks the surface!`, 2, true)
					end)
				end,
				onComplete = FishingRig.unequipRod,
			})
		elseif payload.outcome == "Pull" then
			SoundPlayer.play(SoundIds.PullSnag)
			FishingRig.snagPull(function()
				FishingRig.unequipRod()
				ProgressFeedback.announce("FISHING", payload)
				StatusToast.setTemporary(`Hauled from the depths: {payload.displayName}.`, 2, true)
			end, payload.pullType == "Treasure", payload.pullId)
		else
			-- GotAway / ZoneLocked: dart-away animation (or nothing, for
			-- ZoneLocked which never had a fish), then the letdown.
			FishingRig.endReel(false, {
				onComplete = function()
					FishingRig.unequipRod()
					if payload.outcome == "ZoneLocked" then
						StatusToast.setTemporary("These waters run too deep for you yet — hone your Fishing skill.", 2, true)
					else
						SoundPlayer.play(SoundIds.CatchEscape)
						StatusToast.setTemporary("The line goes slack... it slipped away.", 2, true)
					end
				end,
			})
		end
	end)

	local function setupSpot(instance: Instance)
		if not instance:IsA("BasePart") then
			return
		end
		local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.MaxActivationDistance = 10
			prompt.Parent = instance
		end
		prompt.ActionText = "Cast"
		prompt.Triggered:Connect(function()
			if isFishing then
				-- Prompt.Enabled = false below should already prevent this,
				-- but that toggle only takes effect on the next replication
				-- tick — guard here too so a same-frame double-fire (e.g.
				-- the E press that also serves as HOOK_KEY) can't sneak a
				-- second RequestCast in.
				return
			end
			local zoneId = instance:GetAttribute("ZoneId")
			if typeof(zoneId) == "string" then
				isFishing = true
				activePrompt = prompt
				prompt.Enabled = false
				FishingRig.equipRod(instance)
				CastMeterUI.start(function(power: number?)
					if not power then
						-- cancelled (e.g. walked away) — nothing was cast, so
						-- there's no bite/reel to animate; put the rod away
						-- immediately instead of waiting on CatchResult.
						endFishing()
						FishingRig.unequipRod()
						return
					end
					SoundPlayer.play(SoundIds.FishingCast)
					StatusToast.set("Casting your line into the deep...", true)
					Remotes.get("RequestCast"):FireServer(zoneId, power)
				end)
			else
				warn(`FishingSpot "{instance:GetFullName()}" has no ZoneId attribute`)
			end
		end)
	end

	for _, instance in CollectionService:GetTagged(SPOT_TAG) do
		setupSpot(instance)
	end
	CollectionService:GetInstanceAddedSignal(SPOT_TAG):Connect(setupSpot)

	-- A visual tell that night-only content (the Moonlit Serpent —
	-- LORE_BIBLE.md §5, Shallows only) is in play, since otherwise
	-- there's no way to know without already knowing the config. Fires
	-- once on the day->night transition (not every DayCycleUpdate tick,
	-- which broadcasts several times a second) — matches
	-- NIGHT_START_CLOCK_TIME (8pm) in DayCycleService.lua; duplicated as
	-- a single number here rather than plumbing a proper isNight() flag
	-- through DayCycleUpdate's payload, which felt like overkill for one
	-- flavor toast.
	local NIGHT_START_CLOCK_TIME = 20
	local wasNight = false
	Remotes.get("DayCycleUpdate").OnClientEvent:Connect(function(payload: { day: number, dayProgress: number, season: string, weather: string })
		local clockTime = 6 + payload.dayProgress * 18
		local isNight = clockTime >= NIGHT_START_CLOCK_TIME
		if isNight and not wasNight then
			StatusToast.setTemporary("The water looks different under the moonlight tonight...", 3, true)
		end
		wasNight = isNight
	end)
end

return FishingController
