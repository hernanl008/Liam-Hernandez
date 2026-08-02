# Roadmap

Sessions on this project are intermittent (whenever usage limits reset),
so milestones are organized by **phase completion**, not fixed calendar
dates. Rough week numbers assume ~1 month total, adjust as reality dictates.

## Phase 0 — Foundation (this session)
- [x] Rojo project scaffold + linting/formatting config
- [x] GDD skeleton with open design questions flagged
- [x] Lore bible skeleton (empty — needs Liam's creative input)
- [x] Placeholder data configs for Farming/Fishing/Cooking
- [ ] Liam installs Roblox Studio + Rojo locally, confirms sync works

## Phase 1 — Lore & Design Lock (~week 1)
- [x] Combat scope decided: light, non-core (Frontier Watch/Blightspawn)
- [x] Multiplayer/trading model decided: instanced farms + shared Kotobuki
      Port with a player-driven Trade Exchange (see `GDD.md` §7)
- [x] Anime tone locked: isekai reincarnation
- [x] `LORE_BIBLE.md` premise, world, factions, central conflict, and main
      cast written
- [x] `NPC_ROSTER.md` — 52+ NPCs across village/port/Watch/Academy/traveling
- [x] `OPENING_CUTSCENE.md` — death → rebirth beat sheet
- [ ] 🔲 Land expansion model (buy plots vs. story-gated) — still open
- [ ] 🔲 Romance system in/out of scope — still open
- [ ] 🔲 Visual style: toon-shaded 3D vs. actual 2D/2.5D sprites (`GDD.md`
      §6) — currently assumed toon-shaded 3D, confirm before art starts
- [ ] 🔲 Founding myth specifics — what actually happened to the guardian
      spirit 3 generations ago (`LORE_BIBLE.md` §6) — needed before Act 2
      content is built
- [ ] Async vs. live Trade Exchange stalls (`GDD.md` §7) — recommend async
      for the vertical slice, revisit later

## Phase 2 — Core Systems, Vertical Slice (~weeks 2-3)
- [x] Farming: till/plant/water/harvest loop coded (`FarmingService.lua` +
      `FarmingController.lua`) — no stamina system (GDD.md §5)
- [x] Fishing: Shallows zone cast → bite → reel coded (`FishingService.lua`
      + `FishingController.lua`), plus junk/treasure pulls
- [x] Cooking: Grilled Minnow Skewer playable as a rhythm chart end-to-end
      (`CookingService.lua` + `CookingController.lua`, shares
      `RhythmScoring.lua`/`RhythmUI.lua` with fishing's reel-in)
- [x] Day cycle coded (`DayCycleService.lua`) — adjustable length, resets
      daily watering
- [x] Kaya's full dialogue tree coded and wired (`DialogueService.lua` +
      `DialogueController.lua` + `DialogueData.lua`); Elder Souta, Ren,
      Hinano, and Kaleb's trees are written and ready, just need their
      NPCs placed in Studio
- [ ] **Not yet done — needs Liam in Studio**: none of the above has run
      in an actual Roblox session. Place the parts/tags/attributes in
      `docs/VERTICAL_SLICE_SETUP.md`, sync via Rojo, and playtest — report
      back whatever breaks first.
- [ ] Inventory/HUD UI (data's already replicated client-side via
      `InventoryCache.lua`, just needs a screen)
- [x] Combo/spectacle system (`RhythmScoring.lua` combo bonus,
      `SpectacleUI.lua` banners) shared by fishing reel-in and cooking —
      the "make it feel more anime" pass, see `GDD.md` §11
- [x] Moonlit Serpent — Legendary, night-only fish tied to Ren Amakusa's
      arc (`FishingConfig.lua`, `LORE_BIBLE.md` §5), always triggers the
      spectacle banner
- [x] Fishing level + zone unlocking via the Fishing skill tree
      (`PlayerDataService.getSkillLevel`) — Mid Reef reachable at level 5
- [x] Second crop (Sunpetal Berries, regrowable) + second, harder recipe
      (Sunpetal Jam Tart) to give the combo system room to show off
- [x] Compendium ("the book," `CompendiumUI.lua`, press B) — indexes every
      fish/dish/crop/junk pull, "???" until discovered, see `GDD.md` §12
- [x] Skill trees (`SkillTreeConfig.lua` + `SkillService.lua` +
      `SkillTreeUI.lua`, press P) — 2-perk chain per pillar with real
      gameplay hooks (Green Thumb, Quick Hands, Efficient Cook, etc.)

## Phase 3 — Content Expansion (~week 4)
- [ ] Remaining depth zones (Deep Trench, Abyssal Rift) + fish roster
- [ ] Recipe roster tied to lore (regional dishes, festival specials)
- [ ] Remaining crops + seasons
- [ ] Story beats implemented per the lore bible's arc
- [ ] UI/UX pass (HUD, inventory, shop, dialogue box)
- [ ] Cast-power meter that actually affects bite odds, and/or broader
      weather effects on fish spawns (`GDD.md` §3 — currently only the
      Moonlit Serpent has any time-of-day gating)
- [ ] Crop growth-stage visuals (model swaps per `FarmingConfig.lua` stage)
- [ ] Persistence (DataStores) — everything is in-memory only right now,
      including all Compendium/skill-tree progress from this session
- [ ] Relationship stat persistence for dialogue `relationshipDelta`
      choices (currently just logged, see `DialogueController.lua`)
- [ ] Dialogue "already met" branching (all NPCs currently always start
      at their root node)
- [ ] Playtest and retune the skill trees' XP curve/perk costs (`GDD.md`
      §12 — currently unplaytested guesses)
