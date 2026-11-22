extends RefCounted

## Directed acyclic proof graph with id-addressed nodes, text rendering and
## recursive, rule-semantic validation.

const FormulaRes = preload("res://logic/formula.gd")
const ProofNodeRes = preload("res://logic/proof_node.gd")
const RuleResultRes = preload("res://logic/rule_result.gd")
const ValidationResultRes = preload("res://logic/validation_result.gd")
const RulesRes = preload("res://logic/rules.gd")
const ScopedRulesRes = preload("res://logic/scoped_rules.gd")

var _nodes: Dictionary = {}
var _order: Array[String] = []
var _premise_counter: int = 0
var _assumption_counter: int = 0
var _rule_counter: int = 0
var _last_rule_id: String = ""

## Add an axiom premise and return its newly allocated pN node.
func add_premise(formula: FormulaRes) -> ProofNodeRes:
	_premise_counter += 1
	var node_id := "p%d" % _premise_counter
	var empty_ids: Array[String] = []
	var node := ProofNodeRes.new(node_id, formula, "premise", empty_ids, {})
	_nodes[node_id] = node
	_order.append(node_id)
	return node

## Add a freely constructed assumption leaf and return its aN node.
func add_assumption(formula: FormulaRes) -> ProofNodeRes:
	_assumption_counter += 1
	var node_id := "a%d" % _assumption_counter
	var empty_ids: Array[String] = []
	var context: Array[String] = [node_id]
	var node := ProofNodeRes.new(node_id, formula, "assume", empty_ids, {}, context, [])
	_nodes[node_id] = node
	_order.append(node_id)
	return node

## Look up a node by id; returns null when it does not exist.
func get_node(node_id: String) -> ProofNodeRes:
	if _nodes.has(node_id):
		return _nodes[node_id]
	return null

## Number of premises plus rule nodes currently in the tree.
func node_count() -> int:
	return _order.size()

## Node ids in deterministic insertion order.
func node_ids() -> Array[String]:
	return _order.duplicate()

## Id of the most recently created rule node, or "" if none exists.
func last_rule_node_id() -> String:
	return _last_rule_id

## Apply a rule to existing nodes. A node is created only after full success.
func apply_rule(
	rule_id: String,
	premise_ids: Array[String],
	extra_formula = null
) -> RuleResultRes:
	if not RulesRes.RULES.has(rule_id):
		return _rule_failure(
			"unknown rule '%s'; available rules: %s" % [rule_id, RulesRes.rule_names_text()]
		)
	if RulesRes.is_scoped(rule_id):
		return _rule_failure(
			"%s needs assumption ids; use the scoped application" % rule_id
		)
	var expected_arity := RulesRes.arity(rule_id)
	if premise_ids.size() != expected_arity:
		return _rule_failure(
			"%s expects %d premise id(s), got %d"
			% [rule_id, expected_arity, premise_ids.size()]
		)

	var premises: Array = []
	var context: Array[String] = []
	for premise_id in premise_ids:
		var premise_node := get_node(premise_id)
		if premise_node == null:
			return _rule_failure("%s: unknown premise id '%s'" % [rule_id, premise_id])
		premises.append(premise_node.formula)
		context = _context_union(context, premise_node.context)

	var derivation := RulesRes.derive(rule_id, premises, extra_formula)
	if not derivation.ok:
		return _rule_failure(derivation.error)

	var ordered_ids: Array[String] = []
	for index in derivation.premise_order:
		var slot := int(index)
		if slot < 0 or slot >= premise_ids.size():
			return _rule_failure("%s: internal premise-slot error" % rule_id)
		ordered_ids.append(premise_ids[slot])
	if ordered_ids.size() != premise_ids.size():
		return _rule_failure("%s: internal premise-slot error" % rule_id)

	var extra: Dictionary = {}
	if RulesRes.takes_extra(rule_id):
		extra[ProofNodeRes.EXTRA_OTHER] = extra_formula

	_rule_counter += 1
	var node_id := "n%d" % _rule_counter
	var node := ProofNodeRes.new(
		node_id,
		derivation.formula,
		rule_id,
		ordered_ids,
		extra,
		context,
		[]
	)
	_nodes[node_id] = node
	_order.append(node_id)
	_last_rule_id = node_id
	return _rule_success(node)

