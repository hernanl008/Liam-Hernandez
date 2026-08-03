--!strict
-- Data for the Orange Ville map (GDD.md §13). A text grid of tile-type
-- characters, plus where MapBuilder.lua should auto-place the
-- interactive objects and decorative props that make up the world.
-- Data-driven so the map is a text grid + spot lists to edit, not
-- hand-placed parts.
--
-- Expanded from the original 10x14 proof-of-concept plot into a full
-- starter map with four named districts around the village square (see
-- LORE_BIBLE.md §2 for the wider Veyl Valley/Orange Ville geography):
--   - Village square (center): NPCs, cooking stations, the two starter
--     houses, and a few farm plots — the original vertical-slice content.
--   - Maple Hollow (north): the forest fringe bordering the village,
--     dotted with maple trees — the valley-forest edge LORE_BIBLE.md §2
--     already gestures at (where Blightspawn creep in from).
--   - Sunpetal Fields (east): the expanded farmland, named for the
--     Sunpetal Berries crop it grows (FarmingConfig.lua).
--   - The pasture (west): the village's cows and chickens, fenced in.
--   - The cove (south): the lake/fishing water, with a Shallows spot at
--     the shore and a MidReef spot further out for once players unlock it.
--
-- Note: `Table.Field: Type = value` is NOT valid Luau outside `local`
-- declarations (the parser reads the colon as the start of a method
-- definition) — every field below is a typed local assigned to
-- MapConfig afterward, not typed inline.

export type TileTypeDef = {
	textureName: string, -- looked up via AssetIds.tile(name)
	fallbackColor: Color3, -- shown if the texture hasn't been uploaded yet (AssetIds.lua's rbxassetid://0 fallback)
}

export type GridSpot = { row: number, col: number }

-- A flat standee: a camera-facing decal (MapBuilder places it on the
-- Back face, since CameraController's fixed viewing angle always looks
-- at that face — see MapBuilder.lua) rather than a modeled 3D object,
-- consistent with GDD.md §6's "2D read, thin 3D parts" presentation.
-- Size is hand-tuned per prop (aspect ratio kept from the source PNG,
-- height picked to read sensibly next to an ~5-stud-tall player) rather
-- than derived from the ground tiles' pixel scale — a literal 1:1
-- pixel-to-stud match with the tile grid made buildings ~11x player
-- height, which is exaggerated even for a stylized game. Eyeballed, not
-- tested in Studio — nudge widthStuds/heightStuds per entry to taste.
export type PropSpot = GridSpot & {
	sprite: string, -- looked up via AssetIds.sprite(name)
	widthStuds: number,
	heightStuds: number,
}

local MapConfig = {}

MapConfig.TileSize = 8 -- studs per tile

local TileTypes: { [string]: TileTypeDef } = {
	G = { textureName = "grass", fallbackColor = Color3.fromRGB(58, 168, 74) },
	P = { textureName = "path", fallbackColor = Color3.fromRGB(222, 198, 156) },
	W = { textureName = "water", fallbackColor = Color3.fromRGB(66, 148, 235) },
	-- Decorative grass-with-blossoms variant (GDD.md §14) — same fallback
	-- color as plain grass, purely a corner accent, no gameplay difference.
	S = { textureName = "sakura_grass", fallbackColor = Color3.fromRGB(58, 168, 74) },
}
MapConfig.TileTypes = TileTypes

-- 26 rows x 34 cols (~6x the original 10x14 plot). Row 1 = north edge.
-- Each row must be the same length. Layout: Maple Hollow (rows 1-8) at
-- the top, the village square (rows 9-14) in the middle, Sunpetal Fields
-- spilling east and the pasture spilling west of the square, and the
-- cove (rows 18-25) at the south. The path is a cross connecting all
-- four districts through the square, with a spur down to the cove dock.
local Grid: { string } = {
	"SSGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGSS",
	"SGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGS",
	"GGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGGGGGGPPPPPPPPGGGGGGGGGGGG",
	"GGPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPGG",
	"GGPPPPPPPPPPPPPPPPPPPPPPPPPPPPPPGG",
	"GGGGGGGGGGGGGGPPPPPPPPGGGGGGGGGGGG",
	"GGGGGGGGGPPGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGPPGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGPPGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGPPGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGGGGGPPGGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGGWWWWPPWGGGGGPPGGGGGGGGGGGGGGG",
	"GGGGWWWWWWWWGGGGGPPGGGGGGGGGGGGGGG",
	"GGGWWWWWWWWWWGGGGPPGGGGGGGGGGGGGGG",
	"GGGWWWWWWWWWWGGGGPPGGGGGGGGGGGGGGG",
	"GGGWWWWWWWWWWGGGGPPGGGGGGGGGGGGGGG",
	"GGGWWWWWWWWWWGGGGPPGGGGGGGGGGGGGGG",
	"SGGGGWWWWWWGGGGGGGGGGGGGGGGGGGGGGS",
	"SSGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGSS",
}
MapConfig.Grid = Grid

local SpawnPoint: GridSpot = { row = 12, col = 19 }
MapConfig.SpawnPoint = SpawnPoint

-- Original 3 plots by the village square, plus 8 more out in Sunpetal
-- Fields (GDD.md §5 — no stamina system, so more plots just means more
-- to water/harvest each day, not a new mechanic).
local FarmPlotSpots: { GridSpot } = {
	{ row = 14, col = 15 },
	{ row = 14, col = 16 },
	{ row = 14, col = 22 },
	{ row = 9, col = 26 },
	{ row = 9, col = 28 },
	{ row = 9, col = 30 },
	{ row = 9, col = 32 },
	{ row = 13, col = 26 },
	{ row = 13, col = 28 },
	{ row = 13, col = 30 },
	{ row = 13, col = 32 },
}
MapConfig.FarmPlotSpots = FarmPlotSpots

