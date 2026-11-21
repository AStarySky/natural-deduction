extends RefCounted

## Built-in chapter curriculum. Each chapter introduces one or two rules and
## contains six core levels plus one optional challenge. Rules are cumulative:
## chapter_rules() returns the palette cards available in that chapter.

const CHAPTERS := [
	{
		"id": "ch1",
		"title": "First Moves",
		"subtitle": "MODUS PONENS - CONJUNCTION",
		"blurb": "Learn to take a proof apart and put it back together.",
		"color": Color8(166, 211, 225),
		"rules": ["impl_elim", "and_elim_left", "and_intro", "double_neg_elim"],
		"allow_assumptions": false,
		"levels": [
			{
				"id": "ch1-1",
				"title": "First Drag",
				"subtitle": "MODUS PONENS",
				"premises": ["P", "P -> Q"],
				"goal": "Q",
				"teaches": "impl_elim",
				"optional": false,
			},
			{
				"id": "ch1-2",
				"title": "Double Trouble",
				"subtitle": "DOUBLE NEGATION",
				"premises": ["~~P"],
				"goal": "P",
				"teaches": "double_neg_elim",
				"optional": false,
			},
			{
				"id": "ch1-3",
				"title": "Take It Apart",
				"subtitle": "CONJUNCTION ELIM",
				"premises": ["P & Q"],
				"goal": "P",
				"teaches": "and_elim_left",
				"optional": false,
			},
			{
				"id": "ch1-4",
				"title": "Take the Other Half",
				"subtitle": "CONJUNCTION ELIM",
				"premises": ["P & Q"],
				"goal": "Q",
				"teaches": "and_elim_right",
				"optional": false,
			},
			{
				"id": "ch1-5",
				"title": "Put It Together",
				"subtitle": "CONJUNCTION INTRO",
				"premises": ["P", "Q"],
				"goal": "P & Q",
				"teaches": "and_intro",
				"optional": false,
			},
			{
				"id": "ch1-6",
				"title": "Chain Reaction",
				"subtitle": "MODUS PONENS",
				"premises": ["P", "P -> Q", "Q -> R"],
				"goal": "R",
				"teaches": "impl_elim",
				"optional": false,
			},
			{
				"id": "ch1-star",
				"title": "Conjunction Swap",
				"subtitle": "CHALLENGE",
				"premises": ["P & Q"],
				"goal": "Q & P",
				"teaches": "and_intro",
				"optional": true,
			},
			{
				"id": "ch1-star2",
				"title": "Rearranged Trio",
				"subtitle": "CONJUNCTION REASSEMBLY",
				"premises": ["Q & P", "R"],
				"goal": "P & (R & Q)",
				"teaches": "and_intro",
				"optional": true,
			},
			{
				"id": "ch1-star3",
				"title": "Deep Reassembly",
				"subtitle": "CONJUNCTION REASSEMBLY",
				"premises": ["P & (Q & R)"],
				"goal": "(R & P) & Q",
				"teaches": "and_elim_right",
				"optional": true,
			},
		],
	},
	{
		"id": "ch2",
		"title": "Suppose...",
		"subtitle": "IMPLICATION INTRO",
		"blurb": "Open an assumption window, prove the conclusion, then close it.",
		"color": Color8(199, 166, 216),
		"rules": ["impl_elim", "and_elim_left", "and_intro", "double_neg_elim"],
		"allow_assumptions": true,
		"levels": [
			{
				"id": "ch2-1",
				"title": "Just Suppose",
				"subtitle": "IDENTITY",
				"premises": [],
				"goal": "P -> P",
				"teaches": "impl_intro",
				"optional": false,
			},
			{
				"id": "ch2-2",
				"title": "Vacuous",
				"subtitle": "VACUOUS DISCHARGE",
				"premises": ["Q"],
				"goal": "P -> Q",
				"teaches": "impl_intro",
				"optional": false,
			},
			{
				"id": "ch2-3",
				"title": "Chain the Arrow",
				"subtitle": "IMPLICATION",
				"premises": ["P -> Q", "Q -> R"],
				"goal": "P -> R",
				"teaches": "impl_intro",
				"optional": false,
			},
			{
				"id": "ch2-4",
				"title": "Nested Boxes",
				"subtitle": "IMPLICATION",
				"premises": ["P -> (Q -> R)"],
				"goal": "Q -> (P -> R)",
				"teaches": "impl_intro",
				"optional": false,
			},
			{
				"id": "ch2-5",
				"title": "Shared Hypothesis",
				"subtitle": "IMPLICATION",
				"premises": ["P -> (Q -> R)", "P -> Q"],
				"goal": "P -> R",
				"teaches": "impl_intro",
				"optional": false,
			},
			{
				"id": "ch2-6",
				"title": "Import / Export",
				"subtitle": "IMPLICATION",
				"premises": ["(P & Q) -> R"],
				"goal": "P -> (Q -> R)",
				"teaches": "impl_intro",
				"optional": false,
			},
			{
				"id": "ch2-star",
				"title": "Long Arrow",
				"subtitle": "CHALLENGE",
				"premises": ["P -> Q", "Q -> R", "R -> S"],
				"goal": "P -> S",
				"teaches": "impl_intro",
				"optional": true,
			},
			{
				"id": "ch2-star2",
				"title": "Two Conclusions",
				"subtitle": "IMPLICATION + CONJUNCTION",
				"premises": ["(P -> Q) & (P -> R)"],
				"goal": "P -> (Q & R)",
				"teaches": "and_intro",
				"optional": true,
			},
			{
				"id": "ch2-star3",
				"title": "Split the Conclusion",
				"subtitle": "IMPLICATION + CONJUNCTION",
				"premises": ["P -> (Q & R)"],
				"goal": "(P -> Q) & (P -> R)",
				"teaches": "and_intro",
				"optional": true,
			},
		],
	},
	{
		"id": "ch3",
		"title": "Either Way",
		"subtitle": "DISJUNCTION",
		"blurb": "Prove one side of an OR, or split into cases when you are given one.",
		"color": Color8(143, 227, 200),
		"rules": [
			"impl_elim",
			"and_elim_left",
			"and_intro",
			"double_neg_elim",
			"or_intro_left",
			"or_elim_impl",
		],
		"allow_assumptions": true,
		"levels": [
			{
				"id": "ch3-1",
				"title": "Left Choice",
				"subtitle": "DISJUNCTION INTRO",
				"premises": ["P"],
				"goal": "P | Q",
				"teaches": "or_intro_left",
				"optional": false,
			},
			{
				"id": "ch3-2",
				"title": "Right Choice",
				"subtitle": "DISJUNCTION INTRO",
				"premises": ["Q"],
				"goal": "P | Q",
				"teaches": "or_intro_right",
				"optional": false,
			},
			{
				"id": "ch3-3",
				"title": "Direct Cases",
				"subtitle": "DISJUNCTION ELIM",
				"premises": ["P | Q", "P -> R", "Q -> R"],
				"goal": "R",
				"teaches": "or_elim_impl",
				"optional": false,
			},
			{
				"id": "ch3-4",
				"title": "Swap the Cases",
				"subtitle": "DISJUNCTION",
				"premises": ["P | Q"],
				"goal": "Q | P",
				"teaches": "or_elim_impl",
				"optional": false,
			},
			{
				"id": "ch3-5",
				"title": "Case Work",
				"subtitle": "DISJUNCTION + IMPLICATION",
				"premises": ["P | Q"],
				"goal": "(P -> Q) -> Q",
				"teaches": "or_elim_impl",
				"optional": false,
			},
			{
				"id": "ch3-6",
				"title": "Distribution",
				"subtitle": "DISJUNCTION + CONJUNCTION",
				"premises": ["P & (Q | R)"],
				"goal": "(P & Q) | (P & R)",
				"teaches": "or_elim_impl",
				"optional": false,
			},
			{
				"id": "ch3-star",
				"title": "Associativity",
				"subtitle": "CHALLENGE",
				"premises": ["P | (Q | R)"],
				"goal": "(P | Q) | R",
				"teaches": "or_elim_impl",
				"optional": true,
			},
			{
				"id": "ch3-star2",
				"title": "Factor the Or",
				"subtitle": "DISTRIBUTION",
				"premises": ["(P | Q) & (P | R)"],
				"goal": "P | (Q & R)",
				"teaches": "or_elim_impl",
				"optional": true,
			},
			{
				"id": "ch3-star3",
				"title": "Merge the Or",
				"subtitle": "DISTRIBUTION",
				"premises": ["(P & Q) | (P & R)"],
				"goal": "P & (Q | R)",
				"teaches": "or_elim_impl",
				"optional": true,
			},
		],
	},
	{
		"id": "ch4",
		"title": "Both Ways",
		"subtitle": "BICONDITIONAL",
		"blurb": "An if-and-only-if is two implications that point in opposite directions.",
		"color": Color8(255, 212, 94),
		"rules": [
			"impl_elim",
			"and_elim_left",
			"and_intro",
			"double_neg_elim",
			"or_intro_left",
			"or_elim_impl",
			"iff_elim",
			"iff_intro_impl",
		],
		"allow_assumptions": true,
		"levels": [
			{
				"id": "ch4-1",
				"title": "Either Direction",
				"subtitle": "BICONDITIONAL ELIM",
				"premises": ["P", "P <-> Q"],
				"goal": "Q",
				"teaches": "iff_elim",
				"optional": false,
			},
			{
				"id": "ch4-2",
				"title": "Two Implications",
				"subtitle": "BICONDITIONAL INTRO",
				"premises": ["P -> Q", "Q -> P"],
				"goal": "P <-> Q",
				"teaches": "iff_intro_impl",
				"optional": false,
			},
			{
				"id": "ch4-3",
				"title": "Symmetry",
				"subtitle": "BICONDITIONAL",
				"premises": ["P <-> Q"],
				"goal": "Q <-> P",
				"teaches": "iff_intro_impl",
				"optional": false,
			},
			{
				"id": "ch4-4",
				"title": "Bridge",
				"subtitle": "BICONDITIONAL + DISJUNCTION",
				"premises": ["(P | Q) <-> Q"],
				"goal": "P -> Q",
				"teaches": "iff_elim",
				"optional": false,
			},
			{
				"id": "ch4-5",
				"title": "Transitivity",
				"subtitle": "BICONDITIONAL",
				"premises": ["P <-> Q", "Q <-> R"],
				"goal": "P <-> R",
				"teaches": "iff_intro_impl",
				"optional": false,
			},
			{
				"id": "ch4-6",
				"title": "Biconditional Chain",
				"subtitle": "BICONDITIONAL",
				"premises": ["P <-> Q", "Q <-> R", "R <-> S"],
				"goal": "P <-> S",
				"teaches": "iff_intro_impl",
				"optional": false,
			},
			{
				"id": "ch4-star",
				"title": "Substitution",
				"subtitle": "CHALLENGE",
				"premises": ["P <-> Q"],
				"goal": "(P & R) <-> (Q & R)",
				"teaches": "iff_intro_impl",
				"optional": true,
			},
			{
				"id": "ch4-star2",
				"title": "Biconditional Detour",
				"subtitle": "BICONDITIONAL + IMPLICATION",
				"premises": [],
				"goal": "((P -> Q) <-> P) -> (P <-> Q)",
				"teaches": "iff_intro_impl",
				"optional": true,
			},
			{
				"id": "ch4-star3",
				"title": "Nested Biconditional",
				"subtitle": "BICONDITIONAL + DISJUNCTION",
				"premises": ["((P | Q) <-> Q) <-> P"],
				"goal": "P <-> Q",
				"teaches": "iff_intro_impl",
				"optional": true,
			},
		],
	},
	{
		"id": "ch5",
		"title": "Contradiction",
		"subtitle": "NEGATION",
		"blurb": "Prove a negation by deriving two incompatible conclusions.",
		"color": Color8(231, 154, 168),
		"rules": [
			"impl_elim",
			"and_elim_left",
			"and_intro",
			"double_neg_elim",
			"or_intro_left",
			"or_elim_impl",
			"iff_elim",
			"iff_intro_impl",
			"not_intro_impl",
		],
		"allow_assumptions": true,
		"levels": [
			{
				"id": "ch5-1",
				"title": "Contradiction Intro",
				"subtitle": "NEGATION INTRO",
				"premises": ["P -> Q", "P -> ~Q"],
				"goal": "~P",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch5-2",
				"title": "Modus Tollens",
				"subtitle": "NEGATION",
				"premises": ["P -> Q", "~Q"],
				"goal": "~P",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch5-3",
				"title": "Not Both",
				"subtitle": "NEGATION",
				"premises": ["~P"],
				"goal": "~(P & Q)",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch5-4",
				"title": "Neither",
				"subtitle": "NEGATION",
				"premises": ["~(P | Q)"],
				"goal": "~P & ~Q",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch5-5",
				"title": "Negation Elimination",
				"subtitle": "NEGATION",
				"premises": ["~P -> Q", "~P -> ~Q"],
				"goal": "P",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch5-6",
				"title": "Contraposition",
				"subtitle": "NEGATION + IMPLICATION",
				"premises": ["P -> Q"],
				"goal": "~Q -> ~P",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch5-star",
				"title": "Classical Trick",
				"subtitle": "CHALLENGE",
				"premises": ["~P -> P"],
				"goal": "P",
				"teaches": "double_neg_elim",
				"optional": true,
			},
			{
				"id": "ch5-star2",
				"title": "De Morgan, One Way",
				"subtitle": "NEGATION + DISJUNCTION",
				"premises": ["~P | ~Q"],
				"goal": "~(P & Q)",
				"teaches": "not_intro_impl",
				"optional": true,
			},
			{
				"id": "ch5-star3",
				"title": "Double Negation Rescue",
				"subtitle": "NEGATION + DISJUNCTION",
				"premises": ["~(~P | ~Q)"],
				"goal": "P & Q",
				"teaches": "double_neg_elim",
				"optional": true,
			},
		],
	},
	{
		"id": "ch6",
		"title": "Synthesis",
		"subtitle": "MIXED PROOFS",
		"blurb": "Combine every rule in longer mixed proofs before the classical finale.",
		"color": Color8(246, 179, 124),
		"rules": [
			"impl_elim",
			"and_elim_left",
			"and_intro",
			"or_intro_left",
			"or_elim_impl",
			"iff_intro_impl",
			"iff_elim",
			"not_intro_impl",
			"double_neg_elim",
		],
		"allow_assumptions": true,
		"levels": [
			{
				"id": "ch6-1",
				"title": "Double Wrap",
				"subtitle": "DOUBLE NEGATION BY CONTRADICTION",
				"premises": ["P"],
				"goal": "~~P",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch6-2",
				"title": "Contrapositive Chain",
				"subtitle": "NEGATION + IMPLICATION",
				"premises": ["P -> Q", "Q -> R"],
				"goal": "~R -> ~P",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch6-3",
				"title": "Cases and Conjunction",
				"subtitle": "MIXED",
				"premises": ["(P | Q) & (P -> R) & (Q -> R)"],
				"goal": "R",
				"teaches": "or_elim_impl",
				"optional": false,
			},
			{
				"id": "ch6-4",
				"title": "Substitution",
				"subtitle": "MIXED",
				"premises": ["P <-> Q"],
				"goal": "(P & R) <-> (Q & R)",
				"teaches": "iff_intro_impl",
				"optional": false,
			},
			{
				"id": "ch6-5",
				"title": "Two Cases",
				"subtitle": "MIXED",
				"premises": ["(P | Q) & (P -> R) & (Q -> S)"],
				"goal": "R | S",
				"teaches": "or_elim_impl",
				"optional": false,
			},
			{
				"id": "ch6-6",
				"title": "Nested Biconditional",
				"subtitle": "MIXED",
				"premises": ["P", "(P <-> Q) <-> R"],
				"goal": "Q <-> R",
				"teaches": "iff_intro_impl",
				"optional": false,
			},
			{
				"id": "ch6-star",
				"title": "Disjunctive Syllogism",
				"subtitle": "CHALLENGE",
				"premises": ["P | Q", "~P"],
				"goal": "Q",
				"teaches": "or_elim_impl",
				"optional": true,
			},
			{
				"id": "ch6-star2",
				"title": "Biconditional Negation",
				"subtitle": "BICONDITIONAL + CONTRADICTION",
				"premises": ["P <-> ~~Q"],
				"goal": "P <-> Q",
				"teaches": "not_intro_impl",
				"optional": true,
			},
			{
				"id": "ch6-star3",
				"title": "Peirce's Shadow",
				"subtitle": "CLASSICAL NEGATION",
				"premises": ["(P -> Q) -> Q"],
				"goal": "~Q -> P",
				"teaches": "not_intro_impl",
				"optional": true,
			},
		],
	},

	{
		"id": "ch7",
		"title": "Grand Finale",
		"subtitle": "CLASSICAL MASTERY",
		"blurb": "Indirect arguments, Peirce's law, and De Morgan: the hardest propositional proofs in the pack.",
		"color": Color8(186, 160, 232),
		"rules": [
			"impl_elim",
			"and_elim_left",
			"and_intro",
			"or_intro_left",
			"or_elim_impl",
			"iff_intro_impl",
			"iff_elim",
			"not_intro_impl",
			"double_neg_elim",
		],
		"allow_assumptions": true,
		"levels": [

			{
				"id": "ch7-1",
				"title": "Conjunction Detour",
				"subtitle": "IMPLICATION + CONJUNCTION",
				"premises": [],
				"goal": "(P & Q) -> ((P -> Q) -> P)",
				"teaches": "impl_intro",
				"optional": false,
			},
			{
				"id": "ch7-2",
				"title": "Negated Arrow",
				"subtitle": "CLASSICAL NEGATION",
				"premises": ["~(P -> Q)"],
				"goal": "P",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch7-3",
				"title": "Peirce's Law",
				"subtitle": "CLASSICAL NEGATION",
				"premises": ["(P -> Q) -> P"],
				"goal": "P",
				"teaches": "double_neg_elim",
				"optional": false,
			},
			{
				"id": "ch7-4",
				"title": "Arrow or Arrow",
				"subtitle": "CLASSICAL DISJUNCTION",
				"premises": [],
				"goal": "(P -> Q) | (Q -> R)",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch7-5",
				"title": "The Long Case",
				"subtitle": "MIXED CLASSICAL",
				"premises": ["~P -> Q", "R | ~Q", "P -> (Q1 | Q2)", "~R & ~Q2"],
				"goal": "Q1",
				"teaches": "or_elim_impl",
				"optional": false,
			},
			{
				"id": "ch7-6",
				"title": "Disjunction from Cases",
				"subtitle": "CLASSICAL DISTRIBUTION",
				"premises": ["P -> (Q | R)"],
				"goal": "(P -> Q) | (P -> R)",
				"teaches": "not_intro_impl",
				"optional": false,
			},
			{
				"id": "ch7-star",
				"title": "De Morgan's Theorem",
				"subtitle": "GRAND CHALLENGE",
				"premises": [],
				"goal": "~(P & Q) <-> (~P | ~Q)",
				"teaches": "iff_intro_impl",
				"optional": true,
			},
		],
	},
]


