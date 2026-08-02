# Act 1 Dialogue Scripts

Every tree here maps 1:1 to the node format in
`src/ReplicatedStorage/Modules/Shared/DialogueData.lua` — `id`, `speaker`,
`text`, and `options` (each with `text`, `next` node id, and an optional
`relationshipDelta` / `action`). Per `GDD.md` §8, relationship moves via
dialogue choices, not gift-grinding, so deltas are called out per option.

Node IDs use `<npc>_<scene>_<n>` so future dialogue can slot in without
renumbering.

## Kaya Fumizuki — first meeting (post-cutscene) & farming tutorial

```
[kaya_intro_1] Kaya:
"Hey — hey! Are you alright? You picked a strange place for a nap...
can you stand?"
> "...where am I?"                          -> kaya_intro_2
> "I'm fine. Really." (guarded)             -> kaya_intro_2b  [relationship -1]

[kaya_intro_2] Kaya:
"Orange Ville. Well — the edge of it. You're on old man Halric's fallow
field, actually, which explains a few things about your landing spot.
C'mon, let's get you somewhere that isn't dirt."

[kaya_intro_2b] Kaya:
"...Sure you are. Well, 'fine' people usually don't faceplant in a field.
Come on anyway — I'm not leaving you out here."
-> kaya_intro_3

[kaya_intro_3] Kaya:
"I'm Kaya. This is my grandfather's village, more or less — he's the
elder, so everyone assumes it's mine too. What should I call you?"
[Player name entry — not a dialogue choice, handled by name-entry UI]
-> kaya_farm_1

[kaya_farm_1] Kaya:
"So — actually, funny timing. This field you landed in? Technically
unclaimed. If you're looking for somewhere to stay, and you don't mind
work, it's yours. Interested?"
> "I'd like that." (accept the farm)        -> kaya_farm_2  [relationship +1] [action: GrantStarterFarm]
> "Let me think about it."                  -> kaya_farm_1b
> "What's the catch?" (wary)                -> kaya_farm_1c

[kaya_farm_1b] Kaya:
"Take your time. Not like the field's going anywhere. Come find me at the
store when you decide."
-> END

[kaya_farm_1c] Kaya:
"Ha — no catch. Grandfather says every hand helps, and this valley's had
fewer of those lately. That's it. That's the catch."
-> kaya_farm_1

[kaya_farm_2] Kaya:
"Great! Okay — quick basics, since you clearly aren't from around here.
You'll want to till a patch, plant, water it, and wait. Different crops
take different time. Want me to walk you through it, or are you the
figure-it-out type?"
> "Walk me through it."                     -> kaya_farm_3  [action: StartFarmingTutorial]
> "I've got it." (confident)                -> kaya_farm_3b [relationship +1]

[kaya_farm_3] Kaya:
"Smart. Okay — tool's in your hand already, don't ask me how. Till the
soil first, that dark patch near the fence. Then plant, then water. It
won't grow if you skip the water — trust me, I learned that the hard
way."
-> END

[kaya_farm_3b] Kaya:
"Look at you. Fine, I won't hold your hand. Shout if you get stuck — no
shame in it, everyone does at first."
-> END
```

