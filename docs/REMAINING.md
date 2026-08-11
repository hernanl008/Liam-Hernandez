# What's left to finish Anime Farm Life

An honest status of the project, kept current so "is it done?" has an
answer that isn't a guess. Three sections: what works, what only Liam can
do, and what is left to build.

Last updated: after the quest system landed.

---

## 1. What is built and working

| System | State |
| --- | --- |
| Farming | Till, plant, water, harvest. Seasons enforced. Crop growth visuals. 6 crops. |
| Fishing | Cast meter, bite, reel-in rhythm minigame, catch meter decides the catch, 3D rig, catch showcase. 7 fish + 4 junk/treasure pulls. |
| Cooking | Rhythm minigame, quality tiers, recipe roster. |
| Economy | Kaleb buys crops, fish and dishes. Gold, purse meter. |
| Progression | XP and levels for all three pillars, skill points, 9 perks on a branching animated skill tree. |
| Quests | 6 chained quests, on-screen tracker, journal (J), server-authoritative objectives and rewards. |
| NPCs | 5 speaking characters, branching dialogue, relationship values, "will remember that" cards. |
| World | Tile map, day/night cycle, seasons, weather, sleep-to-next-day, animated water. |
| Presentation | 2D sprite character, unified retro parchment/wood UI across every screen, opening cutscene. |
| Persistence | DataStore save/load with default-merge migration for old saves. |

---

## 2. Blocked on Liam — I cannot do these

These are not "not done yet". They are things the environment I run in
genuinely cannot do, and no amount of coding gets around them.

### 2a. Asset uploads
Uploading an image to Roblox requires Liam's own logged-in Roblox
session. Every PNG in `assets/` is drawn and committed; the ids in
`AssetIds.generated.lua` have to be pasted in after upload.

- [ ] `sprites/perk_icons.png` — skill tree nodes draw a plain pip until
      this lands. Everything else is uploaded.

### 2b. Audio
Every hook is wired and silent. `SoundIds.lua` lists 12 empty strings;
`SoundPlayer.play` no-ops on `""` so nothing breaks. Each needs a real
`rbxassetid://` from the Roblox library or an upload.

- [ ] Fishing: cast, bite, reel hit, reel miss, meter empty, catch,
      escape, snag
- [ ] Skill tree: open, hover, unlock
- [ ] Quests: complete
- [ ] Music: no track hooked up at all yet

### 2c. Publishing and playtesting
- [ ] Publish the place to the web — DataStore does not work until then,
      so no progress persists between sessions (the Output warns about
      this on every run today).
- [ ] Playtest and retune: sell prices, XP curve, perk costs, minigame
      difficulty. I can reason about these numbers but I cannot feel
      them; balance needs someone playing.
- [ ] Game icon, thumbnails, store description, age rating.

---

## 3. Left to build — I can do these

Roughly in the order I would do them.

### 3a. Content depth (the biggest gap)
The systems are broader than the content in them. Everything here is a
data change, not new architecture.

- [ ] More quests — 6 is a tutorial, not a game. The chain ends and
      nothing follows it.
- [ ] More crops, fish and recipes. The Compendium is thin.
- [ ] Dialogue for days 2+. NPCs currently repeat one return greeting
      forever.
- [ ] Deeper skill trees — 3 perks per pillar, and the tree UI is built
      to carry far more.

### 3b. Systems not yet started
- [ ] Title / main menu screen. The game currently drops you straight in.
- [ ] Buying seeds — Kaleb only buys, never sells, so seeds are finite
      apart from quest rewards. This is an economy hole.
- [ ] NPC schedules and movement. NPCs are static, which is why quests
      are auto-accepted rather than handed out in person.
- [ ] Tool upgrades / watering can capacity — classic farm-sim
      progression the skill trees currently stand in for.
- [ ] Festivals or seasonal events.
- [ ] Multiplayer pass: the code is server-authoritative throughout, but
      nothing has been tested with two players in the world.

### 3c. Polish and correctness
- [ ] Mobile / touch layout. Everything is built for mouse and keyboard;
      panels use fixed pixel sizes with constraints, so they will fit,
      but nothing has a touch control path except drag-to-pan.
- [ ] Reskin the remaining minigame overlay (cooking's non-retro lane
      strip) to match the rest.
- [ ] Accessibility beyond Assist Mode: colourblind-safe branch accents,
      text size option.
- [ ] Automated tests. `tools/verify.sh` catches parse errors, undefined
      and out-of-order locals, UIStroke-on-text and dialogue cycles —
      all found real shipped bugs — but there is no test that runs game
      logic.

---

## 4. Honest assessment

The vertical slice is complete: every pillar is playable start to
finish, they feed each other through the economy and the skill trees,
and there is now a quest chain that teaches all of it. What it does not
have is *depth* — a player who finishes the six quests has seen most of
what exists.

The fastest route to something people would actually play for an hour is
section 3a. It is all data, none of it needs new systems, and it is the
part where Liam's judgement about the game's voice matters most.
