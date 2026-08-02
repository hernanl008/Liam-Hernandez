--!strict
-- Cooking rhythm minigame, driven from a ProximityPrompt on Parts tagged
-- "CookingStation" (attribute "RecipeId", e.g. "GrilledMinnowSkewer")
-- placed at a stove/counter in Studio.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")

local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local RhythmUI = require(Modules:WaitForChild("UI"):WaitForChild("RhythmUI"))

local CookingController = {}

local STATION_TAG = "CookingStation"

local statusGui: ScreenGui? = nil
local statusLabel: TextLabel

local function ensureStatusGui()
	if statusGui then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "CookingStatus"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	statusGui = gui

	statusLabel = Instance.new("TextLabel")
	statusLabel.Size = UDim2.fromScale(0.4, 0.06)
	statusLabel.Position = UDim2.fromScale(0.3, 0.55)
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

function CookingController.init()
	Remotes.get("CookingStart").OnClientEvent:Connect(function(payload: { recipeId: string, notes: any })
		setStatus(nil)
		RhythmUI.play(payload.notes, function(hits)
			Remotes.get("CookingResult"):FireServer(hits)
		end)
	end)

	Remotes.get("CookingOutcome").OnClientEvent:Connect(function(payload: { displayName: string, tier: string, estimatedValue: number })
		setStatus(`{payload.tier} {payload.displayName} (~{payload.estimatedValue}g)`)
		task.delay(2.5, function()
			setStatus(nil)
		end)
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
