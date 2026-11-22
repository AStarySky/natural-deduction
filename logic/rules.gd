extends RefCounted

## Registry and stateless semantics for the first-version rule set.
## Exactly one introduction/elimination pair per connective plus modus ponens
## and double-negation elimination. Assumptions and subproof rules are not
## implemented in this milestone.

const FormulaRes = preload("res://logic/formula.gd")
const RuleDerivationRes = preload("res://logic/rule_derivation.gd")

const RULE_ORDER := [
	"impl_elim",
	"and_elim_left",
	"and_elim_right",
	"and_intro",
	"or_intro_left",
	"or_intro_right",
	"or_elim",
	"ds",
	"iff_intro",
	"iff_elim",
	"not_intro",
	"not_elim",
	"or_elim_impl",
	"iff_intro_impl",
	"not_intro_impl",
	"not_elim_impl",
	"lem",
	"double_neg_elim",
	"double_neg_intro",
]

const RULES := {
	"impl_elim": {"arity": 2, "extra": false},
	"impl_intro": {
		"arity": 1,
		"extra": false,
		"scoped": true,
		"proofs": 1,
		"assumptions": 1,
	},
	"and_elim_left": {"arity": 1, "extra": false},
	"and_elim_right": {"arity": 1, "extra": false},
	"and_intro": {"arity": 2, "extra": false},
	"or_intro_left": {"arity": 1, "extra": true},
	"or_intro_right": {"arity": 1, "extra": true},
	"or_elim": {
		"arity": 3,
		"extra": false,
		"scoped": true,
		"proofs": 3,
		"assumptions": 2,
	},
	"ds": {"arity": 2, "extra": false},
	"iff_intro": {
		"arity": 2,
		"extra": false,
		"scoped": true,
		"proofs": 2,
		"assumptions": 2,
	},
	"iff_elim": {"arity": 2, "extra": false},
	"not_intro": {
		"arity": 2,
		"extra": false,
		"scoped": true,
		"proofs": 2,
		"assumptions": 1,
	},
	"not_elim": {
		"arity": 2,
		"extra": false,
		"scoped": true,
		"proofs": 2,
		"assumptions": 1,
	},
	"or_elim_impl": {"arity": 3, "extra": false},
	"iff_intro_impl": {"arity": 2, "extra": false},
	"not_intro_impl": {"arity": 2, "extra": false},
	"not_elim_impl": {"arity": 2, "extra": false},
	"lem": {"arity": 0, "extra": true},
	"double_neg_elim": {"arity": 1, "extra": false},
	"double_neg_intro": {"arity": 1, "extra": false},
}

## UI palette entries. The left variants stand in for their L/R pairs; the
## rule block's side switch selects the concrete rule at runtime.
## Scoped rules are added to the UI after the scope interface is in place.
## Player-facing rules only. DS and LEM remain in the core for CLI/legacy
## proofs, but are shortcuts derivable from the cards below.
const PALETTE_ORDER := [
	"impl_elim",
	"and_elim_left",
	"and_intro",
	"or_intro_left",
	"or_elim_impl",
	"iff_intro_impl",
	"iff_elim",
	"not_intro_impl",
	"double_neg_elim",
]

## CLI argument order for scoped rules: each entry is "proof" or "assumption".
const SCOPED_CLI_LAYOUT := {
	"impl_intro": ["assumption", "proof"],
	"or_elim": ["proof", "assumption", "proof", "assumption", "proof"],
	"iff_intro": ["assumption", "proof", "assumption", "proof"],
	"not_intro": ["assumption", "proof", "proof"],
	"not_elim": ["assumption", "proof", "proof"],
}

## All rule ids in stable display order.
static func rule_ids() -> Array[String]:
	var ids: Array[String] = []
	for rule_id in RULE_ORDER:
		ids.append(str(rule_id))
	return ids

## Compact rule list used by the in-game palette.
static func palette_ids() -> Array[String]:
	var ids: Array[String] = []
	for rule_id in PALETTE_ORDER:
		ids.append(str(rule_id))
	return ids

## Whether a rule needs assumption scopes and proof branches.
static func is_scoped(rule_id: String) -> bool:
	if not RULES.has(rule_id):
		return false
	return bool(RULES[rule_id].get("scoped", false))

