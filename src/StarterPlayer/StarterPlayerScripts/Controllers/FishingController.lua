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

local FishingController = {}

local SPOT_TAG = "FishingSpot"
local HOOK_KEY = Enum.KeyCode.E

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

			-- The banner and the "Landed!" toast used to both fire in the
			-- same instant — technically simultaneous but read as two
			-- unrelated pops rather than one connected beat. Staggering the
			-- toast a beat behind the banner's initial pop-in (only when
			-- there's a banner to follow) makes it read as BANG-then-
			-- confirmation instead.
			local celebrationDelaySeconds = 0
			if payload.spectacle then
				-- Priority: a Legendary catch always reads as Legendary first;
				-- otherwise a near-flawless reel-in (FishingService.lua's
				-- PERFECT_CATCH_QUALITY_THRESHOLD) gets its own distinct
				-- banner rather than folding into the generic combo-triggered
				-- "AMAZING CATCH!" — matches fishing games' "Perfect!" catch
				-- being its own celebrated tier, not just "good enough."
				local label: string
				if payload.rarity == "Legendary" then
					label = "LEGENDARY CATCH!"
				elseif payload.perfect then
					label = "PERFECT CATCH!"
				else
					label = "AMAZING CATCH!"
				end
				SpectacleUI.banner(label, accentColor, { shake = true, retro = true })
				celebrationDelaySeconds = 0.15
			else
				ProgressFeedback.announce("FISHING", payload)
			end

			-- Every catch — not just spectacle ones — gets a rarity-colored
			-- ring pop right where the toast is about to appear, so even a
			-- routine Silver Minnow feels like *something* happened instead
			-- of the toast just silently changing text. Spectacle catches
			-- already get their own bigger shake from the banner above; a
			-- small extra one here gives ordinary catches a bit of the same
			-- punch without competing with it.
			task.delay(celebrationDelaySeconds, function()
				SpectacleUI.burst(UDim2.fromScale(0.5, 0.6), accentColor)
				if not payload.spectacle then
					pcall(SpectacleUI.shake, 0.05, 0.12)
				end
				StatusToast.setTemporary(`Landed! A {payload.displayName} breaks the surface!`, 2, true)
			end)
		elseif payload.outcome == "Pull" then
			ProgressFeedback.announce("FISHING", payload)
			StatusToast.setTemporary(`Hauled from the depths: {payload.displayName}.`, 2, true)
		elseif payload.outcome == "ZoneLocked" then
			StatusToast.setTemporary("These waters run too deep for you yet — hone your Fishing skill.", 2, true)
		else
			StatusToast.setTemporary("The line goes slack... it slipped away.", 2, true)
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
				CastMeterUI.start(function(power: number?)
					if not power then
						-- cancelled (e.g. walked away) — nothing was cast
						endFishing()
						return
					end
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
end

return FishingController
