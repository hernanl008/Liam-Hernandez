--!strict
-- Plays docs/OPENING_CUTSCENE.md's Beats 1-3 (the old life fading out, the
-- Weaver's line, the fall) as a full-screen sequence once per player, then
-- hands off into Beats 4-5 by auto-starting Kaya's existing first dialogue
-- node — no separate content needed there, kaya_intro_1 already carries
-- her Beat 5 line almost verbatim. Gated by the SeenOpeningCutscene flag,
-- which persists through PlayerDataService's DataStore save, so this only
-- ever plays once per player, not once per session.
--
-- Deliberately GUI-only, no real 3D camera choreography for Beat 4's
-- "waking up" pan — the beat sheet explicitly allows this ("no death
-- animation needed — the fade itself carries the beat... cheap to
-- build"). LoadingScreen.client.lua explicitly notes it defers this exact
-- work to later; this is that later session.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local Theme = require(Modules:WaitForChild("UI"):WaitForChild("Theme"))

local OpeningCutsceneController = {}

local WEAVER_LINE = "You're not where you were. You're not who you were, either — "
	.. "not anymore. That's alright. Most people don't get to choose their "
	.. "next page. You will, eventually. For now — rest."
local CHARACTERS_PER_SECOND = 40

-- Waits for InventoryCache's first real sync so the SeenOpeningCutscene
-- check reflects the player's actual save data, not the pre-sync default
-- (which would otherwise look identical to "never seen it" for everyone).
local function waitForFirstSync()
	local snapshot = InventoryCache.get() -- also ensures the listener below has something to attach after
	-- A synced player always starts with >=100 gold (PlayerDataService
	-- .newPlayerData), so 0 almost certainly means this is still the
	-- pre-sync default — cheap early-out for the common case.
	if snapshot.gold > 0 then
		return
	end
	local fired = false
	local connection: RBXScriptConnection
	connection = Remotes.get("InventoryUpdate").OnClientEvent:Connect(function()
		fired = true
	end)
	local waited = 0
	while not fired and waited < 10 do
		task.wait(0.1)
		waited += 0.1
	end
	connection:Disconnect()
end

local function playSequence(onComplete: () -> ())
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "OpeningCutscene"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 90
	gui.Parent = playerGui

	local background = Instance.new("Frame")
	background.Size = UDim2.fromScale(1, 1)
	background.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	background.BorderSizePixel = 0
	background.Parent = gui

	local weaverText = Instance.new("TextLabel")
	weaverText.Size = UDim2.fromScale(0.6, 0.3)
	weaverText.Position = UDim2.fromScale(0.2, 0.35)
	weaverText.BackgroundTransparency = 1
	weaverText.TextWrapped = true
	weaverText.TextScaled = true
	weaverText.TextTransparency = 1
	-- Blocky pixel-style font (Theme.RetroFontFace, set via FontFace — not
	-- the legacy .Font property, since this isn't a legacy Enum.Font
	-- value) rather than the game's everyday Gotham — a deliberate
	-- register shift for the pre-rebirth "between worlds" sequence, since
	-- this beat happens before the player has actually arrived in Orange
	-- Ville.
	weaverText.FontFace = Theme.RetroFontFace
	weaverText.TextColor3 = Color3.fromRGB(230, 225, 240)
	weaverText.Text = ""
	weaverText.Parent = background

	-- Beat 1 — The Old Life: no scene, just a slow fade to white (the beat
	-- sheet's own note: "the fade itself carries the beat").
	task.wait(1.2)
	TweenService:Create(background, TweenInfo.new(1.4), { BackgroundColor3 = Color3.fromRGB(255, 255, 255) }):Play()
	task.wait(1.6)

	-- Beat 2 — Between Worlds: fade off the white into a quiet, formless
	-- space, then the Weaver speaks (typewriter, no player input).
	TweenService:Create(background, TweenInfo.new(1.2), { BackgroundColor3 = Color3.fromRGB(20, 14, 28) }):Play()
	task.wait(1.2)

	TweenService:Create(weaverText, TweenInfo.new(0.8), { TextTransparency = 0 }):Play()
	task.spawn(function()
		for i = 1, #WEAVER_LINE do
			weaverText.Text = string.sub(WEAVER_LINE, 1, i)
			task.wait(1 / CHARACTERS_PER_SECOND)
		end
	end)
	task.wait(#WEAVER_LINE / CHARACTERS_PER_SECOND + 2.5) -- hold once fully revealed

	TweenService:Create(weaverText, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	task.wait(0.6)

	-- Beat 3 — The Fall: a quick white flash standing in for "the
	-- particle space collapses inward toward a single point of light."
	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 0 }):Play()
	task.wait(0.6)

	-- Beats 4/5 handoff: fade into the already-loaded, already-lit game
	-- world (AtmosphereService/CameraController are independent of this
	-- sequence) rather than choreographing a separate "waking up" pan,
	-- then hand straight to Kaya's dialogue for the "Found" beat.
	local fadeOut = TweenService:Create(flash, TweenInfo.new(1.0), { BackgroundTransparency = 1 })
	fadeOut:Play()
	fadeOut.Completed:Wait()
	gui:Destroy()

	onComplete()
end

function OpeningCutsceneController.init()
	task.spawn(function()
		waitForFirstSync()
		if InventoryCache.hasFlag("SeenOpeningCutscene") then
			return
		end
		playSequence(function()
			Remotes.get("DialogueAction"):FireServer("SeenOpeningCutscene")
			local DialogueController = require(script.Parent:WaitForChild("DialogueController"))
			DialogueController.startConversation("Kaya")
		end)
	end)
end

return OpeningCutsceneController
