extends SceneTree

## Negative proof corpus. Every case is an intentionally malformed or unsound
## use of a rule; the CLI/validator must reject it rather than merely avoid
## crashing. These tests complement the valid level-solution corpus.

const CliSessionRes = preload("res://cli/cli_session.gd")
const ParserRes = preload("res://logic/formula_parser.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run()
	print("INVALID PROOFS RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("INVALID PROOF CHECK FAILED: " + label)

func _session(commands: Array) -> Array:
	var session := CliSessionRes.new()
	var results := []
	for command in commands:
		results.append(session.execute(str(command)))
	return results

func _expect_apply_failure(label: String, commands: Array) -> void:
	var results := _session(commands)
	var result = results[-1]
	_check(not result.ok, label + " is rejected")
	_check(not str(result.error).is_empty(), label + " has an error message")

func _expect_validation_failure(label: String, commands: Array) -> void:
	var results := _session(commands)
	var result = results[-1]
	_check(result.validation != null, label + " returns a validation result")
	if result.validation != null:
		_check(not result.validation.ok, label + " fails validation")
		_check(not result.validation.errors.is_empty(), label + " lists validation errors")

func _run() -> void:
	_expect_apply_failure("impl_elim with a non-implication", [
		"goal C", "premise A", "premise B -> C", "apply impl_elim p1 p2",
	])
	_expect_apply_failure("and_elim_left on an implication", [
		"goal A", "premise A -> B", "apply and_elim_left p1",
	])
	_expect_apply_failure("and_intro with a missing input", [
		"goal A & B", "premise A", "apply and_intro p1",
	])
	_expect_apply_failure("double_neg_elim on an atom", [
		"goal A", "premise A", "apply double_neg_elim p1",
	])
	_expect_apply_failure("iff_elim on an implication", [
		"goal B", "premise A", "premise B", "apply iff_elim p1 p2",
	])
	_expect_apply_failure("not_elim with a non-negated assumption", [
		"goal A", "premise A", "assume A", "apply not_elim a1 p1 p1",
	])
	_expect_apply_failure("not_intro without a contradiction", [
		"goal ~A", "premise A", "premise B", "assume A",
		"apply not_intro a1 p1 p2",
	])
	_expect_apply_failure("or_elim on a non-disjunction", [
		"goal C", "premise A", "premise B", "assume A", "assume B",
		"apply or_elim p1 a1 p1 a2 p1",
	])
	_expect_apply_failure("or_elim with the wrong left case assumption", [
		"goal C", "premise A | B", "premise A -> C", "premise B -> C",
		"assume B", "apply impl_elim a1 p3",
		"assume B", "apply impl_elim a2 p3",
		"apply or_elim p1 a1 n1 a2 n2",
	])
	_expect_apply_failure("or_elim with different case conclusions", [
		"goal C", "premise A | B", "assume A",
		"apply or_intro_left a1 B", "assume B",
		"apply or_intro_left a2 A", "apply or_elim p1 a1 n1 a2 n2",
	])
	_expect_apply_failure("or_elim with the disjunction depending on a case", [
		"goal C", "premise A -> C", "premise B -> C",
		"assume A", "apply or_intro_left a1 B",
		"assume B", "apply impl_elim a1 p1", "apply impl_elim a2 p2",
		"apply or_elim n1 a1 n2 a2 n3",
	])
	_expect_apply_failure("or_elim using the other case assumption", [
		"goal C", "premise A | B", "premise A -> C", "premise B -> C",
		"assume A", "assume B",
		"apply impl_elim a2 p3", "apply impl_elim a2 p3",
		"apply or_elim p1 a1 n1 a2 n2",
	])
	_expect_apply_failure("iff_intro reusing one assumption", [
		"goal A <-> A", "assume A", "apply iff_intro a1 a1 a1 a1",
	])
	_expect_apply_failure("or_elim reusing one assumption for A | B", [
		"goal C", "premise A | B", "premise A -> C", "premise B -> C",
		"assume A", "apply impl_elim a1 p2",
		"apply or_elim p1 a1 n1 a1 n1",
	])
	_expect_validation_failure("an undischarged assumption at the root", [
		"goal A | B", "assume A", "apply or_intro_left a1 B", "validate",
	])
	_expect_validation_failure("a root that does not match the goal", [
		"goal B", "premise A", "apply or_intro_left p1 C", "validate",
	])

	for source in ["A ->", "A &", "(A", "A B", "A <->", "~", "A |", "A )"]:
		var parsed := ParserRes.new(source).parse()
		_check(not parsed.ok, "parser rejects malformed formula '%s'" % source)
		_check(not str(parsed.error).is_empty(), "parser explains malformed formula '%s'" % source)
