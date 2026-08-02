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
  eventually a boat/submersible to reach new zones. Better rods widen the
  reel-in tolerance window, not just raw stats (mirrors why Stardew
  players say fishing gets less punishing as gear improves — see §10).
- **Junk & treasure catches** (new, research-informed — §10): every cast
  has a small independent chance of pulling up junk (driftwood, old
  boots — sellable to Kaleb specifically, not the Trade Exchange, fits
  his "unaffiliated" characterization) or a treasure catch (bonus
  currency/rare crafting material). Fields of Mistria and Stardew players
  both cite this as a favorite fishing beat — cheap to build, adds
  variance without extra difficulty.
- **Assist Mode** (accessibility, research-informed): a settings toggle
  that widens reel-in timing tolerance across the board. Direct response
  to a recurring complaint that Stardew's fishing minigame difficulty
  clashes with its chill tone, including players who cite motor/hand
  tremor difficulty specifically (§10) — costless to add now, expensive
  to retrofit later.

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
- **Note-type semantics** (research-informed, §10): a real cooking-rhythm
  prototype pattern worth borrowing is giving note types diegetic meaning
  instead of being purely abstract lanes — `Tap` = crack/chop/plate,
  `Hold` = stir/simmer (hold matches the physical duration of the action),
  `Slide` = flip/toss. Makes charts read as "cooking" instead of a
  disconnected rhythm game bolted onto a farm-sim.
- **Decided — failure state**: always produces *something*, just at lower
  quality (never a wasted-ingredients wipe). Directly informed by the
  Stardew fishing-minigame complaint that punishing minigames clash with
  a cozy tone (§10) — cooking is meant to feel expressive, not
  pass/fail.

🔲 Difficulty scaling — fixed chart per recipe, or procedurally
harder as the player's "chef level" rises (so cooking stays challenging
late-game)?

## 5. Farming

Standard stardew-style: plant → grow (staged, see `FarmingConfig.lua`) →
harvest → sell/cook/gift/trade. Seasons gate what grows. (Land expansion
model — see §8.)

- **Decided — no stamina system** (research-informed, §10): several
  competitors in this exact genre (anime-styled Stardew-likes) call out
  "no stamina grind" as a headline differentiator players specifically
  praise. Pacing instead comes from day length and the social/story
  clock (NPCs keep their own schedules), not an energy bar that punishes
  efficient play.
- **Adjustable day length** (QoL, research-informed, §10): a settings
  option to speed up/slow down the day cycle. Cheap to build if the day
  cycle is driven by one tunable constant from the start (see
  `DayCycleService.lua`), expensive to retrofit — building it in now.

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
- **Decided — dialogue-choice relationships** (research-informed, §10):
  friendship moves via meaningful dialogue choices (each conversation
  offers 2-3 responses that nudge a relationship stat up/down), not pure
  daily-gift-grinding. Avoids the genre's most common social-system
  complaint (every NPC needing to be gift-farmed every single day) while
  keeping gifting as a secondary, not sole, lever.
- Currency/progression sinks: gear tiers (rod/tools), farm plot expansion,
  Trade Exchange stall upgrades, Frontier Watch gear for combat.

🔲 Land expansion model — buy plots, or unlock via story progression?

## 9. Non-goals (for now)

Keeping these explicitly out of scope until the core pillars + lore are
solid, to avoid scope creep on a solo month-long project:
- PvP
- Mobile-specific UI pass
- Live/real-time player-stall trading (start async, see §7)

## 10. Genre research notes

A pass through what players actually say about comparable games, done to
make sure design decisions above aren't just guesses. Cited inline above
via "§10" — full sources here rather than repeated per bullet. These
inform original systems above; nothing here is copied wholesale from any
one title.

