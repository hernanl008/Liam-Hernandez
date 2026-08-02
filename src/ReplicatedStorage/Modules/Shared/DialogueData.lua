--!strict
-- Data-driven dialogue trees. Source of truth for the actual line-by-line
-- scripts is docs/DIALOGUE_ACT1.md — keep the two in sync when editing.
-- Consumed entirely client-side (DialogueController) since none of this
-- is sensitive state; only the `action` strings on options round-trip to
-- the server (via Remotes.DialogueAction) when a choice has a gameplay
-- consequence (granting the starter farm, unlocking Kaleb's shop, etc).

export type DialogueOption = {
	text: string,
	next: string?, -- nil means end the conversation
	relationshipDelta: number?,
	action: string?,
}

export type AutoRoute = {
	check: string, -- name of a client-side predicate, see DialogueController
	ifTrue: string,
	ifFalse: string,
}

export type DialogueNode = {
	speaker: string,
	text: string,
	options: { DialogueOption }?,
	autoRoute: AutoRoute?,
}

local DialogueData: { [string]: { [string]: DialogueNode } } = {}

-- Entry point per NPC. An NPC instance in the world sets its "NpcId"
-- attribute to one of these keys (e.g. "Kaya"); DialogueController looks
-- up DialogueData.Roots[npcId] for where to start the conversation.
-- Vertical-slice scope only has one entry point per NPC (no "already met
-- them, show a different greeting" branching yet — that's Phase 3).
DialogueData.Roots = {
	Kaya = "kaya_intro_1",
	ElderSouta = "souta_notice_1",
	Ren = "ren_intro_1",
	Hinano = "hinano_intro_1",
	Kaleb = "kaleb_first_1",
}

DialogueData.Kaya = {
	kaya_intro_1 = {
		speaker = "Kaya",
		text = "Hey — hey! Are you alright? You picked a strange place for a nap... can you stand?",
		options = {
			{ text = "...where am I?", next = "kaya_intro_2" },
			{ text = "I'm fine. Really.", next = "kaya_intro_2b", relationshipDelta = -1 },
		},
	},
	kaya_intro_2 = {
		speaker = "Kaya",
		text = "Orange Ville. Well — the edge of it. You're on old man Halric's fallow field, actually, "
			.. "which explains a few things about your landing spot. C'mon, let's get you somewhere that isn't dirt.",
		options = { { text = "Continue", next = "kaya_intro_3" } },
	},
	kaya_intro_2b = {
		speaker = "Kaya",
		text = "...Sure you are. Well, 'fine' people usually don't faceplant in a field. Come on anyway — "
			.. "I'm not leaving you out here.",
		options = { { text = "Continue", next = "kaya_intro_3" } },
	},
	kaya_intro_3 = {
		speaker = "Kaya",
		text = "I'm Kaya. This is my grandfather's village, more or less — he's the elder, so everyone "
			.. "assumes it's mine too. What should I call you?",
		options = { { text = "Continue", next = "kaya_farm_1" } },
	},
	kaya_farm_1 = {
		speaker = "Kaya",
		text = "So — actually, funny timing. This field you landed in? Technically unclaimed. If you're "
			.. "looking for somewhere to stay, and you don't mind work, it's yours. Interested?",
		options = {
			{ text = "I'd like that.", next = "kaya_farm_2", relationshipDelta = 1, action = "GrantStarterFarm" },
			{ text = "Let me think about it.", next = "kaya_farm_1b" },
			{ text = "What's the catch?", next = "kaya_farm_1c" },
		},
	},
	kaya_farm_1b = {
		speaker = "Kaya",
		text = "Take your time. Not like the field's going anywhere. Come find me at the store when you decide.",
		options = nil,
	},
	kaya_farm_1c = {
		speaker = "Kaya",
		text = "Ha — no catch. Grandfather says every hand helps, and this valley's had fewer of those "
			.. "lately. That's it. That's the catch.",
		options = { { text = "Continue", next = "kaya_farm_1" } },
	},
	kaya_farm_2 = {
		speaker = "Kaya",
		text = "Great! Okay — quick basics, since you clearly aren't from around here. You'll want to "
			.. "till a patch, plant, water it, and wait. Want me to walk you through it, or are you the "
			.. "figure-it-out type?",
		options = {
			{ text = "Walk me through it.", next = "kaya_farm_3", action = "StartFarmingTutorial" },
			{ text = "I've got it.", next = "kaya_farm_3b", relationshipDelta = 1 },
		},
	},
	kaya_farm_3 = {
		speaker = "Kaya",
		text = "Smart. Okay — tool's in your hand already, don't ask me how. Till the soil first, that "
			.. "dark patch near the fence. Then plant, then water. It won't grow if you skip the water — "
			.. "trust me, I learned that the hard way.",
		options = nil,
	},
	kaya_farm_3b = {
		speaker = "Kaya",
		text = "Look at you. Fine, I won't hold your hand. Shout if you get stuck — no shame in it, "
			.. "everyone does at first.",
		options = nil,
	},
}

DialogueData.ElderSouta = {
	souta_notice_1 = {
		speaker = "Elder Souta",
		text = "Kaya tells me you're settling in well. May I?",
		options = { { text = "Continue", next = "souta_notice_2" } },
	},
	souta_notice_2 = {
		speaker = "Elder Souta",
		text = "That fish you brought in — or was it the crop — Ren mentioned you knew its worth before "
			.. "you'd even properly looked at it. Most who've fished these waters their whole lives "
			.. "couldn't tell you that.",
		options = {
			{ text = "Is that... unusual?", next = "souta_notice_3" },
			{ text = "I just got lucky.", next = "souta_notice_3b", relationshipDelta = -1 },
		},
	},
	souta_notice_3 = {
		speaker = "Elder Souta",
		text = "Unusual isn't the word I'd use. There's an old story about this valley — older than the "
			.. "village, even. I won't trouble you with all of it tonight. But keep noticing what you "
			.. "notice. I have a feeling it matters more than you think.",
		options = { { text = "Continue", next = nil :: any, action = "FoundingMythIntroduced" } },
	},
	souta_notice_3b = {
		speaker = "Elder Souta",
		text = "Perhaps. Luck has a way of finding the same person twice, though. Come speak with me "
			.. "again sometime — I think we'll have more to discuss than you expect.",
		options = { { text = "Continue", next = nil :: any, action = "FoundingMythIntroduced" } },
	},
}

DialogueData.Ren = {
	ren_intro_1 = {
		speaker = "Ren",
		text = "You must be the one Kaya's been telling everyone about. Farmer by day, apparently. "
			.. "You ever fished before?",
		options = {
			{ text = "Never.", next = "ren_intro_2" },
			{ text = "A little, back where I'm from.", next = "ren_intro_2b", relationshipDelta = 1 },
		},
	},
	ren_intro_2 = {
		speaker = "Ren",
		text = "No shame in that. Grab a rod — there's a spare on the rack. Cast out into the shallows "
			.. "there, past the reeds. Timing your cast matters more than distance, so don't just wing it.",
		options = { { text = "Continue", next = "ren_tutorial_1", action = "StartFishingTutorial" } },
	},
	ren_intro_2b = {
		speaker = "Ren",
		text = "Yeah? Different fish out here, I'd wager, but the basics probably translate. Give the "
			.. "shallows a try, tell me if anything surprises you.",
		options = { { text = "Continue", next = "ren_tutorial_1", action = "StartFishingTutorial" } },
	},
	ren_tutorial_1 = {
		speaker = "Ren",
		text = "Once something bites, don't panic — you'll see it. Hook it quick, then it's a battle of "
			.. "patience. Match the struggle, don't fight it head-on.",
		options = nil,
	},
}

DialogueData.Hinano = {
	hinano_intro_1 = {
		speaker = "Hinano",
		text = "You're the new farmer. Good — bring me something worth cooking sometime. What did you bring today?",
		autoRoute = { check = "HasAnyIngredient", ifTrue = "hinano_tutorial_1", ifFalse = "hinano_intro_1b" },
	},
	hinano_intro_1b = {
		speaker = "Hinano",
		text = "Empty-handed, then. Come back with something from your field or the water and we'll talk.",
		options = nil,
	},
	hinano_tutorial_1 = {
		speaker = "Hinano",
		text = "Alright. Cooking here isn't just tossing things in a pot and hoping — you have to *feel* "
			.. "the dish out. Watch the rhythm, match it. Rush it and you'll undercook. Drag your feet "
			.. "and you'll burn it.",
		options = { { text = "Continue", next = "hinano_tutorial_2", action = "StartCookingTutorial" } },
	},
	hinano_tutorial_2 = {
		speaker = "Hinano",
		text = "Don't worry about ruining the ingredients — even a clumsy first attempt still makes "
			.. "*something*. You just won't be proud of it. Go on, try it.",
		options = nil,
	},
}

DialogueData.Kaleb = {
	kaleb_first_1 = {
		speaker = "Kaleb",
		text = "Didn't peg you as the farming type. Then again, didn't peg you as anything, seeing as "
			.. "nobody around here's got the first clue who you are.",
		options = {
			{ text = "Who are you?", next = "kaleb_first_2" },
			{ text = "...How long have you been standing there?", next = "kaleb_first_2b", relationshipDelta = 1 },
		},
	},
	kaleb_first_2 = {
		speaker = "Kaleb",
		text = "Nobody, officially. Unofficially, I've got things. Things you won't find at the port, "
			.. "and definitely not from the Exchange — that lot likes paperwork. I don't.",
		options = { { text = "Continue", next = "kaleb_first_3" } },
	},
	kaleb_first_2b = {
		speaker = "Kaleb",
		text = "Long enough. You're jumpier than most — I like that, actually. Means you're paying attention.",
		options = { { text = "Continue", next = "kaleb_first_3" } },
	},
	kaleb_first_3 = {
		speaker = "Kaleb",
		text = "Anyway. I'll be around — my own schedule, not yours. Got junk, got treasure, got the "
			.. "occasional thing that shouldn't exist yet. Don't ask where it comes from. I won't tell "
			.. "you, and you'll enjoy it more not knowing.",
		options = {
			{ text = "Fair enough.", next = "kaleb_first_4", relationshipDelta = 1 },
			{ text = "That's not ominous at all.", next = "kaleb_first_4b" },
		},
	},
	kaleb_first_4 = {
		speaker = "Kaleb",
		text = "Smart. See you around, farmer.",
		options = { { text = "Continue", next = nil :: any, action = "UnlockKalebShop" } },
	},
	kaleb_first_4b = {
		speaker = "Kaleb",
		text = "Wasn't trying to be. Or — maybe a little. See you around, farmer.",
		options = { { text = "Continue", next = nil :: any, action = "UnlockKalebShop" } },
	},
}

return DialogueData
