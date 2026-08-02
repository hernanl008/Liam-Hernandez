# Act 1 Vertical Slice — Studio Setup

The code synced by Rojo (`src/`) implements the *logic* for farming,
fishing, cooking, day cycle, and dialogue. It doesn't and can't place any
3D objects — parts, terrain, NPC models — since that's Studio's job, not
something a filesystem-synced repo can do (see `README.md`). This doc is
the checklist of what to hand-place in Studio so the vertical slice is
actually playable end to end.

Everything below uses **CollectionService tags** + **attributes** so the
scripts can find what you place without hardcoded paths. In Studio: select
a part → Properties → find "Tags" (or use the Tag Editor plugin/window) →
add the tag → then add attributes via the "+" in the Attributes section
of Properties.

## 1. A farm plot

- Place a **Part** roughly 4x4 studs, flat on the ground.
- Tag: `FarmPlot`
- Attribute: `PlotId` (String) — give it a unique value, e.g. `"Plot1"`.
- That's it — `FarmingController.lua` adds the ProximityPrompt itself and
  updates its text (Till Soil → Plant Seed → Water → Growing... → Harvest)
  automatically as the plot's state changes.
- Repeat for as many plots as you want; each just needs a unique `PlotId`.

## 2. A fishing spot

- Place a **Part** at the water's edge (doesn't need to touch water for
  this vertical slice — the "cast" is instant, no physical bobber yet).
- Tag: `FishingSpot`
- Attribute: `ZoneId` (String) = `"Shallows"` (the only zone with fish
  configured right now — see `FishingConfig.lua`).

## 3. A cooking station

- Place a **Part** (stand-in for a stove/counter).
- Tag: `CookingStation`
- Attribute: `RecipeId` (String) = `"GrilledMinnowSkewer"` (the only
  recipe configured right now — see `RhythmGameConfig.lua`).
- Note this recipe needs a `SilverMinnow` (caught from the Shallows) in
  inventory to start cooking — go fish first.

## 4. Kaya (first NPC)

- Place a **Part or Model** to represent Kaya (a placeholder block is
  fine for now — swap the model later, nothing else needs to change).
- Tag: `NPC`
- Attribute: `NpcId` (String) = `"Kaya"`
- `DialogueController.lua` adds a "Talk" ProximityPrompt automatically if
  you used a Part. If you used a Model, add a ProximityPrompt yourself to
  whichever part should be interactable (e.g. the torso) — the script
  can't guess which part of a Model should hold it.
- Repeat this pattern for `ElderSouta`, `Ren`, `Hinano`, `Kaleb` once
  you're ready to place them — their dialogue trees already exist in
  `DialogueData.lua` / `docs/DIALOGUE_ACT1.md`.

## 5. Playtesting checklist

With the above placed, `rojo serve` running, and the Rojo Studio plugin
connected (see `README.md`):

1. Talk to Kaya → accept the farm → she grants `GrantStarterFarm`
   (you start with 3 Moonrice Stalk seeds already, per
   `PlayerDataService.lua`).
2. Walk to a farm plot → Till Soil → Plant Seed → Water. Growth only
   progresses while watered — leaving it unwatered pauses growth, it
   doesn't kill the crop.
3. Walk to the fishing spot → Cast → wait for "Something's biting!" →
   press E → play the reel-in rhythm prompt (D/F/J/K keys).
4. With a caught fish in inventory, walk to the cooking station → Cook →
   play the rhythm chart → get a dish (Bronze/Silver/Gold/Basic tier).
5. Talk to Kaya again anytime — dialogue re-runs from her root node each
   time in this vertical slice (no "already met" branching yet, that's
   Phase 3 per `docs/ROADMAP.md`).

## Known gaps (intentional, for this pass)

- No visuals for crop growth stages (`FarmingConfig.lua` names model
  variants like `MoonriceSeedling` but nothing swaps them in yet) — plot
  state is inspectable via the Part's attributes in Studio while testing.
- No cast-power meter — casting is instant on trigger (see
  `FishingController.lua` comment for why).
- No inventory/HUD screen yet — `InventoryCache.lua` mirrors the data
  client-side already, just needs a UI built on top of it.
- No persistence (DataStores) — progress resets when the server restarts/
  playtest ends. Deliberately deferred to Phase 3/4.

Report anything that errors in the Studio Output window back here — none
of this has been run in an actual Roblox environment yet, only
written/reasoned through, so bugs are expected on first sync.
