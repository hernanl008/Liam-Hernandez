# Lore Bible — Anime Farm Life (working title)

Status: **premise, world, and main cast locked** (this session, per Liam's
direction). Placeholder proper nouns throughout except where Liam has set
one directly (town name, Kaleb) — swap the rest freely, nothing here is
precious. Full NPC list lives in `NPC_ROSTER.md`; opening cutscene beats
live in `OPENING_CUTSCENE.md`.

A note on the inspiration: Liam pointed at *That Time I Got Reincarnated
as a Slime* for the *shape* of the opening (modern-world death → reborn as
something humble in a new world) — that structural beat is used here, but
the world, characters, names, and plot below are original, not references
to Slime's cast/setting. Keeps this clear of the source material while
keeping the beat that was asked for.

## 1. Premise

A modern-world person, worn thin by an unglamorous life, dies suddenly
(kept light/stylized on-screen, not graphic — see `OPENING_CUTSCENE.md`).
Before fully fading, they're met by **the Weaver**, a being that exists
between worlds, who offers no explanation, only a choice, and rebirths
them as an orphaned farmer waking up face-down in a fallow field on the
edge of **Orange Ville**.

They come back with one strange trait: **the Otherworld Palate** — an
inexplicable, precise sense for freshness, ripeness, and quality that no
one born in this world has. Mechanically, this *is* the fishing
rarity-sense and the cooking rhythm-game's timing cues — in-fiction, the
player is the only person who can "feel" a fish's rarity before it bites,
or "hear" a dish's rhythm as they cook. It's not combat power, it's not
magic in the flashy sense — it's why a farmer with no memory of farming
becomes, over the story, the reason the valley's three trades (farming,
fishing, cooking) start thriving again.

Inciting incident: within the first few days, the village elder recognizes
the Otherworld Palate for what it is — a sign tied to the valley's oldest
legend (§6) — and the "just settle into farm life" opening quietly becomes
"you may be the reason the valley's magic is dying, or the reason it's
saved."

## 2. World

- **World name**: Aselyn
- **Region**: Veyl Valley — a temperate, coastal valley: farmland inland,
  cliffs and reef down to the sea at its mouth.
