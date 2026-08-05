--!strict
-- Cell map for assets/sprites/fish_sheet.png (drawn by
-- tools/make_fish_sheet.py — keep the SPECIES order there and the CELLS
-- table here in sync). One sheet for the whole fish/loot roster because
-- every separate PNG is a separate manual upload; cropping happens at
-- render time via ImageLabel.ImageRectOffset (see FishingRig.lua — a
-- SurfaceGui ImageLabel, since Decals/Textures can't crop).

local FishSpriteSheet = {}

FishSpriteSheet.CELL_WIDTH = 32
FishSpriteSheet.CELL_HEIGHT = 16

local COLUMNS = 4

-- Row-major cell index (0-based) per fish/pull id from FishingConfig.
local CELLS: { [string]: number } = {
	SilverMinnow = 0,
	MoonfinKoi = 1,
	MoonlitSerpent = 2,
	TrenchEel = 3,
	BlightscaleCarp = 4,
	AbyssalAnglerfish = 5,
	GuardiansEcho = 6,
	Generic = 7,
	Driftwood = 8,
	OldBoot = 9,
	TarnishedLocket = 10,
	SunkenCoinPouch = 11,
}

-- Pixel offset of the cell for `id`, falling back to the Generic fish
-- for ids the sheet doesn't know (a new config fish nobody has drawn
-- yet shows as a generic blue fish instead of the wrong species or
-- nothing at all).
function FishSpriteSheet.rectOffsetFor(id: string): Vector2
	local index = CELLS[id] or CELLS.Generic
	local col = index % COLUMNS
	local row = math.floor(index / COLUMNS)
	return Vector2.new(col * FishSpriteSheet.CELL_WIDTH, row * FishSpriteSheet.CELL_HEIGHT)
end

return FishSpriteSheet
