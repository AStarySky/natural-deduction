extends RefCounted

## Human-readable names and one-line semantics for icon-only rule blocks.

static func title(rule_id: String) -> String:
	match rule_id:
		"impl_elim":
			return "Implication elimination"
		"impl_intro":
			return "Implication introduction"
		"and_intro":
			return "Conjunction introduction"
		"and_elim_left", "and_elim_right":
			return "Conjunction elimination (L/R)"
		"or_intro_left", "or_intro_right":
			return "Disjunction introduction (L/R)"
		"ds":
			return "Disjunctive syllogism"
		"or_elim":
			return "Disjunction elimination"
		"or_elim_impl":
			return "Disjunction elimination"
		"iff_intro":
			return "Biconditional introduction"
		"iff_intro_impl":
			return "Biconditional introduction"
		"iff_elim":
			return "Biconditional elimination"
		"not_intro":
			return "Negation introduction"
		"not_intro_impl":
			return "Negation introduction"
		"not_elim":
			return "Negation elimination"
		"not_elim_impl":
			return "Negation elimination"
		"lem":
			return "Law of excluded middle"
		"double_neg_elim":
			return "Double negation elimination"
		"double_neg_intro":
			return "Double negation introduction"
	return rule_id

static func description(rule_id: String) -> String:
	match rule_id:
		"impl_elim":
			return "A and A -> B give B."
		"impl_intro":
			return "Assume A and prove B; discharge A to get A -> B."
		"and_intro":
			return "A and B give A & B."
		"and_elim_left", "and_elim_right":
			return "A & B: switch L/R to take the left or right conjunct."
		"or_intro_left", "or_intro_right":
			return "Prove one side and fill the other-side socket; switch L/R to mirror it."
		"ds":
			return "A | B with ~A gives B; with ~B it gives A."
		"or_elim":
			return "A | B with a proof C under A and under B gives C."
		"or_elim_impl":
			return "A | B with A -> C and B -> C gives C."
		"iff_intro":
			return "A proof B under A and A under B gives A <-> B."
		"iff_intro_impl":
			return "A -> B and B -> A give A <-> B."
		"iff_elim":
			return "A and A <-> B give B; either input order."
		"not_intro":
			return "A proof of a contradiction under A gives ~A."
		"not_intro_impl":
			return "A -> B and A -> ~B give ~A."
		"not_elim":
			return "A proof of a contradiction under ~A gives A."
		"not_elim_impl":
			return "~A -> B and ~A -> ~B give A."
		"lem":
			return "Fill the external other-side slot with any formula P; this gives P | ~P."
		"double_neg_elim":
			return "~~A gives A. Double-negation introduction is derived with a contradiction, not a direct card."
		"double_neg_intro":
			return "A gives ~~A; available to internal/CLI proofs only."
	return ""

static func tooltip(rule_id: String) -> String:
	var text := title(rule_id)
	var detail := description(rule_id)
	if detail.is_empty():
		return text
	return text + "\n" + detail