- **Home village**: **Orange Ville** (Liam's call) — small,
  farming-and-fishing village at the valley's inland edge. Player's
  starting farm is on its outskirts.
- **Trade town**: Kotobuki Port — the valley's only real port/market town,
  a half-day's travel from Orange Ville downriver. Home of the Trade
  Exchange (GDD.md §7) and the Cooking Academy.
- **Tech/magic level**: low-fantasy. Magic is real but rare and mostly
  folk-practice (blessings, wards, the Otherworld Palate itself) rather
  than combat spells — keeps it consistent with "a little" combat and a
  cozy-adjacent tone.
- **Blightspawn**: corrupted wildlife/vermin that have been creeping in
  from the valley's forest edges as its guardian magic fades (§6). This is
  the light-combat threat — never inside the village, mostly forest/coast
  fringes and Frontier Watch territory.

## 3. Factions

- **Orange Ville farming folk** — informal, elder-led. No guild structure,
  just the village.
- **Fisherfolk Guild** — small guild dock in Orange Ville, teaches
  fishing, gates deeper zones by rank.
- **Trade Exchange** — Kotobuki Port's player-facing marketplace
  institution; the multiplayer trading pillar. Broker-run, neutral,
  profits from listing fees (a natural currency sink).
- **Cooking Academy** — Kotobuki Port. Trains chefs, hosts seasonal
  cook-off tournaments (Food-Wars-style stakes for the rhythm game at the
  high end). Has an old rivalry with "home cooking" that Chef Hinano
  embodies from the village side.
- **Frontier Watch** — the valley's light militia/ranger corps, handles
  Blightspawn incursions. Small, three-figure roster (§ NPC_ROSTER.md).

## 4. Central Conflict / Story Arc

Generations ago, Veyl Valley's fertility, fish stocks, and even its food's
"soul" (why a home-cooked meal here always tasted like *something more*)
were tied to a guardian spirit that vanished under circumstances no one
alive remembers clearly — the founding myth (§6). Since then, the valley
has been quietly declining: smaller harvests, rarer fish, Blightspawn
creeping in.

The player's Otherworld Palate is not a coincidence — the Weaver drew them
here *because* the valley's fading magic needed an outside anchor to
re-root itself. Over the story:

1. **Act 1 (village)**: settle in, learn the three trades, small mysteries
   pile up (unnaturally vivid ingredients near the player's farm, a
   recurring dream-fragment of "the Weaver", a shady stranger who keeps
   turning up with items that shouldn't exist yet — see Kaleb, §5).
2. **Act 2 (valley-wide)**: travel to Kotobuki Port, the Trade Exchange and
   Cooking Academy open up, Frontier Watch introduces the Blightspawn
   threat properly, the founding myth gets pieced together via NPCs.
3. **Act 3 (resolution)**: the player, through mastery of all three trades
   (a legendary catch, a legendary dish, a fully restored farm) and
   confronting the source of the Blightspawn, doesn't "fight a final boss"
   in the traditional sense — they complete a ritual that only someone
   with the Otherworld Palate could perform, re-rooting the valley's magic.
   Combat is present but not the climax mechanic — matches "a little
   combat" scope.

Progression gating: story beats unlock new fishing depth zones, new farm
land, and new Cooking Academy tiers — narrative and the three pillars are
never fully decoupled (ties back to GDD.md's non-goal of avoiding a purely
sandbox loop).

## 5. Characters — Main Cast

Full 50+ NPC roster (village, port, Frontier Watch, Academy, traveling
NPCs) is in `NPC_ROSTER.md`. These are the story-critical named cast.

### The Weaver
- Role in town: not "in town" — a between-worlds being, appears in dreams/
  cutscenes only.
- Relationship to player: the one who reincarnated them; deliberately
  withholds *why* until late Act 2.
- Personality / hook: calm, cryptic, not malicious — genuinely believes
  it's giving the player a second chance, not just using them.
- Connection to gameplay system: bookends the opening cutscene; occasional
  dream sequences gate story triggers.
- Arc: revealed in Act 3 to be tied to the valley's original guardian
  spirit — implying the player's reincarnation and the valley's fate were
  entangled from the start.

### Kaya Fumizuki
- Role in town: runs Orange Ville's general store; village elder's
  granddaughter.
- Relationship to player: finds them collapsed in the field the morning
  after rebirth — first friend, tutorializes farming.
- Personality / hook: practical, warm, quietly ambitious to modernize the
  village's trade with Kotobuki Port (foreshadows Trade Exchange arc).
- Connection to gameplay system: farming tutorial; early gifting/social.
- Arc: becomes the village's liaison to the Trade Exchange in Act 2.

### Elder Souta
- Role in town: Orange Ville's elder; Kaya's grandfather.
- Relationship to player: recognizes the Otherworld Palate; gatekeeps
  founding-myth lore.
- Personality / hook: warm but evasive about the past — knows more of the
  founding myth than he lets on early.
- Connection to gameplay system: main quest triggers.
- Arc: reveals his own grandfather's role in the guardian spirit's
  disappearance late in Act 2.

### Ren Amakusa
- Role in town: Fisherfolk Guild dockmaster, Orange Ville.
- Relationship to player: fishing mentor.
- Personality / hook: easygoing, but carries quiet regret over a
  legendary fish he failed to land years ago.
- Connection to gameplay system: fishing tutorial and rank-gating; his
  "one that got away" becomes a postgame Legendary Fish questline.
- Arc: closure via the player landing (or helping him finally land) that fish.

### Chef Hinano
- Role in town: runs Orange Ville's food stall.
- Relationship to player: cooking mentor.
- Personality / hook: strict, old-school "home cooking has soul" ethos;
  long-standing rivalry with Chef Auguste Vane.
- Connection to gameplay system: cooking rhythm-game tutorial.
- Arc: reconciles (or finally beats) Vane at a Kotobuki Port cook-off in
  Act 2/3.

### Yuzuki "Yuzu" Tachibana
- Role in town: neighboring young farmer, player's age.
- Relationship to player: rival-then-friend.
- Personality / hook: competitive, prideful, secretly lonely (her family's
  farm has been struggling as the valley declines).
- Connection to gameplay system: seasonal harvest contests.
- Arc: her farm's fortunes visibly track the valley's restoration —
  a personal stake in the main plot, not just flavor.

### Kaleb
- Role in town: outcast, not affiliated with the village or the guilds.
- Relationship to player: a wandering merchant who deals in illegal,
  mythic, and otherwise-unobtainable rare items — shows up uninvited on
  the player's own farm once every day cycle (roughly hourly in
  real-time), never in town.
- Personality / hook: sus and edgy — cagey about where his stock comes
  from, doesn't do small talk, always implies he knows more than he says.
- Connection to gameplay system: a rotating black-market shop gated to the
  player's farm specifically (not the Trade Exchange — deliberately
  outside the "legitimate" trading system in GDD.md §7); a source for
  items that can't be farmed, fished, or bought anywhere else.
- Arc: n/a per Liam's spec for now — but his "items that shouldn't exist
  yet" are the Act 1 thread feeding the founding-myth mystery (§6):
  🔲 open question whether he turns out connected to the guardian spirit's
  disappearance, or is just an opportunist profiting off the valley's
  decline. Worth deciding before Act 2, same as the rest of §6.

