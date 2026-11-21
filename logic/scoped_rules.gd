extends RefCounted

## Formula semantics for rules whose premises include proof branches and
## assumptions. Scope/context checks live in ProofTree; this module only
## validates shapes and produces the resulting formula.

const FormulaRes = preload("res://logic/formula.gd")
const RuleDerivationRes = preload("res://logic/rule_derivation.gd")
const RulesRes = preload("res://logic/rules.gd")

## Derive the conclusion formula for a scoped rule.
## proofs and assumptions are in the order declared by the rule descriptor;
## or_elim pairs assumption 0 with proof branch 1 and assumption 1 with branch 2.
static func derive(rule_id: String, proofs: Array, assumptions: Array) -> RuleDerivationRes:
	match rule_id:
		"impl_intro":
			return _impl_intro(proofs, assumptions)
		"or_elim":
			return _or_elim(proofs, assumptions)
		"iff_intro":
			return _iff_intro(proofs, assumptions)
		"not_intro":
			return _not_rule(proofs, assumptions, true)
		"not_elim":
			return _not_rule(proofs, assumptions, false)
	return _failure("%s is not a scoped rule" % rule_id)

static func _impl_intro(proofs: Array, assumptions: Array) -> RuleDerivationRes:
	if proofs.size() != 1 or assumptions.size() != 1:
		return _failure("impl_intro: expected one proof and one assumption")
	var implication := FormulaRes.new(FormulaRes.Kind.IMPLIES, "", assumptions[0], proofs[0])
	return _success(implication)

static func _or_elim(proofs: Array, assumptions: Array) -> RuleDerivationRes:
	if proofs.size() != 3 or assumptions.size() != 2:
		return _failure("or_elim: expected a disjunction and two case proofs")
	var disjunction = proofs[0]
	if disjunction.kind != FormulaRes.Kind.OR:
		return _failure(
			"or_elim: first proof must conclude a disjunction, got '%s'"
			% disjunction.to_string()
		)
	if not assumptions[0].equals(disjunction.left):
		return _failure(
			"or_elim: first case assumption '%s' must match the left side '%s'"
			% [assumptions[0].to_string(), disjunction.left.to_string()]
		)
	if not assumptions[1].equals(disjunction.right):
		return _failure(
			"or_elim: second case assumption '%s' must match the right side '%s'"
			% [assumptions[1].to_string(), disjunction.right.to_string()]
		)
	if not proofs[1].equals(proofs[2]):
		return _failure(
			"or_elim: both case proofs must conclude the same formula; got '%s' and '%s'"
			% [proofs[1].to_string(), proofs[2].to_string()]
		)
	return _success(proofs[1])

static func _iff_intro(proofs: Array, assumptions: Array) -> RuleDerivationRes:
	if proofs.size() != 2 or assumptions.size() != 2:
		return _failure("iff_intro: expected two proofs and two assumptions")
	if not proofs[0].equals(assumptions[1]):
		return _failure(
			"iff_intro: first branch must conclude the second assumption '%s'; got '%s'"
			% [assumptions[1].to_string(), proofs[0].to_string()]
		)
	if not proofs[1].equals(assumptions[0]):
		return _failure(
			"iff_intro: second branch must conclude the first assumption '%s'; got '%s'"
			% [assumptions[0].to_string(), proofs[1].to_string()]
		)
	return _success(
		FormulaRes.new(FormulaRes.Kind.IFF, "", assumptions[0], assumptions[1])
	)

static func _not_rule(proofs: Array, assumptions: Array, is_intro: bool) -> RuleDerivationRes:
	var name := "not_intro" if is_intro else "not_elim"
	if proofs.size() != 2 or assumptions.size() != 1:
		return _failure("%s: expected two proofs and one assumption" % name)
	var assumption = assumptions[0]
	if is_intro:
		return _contradiction_result(
			name,
			proofs,
			FormulaRes.new(FormulaRes.Kind.NOT, "", assumption)
		)
	if assumption.kind != FormulaRes.Kind.NOT or assumption.left == null:
		return _failure(
			"%s: assumption must be a negation '~A'; got '%s'"
			% [name, assumption.to_string()]
		)
	return _contradiction_result(name, proofs, assumption.left)

static func _contradiction_result(name: String, proofs: Array, result) -> RuleDerivationRes:
	var first = proofs[0]
	var second = proofs[1]
	var contradiction := false
	if first.kind == FormulaRes.Kind.NOT and first.left != null and first.left.equals(second):
		contradiction = true
	if second.kind == FormulaRes.Kind.NOT and second.left != null and second.left.equals(first):
		contradiction = true
	if not contradiction:
		return _failure(
			"%s: the two proof conclusions must be a contradiction ψ / ~ψ; got '%s' and '%s'"
			% [name, first.to_string(), second.to_string()]
		)
	return _success(result)

static func _success(formula: FormulaRes) -> RuleDerivationRes:
	var result := RuleDerivationRes.new()
	result.ok = true
	result.formula = formula
	return result

static func _failure(message: String) -> RuleDerivationRes:
	var result := RuleDerivationRes.new()
	result.ok = false
	result.error = message
	return result
