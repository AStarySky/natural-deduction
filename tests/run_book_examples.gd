extends SceneTree

## Larger propositional proofs adapted from the ND Pack's practice sections.
## Each case is run through the CLI proof session and must validate to its goal.

const CliSessionRes = preload("res://cli/cli_session.gd")

var tests: int = 0
var failures: int = 0

func _initialize() -> void:
	_run()
	print("BOOK EXAMPLES RESULT: %d tests, %d failed" % [tests, failures])
	quit(0 if failures == 0 else 1)

func _proof(label: String, source: String, commands: Array) -> void:
	tests += 1
	var session := CliSessionRes.new()
	var last = null
	for command in commands:
		last = session.execute(str(command))
	if last == null or last.validation == null or not last.validation.ok:
		failures += 1
		print("BOOK EXAMPLE FAILED: %s [%s]" % [label, source])
		if last != null:
			for line in last.lines:
				print("  " + str(line))
		return
	var root := session.tree.get_node(session.tree.last_rule_node_id())
	print("PASS: %s [%s] => %s" % [label, source, root.formula.to_string()])

func _run() -> void:
	# 4.3 Implication 3
	_proof("impl chain", "4.3.3", [
		"goal P -> R",
		"premise P -> Q",
		"premise Q -> R",
		"assume P",
		"apply impl_elim a1 p1",
		"apply impl_elim n1 p2",
		"apply impl_intro a1 n2",
		"validate",
	])

	# 4.3 Implication 7
	_proof("nested implication intro", "4.3.7", [
		"goal Q -> (P -> R)",
		"premise P -> (Q -> R)",
		"assume Q",
		"assume P",
		"apply impl_elim a2 p1",
		"apply impl_elim a1 n1",
		"apply impl_intro a2 n2",
		"apply impl_intro a1 n3",
		"validate",
	])

	# 4.3 Implication 8
	_proof("shared assumption in two branches", "4.3.8", [
		"goal P -> R",
		"premise P -> (Q -> R)",
		"premise P -> Q",
		"assume P",
		"apply impl_elim a1 p1",
		"apply impl_elim a1 p2",
		"apply impl_elim n2 n1",
		"apply impl_intro a1 n3",
		"validate",
	])

	# 4.2 Conjunction 3
	_proof("conjunction swap", "4.2.3", [
		"goal Q & P",
		"premise P & Q",
		"apply and_elim_right p1",
		"apply and_elim_left p1",
		"apply and_intro n1 n2",
		"validate",
	])

	# 4.2 Conjunction 5
	_proof("conjunction reassembly", "4.2.5", [
		"goal (P1 & Q2) & R",
		"premise P1 & P2",
		"premise (Q1 & Q2) & R",
		"apply and_elim_left p1",
		"apply and_elim_left p2",
		"apply and_elim_right n2",
		"apply and_elim_right p2",
		"apply and_intro n1 n3",
		"apply and_intro n5 n4",
		"validate",
	])

	# 4.4 Disjunction 1
	_proof("disjunction swap via cases", "4.4.1", [
		"goal Q | P",
		"premise P | Q",
		"assume P",
		"apply or_intro_right a1 Q",
		"assume Q",
		"apply or_intro_left a2 P",
		"apply or_elim p1 a1 n1 a2 n2",
		"validate",
	])

	# 4.4 Disjunction 10
	_proof("cases under an implication assumption", "4.4.10", [
		"goal (P -> Q) -> Q",
		"premise P | Q",
		"assume P -> Q",
		"assume P",
		"apply impl_elim a2 a1",
		"assume Q",
		"apply or_elim p1 a2 n1 a3 a3",
		"apply impl_intro a1 n2",
		"validate",
	])

	# 4.5 Biconditional 1
	_proof("biconditional symmetry", "4.5.1", [
		"goal Q <-> P",
		"premise P <-> Q",
		"assume Q",
		"apply iff_elim a1 p1",
		"assume P",
		"apply iff_elim a2 p1",
		"apply iff_intro a1 n1 a2 n2",
		"validate",
	])

	# 4.5 Biconditional 4
	_proof("disjunction/biconditional bridge", "4.5.4", [
		"goal P -> Q",
		"premise (P | Q) <-> Q",
		"assume P",
		"apply or_intro_left a1 Q",
		"apply iff_elim n1 p1",
		"apply impl_intro a1 n2",
		"validate",
	])

	# 4.5 Biconditional 2
	_proof("nested biconditional and scope reuse", "4.5.2", [
		"goal Q <-> R",
		"premise P",
		"premise (P <-> Q) <-> R",
		"assume R",
		"apply iff_elim a1 p2",
		"apply iff_elim p1 n1",
		"assume Q",
		"assume P",
		"assume Q",
		"apply iff_intro a3 a2 a4 p1",
		"apply iff_elim n3 p2",
		"apply iff_intro a2 n4 a1 n2",
		"validate",
	])

	# 4.6 Negation 2
	_proof("negated conjunction", "4.6.2", [
		"goal ~(P & Q)",
		"premise ~P",
		"assume P & Q",
		"apply and_elim_left a1",
		"apply not_intro a1 n1 p1",
		"validate",
	])

	# 4.6 Negation 5
	_proof("implication to negated consequent", "4.6.5", [
		"goal P -> ~Q",
		"premise ~(P & Q)",
		"assume P",
		"assume Q",
		"apply and_intro a1 a2",
		"apply not_intro a2 n1 p1",
		"apply impl_intro a1 n2",
		"validate",
	])

	# 4.6 Negation 6
	_proof("contraposition", "4.6.6", [
		"goal ~Q -> ~P",
		"premise P -> Q",
		"assume ~Q",
		"assume P",
		"apply impl_elim a2 p1",
		"apply not_intro a2 n1 a1",
		"apply impl_intro a1 n2",
		"validate",
	])

	# 4.6 Negation 8
	_proof("negated disjunction", "4.6.8", [
		"goal ~P & ~Q",
		"premise ~(P | Q)",
		"assume P",
		"apply or_intro_left a1 Q",
		"apply not_intro a1 n1 p1",
		"assume Q",
		"apply or_intro_right a2 P",
		"apply not_intro a2 n3 p1",
		"apply and_intro n2 n4",
		"validate",
	])

	# 4.6 Negation 10 (ex falso via classical negation elimination)
	_proof("ex falso / classical neglect", "4.6.10", [
		"goal P -> Q",
		"premise ~P",
		"assume P",
		"assume ~Q",
		"apply not_elim a2 a1 p1",
		"apply impl_intro a1 n1",
		"validate",
	])

	# 4.6 Negation 3
	_proof("self-negating premise", "4.6.3", [
		"goal ~P",
		"premise P -> ~P",
		"assume P",
		"apply impl_elim a1 p1",
		"apply not_intro a1 a1 n1",
		"validate",
	])

	# 4.6 Negation 4
	_proof("double-strength negation intro", "4.6.4", [
		"goal ~Q",
		"premise ~(P -> Q)",
		"assume Q",
		"assume P",
		"apply impl_intro a2 a1",
		"apply not_intro a1 n1 p1",
		"validate",
	])
