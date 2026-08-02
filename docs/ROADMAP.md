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

## Phase 3 — Content Expansion (~week 4)
- [ ] Remaining depth zones + fish roster
- [ ] Recipe roster tied to lore (regional dishes, festival specials)
- [ ] Remaining crops + seasons
- [ ] Story beats implemented per the lore bible's arc
- [ ] UI/UX pass (HUD, inventory, shop, dialogue box)
- [ ] Cast-power meter that actually affects bite odds (deferred from
      Phase 2, see `FishingController.lua`)
- [ ] Crop growth-stage visuals (model swaps per `FarmingConfig.lua` stage)
- [ ] Persistence (DataStores) — everything is in-memory only right now
- [ ] Relationship stat persistence for dialogue `relationshipDelta`
      choices (currently just logged, see `DialogueController.lua`)
- [ ] Dialogue "already met" branching (all NPCs currently always start
      at their root node)

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
