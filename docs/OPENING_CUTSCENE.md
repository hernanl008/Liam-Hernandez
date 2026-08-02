# Opening Cutscene — Beat Sheet

Death → rebirth structure, as requested. Kept stylized/tasteful rather
than graphic throughout — this is an all-ages farm-sim, not a story about
the death itself. The classic isekai "life was a grind, then it ended"
beat is played mostly through mood and implication, not detail.

Runtime target: 60-90 seconds. No dialogue trees, no player input — this
is a fixed intro sequence before the player gets control on Beat 5.

## Beat 1 — The Old Life (5-10s)

A single static or slow-pan shot: a cluttered desk, a cold cup of tea, a
window showing it's dark outside though it clearly shouldn't be this
late. No face shown — deliberately anonymous, could be anyone. A tired
exhale. Screen fades to white — not black, white, to keep the tone soft
rather than grim.

*(Implementation note: no death animation needed — the fade itself carries
the beat. Keeps this cheap to build and avoids the tone risk of showing
anything graphic.)*

## Beat 2 — Between Worlds (15-20s)

White fades into a formless, quiet space — soft particle effects, muted
color. **The Weaver** speaks first, calm and unhurried:

> "You're not where you were. You're not who you were, either — not
> anymore. That's alright. Most people don't get to choose their next
> page. You will, eventually. For now — rest."

No player choice here (matches LORE_BIBLE.md — the Weaver deliberately
withholds explanation). The Weaver's form is intentionally indistinct
(silhouette/light, no fixed model yet — art decision to make later).

## Beat 3 — The Fall (5s)

The particle space collapses inward toward a single point of light —
visual shorthand for "falling into" the new world. No impact shown.

## Beat 4 — Waking Up (10-15s)

Cut to: bright daylight, camera low and tilted (player is lying down).
Sound design carries this beat — birdsong, wind through wheat, distant
livestock. Camera slowly rights itself as the character sits up, revealing
**a fallow field on the edge of Orange Ville**, village rooftops visible
in the distance.

## Beat 5 — Found (10-15s)

**Kaya Fumizuki** enters, sees the player, and reacts with surprise/
concern rather than alarm — she assumes they're a traveler who collapsed,
not anything stranger (nobody yet knows about the Otherworld Palate).

> "Hey — hey! Are you alright? You picked a strange place for a nap...
> Can you stand? Come on, let's get you to the village. You can tell me
> what happened once you've had something to eat."

Player gains control at the end of her line, walking with her toward
Orange Ville — this is also the seam where the tutorial (movement,
Kaya's farming intro) begins. No hard cut to gameplay; the walk itself
is the transition.

## Deliberately left unshown/unresolved (matches LORE_BIBLE.md)

- The player's old-world name, face, and cause of death — never shown or
  stated. Keeps the "could be anyone" framing and sidesteps needing to
  write/localize an old-world backstory that mostly doesn't matter.
- Why the Weaver chose *this* person — not explained until Act 2/3.
- Any visual confirmation of what the Weaver actually is — kept as
  light/silhouette through the whole game until the Act 3 reveal tying it
  to the valley's guardian spirit.

## Implementation notes

- Beats 1-3 can be built as a single non-interactive cutscene
  (`ReplicatedFirst` loading-screen-adjacent or a dedicated intro
  `ScreenGui` with camera control) before the player's character even
  spawns into the real world.
- Beat 4's field and Beat 5's walk-in are the actual spawn point — no
  teleport needed between cutscene and gameplay, just a camera handoff.
- Voice acting is optional; the Weaver's line and Kaya's line both read
  fine as text-only with a simple typewriter effect if VO isn't in budget.
