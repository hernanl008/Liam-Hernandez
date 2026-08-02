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
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmUI = require(Modules:WaitForChild("UI"):WaitForChild("RhythmUI"))
local SpectacleUI = require(Modules:WaitForChild("UI"):WaitForChild("SpectacleUI"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))

local FishingController = {}

local SPOT_TAG = "FishingSpot"
local HOOK_KEY = Enum.KeyCode.E

local statusGui: ScreenGui? = nil
local statusLabel: TextLabel

local function ensureStatusGui()
	if statusGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "FishingStatus"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	statusGui = gui

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.fromScale(0.4, 0.06)
	statusLabel.Position = UDim2.fromScale(0.3, 0.6)
	statusLabel.BackgroundTransparency = 0.4
	statusLabel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
	statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	statusLabel.TextScaled = true
	statusLabel.Text = ""
	statusLabel.Visible = false
	statusLabel.Parent = gui
end

local function setStatus(text: string?)
	ensureStatusGui()
	if text then
		statusLabel.Text = text
		statusLabel.Visible = true
	else
		statusLabel.Visible = false
	end
end

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
		setStatus("Something's biting! Press E!")
		hookConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if gameProcessed or not awaitingHook then
				return
			end
			if input.KeyCode == HOOK_KEY then
				stopAwaitingHook()
				setStatus(nil)
				Remotes.get("HookAttempt"):FireServer()
			end
		end)
	end)

	Remotes.get("ReelStart").OnClientEvent:Connect(function(payload: { fishId: string, notes: any })
		stopAwaitingHook()
		setStatus(nil)
		RhythmUI.play(payload.notes, function(hits)
			Remotes.get("ReelResult"):FireServer(hits)
		end, RhythmGameConfig.TimingWindows)
	end)

	Remotes.get("CatchResult").OnClientEvent:Connect(function(payload: { outcome: string, displayName: string?, rarity: string?, spectacle: boolean? })
		stopAwaitingHook()
		if payload.outcome == "Caught" then
			if payload.spectacle then
				local label = payload.rarity == "Legendary" and "LEGENDARY CATCH!" or "AMAZING CATCH!"
				SpectacleUI.banner(label, Color3.fromRGB(255, 220, 80), { shake = true })
			end
			setStatus(`Caught a {payload.displayName}!`)
		elseif payload.outcome == "Pull" then
			setStatus(`Reeled up: {payload.displayName}`)
		elseif payload.outcome == "ZoneLocked" then
			setStatus("This zone needs a higher fishing level.")
		else
			setStatus("It got away...")
		end
		task.delay(2, function()
			setStatus(nil)
		end)
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
				setStatus("Casting...")
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