Gameplay hooks: `GrantStarterFarm` unlocks the player's farm plots and
starter seeds (see `FarmingService.lua`); `StartFarmingTutorial` flags a
UI highlight on the till/plant/water prompts for new players (first-run
only, doesn't replay on later conversations).

## Elder Souta — the Otherworld Palate is noticed

Triggered once the player has harvested and sold their first crop *or*
landed their first fish — first of either fires this scene.

```
[souta_notice_1] Elder Souta:
"Kaya tells me you're settling in well. May I?" (gestures to sit)
-> souta_notice_2

[souta_notice_2] Elder Souta:
"That fish you brought in — or was it the crop — Ren mentioned you knew
its worth before you'd even properly looked at it. Most who've fished
these waters their whole lives couldn't tell you that."
> "Is that... unusual?"                     -> souta_notice_3
> "I just got lucky."                       -> souta_notice_3b [relationship -1]

[souta_notice_3] Elder Souta:
"Unusual isn't the word I'd use. There's an old story about this valley
— older than the village, even. I won't trouble you with all of it
tonight. But keep noticing what you notice. I have a feeling it matters
more than you think."
-> END

[souta_notice_3b] Elder Souta:
(a long pause, a small smile) "Perhaps. Luck has a way of finding the
same person twice, though. Come speak with me again sometime — I think
we'll have more to discuss than you expect."
-> END
```

Gameplay hook: this scene sets a flag (`FoundingMythIntroduced`) gating
later Elder Souta content — doesn't grant an item, purely narrative.

## Ren Amakusa — fishing tutorial

```
[ren_intro_1] Ren:
"You must be the one Kaya's been telling everyone about. Farmer by day,
apparently. You ever fished before?"
> "Never."                                  -> ren_intro_2
> "A little, back where I'm from."          -> ren_intro_2b [relationship +1]

[ren_intro_2] Ren:
"No shame in that. Grab a rod — there's a spare on the rack. Cast out
into the shallows there, past the reeds. Timing your cast matters more
than distance, so don't just wing it."
-> ren_tutorial_1 [action: StartFishingTutorial]

[ren_intro_2b] Ren:
"Yeah? Different fish out here, I'd wager, but the basics probably
translate. Give the shallows a try, tell me if anything surprises you."
-> ren_tutorial_1 [action: StartFishingTutorial]

[ren_tutorial_1] Ren:
"Once something bites, don't panic — you'll feel it, or, well, you'll
see it. Hook it quick, then it's a battle of patience. Match the
struggle, don't fight it head-on."
-> END
```

Gameplay hook: `StartFishingTutorial` highlights the cast-meter UI on
first use, and marks the Shallows zone as unlocked if it wasn't already
(should be unlocked from the start per `FishingConfig.lua`, this is a
safety net).

## Chef Hinano — cooking tutorial

```
[hinano_intro_1] Hinano:
"You're the new farmer. Good — bring me something worth cooking
sometime. What did you bring today?"
[Player selects an ingredient from inventory, or has none]
> (has an ingredient)                        -> hinano_tutorial_1
> (empty-handed)                             -> hinano_intro_1b

[hinano_intro_1b] Hinano:
"Empty-handed, then. Come back with something from your field or the
water and we'll talk."
-> END

[hinano_tutorial_1] Hinano:
"Alright. Cooking here isn't just tossing things in a pot and hoping —
you have to *feel* the dish out. Watch the rhythm, match it. Rush it and
you'll undercook. Drag your feet and you'll burn it."
-> hinano_tutorial_2 [action: StartCookingTutorial]

[hinano_tutorial_2] Hinano:
"Don't worry about ruining the ingredients — even a clumsy first attempt
still makes *something*. You just won't be proud of it. Go on, try it."
-> END
```

Gameplay hook: `StartCookingTutorial` highlights the rhythm-note lanes on
first use. Note this dialogue explicitly reinforces the "always produces
something, quality varies" decision from `GDD.md` §4 — Hinano's own words
carry the design rule instead of a dry tooltip explaining it.

## Kaleb — first encounter (farm visit, Act 1)

Kaleb doesn't get "found" — he shows up. First appearance triggers once,
the *first* time he spawns on the player's farm (random within his
once-per-day-cycle window, per `LORE_BIBLE.md` §5), regardless of what
else the player has or hasn't done yet.

```
[kaleb_first_1] Kaleb:
(already standing there when you notice him, like he's been waiting)
"Didn't peg you as the farming type. Then again, didn't peg you as
anything, seeing as nobody around here's got the first clue who you
are."
> "Who are you?"                            -> kaleb_first_2
> "...How long have you been standing there?" -> kaleb_first_2b [relationship +1]

[kaleb_first_2] Kaleb:
"Nobody, officially. Unofficially, I've got things. Things you won't
find at the port, and definitely not from the Exchange — that lot likes
paperwork. I don't."
-> kaleb_first_3

[kaleb_first_2b] Kaleb:
(a shrug, no real answer) "Long enough. You're jumpier than most —
I like that, actually. Means you're paying attention."
-> kaleb_first_3

[kaleb_first_3] Kaleb:
"Anyway. I'll be around — my own schedule, not yours. Got junk, got
treasure, got the occasional thing that shouldn't exist yet. Don't ask
where it comes from. I won't tell you, and you'll enjoy it more not
knowing."
> "Fair enough."                            -> kaleb_first_4  [relationship +1]
> "That's not ominous at all."              -> kaleb_first_4b

[kaleb_first_4] Kaleb:
(almost a smile) "Smart. See you around, farmer."
-> END [action: UnlockKalebShop]

[kaleb_first_4b] Kaleb:
"Wasn't trying to be. Or — maybe a little. See you around, farmer."
-> END [action: UnlockKalebShop]
```

Gameplay hook: `UnlockKalebShop` flags his rotating black-market
inventory as accessible from here on, whenever he's actually present on
the farm (his visit timer, not a persistent shop). Per `LORE_BIBLE.md`
§6, keep his lines implying more than they confirm — no version of this
scene should hint at whether he's connected to the founding myth.
