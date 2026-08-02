# Act 1 Vertical Slice — Studio Setup

**This got a lot simpler this session.** Previously this doc walked
through hand-placing farm plots, a fishing spot, a cooking station, and
Kaya in Studio. `MapBuilder.lua` now does all of that automatically at
server start — it builds a small tile-based starter map and auto-places
every interactive object from `MapConfig.lua` (farm plots, fishing spot,
two cooking stations, all five Act 1 NPCs, and a spawn point). Syncing
the repo and pressing Play in Studio should now be enough on its own —
no manual placement required.

What you still can't get from a synced repo (see `README.md`): terrain
sculpting beyond the flat tile grid, and — the big one — **actual
uploaded art**. Everything below covers that gap and how to verify the
auto-generated map actually works.

## 1. Sync and press Play

1. `rojo serve` from the repo root, connect via the Rojo Studio plugin
   (see `README.md`), same as always.
2. Press Play in Studio. You should land on the generated spawn point in
   a small tiled clearing — grass, a path, a pond, three farm plots, two
   cooking stations, and five placeholder-block NPCs with floating name
   labels (Kaya, Elder Souta, Ren, Hinano, Kaleb).
3. Camera should be locked to a fixed top-down angle, following you but
   never rotating (`CameraController.lua`, `GDD.md` §6's "locked
   top-down 2D" decision). If it's still Roblox's default orbiting
   camera, the sync didn't pick up `CameraController.lua` — check the
   Studio Output window for require errors.
4. Ground tiles will look flat-colored (green/tan/blue) rather than
   textured — that's expected until you run the asset pipeline below.

## 2. Assets pipeline (getting real pixel art in)

Rojo can sync *code* but has no way to upload *images* to Roblox — that
needs an authenticated Roblox account, which only you have. The fix is
[Tarmac](https://github.com/rojo-rbx/tarmac) (`tarmac.toml`, already
configured):

1. `aftman install` (picks up the `tarmac` entry added to `aftman.toml`
   this session, alongside rojo/selene/stylua).
2. From the repo root: `tarmac sync --target roblox`. It'll use your
   local Roblox login (or pass `--auth` with a `.ROBLOSECURITY` cookie).
3. This uploads everything under `assets/` (right now: `grass.png`,
   `tilled_soil.png`, `water.png`, `path.png` in `assets/tiles/`, and
   `player_placeholder.png`/`kaya_placeholder.png` in `assets/sprites/`
   — small hand-generated pixel-art placeholders, not final art) and
   rewrites `src/ReplicatedStorage/Modules/Shared/AssetIds.generated.lua`
   with the real `rbxassetid://` for each. Commit that file afterward.
4. Re-sync via Rojo (or it'll pick up automatically if `rojo serve` is
   still running) and the ground tiles should switch from flat colors to
   the actual pixel textures.
5. To use your own art instead: replace the files in `assets/` (same
   names, or update `MapConfig.lua`'s `textureName`/`AssetIds.lua` calls
   to match new ones) and re-run `tarmac sync`. Nothing else changes.

## 3. Loading screen

`src/ReplicatedFirst/LoadingScreen.client.lua` shows a full-screen splash
("Anime Farm Life / Waking up...") from the moment the client connects,
waits for the game and character to finish loading, then fades out. This
does *not* play the opening cutscene from `OPENING_CUTSCENE.md` — that's
a separate, not-yet-built cinematic sequence; the loading screen just
guarantees you never see a blank/frozen screen while joining.

## 4. HUD

A persistent top bar (`HudUI.lua`) always shows gold, the current day/
time, and your Farming/Fishing/Cooking levels. No toggle — it's always
visible, unlike the Compendium (B) and Skills (P) screens.

## 5. Playtesting checklist

1. Talk to Kaya → accept the farm → she grants `GrantStarterFarm` (you
   start with 3 Moonrice Stalk + 2 Sunpetal Berries seeds already).
2. Walk to a farm plot → Till Soil → Plant Seed → Water. Growth only
   progresses while watered — leaving it unwatered pauses growth, it
   doesn't kill the crop.
3. Walk to the fishing spot (marked by a translucent white patch near the
   pond) → Cast → wait for "Something's biting!" → press E → play the
   reel-in rhythm prompt (D/F/J/K keys). Chain several Perfect hits in a
   row and you should see a "Nx COMBO!" counter pulse.
4. With a caught fish in inventory, walk to a cooking station → Cook →
   play the rhythm chart → get a dish (Bronze/Silver/Gold/Basic tier). A
   Gold-tier result or a 5+ combo should trigger a full-screen banner +
   camera shake (`SpectacleUI.lua`).
5. Press **B** to open the Compendium — everything you've caught/cooked/
   harvested/pulled shows its name and flavor text; everything else shows
   "???". Press **P** to open Skills — you should see 1 skill point per
   pillar the first time you level that skill, spendable on that tree's
   first perk (the second perk needs the first unlocked, plus a higher
   level).
6. Fish enough Shallows catches to hit Fishing level 5 and unlock Mid
   Reef — no spot for it on the auto-generated map yet, add one to
   `MapConfig.FarmPlotSpots`-style lists if you want to test it, or
   extend `MapConfig.lua`'s `Grid`/spot lists directly. At night, try the
   Shallows for the Moonlit Serpent (`DayCycleService.lua`'s comment on
   `dayLengthSeconds` explains how to speed up day/night for testing).
7. Talk to any of the five NPCs — all their dialogue trees are wired
   (`docs/DIALOGUE_ACT1.md`), though only Kaya's grants anything right
   now (`DialogueService.lua`'s `FLAG_ONLY_ACTIONS`).

## Known gaps (intentional, for this pass)

- Ground tiles/NPCs are flat-colored placeholders until you run the
  Tarmac sync above (§2) — and even then, the "art" is small
  hand-generated pixel placeholders, not real character/tile art.
- No visuals for crop growth stages (`FarmingConfig.lua` names model
  variants like `MoonriceSeedling` but nothing swaps them in yet) — plot
  state is inspectable via the Part's attributes in Studio while testing.
- No cast-power meter — casting is instant on trigger (see
  `FishingController.lua` comment for why).
- The opening cutscene (`OPENING_CUTSCENE.md`) is written but not wired
  into a playable sequence — the loading screen fades straight into
  normal gameplay at the spawn point instead.
- No persistence (DataStores) — progress resets when the server restarts/
  playtest ends, including Compendium discoveries and skill points.
  Deliberately deferred to Phase 3/4.
- Only one map region exists (`MapConfig.lua`'s small starter grid) —
  Kotobuki Port and the rest of Orange Ville aren't built.

Report anything that errors in the Studio Output window back here — none
of this has been run in an actual Roblox environment yet, only
written/reasoned through, so bugs are expected on first sync.