## Flatten chapters into level dictionaries with chapter metadata attached.
static func all_levels() -> Array:
	var levels: Array = []
	for chapter_index in range(CHAPTERS.size()):
		var chapter: Dictionary = CHAPTERS[chapter_index]
		var chapter_levels: Array = chapter.get("levels", [])
		for level_index in range(chapter_levels.size()):
			var level: Dictionary = chapter_levels[level_index].duplicate()
			level["chapter_id"] = str(chapter.get("id", ""))
			level["chapter_index"] = chapter_index
			level["index_in_chapter"] = level_index
			level["optional"] = bool(level.get("optional", false))
			levels.append(level)
	return levels


## Find one level by stable id and attach its chapter metadata.
static func find_level(level_id: String) -> Dictionary:
	for level in all_levels():
		if str(level.get("id", "")) == level_id:
			return level
	return {}


## Find a chapter dictionary by id.
static func find_chapter(chapter_id: String) -> Dictionary:
	for chapter in CHAPTERS:
		if str(chapter.get("id", "")) == chapter_id:
			return chapter
	return {}


## Chapter position, or -1 when the id is unknown.
static func chapter_index(chapter_id: String) -> int:
	for index in range(CHAPTERS.size()):
		if str(CHAPTERS[index].get("id", "")) == chapter_id:
			return index
	return -1


