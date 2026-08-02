# NPC Roster — Anime Farm Life (working title)

54 NPCs across 5 locations/factions, plus Kaleb who is deliberately
unaffiliated with any of them. The 11 story-critical characters have full
profiles in `LORE_BIBLE.md` §5 (the Weaver, Kaya Fumizuki, Elder Souta,
Ren Amakusa, Chef Hinano, Yuzuki "Yuzu" Tachibana, Kaleb, Mira Kessler,
Chef Auguste Vane, Captain Reido, Mossom) — not repeated here. This file
is the implementation-facing list: everyone else, organized by where they
live and what they gate.

Treat this as a build-priority list top-to-bottom within each section —
build the Act 1 (Orange Ville) roster first, Kotobuki Port for Act 2, the
rest can trail behind first-playable.

## Orange Ville (home village — Act 1)

Main cast here: Kaya Fumizuki, Elder Souta, Ren Amakusa, Chef Hinano, Yuzu
Tachibana (see LORE_BIBLE.md). Rest of the village:

| Name | Role | Hook |
|---|---|---|
| Farmer Daigo | Neighboring farmer | Gruff, gives crop-rotation tips; secretly proud of the player's progress |
| Widow Tsune | Livestock keeper | Sells coop/pasture animals and feed; village's unofficial gossip hub |
| Little Emi | Village kid | Fetch-quest giver; idolizes Yuzu |
| Blacksmith Goro | Tool repair/upgrade | Gruff but fair pricing; upgrades rods and farm tools |
| Carpenter Nao | Farm building upgrades | Handles barn/coop/plot expansions |
| Herbalist Sayo | Seeds & fertilizer | Also teaches foraging; knows the forest edge better than Frontier Watch does |
| Pip | Messenger spirit-bird | Delivers letters/quest notices; comic relief, non-human |
| Miller Ume | Runs the grain mill | Crafting tie-in (flour/feed processing) |
| Innkeeper Botan | Runs the village inn | Rumor hub, sells simple meals, side-quest board |
| Shrine Keeper Wren | Maintains the old valley shrine | Knows fragments of the founding myth Elder Souta won't share |

## Kotobuki Port (trade town — Act 2)

Main cast here: Mira Kessler, Chef Auguste Vane (see LORE_BIBLE.md). Rest
of the port:

| Name | Role | Hook |
|---|---|---|
| Harbor Master Denji | Manages the docks | Gate NPC for boat/submersible unlocks (deep fishing zones) |
| Fishmonger Cael | Buys/appraises fish | Rival appraiser to the player's Otherworld Palate — friendly competition |
| Shipwright Rin | Builds/upgrades boats | Gates deep-water fishing gear |
| Tailor Momo | Cosmetics/outfits | Non-gameplay-critical but good social/gifting NPC |
| Banker Elric | Loans/currency services | Framing for farm/plot expansion financing |
| Street Chef Kobo | Rival food-cart trader | Low-stakes cooking rival before Vane |
| Dock Kid Sable | Side-quest giver | Kotobuki's version of Little Emi, older and more cynical |
| Bounty Clerk Ivo | Posts Frontier Watch bounties | Bridges Port ↔ Frontier Watch questlines |
| Rare Goods Trader Yansu | Sells rotating rare items | Currency sink, ties to Trade Exchange lore |
| Festival Coordinator Hazel | Runs seasonal festivals | Schedules the cook-off tournaments (Vane's arc) |
| Sailor Quinn | Dock regular | Sea legends, world-building flavor, hints at Legendary Fish locations |
| Customs Officer Bram | Manages port entry | Light gatekeeper/flavor NPC for the Act 1→2 transition |

## Frontier Watch (light combat — Act 2+)

Main cast here: Captain Reido (see LORE_BIBLE.md). Rest of the Watch:

| Name | Role | Hook |
|---|---|---|
| Ranger Foss | Scout, combat basics tutorial | Comic relief, teaches dodge/hit fundamentals |
| Scholar Livia | Bestiary/Blightspawn lore | Academic outsider, provides the "what are Blightspawn" exposition |
| Veteran Hunter Dask | High-tier combat trainer | Gates late-game combat content |
| Medic Sana | Heals/sells recovery items | Also quietly worried Reido pushes the Watch too hard |
| Trapper Nix | Sets snares, tracks Blightspawn | Side-quest chain tracking a specific Blightspawn migration |
| Alchemist Bex | Crafts potions from combat drops | Crafting tie-in between combat drops and usable items |

## Cooking Academy & Festival Circuit (Act 2+)

Main cast here: Chef Hinano, Chef Auguste Vane. Rest of the circuit:

| Name | Role | Hook |
|---|---|---|
| Dean Marchetti | Head of the Cooking Academy | Oversees tournament rules; arbiter of the Hinano/Vane rivalry |
| Student Chef Poppy | Player's cooking-rival apprentice | Peer rival distinct from the adult Hinano/Vane feud |
| Judge Otome | Tournament judge | Strict scoring, ties directly into the rhythm-game quality score |
| Spice Trader Saffra | Sells rare cooking ingredients | Currency sink, gates high-tier recipes |
| Pastry Chef Lumen | Dessert specialist | Optional recipe-line unlock |
| Butcher Rask | Meat/protein ingredient source | Ties Frontier Watch combat drops into cooking |
| Sommelier Vesper | Drinks/festival pairing | Festival-flavor NPC, minor recipe unlocks |
| Festival Bard Lyric | Performs at festivals | Pure flavor/atmosphere, no mechanical gate |

## Traveling & Rare NPCs

| Name | Role | Hook |
|---|---|---|
| The Masked Angler | Rival legendary fisherman | Seasonal appearances at specific depth zones; late-game fishing rival |
| Traveling Merchant Zephyr | Rotating-stock trader | Appears on a rotation, sells otherwise-unavailable items |
| Wandering Monk Kestrel | Traveling lore-dispenser | Drops founding-myth hints across multiple visits |
| The Weaver's Messenger | Fox-spirit that appears at festivals | Subtle recurring tie to the Weaver/Mossom's true nature |
| Retired Hero Baelin | Postgame combat content gate | Unlocks harder Frontier Watch content after the main story |
| The Mystery Farmer | Amnesiac NPC found late in Act 2 | Twist hook — deliberately vague; see 🔲 in LORE_BIBLE.md §6 for how this ties to the founding myth once decided |

## Count check

11 (LORE_BIBLE main cast, including Kaleb) + 10 (Orange Ville) + 12
(Kotobuki Port) + 6 (Frontier Watch) + 8 (Cooking Academy) + 6 (Traveling)
= **53 NPCs**. Comfortably over the 50+ target with room to add without
renumbering (append new rows to whichever section they belong in).
