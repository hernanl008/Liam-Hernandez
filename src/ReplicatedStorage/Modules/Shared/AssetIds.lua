--!strict
-- Stable API for referencing uploaded pixel-art assets (GDD.md §13).
-- AssetIds.generated.lua is overwritten by `tarmac sync --target roblox`
-- (see tarmac.toml) and is empty until that's been run at least once —
-- looking up an asset that hasn't been uploaded yet logs a warning and
-- falls back to rbxassetid://0 (Roblox's blank-image placeholder)
-- instead of erroring, so missing art degrades gracefully.
--
-- If your Tarmac version's generated file has a different shape than a
-- flat { [path] = "rbxassetid://..." } table, open
-- AssetIds.generated.lua after your first sync and adjust GENERATED
-- below to match — this is the only place that needs to change.

local GENERATED: { [string]: string } = require(script.Parent:WaitForChild("AssetIds.generated")) :: any

local AssetIds = {}

local warnedOnce: { [string]: boolean } = {}

local function lookup(path: string): string
	local id = GENERATED[path]
	if not id then
		if not warnedOnce[path] then
			warnedOnce[path] = true
			warn(`No uploaded asset for "{path}" yet — run \`tarmac sync --target roblox\` after adding it. Using a blank placeholder for now.`)
		end
		return "rbxassetid://0"
	end
	return id
end

function AssetIds.tile(name: string): string
	return lookup(`tiles/{name}.png`)
end

function AssetIds.sprite(name: string): string
	return lookup(`sprites/{name}.png`)
end

return AssetIds
