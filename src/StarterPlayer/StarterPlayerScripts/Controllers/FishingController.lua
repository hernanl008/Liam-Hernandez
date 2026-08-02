--!strict
-- Cast -> bite -> reel, driven from a ProximityPrompt on Parts tagged
-- "FishingSpot" (attribute "ZoneId", e.g. "Shallows") placed at the
-- water's edge in Studio. The cast-power meter described in GDD.md §3 is
-- deliberately not built yet — FishingService doesn't consume a cast
-- quality value today, so a meter here would be UI with nothing behind
-- it. Casting is instant on trigger for this vertical slice; the meter
-- is a Phase 3 addition once it actually affects bite odds server-side.

local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmUI = require(Modules:WaitForChild("UI"):WaitForChild("RhythmUI"))
local SpectacleUI = require(Modules:WaitForChild("UI"):WaitForChild("SpectacleUI"))
local ProgressFeedback = require(Modules:WaitForChild("UI"):WaitForChild("ProgressFeedback"))
local StatusToast = require(Modules:WaitForChild("UI"):WaitForChild("StatusToast"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))

local FishingController = {}

local SPOT_TAG = "FishingSpot"
local HOOK_KEY = Enum.KeyCode.E

function FishingController.init()
	local awaitingHook = false
	local hookConnection: RBXScriptConnection? = nil

	local function stopAwaitingHook()
		awaitingHook = false
		if hookConnection then
			hookConnection:Disconnect()
			hookConnection = nil
		end
	end

	Remotes.get("FishBite").OnClientEvent:Connect(function()
		awaitingHook = true
		StatusToast.set("Something's biting! Press E!")
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

	Remotes.get("ReelStart").OnClientEvent:Connect(function(payload: { fishId: string, notes: any })
		stopAwaitingHook()
		StatusToast.set(nil)
		RhythmUI.play(payload.notes, function(hits)
			Remotes.get("ReelResult"):FireServer(hits)
		end, RhythmGameConfig.TimingWindows)
	end)

	Remotes.get("CatchResult").OnClientEvent:Connect(function(payload: {
		outcome: string,
		displayName: string?,
		rarity: string?,
		spectacle: boolean?,
		newDiscovery: boolean?,
		leveledUp: boolean?,
		newLevel: number?,
	})
		stopAwaitingHook()
		if payload.outcome == "Caught" then
			if payload.spectacle then
				local label = payload.rarity == "Legendary" and "LEGENDARY CATCH!" or "AMAZING CATCH!"
				SpectacleUI.banner(label, Color3.fromRGB(255, 220, 80), { shake = true })
			else
				ProgressFeedback.announce("FISHING", payload)
			end
			StatusToast.setTemporary(`Caught a {payload.displayName}!`, 2)
		elseif payload.outcome == "Pull" then
			ProgressFeedback.announce("FISHING", payload)
			StatusToast.setTemporary(`Reeled up: {payload.displayName}`, 2)
		elseif payload.outcome == "ZoneLocked" then
			StatusToast.setTemporary("This zone needs a higher fishing level.", 2)
		else
			StatusToast.setTemporary("It got away...", 2)
		end
	end)

	local function setupSpot(instance: Instance)
		local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			return
		end
		prompt.ActionText = "Cast"
		prompt.Triggered:Connect(function()
			local zoneId = instance:GetAttribute("ZoneId")
			if typeof(zoneId) == "string" then
				StatusToast.set("Casting...")
				Remotes.get("RequestCast"):FireServer(zoneId)
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
