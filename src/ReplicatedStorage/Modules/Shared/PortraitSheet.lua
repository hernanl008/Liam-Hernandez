--!strict
-- Cell map for assets/sprites/portrait_sheet.png (drawn by
-- tools/make_portrait_sheet.py — keep the CAST order there and the CELLS
-- table here in sync). One sheet for the whole speaking cast, because
-- every separate PNG is a separate manual upload; cropping happens at
-- render time via ImageLabel.ImageRectOffset, same as the fish roster.

local PortraitSheet = {}

PortraitSheet.CELL_SIZE = 32

local COLUMNS = 3

-- Row-major cell index (0-based).
local CELLS: { [string]: number } = {
	kaya = 0,
	eldersouta = 1,
	ren = 2,
	hinano = 3,
	kaleb = 4,
	generic = 5,
}

-- DialogueData stores `speaker` as the name shown on screen ("Elder
-- Souta", "Ren Amakusa", "Chef Hinano") while the rest of the codebase
-- keys relationships by a bare id ("ElderSouta", "Ren", "Hinano"). Both
-- forms resolve here so callers never have to care which they hold:
-- strip everything that isn't a letter, lower-case it, then match on the
-- distinctive part of the name.
local ALIASES: { { pattern: string, cell: string } } = {
	{ pattern = "kaya", cell = "kaya" },
	{ pattern = "souta", cell = "eldersouta" },
	{ pattern = "ren", cell = "ren" },
	{ pattern = "hinano", cell = "hinano" },
	{ pattern = "kaleb", cell = "kaleb" },
}

local function normalize(name: string): string
	return string.lower(string.gsub(name, "[^%a]", ""))
end

-- True when `name` maps to a real portrait rather than the generic
-- fallback — lets callers skip the portrait frame entirely for narration
-- nodes, which have an empty speaker.
function PortraitSheet.has(name: string): boolean
	if name == "" then
		return false
	end
	local key = normalize(name)
	for _, alias in ALIASES do
		if string.find(key, alias.pattern, 1, true) then
			return true
		end
	end
	return false
end

-- Pixel offset of `name`'s cell, falling back to the generic bust for
-- anyone nobody has drawn yet — a new NPC shows a neutral face rather
-- than the wrong character's or a blank box.
function PortraitSheet.rectOffsetFor(name: string): Vector2
	local key = normalize(name)
	local cellName = "generic"
	for _, alias in ALIASES do
		if string.find(key, alias.pattern, 1, true) then
			cellName = alias.cell
			break
		end
	end
	local index = CELLS[cellName] or CELLS.generic
	local col = index % COLUMNS
	local row = math.floor(index / COLUMNS)
	return Vector2.new(col * PortraitSheet.CELL_SIZE, row * PortraitSheet.CELL_SIZE)
end

return PortraitSheet
