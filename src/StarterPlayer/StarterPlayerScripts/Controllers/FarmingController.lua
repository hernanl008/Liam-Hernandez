--!strict
-- Drives the till -> plant -> water -> harvest ProximityPrompt on every
-- Part tagged "FarmPlot" in the Studio place (see FarmingService.lua for
-- what those attributes mean — this controller only reads them to decide
-- what the prompt should say/do, all validation happens server-side).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local FarmingConfig = require(Modules:WaitForChild("Farming"):WaitForChild("FarmingConfig"))
local InventoryCache = require(Modules:WaitForChild("Client"):WaitForChild("InventoryCache"))
local ProgressFeedback = require(Modules:WaitForChild("UI"):WaitForChild("ProgressFeedback"))
local StatusToast = require(Modules:WaitForChild("UI"):WaitForChild("StatusToast"))

local FarmingController = {}

local PLOT_TAG = "FarmPlot"

-- Updated from DayCycleUpdate; only used to *prefer* an in-season seed
-- when picking which one to auto-plant below — the server is what
-- actually enforces season (FarmingService.lua), this is just to avoid
-- reliably picking a doomed-to-be-rejected seed when the player is
-- holding more than one kind.
local currentSeason: string = "Spring"

-- No seed-selection UI yet (docs/ROADMAP.md Phase 3) — plants whichever
-- seed the player has, preferring one that's actually in season this time
-- of year, first-in-table-order among ties. Good enough while there are
-- only a handful of crops to juggle.
local function pickSeedToPlant(): string?
	local seeds = InventoryCache.get().seeds
	local fallback: string? = nil
	for _, crop in FarmingConfig.Crops do
		if (seeds[crop.id] or 0) > 0 then
			if crop.season == "AllSeason" or crop.season == currentSeason then
				return crop.id
			end
			fallback = fallback or crop.id
		end
	end
	return fallback
end

local function maxStageFor(cropId: string): number
	for _, crop in FarmingConfig.Crops do
		if crop.id == cropId then
			return #crop.stages
		end
	end
	return 0
end

local function describeState(plot: BasePart): string
	local cropId = plot:GetAttribute("CropId")
	if cropId == nil or cropId == "" then
		if plot:GetAttribute("Tilled") then
			return "Plant Seed"
		end
		return "Till Soil"
	end

	local stageIndex = (plot:GetAttribute("StageIndex") :: number) or 0
	if stageIndex >= maxStageFor(cropId :: string) then
		return "Harvest"
	end
	if not plot:GetAttribute("WateredToday") then
		return "Water"
	end
	return "Growing..."
end

local function triggerAction(plot: BasePart)
	local plotId = plot:GetAttribute("PlotId")
	if typeof(plotId) ~= "string" then
		return
	end

	local cropId = plot:GetAttribute("CropId")
	if cropId == nil or cropId == "" then
		if plot:GetAttribute("Tilled") then
			local seedId = pickSeedToPlant()
			if seedId then
				Remotes.get("PlantSeed"):FireServer(plotId, seedId)
			end
		else
			Remotes.get("TillSoil"):FireServer(plotId)
		end
		return
	end

	local stageIndex = (plot:GetAttribute("StageIndex") :: number) or 0
	if stageIndex >= maxStageFor(cropId :: string) then
		Remotes.get("HarvestCrop"):FireServer(plotId)
	elseif not plot:GetAttribute("WateredToday") then
		Remotes.get("WaterPlot"):FireServer(plotId)
	end
end

local function setupPlot(plot: Instance)
	if not plot:IsA("BasePart") then
		return
	end

	local prompt = plot:FindFirstChildWhichIsA("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Parent = plot
		prompt.MaxActivationDistance = 8
		prompt.HoldDuration = 0
	end

	local function refresh()
		local text = describeState(plot)
		prompt.ActionText = text
		prompt.Enabled = text ~= "Growing..."
	end

	refresh()
	plot:GetAttributeChangedSignal("CropId"):Connect(refresh)
	plot:GetAttributeChangedSignal("Tilled"):Connect(refresh)
	plot:GetAttributeChangedSignal("StageIndex"):Connect(refresh)
	plot:GetAttributeChangedSignal("WateredToday"):Connect(refresh)

	prompt.Triggered:Connect(function()
		triggerAction(plot)
	end)
end

function FarmingController.init()
	for _, plot in CollectionService:GetTagged(PLOT_TAG) do
		setupPlot(plot)
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(setupPlot)

	Remotes.get("FarmingOutcome").OnClientEvent:Connect(function(payload: {
		displayName: string,
		bonus: boolean,
		newDiscovery: boolean,
		leveledUp: boolean,
		newLevel: number,
	})
		ProgressFeedback.announce("FARMING", payload)
		local suffix = payload.bonus and " (bonus crop!)" or ""
		StatusToast.setTemporary(`Harvested {payload.displayName}{suffix}`, 2)
	end)

	Remotes.get("PlantSeedRejected").OnClientEvent:Connect(function(reason: string)
		StatusToast.setTemporary(reason, 3)
	end)

	Remotes.get("DayCycleUpdate").OnClientEvent:Connect(function(payload: { season: string? })
		if payload.season then
			currentSeason = payload.season
		end
	end)
end

return FarmingController
