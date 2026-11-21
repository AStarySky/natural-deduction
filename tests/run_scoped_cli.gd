extends SceneTree

## Headless checks for the scoped proof core and the CLI's assumption syntax.
## Covers ->Intro, ->Elim, full \/Elim, <->Intro/Elim, ~Intro/Elim, and
## undischarged-assumption rejection.

const CliSessionRes = preload("res://cli/cli_session.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const RulesRes = preload("res://logic/rules.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run()
	print("SCOPED CLI RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _session(commands: Array):
	var session := CliSessionRes.new()
	var results := []
	for command in commands:
		results.append(session.execute(str(command)))
	return {"session": session, "results": results}

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("SCOPED CHECK FAILED: " + label)

func _run() -> void:
	var implication = _session([
		"goal A -> A", "assume A", "apply impl_intro a1 a1", "validate",
	])
	var implication_results: Array = implication["results"]
	_check(
		implication_results[2].ok and implication_results[2].node.formula.to_string() == "A -> A",
		"impl_intro derives A -> A"
	)
	_check(implication_results[3].validation.ok, "impl_intro A -> A validates")

	var nested = _session([
		"goal A -> (B -> A)",
		"assume A",
		"assume B",
		"apply impl_intro a2 a1",
		"apply impl_intro a1 n1",
		"validate",
	])
	var nested_results: Array = nested["results"]
	_check(nested_results[3].node.formula.to_string() == "B -> A", "nested intro inner conclusion")
	_check(
		nested_results[4].node.formula.to_string() == "A -> (B -> A)",
		"nested intro outer conclusion"
	)
	_check(nested_results[5].validation.ok, "nested assumptions discharge in order")

	var disjunction = _session([
		"goal A | B",
		"premise A | B",
		"assume A",
		"assume B",
		"apply or_intro_left a1 B",
		"apply or_intro_right a2 A",
		"apply or_elim p1 a1 n1 a2 n2",
		"validate",
	])
	var disjunction_results: Array = disjunction["results"]
	_check(disjunction_results[6].node.formula.to_string() == "A | B", "or_elim derives the common case result")
	_check(disjunction_results[7].validation.ok, "or_elim with used case assumptions validates")

	var biconditional = _session([
		"goal A <-> B",
		"premise A",
		"premise B",
		"assume A",
		"assume B",
		"apply iff_intro a1 p2 a2 p1",
		"validate",
	])
	var biconditional_results: Array = biconditional["results"]
	_check(biconditional_results[5].node.formula.to_string() == "A <-> B", "iff_intro derives A <-> B")
	_check(biconditional_results[6].validation.ok, "iff_intro validates")

	var negation_intro = _session([
		"goal ~A",
		"assume A",
		"premise ~A",
		"apply not_intro a1 a1 p1",
		"validate",
	])
	var negation_intro_results: Array = negation_intro["results"]
	_check(negation_intro_results[3].node.formula.to_string() == "~A", "not_intro derives ~A")
	_check(negation_intro_results[4].validation.ok, "not_intro validates")

	var negation_elim = _session([
		"goal A",
		"assume ~A",
		"premise A",
		"apply not_elim a1 p1 a1",
		"validate",
	])
	var negation_elim_results: Array = negation_elim["results"]
	_check(negation_elim_results[3].node.formula.to_string() == "A", "not_elim derives A")
	_check(negation_elim_results[4].validation.ok, "not_elim validates")

	var iff_elim = _session([
		"goal B",
		"premise A <-> B",
		"premise A",
		"apply iff_elim p2 p1",
		"validate",
	])
	var iff_elim_results: Array = iff_elim["results"]
	_check(iff_elim_results[3].node.formula.to_string() == "B", "iff_elim derives B")
	_check(iff_elim_results[4].validation.ok, "iff_elim validates")

	var open_assumption = _session([
		"goal A & A",
		"assume A",
		"apply and_intro a1 a1",
		"validate",
	])
	_check(not open_assumption["results"][3].validation.ok, "undischarged assumption is rejected")

	var unicode_iff = _session(["premise A ↔ B"])
	_check(
		unicode_iff["results"][0].ok
		and unicode_iff["results"][0].node.formula.to_string() == "A <-> B",
		"unicode biconditional parses"
	)

	var bad_scope = _session(["apply impl_intro a1"])
	_check(not bad_scope["results"][0].ok, "scoped rule rejects a missing proof argument")
	_run_derived_rule_checks()

func _f(text: String):
	return ParserRes.new(text).parse().formula

func _run_derived_rule_checks() -> void:
	var disj = RulesRes.derive("or_elim_impl", [_f("A | B"), _f("A -> C"), _f("B -> C")])
	_check(disj.ok and disj.formula.to_string() == "C", "derived or_elim gives C")
	var iff = RulesRes.derive("iff_intro_impl", [_f("A -> B"), _f("B -> A")])
	_check(iff.ok and iff.formula.to_string() == "A <-> B", "derived iff_intro gives A <-> B")
	var ni = RulesRes.derive("not_intro_impl", [_f("A -> B"), _f("A -> ~B")])
	_check(ni.ok and ni.formula.to_string() == "~A", "derived not_intro gives ~A")
	var ne = RulesRes.derive("not_elim_impl", [_f("~A -> B"), _f("~A -> ~B")])
	_check(ne.ok and ne.formula.to_string() == "A", "derived not_elim gives A")
	var bad = RulesRes.derive("iff_intro_impl", [_f("A -> B"), _f("C -> A")])
	_check(not bad.ok, "derived iff_intro rejects non-converses")