- [ ] More perks per tree / branching instead of a flat 2-perk chain
      (`SkillTreeConfig.lua`)
- [x] Visual style locked: top-down 2D presentation (`CameraController.lua`
      + `GDD.md` §6) — the earlier open question is resolved
- [x] Loading screen (`ReplicatedFirst/LoadingScreen.client.lua`)
- [x] Persistent HUD (`HudUI.lua`) — gold, day/time, skill levels
- [x] Tile-based starter map + auto-placed farm plots/fishing spot/
      cooking stations/NPCs/spawn (`MapConfig.lua` + `MapBuilder.lua`,
      `GDD.md` §13) — Studio no longer needs manual object placement,
      see `docs/VERTICAL_SLICE_SETUP.md`
- [x] Real asset pipeline (Tarmac, `tarmac.toml`) + a first batch of
      placeholder pixel-art tiles/sprites in `assets/` — Claude can't
      upload to Roblox (no API for that without a human login), so this
      is set up for Liam to run, not run automatically
- [ ] Upload the placeholder assets (or real art) via `tarmac sync` and
      confirm the generated map actually shows textures instead of flat colors
- [ ] Real Orange Ville map (this session's map is a small
      proof-of-concept plot, not the LORE_BIBLE.md village)
- [ ] Wire the actual opening cutscene (`OPENING_CUTSCENE.md`) into a
      playable sequence — currently just written, not implemented
- [ ] Billboard-sprite characters, if locked-camera-3D doesn't read as
      "2D enough" once playtested (`GDD.md` §6 fallback option)
- [x] Shared UI Theme (`Theme.lua`) + retrofit of every existing UI
      module to use it (`GDD.md` §14)
- [x] Lighting/post-processing pass (`AtmosphereService.lua`) — Bloom,
      ColorCorrection, SunRays, Atmosphere haze
- [x] Dialogue box portrait + typewriter text reveal
- [x] Spectacle banner speed-line "impact frame" burst
- [x] Ambient sakura petal particles (`AmbienceController.lua`)
- [x] Regenerated placeholder art with a more saturated anime palette +
      a decorative sakura-blossom tile variant
- [ ] Real character/tile art to replace the placeholders (needs Liam to
      commission/create it and run `tarmac sync`)

## Phase 4 — Polish & Pre-release
- [ ] Playtesting pass, balance tuning (sell prices, XP curves, difficulty)
- [ ] Bug bash
- [ ] Roblox-specific release prep (game icon, thumbnails, description,
      monetization decisions if any, age rating considerations)

## Notes
- Update the checkboxes above as work lands each session so picking back
  up after a gap is fast — check this file first each time you return.
- If scope needs to shrink to hit the month, cut from Phase 3 (content
  breadth) before cutting Phase 1 (lore) or Phase 2 (core feel) — a
  smaller lore-tight game beats a broad shallow one.
