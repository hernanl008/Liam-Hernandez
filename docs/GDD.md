# Game Design Document — Anime Farm Life (working title)

Status: **draft skeleton**. Sections marked 🔲 need a decision from Liam
before implementation locks in — everything else is a proposed starting
point, open to change.

## 1. Pitch

An anime-styled farm-sim/life-sim, Stardew Valley-inspired but with its own
identity: fishing has real mechanical depth (not just a bobber minigame),
and cooking is a rhythm game instead of a menu/timer. Built to ship with a
tight, intentional story/lore rather than a purely sandbox loop.

🔲 **Working title** — placeholder "Anime Farm Life" used throughout these
docs. Replace once you have a real name (also drives lore — town name,
protagonist name, etc.).

## 2. Core Loop

Day cycle: wake → farm chores (water/harvest/plant) → head out (fish /
forage / town errands / story beats / light combat) → cook using the
day's catch+harvest → sell / eat / gift / trade → sleep → next day. XP and
currency from all five pillars (farming, fishing, cooking, social/story,
trading) feed back into unlocking more of each system.

**Decided:** light combat is in scope, not a core pillar. It's pest/monster
encounters ("Blightspawn" — see `LORE_BIBLE.md`) tied to the Frontier Watch
faction: clearing farmland threats, escorting caravans, seasonal hunts.
Think Stardew's mines in spirit, but shallow — a few enemy types, simple
hit-and-dodge combat, mainly a gate for rare crafting materials and a
questline, not a skill tree of its own. No PvP (see Non-goals).

## 3. Fishing — the depth pillar

Proposed structure (see `src/ReplicatedStorage/Modules/Fishing/FishingConfig.lua`
for the data shape already scaffolded):

- **Depth zones**: Shallows → Mid Reef → Deep Trench → Abyssal Rift, gated
  by a fishing level. Deeper zones = rarer fish, harder catch mechanics,
  need better rod/gear.
- **Cast → bite → reel arc**:
  1. Cast with a power/accuracy meter (where in the water you land affects
     what can bite).
  2. Wait for a bite (patience window varies by fish).
  3. Reel-in tension minigame: keep a moving fish icon inside a bar that
     drifts, similar in spirit to Stardew but with per-fish "struggle
     difficulty" driving bar speed/erraticness (already modeled as
     `struggleDifficulty` 1-10 in the config).
- **Rarity tiers**: Common/Uncommon/Rare/Epic/Legendary, legendary fish as
  one-off named catches tied to lore (a specific spot, specific weather,
  specific season/time).
- **Gear progression**: rod tiers, bait types (bait could bias which fish
  bite, not just bite speed — more interesting than a flat speed buff),
  eventually a boat/submersible to reach new zones.

🔲 Weather/time-of-day affecting fish spawns? (Stardew does this heavily —
worth deciding early since it touches the day/night + weather systems.)

## 4. Cooking — rhythm game pillar

Proposed structure (see `RhythmGameConfig.lua`):

- Each recipe = a note chart (Tap/Hold/Slide notes across lanes), like a
  lightweight DDR/Friday Night Funkin' chart, scaled to the recipe's
  complexity (simple dishes = short/easy charts, festival/legendary dishes
  = long/hard charts).
- Timing accuracy per note (Perfect/Good/Okay/Miss) rolls up into a dish
  **quality score**, which affects sell price, buff strength if eaten, and
  gift reactions from NPCs.
- Ingredients consumed = crops/fish by id, so the chart system plugs
  directly into Farming/Fishing output.

🔲 Difficulty scaling — fixed chart per recipe, or procedurally
harder as the player's "chef level" rises (so cooking stays challenging
late-game)?
🔲 Failure state — can you botch a dish entirely (wasted ingredients) or
does it always produce *something*, just lower quality?

## 5. Farming

Standard stardew-style: plant → grow (staged, see `FarmingConfig.lua`) →
harvest → sell/cook/gift/trade. Seasons gate what grows. (Land expansion
model — see §8.)

## 6. Anime theme direction

**Decided: Isekai reincarnation.** Protagonist dies in the real world and
is reborn as a farmer in an anime fantasy world, opening on a death →
rebirth cutscene. Full premise, world, and cast in `LORE_BIBLE.md` and
`NPC_ROSTER.md`; opening cutscene beats in `OPENING_CUTSCENE.md`.

🔲 **Visual style** — "anime themed... '2D' world" could mean two very
different engineering paths:
1. Toon-shaded 3D (cel-shading, flat lighting, anime-proportioned rigs) —
   Roblox has done this before (see games using outline/toon shaders); full
   3D movement and camera, just styled to read as anime.
2. Actual 2D/2.5D — billboarded sprite characters on a 3D or flat plane
   (à la old-school JRPGs or Roblox's billboard-sprite games), which
   changes animation pipeline, camera setup, and asset creation entirely.

   Went with reading "ykwis"/'2D world' as the toon-shaded-3D look for
   now since it's far less asset-pipeline risk for a solo month-long
   project — say the word if you actually meant flat 2D sprites and this
   flips.

## 7. Multiplayer & Trading

**Decided:** shared-world with a player-driven trading system.

- Farms are **per-player instanced plots** (like Stardew) — no one
  trampling your crops — but town hubs (Kotobuki Port especially) are
  **shared multiplayer spaces**.
- **Trade Exchange** (Kotobuki Port, run by NPC broker Mira Kessler — see
  `NPC_ROSTER.md`): players list fish/crops/dishes for other *players* to
  buy, not just an NPC shop. This is the core of the trading pillar the
  valley's prosperity narrative hooks into.
- 🔲 Still open: real-time player stalls (see other players placing/buying
  live) vs. an async listing board (post an item, it sells whenever
  someone buys — simpler to build, no need to solve live-economy sync
  issues early). Recommend starting async for the vertical slice and
  upgrading to live stalls later if it's landing well.
- No PvP, no combat trading exploits — trading is cooperative/economic
  only.

## 8. Social & Progression

- Social/relationship system: **in scope** — 50+ NPCs (`NPC_ROSTER.md`),
  dialogue, gifting; romance is a 🔲 open question (isekai farm-sims often
  include it, but it's a large scope add — decide once the vertical slice
  cast is proven out).
- Currency/progression sinks: gear tiers (rod/tools), farm plot expansion,
  Trade Exchange stall upgrades, Frontier Watch gear for combat.

🔲 Land expansion model — buy plots, or unlock via story progression?

## 9. Non-goals (for now)

Keeping these explicitly out of scope until the core pillars + lore are
solid, to avoid scope creep on a solo month-long project:
- PvP
- Mobile-specific UI pass
- Live/real-time player-stall trading (start async, see §7)