## Apply a discharging rule to proof branches and explicit assumption ids.
func apply_scoped(
	rule_id: String,
	proof_ids: Array,
	assumption_ids: Array
) -> RuleResultRes:
	var proof_id_list: Array[String] = []
	for proof_id in proof_ids:
		proof_id_list.append(str(proof_id))
	var assumption_id_list: Array[String] = []
	for assumption_id in assumption_ids:
		assumption_id_list.append(str(assumption_id))
	proof_ids = proof_id_list
	assumption_ids = assumption_id_list
	if not RulesRes.is_scoped(rule_id):
		return _rule_failure("%s is not a scoped rule" % rule_id)
	if proof_ids.size() != RulesRes.proof_count(rule_id):
		return _rule_failure(
			"%s expects %d proof id(s), got %d"
			% [rule_id, RulesRes.proof_count(rule_id), proof_ids.size()]
		)
	if assumption_ids.size() != RulesRes.assumption_count(rule_id):
		return _rule_failure(
			"%s expects %d assumption id(s), got %d"
			% [rule_id, RulesRes.assumption_count(rule_id), assumption_ids.size()]
		)

	var proof_nodes: Array = []
	var proof_formulas: Array = []
	for proof_id in proof_ids:
		var node := get_node(proof_id)
		if node == null:
			return _rule_failure("%s: unknown proof id '%s'" % [rule_id, proof_id])
		proof_nodes.append(node)
		proof_formulas.append(node.formula)

	var assumption_nodes: Array = []
	var assumption_formulas: Array = []
	for assumption_id in assumption_ids:
		var node := get_node(assumption_id)
		if node == null:
			return _rule_failure("%s: unknown assumption id '%s'" % [rule_id, assumption_id])
		if node.rule_id != "assume":
			return _rule_failure(
				"%s: [%s] is not an assumption; use an assume node"
				% [rule_id, assumption_id]
			)
		assumption_nodes.append(node)
		assumption_formulas.append(node.formula)

	# or_elim may legitimately use the same assumption occurrence for both
	# cases when the disjunction has identical sides (for example A | A):
	# the single open assumption is discharged once. Other scoped rules still
	# require distinct assumptions.
	var duplicate_case_assumption: bool = (
		rule_id == "or_elim"
		and assumption_ids.size() == 2
		and assumption_ids[0] == assumption_ids[1]
	)
	var seen_assumptions: Dictionary = {}
	for assumption_id in assumption_ids:
		if seen_assumptions.has(assumption_id) and not duplicate_case_assumption:
			return _rule_failure("%s: assumption id '%s' is used twice" % [rule_id, assumption_id])
		seen_assumptions[assumption_id] = true

	var derivation := ScopedRulesRes.derive(rule_id, proof_formulas, assumption_formulas)
	if not derivation.ok:
		return _rule_failure(derivation.error)

	var context_result := _scoped_context(rule_id, proof_nodes, assumption_nodes)
	if not bool(context_result["ok"]):
		return _rule_failure(str(context_result["error"]))

	_rule_counter += 1
	var node_id := "n%d" % _rule_counter
	var node := ProofNodeRes.new(
		node_id,
		derivation.formula,
		rule_id,
		proof_id_list,
		{},
		context_result["context"],
		assumption_id_list
	)
	_nodes[node_id] = node
	_order.append(node_id)
	_last_rule_id = node_id
	return _rule_success(node)

## Compute the free-assumption context after discharging this rule's binders.
func _scoped_context(rule_id: String, proofs: Array, assumptions: Array) -> Dictionary:
	var first_context: Array[String] = proofs[0].context
	match rule_id:
		"impl_intro":
			return {
				"ok": true,
				"context": _context_remove(first_context, [assumptions[0].id]),
			}
		"or_elim":
			var disjunction = proofs[0]
			var case_a = proofs[1]
			var case_b = proofs[2]
			var a = assumptions[0]
			var b = assumptions[1]
			if _contains_context(disjunction.context, a.id) or _contains_context(disjunction.context, b.id):
				return _context_failure("or_elim: the disjunction depends on a case assumption")
			# A | A can be eliminated with one assumption shared by both
			# branches. That occurrence is discharged once, not twice.
			if a.id == b.id:
				return {
					"ok": true,
					"context": _context_union(
						disjunction.context,
						_context_union(
							_context_remove(case_a.context, [a.id]),
							_context_remove(case_b.context, [a.id])
						)
					),
				}
			if _contains_context(case_a.context, b.id):
				return _context_failure("or_elim: the left case uses the right case assumption")
			if _contains_context(case_b.context, a.id):
				return _context_failure("or_elim: the right case uses the left case assumption")
			var context := _context_union(
				disjunction.context,
				_context_union(
					_context_remove(case_a.context, [a.id]),
					_context_remove(case_b.context, [b.id])
				)
			)
			return {"ok": true, "context": context}
		"iff_intro":
			var forward = proofs[0]
			var backward = proofs[1]
			var a = assumptions[0]
			var b = assumptions[1]
			if _contains_context(forward.context, b.id):
				return _context_failure("iff_intro: the forward branch uses the backward assumption")
			if _contains_context(backward.context, a.id):
				return _context_failure("iff_intro: the backward branch uses the forward assumption")
			return {
				"ok": true,
				"context": _context_union(
					_context_remove(forward.context, [a.id]),
					_context_remove(backward.context, [b.id])
				),
			}
		"not_intro", "not_elim":
			var a = assumptions[0].id
			return {
				"ok": true,
				"context": _context_union(
					_context_remove(proofs[0].context, [a]),
					_context_remove(proofs[1].context, [a])
				),
			}
	return _context_failure("%s: no scoped context implementation" % rule_id)

