extends SceneTree

## Deterministic stability suite for the scoped proof core.
## Covers parser round-trips/fuzzing, malformed CLI input, scope isolation,
## vacuous discharge, nested scopes, long derivations and repeated validation.

const FormulaRes = preload("res://logic/formula.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const ProofTreeRes = preload("res://logic/proof_tree.gd")
const CliSessionRes = preload("res://cli/cli_session.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run()
	print("STABILITY RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("STABILITY CHECK FAILED: " + label)

func _parse(text: String) -> FormulaRes:
	var result := ParserRes.new(text).parse()
	if not result.ok:
		_check(false, "test formula parses: " + text)
		return null
	return result.formula

func _run() -> void:
	_test_parser_roundtrip()
	_test_parser_fuzz()
	_test_precedence()
	_test_scope_guards()
	_test_vacuous_and_identity()
	_test_or_elim_impl_same_sides()
	_test_deep_scope()
	_test_long_simple_chain()
	_test_cli_fuzz_and_isolation()

## Random AST -> text -> parser -> equal AST.
func _test_parser_roundtrip() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE
	for index in range(350):
		var formula := _random_formula(rng, 4)
		var text := formula.to_string()
		var parsed := ParserRes.new(text).parse()
		_check(parsed.ok, "random AST round-trip parses #%d: %s" % [index, text])
		if parsed.ok:
			_check(parsed.formula.equals(formula), "random AST round-trip equal #%d: %s" % [index, text])

func _random_formula(rng: RandomNumberGenerator, depth: int) -> FormulaRes:
	var atoms := ["A", "B", "C", "P", "Q", "P1"]
	if depth <= 0 or rng.randf() < 0.28:
		return FormulaRes.new(
			FormulaRes.Kind.ATOM,
			atoms[rng.randi_range(0, atoms.size() - 1)]
		)
	var kinds := [
		FormulaRes.Kind.NOT,
		FormulaRes.Kind.AND,
		FormulaRes.Kind.OR,
		FormulaRes.Kind.IMPLIES,
		FormulaRes.Kind.IFF,
	]
	var kind: int = kinds[rng.randi_range(0, kinds.size() - 1)]
	if kind == FormulaRes.Kind.NOT:
		return FormulaRes.new(FormulaRes.Kind.NOT, "", _random_formula(rng, depth - 1))
	return FormulaRes.new(
		kind,
		"",
		_random_formula(rng, depth - 1),
		_random_formula(rng, depth - 1)
	)

## Arbitrary character soup must fail or round-trip, never crash.
func _test_parser_fuzz() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51AB1E
	var alphabet := "ABC~&|-><() \t"
	for index in range(300):
		var length := rng.randi_range(0, 28)
		var text := ""
		for position in range(length):
			text += alphabet.substr(rng.randi_range(0, alphabet.length() - 1), 1)
		var parsed := ParserRes.new(text).parse()
		if parsed.ok:
			var reparsed := ParserRes.new(parsed.formula.to_string()).parse()
			_check(reparsed.ok, "fuzz parsed formula reparses #%d: %s" % [index, text])
			if reparsed.ok:
				_check(
					reparsed.formula.equals(parsed.formula),
					"fuzz parsed formula stable #%d: %s" % [index, text]
				)

func _test_precedence() -> void:
	_check(
		_parse("A -> B -> C").equals(_parse("A -> (B -> C)")),
		"implication is right-associative"
	)
	_check(
		_parse("A <-> B <-> C").equals(_parse("A <-> (B <-> C)")),
		"biconditional is right-associative"
	)
	_check(
		_parse("A & B | C").equals(FormulaRes.new(
			FormulaRes.Kind.OR,
			"",
			_parse("A & B"),
			_parse("C")
		)),
		"conjunction binds tighter than disjunction"
	)
	_check(
		_parse("A -> B <-> C").equals(FormulaRes.new(
			FormulaRes.Kind.IFF,
			"",
			_parse("A -> B"),
			_parse("C")
		)),
		"implication binds tighter than biconditional"
	)
	_check(_parse("A ↔ B").to_string() == "A <-> B", "unicode biconditional normalizes")
	_check(_parse("A → B").to_string() == "A -> B", "unicode arrow normalizes")
	_check(_parse("A -> B").to_display_string() == "A -> B", "display uses ASCII arrow for web fonts")
	_check(_parse("A <-> B").to_display_string() == "A <-> B", "display uses ASCII biconditional for web fonts")

func _test_scope_guards() -> void:
	var tree := ProofTreeRes.new()
	var disj := tree.add_premise(_parse("A | B"))
	var left := tree.add_assumption(_parse("A"))
	var right := tree.add_assumption(_parse("B"))
	var proof_a := tree.add_premise(_parse("A"))
	var proof_b := tree.add_premise(_parse("B"))

	var cross_or := tree.apply_scoped(
		"or_elim",
		[disj.id, right.id, right.id],
		[left.id, right.id]
	)
	_check(not cross_or.ok, "or_elim rejects a left case using the right assumption")

	var cross_iff := tree.apply_scoped(
		"iff_intro",
		[right.id, left.id],
		[left.id, right.id]
	)
	_check(not cross_iff.ok, "iff_intro rejects cross-scope assumptions")

	var duplicate := tree.apply_scoped(
		"iff_intro",
		[proof_b.id, proof_a.id],
		[left.id, left.id]
	)
	_check(not duplicate.ok, "iff_intro rejects duplicate assumption ids")

	var not_assumption := tree.apply_scoped(
		"impl_intro",
		[proof_a.id],
		[proof_a.id]
	)
	_check(not not_assumption.ok, "impl_intro requires an assume node, not a premise")

	var wrong_count := tree.apply_scoped("impl_intro", [], [])
	_check(not wrong_count.ok, "scoped rule rejects missing arguments")

	var disj_wrong := tree.apply_scoped(
		"or_elim",
		[disj.id, proof_a.id, proof_b.id],
		[left.id, right.id]
	)
	_check(not disj_wrong.ok, "or_elim rejects different case conclusions")

	var contradiction_wrong := tree.apply_scoped(
		"not_intro",
		[proof_a.id, proof_b.id],
		[left.id]
	)
	_check(not contradiction_wrong.ok, "not_intro rejects non-contradictory branches")

	var non_negation := tree.apply_scoped(
		"not_elim",
		[proof_a.id, proof_b.id],
		[left.id]
	)
	_check(not non_negation.ok, "not_elim requires a negated assumption")

	var unknown_proof := tree.apply_scoped("impl_intro", ["missing"], [left.id])
	_check(not unknown_proof.ok, "scoped rule rejects unknown proof id")

	var unknown_assumption := tree.apply_scoped("impl_intro", [proof_a.id], ["missing"])
	_check(not unknown_assumption.ok, "scoped rule rejects unknown assumption id")

func _test_vacuous_and_identity() -> void:
	var vacuous := ProofTreeRes.new()
	var a := vacuous.add_premise(_parse("A"))
	var b := vacuous.add_assumption(_parse("B"))
	var implication := vacuous.apply_scoped("impl_intro", [a.id], [b.id])
	_check(implication.ok, "vacuous implication intro succeeds")
	if implication.ok:
		_check(implication.node.formula.to_string() == "B -> A", "vacuous intro conclusion")
		_check(implication.node.context.is_empty(), "vacuous intro has empty context")
		_check(implication.node.discharged == [b.id], "vacuous intro records its binder")
		_check(vacuous.validate(implication.node.id, _parse("B -> A")).ok, "vacuous intro validates")

	var identity := ProofTreeRes.new()
	identity.add_assumption(_parse("A"))
	var second := identity.add_assumption(_parse("A"))
	var use_second := identity.apply_scoped("impl_intro", [second.id], ["a1"])
	_check(use_second.ok, "identity test rule application succeeds")
	if use_second.ok:
		_check(use_second.node.context == [second.id], "same-formula outer assumption survives")
		var validation := identity.validate(use_second.node.id, _parse("A -> A"))
		_check(not validation.ok, "same-formula outer assumption remains undischarged")
		_check(
			_join(validation.errors).contains(second.id),
			"undischarged error names the surviving assumption"
		)

## or_elim_impl with identical disjuncts: P | P, P -> Q, P -> Q |- Q.
func _test_or_elim_impl_same_sides() -> void:
	var tree := ProofTreeRes.new()
	var disj := tree.add_premise(_parse("P | P"))
	var impl := tree.add_premise(_parse("P -> Q"))
	var same := tree.apply_rule("or_elim_impl", [disj.id, impl.id, impl.id])
	_check(same.ok, "or_elim_impl accepts P | P with the same implication twice")
	if same.ok:
		_check(same.node.formula.to_string() == "Q", "or_elim_impl on P | P concludes Q")
		_check(tree.validate(same.node.id, _parse("Q")).ok, "or_elim_impl on P | P validates")

	var other := tree.add_premise(_parse("P -> R"))
	var mixed := tree.apply_rule("or_elim_impl", [disj.id, impl.id, other.id])
	_check(not mixed.ok, "or_elim_impl on P | P still rejects different consequents")

	var ab := tree.add_premise(_parse("A | B"))
	var a_to_c := tree.add_premise(_parse("A -> C"))
	var twice_left := tree.apply_rule("or_elim_impl", [ab.id, a_to_c.id, a_to_c.id])
	_check(not twice_left.ok, "or_elim_impl on A | B rejects two left-side implications")

	var b_to_c := tree.add_premise(_parse("B -> C"))
	var swapped := tree.apply_rule("or_elim_impl", [b_to_c.id, ab.id, a_to_c.id])
	_check(swapped.ok, "or_elim_impl still accepts inputs in any order")

func _test_deep_scope() -> void:
	var tree := ProofTreeRes.new()
	var depth := 60
	var assumptions: Array = []
	for index in range(depth):
		assumptions.append(tree.add_assumption(_parse("A")))
	var proof = assumptions[0]
	var ok := true
	for index in range(depth - 1, -1, -1):
		var applied := tree.apply_scoped("impl_intro", [proof.id], [assumptions[index].id])
		if not applied.ok:
			ok = false
			break
		proof = applied.node
	_check(ok, "60 nested implication introductions succeed")
	if not ok:
		return
	_check(proof.context.is_empty(), "deep scope root is closed")
	var validation := tree.validate(proof.id, proof.formula)
	_check(validation.ok, "deep scope proof validates")
	if not validation.ok:
		print("  deep errors: ", validation.errors)
	var repeated := tree.validate(proof.id, proof.formula)
	_check(repeated.ok and validation.ok, "deep scope validation is repeatable")
	_check(not tree.to_text().is_empty(), "deep scope tree renders")
	_check_unique_contexts(tree, "deep scope")
	_check(
		tree.validate(proof.id, _parse("A")).ok == false,
		"deep scope rejects a mismatched goal"
	)

func _test_long_simple_chain() -> void:
	var tree := ProofTreeRes.new()
	var current := tree.add_premise(_parse("A"))
	var implication := tree.add_premise(_parse("A -> A"))
	var ok := true
	for index in range(120):
		var applied := tree.apply_rule("impl_elim", [current.id, implication.id])
		if not applied.ok:
			ok = false
			break
		current = applied.node
	_check(ok, "120-step modus ponens chain applies")
	if not ok:
		return
	var validation := tree.validate(current.id, _parse("A"))
	_check(validation.ok, "long simple chain validates")
	_check(tree.node_count() == 122, "long simple chain node count")
	_check_unique_contexts(tree, "long chain")
	var text := tree.to_text()
	_check(text.contains("[n120]"), "long chain tree includes final node")
	_check(text.count("impl_elim") >= 120, "long chain tree includes all rule applications")

func _test_cli_fuzz_and_isolation() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0xBADF00D
	var session := CliSessionRes.new()
	var verbs := ["", "premise", "assume", "goal", "apply", "validate", "tree", "nonsense"]
	var pieces := ["", "A", "B", "~", "A &", "A -> B", "impl_intro", "a1", "p1", "n1", "(", ")"]
	var executed := 0
	for index in range(180):
		var command: String = verbs[rng.randi_range(0, verbs.size() - 1)]
		if not command.is_empty():
			command += " "
		command += pieces[rng.randi_range(0, pieces.size() - 1)]
		if rng.randf() < 0.5:
			command += " " + pieces[rng.randi_range(0, pieces.size() - 1)]
		var result := session.execute(command)
		_check(result != null, "CLI fuzz returns a result #%d" % index)
		executed += 1
	_check(executed == 180, "CLI fuzz executed all commands")

	var first := CliSessionRes.new()
	var second := CliSessionRes.new()
	first.execute("assume A")
	second.execute("premise B")
	_check(first.tree.node_count() == 1, "first session isolated node count")
	_check(second.tree.node_count() == 1, "second session isolated node count")
	_check(first.tree.get_node("a1") != null, "first session assumption exists")
	_check(second.tree.get_node("a1") == null, "second session has no leaked assumption")

	var fresh := CliSessionRes.new()
	for command in ["goal A -> A", "assume A", "apply impl_intro a1 a1", "validate"]:
		fresh.execute(command)
	var valid_nodes := fresh.tree.node_count()
	_check(valid_nodes == 2, "fresh session remains usable after fuzz")
	var validation := fresh.tree.validate(fresh.tree.last_rule_node_id(), _parse("A -> A"))
	_check(validation.ok, "fresh session proof validates after fuzz")

func _check_unique_contexts(tree, label: String) -> void:
	for node_id in tree.node_ids():
		var node = tree.get_node(node_id)
		var seen := {}
		for assumption_id in node.context:
			_check(not seen.has(assumption_id), "%s: context has no duplicates at %s" % [label, node_id])
			seen[assumption_id] = true
			var assumption = tree.get_node(assumption_id)
			_check(
				assumption != null and assumption.rule_id == "assume",
				"%s: context id %s refers to an assumption" % [label, assumption_id]
			)

func _join(lines: Array) -> String:
	var text := ""
	for index in range(lines.size()):
		if index > 0:
			text += "\n"
		text += str(lines[index])
	return text
