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
forage / town errands / story beats) → cook using the day's catch+harvest →
sell / eat / gift → sleep → next day. XP and currency from all four
pillars (farming, fishing, cooking, social/story) feed back into
unlocking more of each system.

🔲 Is there combat/dungeon-crawling (like Stardew's mines), or is this
purely farm/fish/cook/social? This materially changes scope.

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
harvest → sell/cook/gift. Seasons gate what grows.

🔲 Land expansion model — buy plots, or unlock via story progression?

## 6. Anime theme direction

🔲 Needs your input — this is the single biggest lever on asset style,
lore tone, and character design. Rough spectrum to pick a lane on:
- Slice-of-life/cozy (Natsume's Book of Friends, Non Non Biyori tone)
- Shonen-adjacent (mild stakes, rival characters, tournament-style cooking
  showdowns — think Food Wars energy for the cooking system)
- Isekai framing (protagonist arrives in the town from elsewhere — gives a
  built-in reason for an amnesiac/outsider player character, common in
  farm-sim narratives)

## 7. Systems NOT yet designed

- Social/relationship system (NPCs, dialogue, gifting, romance?) 🔲 in scope?
- Progression/currency sinks beyond gear
- Multiplayer scope — solo-instanced farms, shared-world, or drop-in co-op? 🔲
  (Big architectural decision — affects how ServerScriptService state is
  structured from day one.)

## 8. Non-goals (for now)

Keeping these explicitly out of scope until the core 3 pillars + lore are
solid, to avoid scope creep on a solo month-long project:
- PvP
- Trading/marketplace between players
- Mobile-specific UI pass
