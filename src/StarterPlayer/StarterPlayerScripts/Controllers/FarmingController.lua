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

local FarmingController = {}

local PLOT_TAG = "FarmPlot"

-- Only one crop exists in FarmingConfig.lua right now, so planting is
-- hardcoded to it — swap this for a seed-selection UI once there's more
-- than one to choose from (docs/ROADMAP.md Phase 3).
local DEFAULT_SEED_ID = "MoonriceStalk"

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
			Remotes.get("PlantSeed"):FireServer(plotId, DEFAULT_SEED_ID)
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
end

return FarmingController