-- Shallows at the cove's shore (always open); MidReef further out in
-- deeper water for once Fishing level 5 unlocks it (FishingConfig.lua).
local FishingSpots: { GridSpot & { zoneId: string } } = {
	{ row = 21, col = 7, zoneId = "Shallows" },
	{ row = 23, col = 10, zoneId = "MidReef" },
}
MapConfig.FishingSpots = FishingSpots

local CookingStationSpots: { GridSpot & { recipeId: string } } = {
	{ row = 8, col = 16, recipeId = "GrilledMinnowSkewer" },
	{ row = 8, col = 21, recipeId = "SunpetalJamTart" },
}
MapConfig.CookingStationSpots = CookingStationSpots

local NpcSpots: { GridSpot & { npcId: string } } = {
	{ row = 9, col = 16, npcId = "Kaya" },
	{ row = 9, col = 21, npcId = "ElderSouta" },
	{ row = 16, col = 8, npcId = "Ren" },
	{ row = 9, col = 17, npcId = "Hinano" },
	{ row = 23, col = 14, npcId = "Kaleb" },
}
MapConfig.NpcSpots = NpcSpots

-- Purely decorative standees (trees, houses, fences, animals, stones) —
-- see the PropSpot doc comment above for how these render. None of these
-- are tagged/interactive; they're world dressing around the systems
-- above, sliced from the "Farm RPG FREE 16x16" asset pack.
local Props: { PropSpot } = {
	-- The two starter houses, flanking the village square.
	{ row = 7, col = 15, sprite = "house_cottage", widthStuds = 12.6, heightStuds = 22 },
	{ row = 7, col = 22, sprite = "house_grand", widthStuds = 15.7, heightStuds = 22 },

	-- Maple Hollow (north forest fringe).
	{ row = 3, col = 6, sprite = "tree_large", widthStuds = 9.3, heightStuds = 14 },
	{ row = 5, col = 9, sprite = "tree_small", widthStuds = 7.3, heightStuds = 11 },
	{ row = 2, col = 13, sprite = "tree_large", widthStuds = 9.3, heightStuds = 14 },
	{ row = 6, col = 13, sprite = "tree_stump", widthStuds = 4, heightStuds = 4 },
	{ row = 3, col = 23, sprite = "tree_small", widthStuds = 7.3, heightStuds = 11 },
	{ row = 5, col = 27, sprite = "tree_large", widthStuds = 9.3, heightStuds = 14 },
	{ row = 2, col = 30, sprite = "tree_small", widthStuds = 7.3, heightStuds = 11 },
	{ row = 7, col = 25, sprite = "tree_stump", widthStuds = 4, heightStuds = 4 },
	{ row = 4, col = 21, sprite = "stone_round", widthStuds = 4, heightStuds = 4 },
	{ row = 6, col = 24, sprite = "stone_cluster", widthStuds = 8, heightStuds = 4 },
	-- A small shrine marking the forest edge — original art (not from the
	-- pack), tying Maple Hollow to LORE_BIBLE.md §2's "guardian magic
	-- fading" framing without adding any new mechanic.
	{ row = 4, col = 16, sprite = "shrine_torii", widthStuds = 5.3, heightStuds = 8 },

	-- Sunpetal Fields fence border (east farmland).
	{ row = 8, col = 25, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 8, col = 33, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 14, col = 25, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 14, col = 33, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 8, col = 27, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },
	{ row = 8, col = 29, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },
	{ row = 14, col = 27, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },
	{ row = 14, col = 29, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },

	-- The pasture (west), fenced with the village's cow and chickens.
	{ row = 14, col = 3, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 14, col = 8, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 18, col = 3, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 18, col = 8, sprite = "fence_post", widthStuds = 2, heightStuds = 6 },
	{ row = 14, col = 5, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },
	{ row = 14, col = 7, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },
	{ row = 18, col = 5, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },
	{ row = 18, col = 7, sprite = "fence_rail", widthStuds = 12, heightStuds = 4 },
	{ row = 16, col = 5, sprite = "cow_brown", widthStuds = 7, heightStuds = 7 },
	{ row = 15, col = 4, sprite = "chicken_yellow", widthStuds = 3, heightStuds = 3 },
	{ row = 17, col = 6, sprite = "chicken_red", widthStuds = 3, heightStuds = 3 },

	-- The cove shoreline (south).
	{ row = 20, col = 14, sprite = "stone_round", widthStuds = 4, heightStuds = 4 },
	{ row = 22, col = 17, sprite = "stone_cluster", widthStuds = 8, heightStuds = 4 },
	-- A lit stone lantern at the shore — original art, a quiet nighttime
	-- beat for Ren's Moonlit Serpent legend (FishingConfig.lua's nightOnly
	-- Legendary fish, LORE_BIBLE.md §5) without any new mechanic attached.
	{ row = 20, col = 16, sprite = "lantern", widthStuds = 2.5, heightStuds = 5 },
	-- An abandoned trader's chest by the water — flavor near Kaleb's spot
	-- (LORE_BIBLE.md §5, his black-market junk/treasure trade), decorative
	-- only for now, not tagged interactive.
	{ row = 24, col = 16, sprite = "chest_closed", widthStuds = 6, heightStuds = 3 },
}
MapConfig.Props = Props

return MapConfig
