--!strict
-- One place to ask "is the player allowed to open things right now?".
--
-- The opening cutscene runs a scripted sequence with the camera and the
-- character taken over, and during it every menu keybind still worked:
-- P opened the skill tree over the cutscene, I opened the inventory,
-- ProximityPrompts could be triggered on NPCs the scene had not
-- introduced yet. Each of those is its own controller with its own
-- InputBegan listener, so the alternative was five copies of the same
-- "unless a cutscene is playing" check, drifting apart the moment a
-- sixth screen is added.
--
-- Reference-counted rather than a boolean, so two overlapping reasons to
-- lock (a cutscene that starts a dialogue, say) do not have the inner
-- one unlock everything when it ends.

local UiLock = {}

local holds: { [string]: number } = {}
local total = 0

-- Takes a lock under `reason`. Reasons are free-form strings and exist
-- purely so a leaked lock can be identified in the log.
function UiLock.acquire(reason: string)
	holds[reason] = (holds[reason] or 0) + 1
	total += 1
end

function UiLock.release(reason: string)
	local held = holds[reason]
	if not held or held <= 0 then
		warn(`[UiLock] released "{reason}" without holding it — check for a mismatched acquire/release pair.`)
		return
	end
	if held == 1 then
		holds[reason] = nil
	else
		holds[reason] = held - 1
	end
	total -= 1
end

-- True when the player may open menus / trigger prompts.
function UiLock.isFree(): boolean
	return total == 0
end

-- Convenience for the common `if UiLock.isLocked() then return end` guard
-- at the top of an input handler.
function UiLock.isLocked(): boolean
	return total > 0
end

-- Names every current holder, for diagnosing a UI that has gone
-- unresponsive because something forgot to release.
function UiLock.describe(): string
	local parts = {}
	for reason, count in holds do
		table.insert(parts, `{reason} x{count}`)
	end
	if #parts == 0 then
		return "free"
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end

return UiLock
