--!strict
-- Cooking rhythm minigame, driven from a ProximityPrompt on Parts tagged
-- "CookingStation" (attribute "RecipeId", e.g. "GrilledMinnowSkewer")
-- placed at a stove/counter in Studio.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmUI = require(Modules:WaitForChild("UI"):WaitForChild("RhythmUI"))
local SpectacleUI = require(Modules:WaitForChild("UI"):WaitForChild("SpectacleUI"))
local ProgressFeedback = require(Modules:WaitForChild("UI"):WaitForChild("ProgressFeedback"))
local StatusToast = require(Modules:WaitForChild("UI"):WaitForChild("StatusToast"))
local RhythmGameConfig = require(Modules:WaitForChild("Cooking"):WaitForChild("RhythmGameConfig"))

local CookingController = {}

local STATION_TAG = "CookingStation"

function CookingController.init()
	Remotes.get("CookingStart").OnClientEvent:Connect(function(payload: { recipeId: string, notes: any })
		StatusToast.set(nil)
		RhythmUI.play(payload.notes, function(hits)
			Remotes.get("CookingResult"):FireServer(hits)
		end, RhythmGameConfig.TimingWindows)
	end)

	Remotes.get("CookingOutcome").OnClientEvent:Connect(function(payload: {
		displayName: string,
		tier: string,
		estimatedValue: number,
		spectacle: boolean?,
		newDiscovery: boolean?,
		leveledUp: boolean?,
		newLevel: number?,
	})
		if payload.spectacle then
			local color = payload.tier == "Gold" and Color3.fromRGB(255, 215, 60) or Color3.fromRGB(255, 220, 80)
			SpectacleUI.banner(`{string.upper(payload.tier)} TIER!`, color, { shake = true })
		else
			ProgressFeedback.announce("COOKING", payload)
		end
		StatusToast.setTemporary(`{payload.tier} {payload.displayName} (~{payload.estimatedValue}g)`, 2.5)
	end)

	local function setupStation(instance: Instance)
		local prompt = instance:FindFirstChildWhichIsA("ProximityPrompt", true)
		if not prompt then
			return
		end
		prompt.ActionText = "Cook"
		prompt.Triggered:Connect(function()
			local recipeId = instance:GetAttribute("RecipeId")
			if typeof(recipeId) == "string" then
				Remotes.get("StartCooking"):FireServer(recipeId)
			else
				warn(`CookingStation "{instance:GetFullName()}" has no RecipeId attribute`)
			end
		end)
	end

	for _, instance in CollectionService:GetTagged(STATION_TAG) do
		setupStation(instance)
	end
	CollectionService:GetInstanceAddedSignal(STATION_TAG):Connect(setupStation)
end

return CookingController
