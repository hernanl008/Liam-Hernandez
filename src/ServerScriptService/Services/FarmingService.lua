--!strict
-- Farming loop: till -> plant -> water -> wait -> harvest. No stamina
-- cost per GDD.md §5 (research-informed decision) — pacing comes from
-- needing to revisit/rewater plots each day, not an energy bar.
--
-- Plots are Parts tagged "FarmPlot" in the Studio place (placed by hand
-- in the world editor — see README.md on what Rojo does and doesn't
-- sync) with a unique string attribute "PlotId" set per part. This
-- service manages the rest of the plot's state as attributes on that
-- same Part, so plot state is inspectable live in Studio while testing.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Remotes = require(Modules:WaitForChild("Shared"):WaitForChild("Remotes"))
local FarmingConfig = require(Modules:WaitForChild("Farming"):WaitForChild("FarmingConfig"))

local PlayerDataService = require(script.Parent:WaitForChild("PlayerDataService"))

local FarmingService = {}

local PLOT_TAG = "FarmPlot"

local function getCropDef(cropId: string)
	for _, crop in FarmingConfig.Crops do
		if crop.id == cropId then
			return crop
		end
	end
	return nil
end

local function findPlot(plotId: string): BasePart?
	for _, instance in CollectionService:GetTagged(PLOT_TAG) do
		if instance:IsA("BasePart") and instance:GetAttribute("PlotId") == plotId then
			return instance
		end
	end
	return nil
end

local function ensureDefaultAttributes(plot: BasePart)
	if plot:GetAttribute("Tilled") == nil then
		plot:SetAttribute("Tilled", false)
	end
	if plot:GetAttribute("CropId") == nil then
		plot:SetAttribute("CropId", "")
	end
	if plot:GetAttribute("WateredToday") == nil then
		plot:SetAttribute("WateredToday", false)
	end
	if plot:GetAttribute("GrowthSeconds") == nil then
		plot:SetAttribute("GrowthSeconds", 0)
	end
	if plot:GetAttribute("StageIndex") == nil then
		plot:SetAttribute("StageIndex", 0)
	end
end

local function stageAtGrowth(cropId: string, growthSeconds: number): number
	local crop = getCropDef(cropId)
	if not crop then
		return 0
	end
	local elapsed = 0
	for _, stage in crop.stages do
		elapsed += stage.durationSeconds
		if growthSeconds < elapsed then
			return stage.stageIndex
		end
	end
	return #crop.stages -- fully grown, sits at final stage until harvested
end

local function isFullyGrown(cropId: string, growthSeconds: number): boolean
	local crop = getCropDef(cropId)
	if not crop then
		return false
	end
	local total = 0
	for _, stage in crop.stages do
		total += stage.durationSeconds
	end
	return growthSeconds >= total
end

function FarmingService.init()
	for _, instance in CollectionService:GetTagged(PLOT_TAG) do
		if instance:IsA("BasePart") then
			ensureDefaultAttributes(instance)
		end
	end

	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(function(instance)
		if instance:IsA("BasePart") then
			ensureDefaultAttributes(instance)
		end
	end)

	Remotes.get("TillSoil").OnServerEvent:Connect(function(player: Player, plotId: string)
		local plot = findPlot(plotId)
		if not plot then
			return
		end
		if plot:GetAttribute("CropId") ~= "" then
			return -- can't till an occupied plot
		end
		plot:SetAttribute("Tilled", true)
	end)

	Remotes.get("PlantSeed").OnServerEvent:Connect(function(player: Player, plotId: string, cropId: string)
		local plot = findPlot(plotId)
		if not plot then
			return
		end
		if not plot:GetAttribute("Tilled") or plot:GetAttribute("CropId") ~= "" then
			return
		end
		if not getCropDef(cropId) then
			warn(`Unknown cropId "{cropId}" requested by {player.Name}`)
			return
		end
		if not PlayerDataService.removeItem(player, "seeds", cropId, 1) then
			return -- doesn't own the seed
		end

		plot:SetAttribute("CropId", cropId)
		plot:SetAttribute("GrowthSeconds", 0)
		plot:SetAttribute("StageIndex", 1)
		plot:SetAttribute("WateredToday", false)
		plot:SetAttribute("Tilled", false)
	end)

	Remotes.get("WaterPlot").OnServerEvent:Connect(function(player: Player, plotId: string)
		local plot = findPlot(plotId)
		if not plot or plot:GetAttribute("CropId") == "" then
			return
		end
		plot:SetAttribute("WateredToday", true)
	end)

	Remotes.get("HarvestCrop").OnServerEvent:Connect(function(player: Player, plotId: string)
		local plot = findPlot(plotId)
		if not plot then
			return
		end
		local cropId = plot:GetAttribute("CropId") :: string
		if cropId == "" then
			return
		end
		local growthSeconds = plot:GetAttribute("GrowthSeconds") :: number
		if not isFullyGrown(cropId, growthSeconds) then
			return
		end

		PlayerDataService.addItem(player, "crops", cropId, 1)

		local crop = getCropDef(cropId)
		if crop and not crop.regrowable then
			plot:SetAttribute("CropId", "")
			plot:SetAttribute("GrowthSeconds", 0)
			plot:SetAttribute("StageIndex", 0)
			plot:SetAttribute("WateredToday", false)
		else
			-- regrowable crops: reset only the final stage's progress
			plot:SetAttribute("WateredToday", false)
		end
	end)

	-- Growth tick: only accumulates while watered, matching the till ->
	-- plant -> water -> wait loop described in Kaya's tutorial dialogue
	-- (docs/DIALOGUE_ACT1.md).
	RunService.Heartbeat:Connect(function(dt: number)
		for _, instance in CollectionService:GetTagged(PLOT_TAG) do
			if instance:IsA("BasePart") then
				local cropId = instance:GetAttribute("CropId") :: string
				if cropId ~= "" and instance:GetAttribute("WateredToday") then
					local growth = (instance:GetAttribute("GrowthSeconds") :: number) + dt
					instance:SetAttribute("GrowthSeconds", growth)
					instance:SetAttribute("StageIndex", stageAtGrowth(cropId, growth))
				end
			end
		end
	end)
end

-- Called by DayCycleService at the start of each new day.
function FarmingService.resetDailyWatering()
	for _, instance in CollectionService:GetTagged(PLOT_TAG) do
		if instance:IsA("BasePart") then
			instance:SetAttribute("WateredToday", false)
		end
	end
end

return FarmingService