static func proof_count(rule_id: String) -> int:
	if not RULES.has(rule_id):
		return 0
	return int(RULES[rule_id].get("proofs", 0))

static func assumption_count(rule_id: String) -> int:
	if not RULES.has(rule_id):
		return 0
	return int(RULES[rule_id].get("assumptions", 0))

static func scoped_cli_layout(rule_id: String) -> Array:
	if SCOPED_CLI_LAYOUT.has(rule_id):
		return SCOPED_CLI_LAYOUT[rule_id].duplicate()
	return []

## Comma-separated list of supported rules, for help and error messages.
static func rule_names_text() -> String:
	var text := ""
	for rule_id in RULE_ORDER:
		if text != "":
			text += ", "
		text += str(rule_id)
	return text

## Number of premise slots for a rule; -1 when the rule is unknown.
static func arity(rule_id: String) -> int:
	if not RULES.has(rule_id):
		return -1
	return int(RULES[rule_id]["arity"])

## Whether a rule requires an explicitly supplied extra formula.
static func takes_extra(rule_id: String) -> bool:
	if not RULES.has(rule_id):
		return false
	return bool(RULES[rule_id]["extra"])

## Apply one rule to already-parsed premise formulas.
##
## Returns a RuleDerivation whose premise_order lists supplied premise indices
## in canonical rule-slot order. No nodes are created here.
static func derive(rule_id: String, premises: Array, extra_formula = null) -> RuleDerivationRes:
	if not RULES.has(rule_id):
		return _failure(
			"unknown rule '%s'; available rules: %s" % [rule_id, rule_names_text()]
		)
	if is_scoped(rule_id):
		return _failure(
			"%s is a scoped rule and needs assumption ids; use the scoped proof application"
			% rule_id
		)

	var expected_arity := arity(rule_id)
	if premises.size() != expected_arity:
		return _failure(
			"%s expects %d premise id(s), got %d" % [rule_id, expected_arity, premises.size()]
		)

	if takes_extra(rule_id):
		if extra_formula == null:
			return _failure(
				"%s: missing extra formula (the other side of the disjunction); usage: apply %s <id> <formula>"
				% [rule_id, rule_id]
			)
	else:
		if extra_formula != null:
			return _failure(
				"%s does not take an extra formula; got '%s'"
				% [rule_id, extra_formula.to_string()]
			)

	match rule_id:
		"impl_elim":
			return _impl_elim(premises[0], premises[1])
		"and_elim_left":
			return _and_elim_left(premises[0])
		"and_elim_right":
			return _and_elim_right(premises[0])
		"and_intro":
			return _success(
				FormulaRes.new(FormulaRes.Kind.AND, "", premises[0], premises[1]),
				[0, 1]
			)
		"or_intro_left":
			return _success(
				FormulaRes.new(FormulaRes.Kind.OR, "", premises[0], extra_formula),
				[0]
			)
		"or_intro_right":
			return _success(
				FormulaRes.new(FormulaRes.Kind.OR, "", extra_formula, premises[0]),
				[0]
			)
		"ds":
			return _disjunctive_syllogism(premises[0], premises[1])
		"or_elim_impl":
			return _or_elim_impl(premises)
		"iff_intro_impl":
			return _iff_intro_impl(premises[0], premises[1])
		"not_intro_impl":
			return _not_intro_impl(premises[0], premises[1])
		"not_elim_impl":
			return _not_elim_impl(premises[0], premises[1])
		"iff_elim":
			return _iff_elim(premises[0], premises[1])
		"lem":
			return _excluded_middle(extra_formula)
		"double_neg_elim":
			return _double_neg_elim(premises[0])
		"double_neg_intro":
			return _double_neg_intro(premises[0])

	return _failure("rule '%s' is registered but has no implementation" % rule_id)

## Modus ponens: A, A -> B |- B (either input order).
static func _impl_elim(first: FormulaRes, second: FormulaRes) -> RuleDerivationRes:
	# Given order: first is the implication, second its antecedent.
	if first.kind == FormulaRes.Kind.IMPLIES and first.left.equals(second):
		return _success(first.right, [1, 0])
	# Swapped order: second is the implication, first its antecedent.
	if second.kind == FormulaRes.Kind.IMPLIES and second.left.equals(first):
		return _success(second.right, [0, 1])
	return _failure(
		"impl_elim: no matching implication found; expected a premise of form 'A -> ?' or '? -> ?' whose antecedent equals the other premise (either order); got '%s' and '%s'"
		% [first.to_string(), second.to_string()]
	)