### Mira Kessler
- Role in town: Trade Exchange broker, Kotobuki Port.
- Relationship to player: professional — onboards them to trading once
  they reach the port.
- Personality / hook: sharp, fair, treats the Exchange as sacred neutral
  ground (a deliberate contrast to Kaleb's black-market dealing).
- Connection to gameplay system: the multiplayer trading system's
  narrative anchor (GDD.md §7).
- Arc: reveals the Exchange itself was founded generations ago specifically
  because of the valley's declining harvests — ties trading mechanically
  and narratively to the central conflict.

### Chef Auguste Vane
- Role in town: celebrity judge, Kotobuki Port Cooking Academy.
- Relationship to player: antagonistic rival, softens over time.
- Personality / hook: flamboyant, technically brilliant, dismissive of
  "farm cooking" until the player proves otherwise.
- Connection to gameplay system: hosts the harder/late-game rhythm charts
  and cook-off tournaments.
- Arc: his rivalry with Hinano resolves alongside the player's own
  cooking-mastery arc.

### Captain Reido
- Role in town: Frontier Watch commander.
- Relationship to player: light-combat mentor once Blightspawn appear.
- Personality / hook: no-nonsense, protective of the valley, aware of more
  of the founding myth's "danger" side than the village elders.
- Connection to gameplay system: combat tutorial, Frontier Watch questline.
- Arc: provides the Act 2/3 exposition on what Blightspawn actually are.

### Mossom
- Role in town: small spirit-animal (fox/otter-adjacent, TBD art) that
  starts following the player after rebirth.
- Relationship to player: constant companion, minimal dialogue at first.
- Personality / hook: mute/simple at first, gains "vocabulary" as the
  valley's magic is restored — a soft difficulty/progress indicator made
  diegetic.
- Connection to gameplay system: could serve as the UI's guide/tutorial
  voice long-term (open implementation detail, not locked).
- Arc: revealed to be a fragment of the original guardian spirit.

## 6. Founding Myth (Timeline)

- **Long ago**: Veyl Valley's abundance was tied to a guardian spirit
  (implied to be what Mossom is a fragment of) who kept the land, sea, and
  even the "soul" of its food thriving.
- **Three generations ago**: something happened — deliberately left
  ambiguous until Act 2 — and the guardian spirit vanished. Elder Souta's
  grandfather was involved. The valley began slowly declining.
- **Since**: Blightspawn incursions have grown gradually worse; the Trade
  Exchange was founded in response to weakening harvests, to keep the
  valley's economy afloat by trading with outside regions; Kaleb (or
  someone like him) has apparently been operating on the fringes long
  enough to have a supply of things that "shouldn't exist yet."
- **Now**: the Weaver, sensing the valley's magic has fallen critically
  low, reincarnates the player — someone from entirely outside the
  world's rules — to serve as a new anchor point.

🔲 Open: exactly *what* happened three generations ago (an accident? a
sacrifice gone wrong? a deliberate binding to protect something worse?),
and whether Kaleb is tied to it — worth deciding before Act 2 content gets
built, since it's the mystery the whole back half hangs on.

## 7. Tone & Themes

- **Tone**: cozy-adjacent with real narrative stakes underneath — starts
  slice-of-life, the isekai/mystery layer surfaces gradually rather than
  front-loaded.
- **Themes**: found family (village accepting an amnesiac stranger),
  renewal/restoration (both the valley's and the player's own "second
  life"), tradition vs. outside influence (Hinano vs. Vane, village vs.
  port, legitimate trade vs. Kaleb's black market), quiet competence (a
  farmer, not a chosen-one warrior, saves the valley through craft, not
  combat).

## 8. Consistency Rules

- The Otherworld Palate is a *sense*, never a combat ability or a way to
  cheat crafting outright — it informs (rarity, timing), it doesn't
  auto-win minigames. Keeps fishing/cooking mechanically meaningful.
- Magic in this world is folk/ambient, never flashy spellcasting — keeps
  combat "a little" by construction; Blightspawn are corrupted-creature
  fights, not wizard duels.
- No character currently alive remembers the founding myth firsthand —
  everything about it is secondhand/legend until Act 2 reveals, which
  keeps early-game dialogue from accidentally over-explaining the mystery.
  Kaleb is the one exception worth guarding carefully — he should *imply*
  he knows more than the villagers without confirming anything, until
  his own open question above is resolved.
- Kotobuki Port and Orange Ville are the only two settlements referenced
  unless a future decision explicitly adds more (avoid scope creep on
  named locations). Kaleb is explicitly unaffiliated with either.
