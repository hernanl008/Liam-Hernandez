--!strict
-- Purely visual: a small marker over each FarmPlot that grows taller and
-- shifts from green to gold as StageIndex advances, since nothing else
-- ever visualizes crop growth — MapBuilder's plot parts are flat brown
-- rectangles at every stage, and FarmingConfig.lua's GrowthStage.modelName
-- field (a unique model per crop per stage) is never read by anything.
-- Building real art for that would mean ~13 distinct models across the 5
-- crops, well out of scope for this pass; this is a crop-agnostic stand-in
-- so a planted plot at least visibly changes as it grows instead of only
-- the ProximityPrompt text ("Water" / "Growing..." / "Harvest") saying so.
--
-- Client-only and driven entirely by FarmPlot's existing Attributes
-- (CropId/StageIndex, already replicated for FarmingController's prompt
-- text) — no new remotes or server changes needed.

local CollectionService = game:GetService("CollectionService")

local CropVisualController = {}

local PLOT_TAG = "FarmPlot"
local MARKER_NAME = "CropVisualMarker"

local SPROUT_COLOR = Color3.fromRGB(120, 200, 120)
local RIPE_COLOR = Color3.fromRGB(255, 205, 90)

-- Actual max stage varies per crop (FarmingConfig.lua) — this doesn't need
-- the exact value, the plot's own "Harvest" prompt is the real signal for
-- fully grown; clamping against a generous ceiling just keeps the marker
-- reading as "clearly ripe" once a crop is close to done.
local ASSUMED_MAX_STAGE = 3

local function updateMarker(plot: BasePart)
	local cropId = plot:GetAttribute("CropId")
	local existing = plot:FindFirstChild(MARKER_NAME)

	if typeof(cropId) ~= "string" or cropId == "" then
		if existing then
			existing:Destroy()
		end
		return
	end

	local stageIndex = plot:GetAttribute("StageIndex")
	local progress = math.clamp((typeof(stageIndex) == "number" and stageIndex or 0) / ASSUMED_MAX_STAGE, 0, 1)
	local height = 0.6 + progress * 2.4

	local part: Part
	if existing and existing:IsA("Part") then
		part = existing
	else
		part = Instance.new("Part")
		part.Name = MARKER_NAME
		part.Anchored = true
		part.CanCollide = false
		part.Material = Enum.Material.Neon
		part.Parent = plot
	end

	part.Size = Vector3.new(0.8, height, 0.8)
	part.Position = plot.Position + Vector3.new(0, plot.Size.Y / 2 + height / 2, 0)
	part.Color = SPROUT_COLOR:Lerp(RIPE_COLOR, progress)
end

local function setupPlot(instance: Instance)
	if not instance:IsA("BasePart") then
		return
	end
	updateMarker(instance)
	instance:GetAttributeChangedSignal("CropId"):Connect(function()
		updateMarker(instance)
	end)
	instance:GetAttributeChangedSignal("StageIndex"):Connect(function()
		updateMarker(instance)
	end)
end

function CropVisualController.init()
	for _, instance in CollectionService:GetTagged(PLOT_TAG) do
		setupPlot(instance)
	end
	CollectionService:GetInstanceAddedSignal(PLOT_TAG):Connect(setupPlot)
end

return CropVisualController