## Left conjunction elimination: A & B |- A.
static func _and_elim_left(premise: FormulaRes) -> RuleDerivationRes:
	if premise.kind != FormulaRes.Kind.AND:
		return _failure(
			"and_elim_left: expected a conjunction 'A & B', got '%s'" % premise.to_string()
		)
	return _success(premise.left, [0])

## Right conjunction elimination: A & B |- B.
static func _and_elim_right(premise: FormulaRes) -> RuleDerivationRes:
	if premise.kind != FormulaRes.Kind.AND:
		return _failure(
			"and_elim_right: expected a conjunction 'A & B', got '%s'" % premise.to_string()
		)
	return _success(premise.right, [0])

## Derived ∨E: A | B, A -> C, B -> C |- C.
static func _or_elim_impl(premises: Array) -> RuleDerivationRes:
	if premises.size() != 3:
		return _failure("or_elim_impl: expected a disjunction and two implications")
	var disjunction = null
	var implications: Array = []
	for premise in premises:
		if premise.kind == FormulaRes.Kind.OR and disjunction == null:
			disjunction = premise
		elif premise.kind == FormulaRes.Kind.IMPLIES:
			implications.append(premise)
	if disjunction == null or implications.size() != 2:
		return _failure(
			"or_elim_impl: expected one disjunction and two implications; got %s"
			% _formulas_text(premises)
		)
	var left_impl = null
	var right_impl = null
	# Fill each side at most once. When both disjuncts are equal (A | A), the
	# second implication must go to the still-empty right side instead of
	# overwriting the left one.
	for implication in implications:
		if left_impl == null and implication.left.equals(disjunction.left):
			left_impl = implication
		elif right_impl == null and implication.left.equals(disjunction.right):
			right_impl = implication
	if left_impl == null or right_impl == null:
		return _failure(
			"or_elim_impl: implication antecedents must match both sides of '%s'"
			% disjunction.to_string()
		)
	if not left_impl.right.equals(right_impl.right):
		return _failure(
			"or_elim_impl: both implications must have the same consequent; got '%s' and '%s'"
			% [left_impl.right.to_string(), right_impl.right.to_string()]
		)
	return _success(left_impl.right, [0, 1, 2])

## Derived ↔I: A -> B, B -> A |- A <-> B.
static func _iff_intro_impl(first: FormulaRes, second: FormulaRes) -> RuleDerivationRes:
	if first.kind != FormulaRes.Kind.IMPLIES or second.kind != FormulaRes.Kind.IMPLIES:
		return _failure("iff_intro_impl: expected two implications")
	if not first.left.equals(second.right) or not first.right.equals(second.left):
		return _failure(
			"iff_intro_impl: implications must be converses; got '%s' and '%s'"
			% [first.to_string(), second.to_string()]
		)
	return _success(
		FormulaRes.new(FormulaRes.Kind.IFF, "", first.left, first.right),
		[0, 1]
	)

## Derived ¬I: A -> B and A -> ~B |- ~A.
static func _not_intro_impl(first: FormulaRes, second: FormulaRes) -> RuleDerivationRes:
	var pair := _contradictory_implications(first, second, false)
	if not pair.ok:
		return pair
	return _success(FormulaRes.new(FormulaRes.Kind.NOT, "", pair.formula), [0, 1])

## Derived classical ¬E: ~A -> B and ~A -> ~B |- A.
static func _not_elim_impl(first: FormulaRes, second: FormulaRes) -> RuleDerivationRes:
	var pair := _contradictory_implications(first, second, true)
	if not pair.ok:
		return pair
	return _success(pair.formula, [0, 1])