func _context_failure(message: String) -> Dictionary:
	return {"ok": false, "error": message, "context": []}

func _context_union(first: Array, second: Array) -> Array[String]:
	var merged: Array[String] = first.duplicate()
	var seen: Dictionary = {}
	for item in merged:
		seen[item] = true
	for item in second:
		if not seen.has(item):
			seen[item] = true
			merged.append(item)
	return merged

func _context_remove(source: Array, removed: Array) -> Array[String]:
	var removal: Dictionary = {}
	for item in removed:
		removal[item] = true
	var result: Array[String] = []
	for item in source:
		if not removal.has(item):
			result.append(item)
	return result

func _contains_context(source: Array, item: String) -> bool:
	return source.has(item)

## Recursively validate every reachable derivation and the root/goal match.
func validate(root_id: String, goal: FormulaRes, require_closed: bool = true) -> ValidationResultRes:
	var errors: Array[String] = []
	if goal == null:
		errors.append("goal formula is missing")
		return _validation_failure(errors)

	var root := get_node(root_id)
	if root == null:
		errors.append("unknown root node id '%s'" % root_id)
		return _validation_failure(errors)

	var visited: Dictionary = {}
	var stack: Dictionary = {}
	_validate_node(root, visited, stack, errors)

	if not root.formula.equals(goal):
		errors.append(
			"root [%s] formula '%s' does not equal goal '%s'"
			% [root.id, root.formula.to_string(), goal.to_string()]
		)
	if require_closed and not root.context.is_empty():
		errors.append(
			"root [%s] has undischarged assumption(s): %s"
			% [root.id, _join_ids(root.context)]
		)

	if errors.is_empty():
		return _validation_success()
	return _validation_failure(errors)

## Re-derive one node from its premises, then recurse into those premises.
func _validate_node(
	node: ProofNodeRes,
	visited: Dictionary,
	stack: Dictionary,
	errors: Array[String]
) -> void:
	if node.rule_id == "premise" or node.rule_id == "assume":
		return
	if stack.has(node.id):
		errors.append("[%s] cycle detected in the proof tree" % node.id)
		return
	if visited.has(node.id):
		return

	stack[node.id] = true
	var premise_nodes: Array = []
	for premise_id in node.premise_ids:
		var premise_node := get_node(premise_id)
		if premise_node == null:
			errors.append(
				"[%s] %s references unknown proof/premise id '%s'"
				% [node.id, node.rule_id, premise_id]
			)
			continue
		premise_nodes.append(premise_node)
		_validate_node(premise_node, visited, stack, errors)
	stack.erase(node.id)
	visited[node.id] = true

	if premise_nodes.size() != node.premise_ids.size():
		return

	var premise_formulas: Array = []
	for premise_node in premise_nodes:
		premise_formulas.append(premise_node.formula)

	if RulesRes.is_scoped(node.rule_id):
		_validate_scoped_node(node, premise_nodes, errors)
		return

	var extra_formula = node.extra.get(ProofNodeRes.EXTRA_OTHER, null)
	var derivation := RulesRes.derive(node.rule_id, premise_formulas, extra_formula)
	if not derivation.ok:
		errors.append("[%s] %s: %s" % [node.id, node.rule_id, derivation.error])
		return
	if not derivation.formula.equals(node.formula):
		errors.append(
			"[%s] %s expected formula '%s' but node records '%s'"
			% [node.id, node.rule_id, derivation.formula.to_string(), node.formula.to_string()]
		)
		return

	var expected_context: Array[String] = []
	for premise_node in premise_nodes:
		expected_context = _context_union(expected_context, premise_node.context)
	if not _same_context(node.context, expected_context):
		errors.append(
			"[%s] %s context mismatch: expected %s, node records %s"
			% [node.id, node.rule_id, _join_ids(expected_context), _join_ids(node.context)]
		)

