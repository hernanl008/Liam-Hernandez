--!strict
-- Builds the small Orange Ville starter map from MapConfig.lua's tile
-- grid, and auto-places the interactive objects (farm plots, fishing
-- spot, cooking stations, NPCs, spawn point) that
-- docs/VERTICAL_SLICE_SETUP.md previously asked Liam to hand-place in
-- Studio. Run once at server start; safe to re-run (clears its own
-- "GeneratedMap" folder first) so re-syncing doesn't create duplicates.
--
-- NPC placeholders here are plain colored blocks with a floating name
-- label, not the pixel-art sprites (GDD.md §13) — swapping in real
-- character art/models is a Studio task, this just guarantees something
-- tagged "NPC" with the right NpcId exists to talk to.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Modules = ReplicatedStorage:WaitForChild("Modules")
local MapConfig = require(Modules:WaitForChild("Shared"):WaitForChild("MapConfig"))
local AssetIds = require(Modules:WaitForChild("Shared"):WaitForChild("AssetIds"))

local MapBuilder = {}

local FOLDER_NAME = "GeneratedMap"

-- Y = 0.5 is ground level: tiles are 1 stud tall centered at y=0, so
-- their top surface sits at 0.5. Callers add half their own height on
-- top of this so everything rests flush on the ground instead of
-- floating (each `+ Vector3.new(0, halfHeight, 0)` below is exactly that).
local function worldPositionFor(spot: MapConfig.GridSpot): Vector3
	local tileSize = MapConfig.TileSize
	return Vector3.new((spot.col - 1) * tileSize, 0.5, (spot.row - 1) * tileSize)
end

local function tagPart(part: BasePart, tag: string, attributes: { [string]: any })
	CollectionService:AddTag(part, tag)
	for key, value in attributes do
		part:SetAttribute(key, value)
	end
end

local function buildGround(folder: Folder)
	local tileSize = MapConfig.TileSize
	for rowIndex, row in MapConfig.Grid do
		for col = 1, #row do
			local char = row:sub(col, col)
			local tileDef = MapConfig.TileTypes[char]
			if tileDef then
				local part = Instance.new("Part")
				part.Name = `Tile_{rowIndex}_{col}`
				part.Anchored = true
				part.Size = Vector3.new(tileSize, 1, tileSize)
				part.Position = Vector3.new((col - 1) * tileSize, 0, (rowIndex - 1) * tileSize)
				part.Color = tileDef.fallbackColor
				part.Material = Enum.Material.SmoothPlastic
				part.Parent = folder

				local texture = Instance.new("Texture")
				texture.Face = Enum.NormalId.Top
				texture.Texture = AssetIds.tile(tileDef.textureName)
				texture.StudsPerTileU = tileSize
				texture.StudsPerTileV = tileSize
				texture.Parent = part
			end
		end
	end
end

local function placeFarmPlots(folder: Folder)
	for i, spot in MapConfig.FarmPlotSpots do
		local part = Instance.new("Part")
		part.Name = `FarmPlot_{i}`
		part.Anchored = true
		part.Size = Vector3.new(MapConfig.TileSize - 1, 0.2, MapConfig.TileSize - 1)
		part.Position = worldPositionFor(spot) + Vector3.new(0, 0.1, 0)
		part.Color = Color3.fromRGB(92, 64, 40)
		part.Parent = folder
		tagPart(part, "FarmPlot", { PlotId = `Plot{i}` })
	end
end

local function placeFishingSpot(folder: Folder)
	local spot = MapConfig.FishingSpot
	local part = Instance.new("Part")
	part.Name = "FishingSpot"
	part.Anchored = true
	part.Size = Vector3.new(3, 1, 3)
	part.Position = worldPositionFor(spot) + Vector3.new(0, 0.5, 0)
	part.Color = Color3.fromRGB(255, 255, 255)
	part.Transparency = 0.6
	part.Parent = folder
	tagPart(part, "FishingSpot", { ZoneId = spot.zoneId })
end

local function placeCookingStations(folder: Folder)
	for i, spot in MapConfig.CookingStationSpots do
		local part = Instance.new("Part")
		part.Name = `CookingStation_{i}`
		part.Anchored = true
		part.Size = Vector3.new(4, 3, 2)
		part.Position = worldPositionFor(spot) + Vector3.new(0, 1.5, 0)
		part.Color = Color3.fromRGB(120, 120, 130)
		part.Parent = folder
		tagPart(part, "CookingStation", { RecipeId = spot.recipeId })
	end
end

local function placeNpcs(folder: Folder)
	for _, spot in MapConfig.NpcSpots do
		local part = Instance.new("Part")
		part.Name = spot.npcId
		part.Anchored = true
		part.CanCollide = true
		part.Size = Vector3.new(2, 5, 1)
		part.Position = worldPositionFor(spot) + Vector3.new(0, 2.5, 0)
		part.Color = Color3.fromRGB(200, 150, 100)
		part.Parent = folder

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(80, 24)
		billboard.StudsOffset = Vector3.new(0, 3, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = part

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.4
		label.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.TextScaled = true
		label.Text = spot.npcId
		label.Parent = billboard

		tagPart(part, "NPC", { NpcId = spot.npcId })
	end
end

local function placeSpawn(folder: Folder)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GeneratedSpawn"
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = worldPositionFor(MapConfig.SpawnPoint) + Vector3.new(0, 0.5, 0)
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Parent = folder
end

function MapBuilder.init()
	local existing = Workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = Workspace

	buildGround(folder)
	placeFarmPlots(folder)
	placeFishingSpot(folder)
	placeCookingStations(folder)
	placeNpcs(folder)
	placeSpawn(folder)
end

return MapBuilder