## Shared checker for the two implication-encoded contradiction rules.
static func _contradictory_implications(first: FormulaRes, second: FormulaRes, negated: bool) -> RuleDerivationRes:
	if first.kind != FormulaRes.Kind.IMPLIES or second.kind != FormulaRes.Kind.IMPLIES:
		return _failure("expected two implications")
	if not first.left.equals(second.left):
		return _failure("both implications must share the same antecedent")
	if negated:
		if first.left.kind != FormulaRes.Kind.NOT or first.left.left == null:
			return _failure("negation elimination needs an antecedent of the form ~A")
	var contradiction := false
	if first.right.kind == FormulaRes.Kind.NOT and first.right.left != null and first.right.left.equals(second.right):
		contradiction = true
	if second.right.kind == FormulaRes.Kind.NOT and second.right.left != null and second.right.left.equals(first.right):
		contradiction = true
	if not contradiction:
		return _failure("the consequents must be a contradiction B / ~B")
	var result = first.left.left if negated else first.left
	var output := RuleDerivationRes.new()
	output.ok = true
	output.formula = result
	output.premise_order = [0, 1]
	return output

static func _formulas_text(formulas: Array) -> String:
	var parts: Array[String] = []
	for formula in formulas:
		parts.append(formula.to_string())
	return ", ".join(parts)

## Disjunctive syllogism: A | B and ~A give B; A | B and ~B give A.
## The two inputs may arrive in either order.
static func _disjunctive_syllogism(first: FormulaRes, second: FormulaRes) -> RuleDerivationRes:
	var disjunction = null
	var negation = null
	if first.kind == FormulaRes.Kind.OR:
		disjunction = first
		negation = second
	elif second.kind == FormulaRes.Kind.OR:
		disjunction = second
		negation = first
	if disjunction == null:
		return _failure(
			"ds: one premise must be a disjunction 'A | B'; got '%s' and '%s'"
			% [first.to_string(), second.to_string()]
		)
	if negation.kind != FormulaRes.Kind.NOT or negation.left == null:
		return _failure(
			"ds: the other premise must negate one side of the disjunction; got '%s'"
			% negation.to_string()
		)
	if disjunction.left.equals(negation.left):
		return _success(disjunction.right, [0, 1])
	if disjunction.right.equals(negation.left):
		return _success(disjunction.left, [0, 1])
	return _failure(
		"ds: '%s' does not negate either side of '%s'"
		% [negation.to_string(), disjunction.to_string()]
	)

## Biconditional elimination in either direction.
static func _iff_elim(first: FormulaRes, second: FormulaRes) -> RuleDerivationRes:
	if first.kind == FormulaRes.Kind.IFF:
		if first.left.equals(second):
			return _success(first.right, [1, 0])
		if first.right.equals(second):
			return _success(first.left, [1, 0])
	if second.kind == FormulaRes.Kind.IFF:
		if second.left.equals(first):
			return _success(second.right, [0, 1])
		if second.right.equals(first):
			return _success(second.left, [0, 1])
	return _failure(
		"iff_elim: expected a formula and a biconditional containing it; got '%s' and '%s'"
		% [first.to_string(), second.to_string()]
	)

## Law of excluded middle: no premises; P | ~P for any P.
static func _excluded_middle(formula: FormulaRes) -> RuleDerivationRes:
	if formula == null:
		return _failure("lem: an arbitrary formula is required")
	var negated := FormulaRes.new(FormulaRes.Kind.NOT, "", formula)
	return _success(FormulaRes.new(FormulaRes.Kind.OR, "", formula, negated), [])

## Double-negation elimination: ~~A |- A.
static func _double_neg_elim(premise: FormulaRes) -> RuleDerivationRes:
	if premise.kind != FormulaRes.Kind.NOT or premise.left == null or premise.left.kind != FormulaRes.Kind.NOT:
		return _failure(
			"double_neg_elim: expected a double negation '~~A', got '%s'" % premise.to_string()
		)
	return _success(premise.left.left, [0])

## Double-negation introduction: A |- ~~A.
static func _double_neg_intro(premise: FormulaRes) -> RuleDerivationRes:
	var negated := FormulaRes.new(FormulaRes.Kind.NOT, "", premise)
	return _success(FormulaRes.new(FormulaRes.Kind.NOT, "", negated), [0])

## Build a successful derivation.
static func _success(conclusion: FormulaRes, order: Array = []) -> RuleDerivationRes:
	var result := RuleDerivationRes.new()
	result.ok = true
	result.formula = conclusion
	result.premise_order = order.duplicate()
	return result

## Build a failed derivation.
static func _failure(message: String) -> RuleDerivationRes:
	var result := RuleDerivationRes.new()
	result.ok = false
	result.error = message
	return result