## Palette cards available in a chapter (representative ids).
static func chapter_rules(chapter_id: String) -> Array[String]:
	var result: Array[String] = []
	var chapter := find_chapter(chapter_id)
	for rule_id in chapter.get("rules", []):
		result.append(str(rule_id))
	return result


## Whether the chapter has unlocked the ASSUME window.
static func allow_assumptions(chapter_id: String) -> bool:
	return bool(find_chapter(chapter_id).get("allow_assumptions", false))


## Rules newly introduced by this chapter, including ASSUME for chapter 2.
static func chapter_new_rules(chapter_id: String) -> Array[String]:
	var index := chapter_index(chapter_id)
	if index < 0:
		return []
	var current := chapter_rules(chapter_id)
	var result: Array[String] = []
	if index == 0:
		for rule_id in current:
			result.append(rule_id)
	else:
		var previous: Dictionary = CHAPTERS[index - 1]
		var previous_id := str(previous.get("id", ""))
		var previous_rules := chapter_rules(previous_id)
		for rule_id in current:
			if not previous_rules.has(rule_id):
				result.append(rule_id)
		if allow_assumptions(chapter_id) and not allow_assumptions(previous_id):
			result.append("impl_intro")
	return result


## Core or challenge levels in a chapter, with metadata attached.
static func chapter_levels(chapter_id: String, optional_only: bool = false) -> Array:
	var result: Array = []
	for level in all_levels():
		if str(level.get("chapter_id", "")) != chapter_id:
			continue
		if bool(level.get("optional", false)) != optional_only:
			continue
		result.append(level)
	return result


## Rule ids a level may use, including side-switch variants and scope rules.
## Used by the curriculum validator to keep solutions inside the taught set.
static func unlocked_rule_ids(level_id: String) -> Array[String]:
	var level := find_level(level_id)
	if level.is_empty():
		return []
	var chapter_id := str(level.get("chapter_id", ""))
	var chapter := find_chapter(chapter_id)
	var result: Array[String] = []
	for rule_id in chapter.get("rules", []):
		var name := str(rule_id)
		if not result.has(name):
			result.append(name)
		match name:
			"and_elim_left":
				if not result.has("and_elim_right"):
					result.append("and_elim_right")
			"and_elim_right":
				if not result.has("and_elim_left"):
					result.append("and_elim_left")
			"or_intro_left":
				if not result.has("or_intro_right"):
					result.append("or_intro_right")
			"or_intro_right":
				if not result.has("or_intro_left"):
					result.append("or_intro_left")
			"double_neg_elim":
				pass
	if bool(chapter.get("allow_assumptions", false)) and not result.has("impl_intro"):
		result.append("impl_intro")
	return result
