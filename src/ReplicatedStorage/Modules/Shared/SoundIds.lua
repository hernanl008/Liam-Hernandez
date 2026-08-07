--!strict
-- Stable API for referencing sound effects, same shape/spirit as
-- AssetIds.lua's image lookup — but hand-maintained, not tarmac-
-- generated. Tarmac (tarmac.toml) only uploads PNGs; Roblox's asset
-- pipeline has no equivalent unauthenticated upload path for audio, and
-- getting a sound onto Roblox at all requires a human with a Roblox
-- account (via Studio's Toolbox > search the free audio library > right-
-- click a result > "Copy Asset ID", or uploading your own recording
-- through create.roblox.com and waiting for moderation).
--
-- To wire up a real sound: paste its "rbxassetid://<number>" string in
-- as the value below. Leave it as "" (or delete the line) to leave that
-- cue silent — SoundPlayer.lua treats an empty id as "not configured
-- yet" and no-ops instead of erroring, so half-filled-in audio never
-- breaks anything, the same way a missing tile texture just shows a
-- fallback color instead of crashing.

local SoundIds = {}

-- Fishing (GDD.md §3) — the reel-in juice pass this session added visual
-- feedback for; these are the audio equivalents, same beats:
SoundIds.FishingCast = "" -- CastMeterUI locks in (line goes out)
SoundIds.FishingBite = "" -- FishBite fires ("press E!" moment)
SoundIds.ReelHit = "" -- RhythmUI lands a note during the reel-in
SoundIds.ReelMiss = "" -- RhythmUI whiffs/misses a note during the reel-in
SoundIds.ReelMeterEmpty = "" -- the catch meter empties — fish escapes mid-reel
SoundIds.CatchSuccess = "" -- a fish is landed (plays with the catch banner/toast)
SoundIds.CatchEscape = "" -- "the line goes slack... it slipped away"
SoundIds.PullSnag = "" -- a junk/treasure Pull snags on the line

-- Skill tree (SkillTreeUI.lua)
SoundIds.SkillOpen = "" -- the tree screen opens
SoundIds.SkillHover = "" -- cursor enters a node
SoundIds.SkillUnlock = "" -- a perk is bought

return SoundIds