## Validate a discharging rule node from its proof branches and assumptions.
func _validate_scoped_node(
	node: ProofNodeRes,
	proof_nodes: Array,
	errors: Array[String]
) -> void:
	if proof_nodes.size() != RulesRes.proof_count(node.rule_id):
		errors.append("[%s] %s: wrong proof-branch count" % [node.id, node.rule_id])
		return
	var assumption_nodes: Array = []
	for assumption_id in node.discharged:
		var assumption_node := get_node(assumption_id)
		if assumption_node == null:
			errors.append(
				"[%s] %s discharges unknown assumption '%s'"
				% [node.id, node.rule_id, assumption_id]
			)
			return
		if assumption_node.rule_id != "assume":
			errors.append(
				"[%s] %s discharges [%s], which is not an assumption"
				% [node.id, node.rule_id, assumption_id]
			)
			return
		assumption_nodes.append(assumption_node)

	if assumption_nodes.size() != RulesRes.assumption_count(node.rule_id):
		errors.append("[%s] %s: wrong discharged-assumption count" % [node.id, node.rule_id])
		return

	var proof_formulas: Array = []
	for proof_node in proof_nodes:
		proof_formulas.append(proof_node.formula)
	var assumption_formulas: Array = []
	for assumption_node in assumption_nodes:
		assumption_formulas.append(assumption_node.formula)

	var derivation := ScopedRulesRes.derive(node.rule_id, proof_formulas, assumption_formulas)
	if not derivation.ok:
		errors.append("[%s] %s: %s" % [node.id, node.rule_id, derivation.error])
		return
	if not derivation.formula.equals(node.formula):
		errors.append(
			"[%s] %s expected formula '%s' but node records '%s'"
			% [node.id, node.rule_id, derivation.formula.to_string(), node.formula.to_string()]
		)

	var context_result := _scoped_context(node.rule_id, proof_nodes, assumption_nodes)
	if not bool(context_result["ok"]):
		errors.append("[%s] %s: %s" % [node.id, node.rule_id, context_result["error"]])
		return
	if not _same_context(node.context, context_result["context"]):
		errors.append(
			"[%s] %s context mismatch: expected %s, node records %s"
			% [
				node.id,
				node.rule_id,
				_join_ids(context_result["context"]),
				_join_ids(node.context)
			]
		)

func _same_context(first: Array, second: Array) -> bool:
	if first.size() != second.size():
		return false
	for item in first:
		if not second.has(item):
			return false
	return true

func _join_ids(ids: Array) -> String:
	var text := ""
	for index in range(ids.size()):
		if index > 0:
			text += ", "
		text += str(ids[index])
	return text

## Render the whole proof as an indented forest of node lines.
func to_text() -> String:
	if _order.is_empty():
		return "(empty proof tree)"

	var used_as_premise: Dictionary = {}
	for node_id in _order:
		var node: ProofNodeRes = _nodes[node_id]
		for premise_id in node.premise_ids:
			used_as_premise[premise_id] = true

	var roots: Array[String] = []
	for node_id in _order:
		if not used_as_premise.has(node_id):
			roots.append(node_id)
	if roots.is_empty():
		roots = _order.duplicate()

	var lines: Array[String] = []
	var expanded: Dictionary = {}
	for root_id in roots:
		_render_node(root_id, 0, expanded, lines)
	return _join_lines(lines)

## Depth-first pre-order rendering; repeated nodes become reference lines.
func _render_node(
	node_id: String,
	depth: int,
	expanded: Dictionary,
	lines: Array[String]
) -> void:
	var node := get_node(node_id)
	if node == null:
		return
	var indent := "  ".repeat(depth)
	if expanded.has(node_id):
		lines.append(indent + "[%s] %s  (see above)" % [node.id, node.formula.to_string()])
		return
	expanded[node_id] = true
	lines.append(indent + node.to_line())
	for premise_id in node.premise_ids:
		_render_node(premise_id, depth + 1, expanded, lines)

## Build a successful rule result for a newly created node.
func _rule_success(created: ProofNodeRes) -> RuleResultRes:
	var result := RuleResultRes.new()
	result.ok = true
	result.node = created
	return result

## Build a failed rule result; no node is created.
func _rule_failure(message: String) -> RuleResultRes:
	var result := RuleResultRes.new()
	result.ok = false
	result.error = message
	return result

## Build a successful validation result.
func _validation_success() -> ValidationResultRes:
	var result := ValidationResultRes.new()
	result.ok = true
	return result

## Build a failed validation result.
func _validation_failure(problems: Array[String]) -> ValidationResultRes:
	var result := ValidationResultRes.new()
	result.ok = false
	result.errors = problems.duplicate()
	return result

## Join pre-rendered lines with newlines without relying on array conversion.
func _join_lines(lines: Array[String]) -> String:
	var text := ""
	for index in range(lines.size()):
		if index > 0:
			text += "\n"
		text += lines[index]
	return text