- Fields of Mistria fishing/junk-catch discussion — [Fishing | Fields of
  Mistria Wiki](https://fields-of-mistria.fandom.com/wiki/Fishing),
  [Steam community discussions](https://steamcommunity.com/app/2142790/discussions/0/4702413158524946450)
- Stardew Valley fishing-minigame difficulty/accessibility complaints —
  [Steam community discussions](https://steamcommunity.com/app/413150/discussions/0/405692758724056415)
- Sun Haven's no-stamina system, dialogue-choice friendship, adjustable
  day length — [What does Sun Haven do better than average for the
  genre?](https://steamcommunity.com/app/1432860/discussions/0/4848777260030684532/),
  [Top Farming Sims feature — ModDB](https://www.moddb.com/games/sun-haven/features/top-farming-sims)
- Cooking-rhythm-game note-type design patterns (tap/hold/toss mapped to
  physical actions) — [Cooking Rhythm Game
  Prototype](https://clam-meditation.itch.io/crg-prototype), [Cook, Serve,
  Delicious! 2](https://en.wikipedia.org/wiki/Cook,_Serve,_Delicious!_2)
- Isekai worldbuilding fan preferences (earned growth over instant power)
  — [10 most common Isekai anime
  tropes](https://www.sportskeeda.com/anime/common-isekai-anime-tropes) —
  validates the existing Otherworld Palate design (a sense, not raw
  power) rather than changing it.

## 11. Spectacle & Combo System

The "make it feel more anime" pass. Both rhythm minigames (fishing
reel-in, cooking) now share a combo/spectacle layer on top of the base
scoring, instead of just returning a flat quality number:

- **Combo bonus** (`RhythmScoring.evaluate`): consecutive top-tier
  ("Perfect") hits build a streak; each streak point adds +2 quality, up
  to a 5-hit cap (+10 quality). Rewards nailing a run without making the
  base timing windows meaningless.
- **Live combo counter** (`RhythmUI.lua`): a "3x COMBO!" style counter
  during play that pulses every 3rd hit, so the streak feels good in the
  moment, not just as a number in the results screen.
- **Spectacle banners** (`SpectacleUI.lua`): a punchy full-screen banner +
  flash + light camera shake for standout moments — a Legendary catch, a
  5+ combo, a Gold-tier dish. One shared module, not bespoke VFX per
  system, so adding a new "big moment" elsewhere is a one-line call.
- **The Moonlit Serpent** (`LORE_BIBLE.md` §5, Ren Amakusa's arc): the
  first piece of content actually built around this — a Legendary,
  night-only fish in the Shallows (no need to grind to a deeper zone for
  the payoff), always triggers the spectacle banner. Ties a mechanical
  flex directly to a named story beat instead of being generic loot.
- **Fishing level & zone gating** (closes the §3 weather/time-of-day
  question partially): catches now raise a `FishingLvl` stat
  (`PlayerDataService.lua`), which gates `FishingConfig.DepthZones`'
  `unlockLevel` — Mid Reef (and its Moonfin Koi) becomes reachable at
  level 5, roughly 12 catches in. Time-of-day gating exists today only
  for the Moonlit Serpent; broader weather/spawn-table effects are still
  open per §3.

Deliberately not spectacle-ified: dialogue, and farming's day-to-day
loop. Those are meant to stay calm/cozy per the tone in `LORE_BIBLE.md`
§7 — the full flash/shake `SpectacleUI` treatment is reserved for the
two skill-based minigames. Farming does get the quieter "New Discovery!"/
"LEVEL UP!" banners (§12) on harvest, same as the other two pillars, just
never the shake-and-flash version.

## 12. Compendium & Skill Trees

Two systems added this session, both reusing the spectacle/feedback
plumbing from §11 rather than bolting on new UI patterns.

**Compendium** ("the book," `CompendiumUI.lua`, toggled with **B**): a
scrollable index of every fish, dish, crop, and junk/treasure pull,
sectioned by category. Undiscovered entries show as "???" for both name
and description; discovery happens the first time you catch/cook/harvest/
pull that specific thing (`PlayerDataService.discover`/`addItem`). Purely
a reference screen — no gameplay effect from having it open, just the
payoff of filling it in. Every fish/dish/crop/junk entry got a one-line
flavor description as part of this pass, so the book actually reads like
one instead of a bare list.

**Skill trees** (`SkillTreeConfig.lua`, toggled with **P**): one tree per
pillar (Farming/Fishing/Cooking), a flat 100-XP-per-level curve, one
skill point per level. Each tree is a short 2-perk linear chain rather
than a branching graph — enough to feel like real progression without
needing a graph-layout UI yet:

- **Farming**: Green Thumb (15% bonus-crop chance on harvest) → No Till
  Needed (harvested plots stay tilled).
- **Fishing**: Quick Hands (50% longer hook window) → Treasure Hunter
  (doubles the odds a pull is treasure, GDD.md §3).
- **Cooking**: Efficient Cook (20% chance to keep ingredients when you
  start cooking) → Show Stopper (dishes are never worse than Bronze).

XP sources: Fishing awards more for rarer fish (`FishingConfig.RarityXp`,
up to 100 for the Moonlit Serpent); Cooking awards more for higher dish
tiers; Farming awards a flat amount per harvest based on the crop's sell
price. All perks are applied *at the moment of the action* (harvest/
catch/cook), not via persistent ownership of world objects — sidesteps
needing real per-player farm-plot ownership (a bigger architecture change
implied by §7's "instanced farms" but not yet built) while still giving
Farming perks that do something. See `SkillTreeConfig.lua`'s header
comment for the full reasoning.

🔲 Open: the XP curve (flat 100/level) and perk costs are unplaytested
guesses — expect to retune once these have actually been played.
