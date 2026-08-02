--!strict
-- Data for the small Orange Ville starter map (GDD.md §13). A text grid
-- of tile-type characters, plus where MapBuilder.lua should auto-place
-- the interactive objects that docs/VERTICAL_SLICE_SETUP.md previously
-- asked Liam to hand-place in Studio — syncing this now gets the whole
-- vertical slice playable with zero manual setup.
--
-- This is a small proof-of-concept plot, not the real Orange Ville map
-- from LORE_BIBLE.md — extend the Grid (and the spot lists below) as the
-- real village layout gets designed in Phase 3.

export type TileTypeDef = {
	textureName: string, -- looked up via AssetIds.tile(name)
	fallbackColor: Color3, -- shown if the texture hasn't been uploaded yet (AssetIds.lua's rbxassetid://0 fallback)
}

export type GridSpot = { row: number, col: number }

local MapConfig = {}

MapConfig.TileSize = 8 -- studs per tile

MapConfig.TileTypes: { [string]: TileTypeDef } = {
	G = { textureName = "grass", fallbackColor = Color3.fromRGB(58, 168, 74) },
	P = { textureName = "path", fallbackColor = Color3.fromRGB(222, 198, 156) },
	W = { textureName = "water", fallbackColor = Color3.fromRGB(66, 148, 235) },
	-- Decorative grass-with-blossoms variant (GDD.md §14) — same fallback
	-- color as plain grass, purely a corner accent, no gameplay difference.
	S = { textureName = "sakura_grass", fallbackColor = Color3.fromRGB(58, 168, 74) },
}

-- Row 1 = north edge. Each row must be the same length (14 columns).
MapConfig.Grid: { string } = {
	"SSGGGGGGGGGGSS",
	"GGGGGPPPPGGGGG",
	"GGGGGPPPPGGGGG",
	"GGGGGPPPPGGGGG",
	"GGGGGPPPPGGGGG",
	"GGWWWPPPPGGGGG",
	"GGWWWWGGGGGGGG",
	"GGWWWWGGGGGGGG",
	"GGGGGGGGGGGGGG",
	"SSGGGGGGGGGGGG",
}

MapConfig.SpawnPoint: GridSpot = { row = 2, col = 7 }

MapConfig.FarmPlotSpots: { GridSpot } = {
	{ row = 4, col = 10 },
	{ row = 4, col = 11 },
	{ row = 4, col = 12 },
}

MapConfig.FishingSpot: GridSpot & { zoneId: string } = { row = 6, col = 6, zoneId = "Shallows" }

MapConfig.CookingStationSpots: { GridSpot & { recipeId: string } } = {
	{ row = 3, col = 11, recipeId = "GrilledMinnowSkewer" },
	{ row = 3, col = 12, recipeId = "SunpetalJamTart" },
}

MapConfig.NpcSpots: { GridSpot & { npcId: string } } = {
	{ row = 3, col = 13, npcId = "Kaya" },
	{ row = 4, col = 13, npcId = "ElderSouta" },
	{ row = 7, col = 2, npcId = "Ren" },
	{ row = 5, col = 13, npcId = "Hinano" },
	{ row = 9, col = 11, npcId = "Kaleb" },
}

return MapConfig
