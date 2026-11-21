extends RefCounted

## Convert the nested UI blocks into a ProofTree and run the formal validator.
## This reuses the same rule semantics as the CLI and catches any adapter
## mismatch between the live OUT labels and the underlying proof.

const FormulaRes = preload("res://logic/formula.gd")
const ProofTreeRes = preload("res://logic/proof_tree.gd")
const RulesRes = preload("res://logic/rules.gd")
const ValidationResultRes = preload("res://logic/validation_result.gd")

## Build and validate the proof rooted at [param goal_block].
static func validate(goal_block, goal_formula: FormulaRes, require_closed: bool = true) -> ValidationResultRes:
	if goal_formula == null:
		return _failure("goal formula is missing")
	if goal_block == null or not is_instance_valid(goal_block):
		return _failure("no final block is linked to the goal")
	if not goal_block.has_method("refresh"):
		return _failure("goal target is not a proof block")

	goal_block.refresh()

	var tree := ProofTreeRes.new()
	var state := {"ok": true, "error": "", "visiting": {}}
	var memo := {}
	var assumption_memo := {}
	var root_id := _build_block(goal_block, tree, memo, assumption_memo, state)
	if not bool(state["ok"]) or root_id.is_empty():
		return _failure(str(state["error"]))
	return tree.validate(root_id, goal_formula, require_closed)

## Post-order build: premises become ProofTree premises, rule blocks apply rules.
static func _build_block(
	block,
	tree: ProofTreeRes,
	memo: Dictionary,
	assumption_memo: Dictionary,
	state: Dictionary
) -> String:
	if block == null or not is_instance_valid(block):
		_fail(state, "a referenced block is missing")
		return ""

	if block.has_method("is_assumption_block") and block.is_assumption_block():
		var group: int = block.get_assumption_group()
		var group_key := "assumption:%d" % group
		if assumption_memo.has(group_key):
			return str(assumption_memo[group_key])
		var formula = block.get_result_formula()
		if formula == null:
			_fail(state, "an assumption block is incomplete")
			return ""
		var assumption_node := tree.add_assumption(formula)
		assumption_memo[group_key] = assumption_node.id
		return assumption_node.id

	var key: int = block.get_instance_id()
	if memo.has(key):
		return str(memo[key])
	if state["visiting"].has(key):
		_fail(state, "cycle detected in the block tree")
		return ""
	state["visiting"][key] = true

	var node_id := ""
	if block.has_method("is_scope_block") and block.is_scope_block():
		node_id = _build_scope(block, tree, memo, assumption_memo, state)
	elif block.has_method("get_rule_id"):
		var rule_id: String = str(block.get_rule_id())
		if RulesRes.is_scoped(rule_id):
			node_id = _build_scoped(block, rule_id, tree, memo, assumption_memo, state)
		else:
			var input_ids: Array[String] = []
			for input_block in block.get_input_blocks():
				if input_block == null:
					_fail(state, "%s has an empty input socket" % rule_id)
					break
				var input_id := _build_block(input_block, tree, memo, assumption_memo, state)
				if input_id.is_empty():
					break
				input_ids.append(input_id)
			if bool(state["ok"]):
				var extra = null
				if RulesRes.takes_extra(rule_id):
					extra = block.get_extra_formula()
				var applied = tree.apply_rule(rule_id, input_ids, extra)
				if not applied.ok:
					_fail(state, "%s: %s" % [rule_id, applied.error])
				else:
					node_id = applied.node.id
	else:
		var formula = block.get_result_formula()
		if formula == null:
			_fail(state, "a premise block is incomplete")
		else:
			node_id = tree.add_premise(formula).id

	state["visiting"].erase(key)
	if not node_id.is_empty():
		memo[key] = node_id
	return node_id

static func _build_scope(
	block,
	tree: ProofTreeRes,
	memo: Dictionary,
	assumption_memo: Dictionary,
	state: Dictionary
) -> String:
	var proof_block = block.get_scope_proof_block()
	if proof_block == null:
		_fail(state, "assumption scope has no proof branch")
		return ""
	var proof_id := _build_block(proof_block, tree, memo, assumption_memo, state)
	if proof_id.is_empty():
		return ""
	var group: int = block.get_assumption_group()
	var group_key := "assumption:%d" % group
	var assumption_id := ""
	if assumption_memo.has(group_key):
		assumption_id = str(assumption_memo[group_key])
	else:
		var formula = block.get_scope_assumption_formula()
		if formula == null:
			_fail(state, "assumption scope has no hypothesis formula")
			return ""
		var assumption_node := tree.add_assumption(formula)
		assumption_id = assumption_node.id
		assumption_memo[group_key] = assumption_id
	var applied = tree.apply_scoped("impl_intro", [proof_id], [assumption_id])
	if not applied.ok:
		_fail(state, "assumption scope: %s" % applied.error)
		return ""
	return applied.node.id

static func _build_scoped(
	block,
	rule_id: String,
	tree: ProofTreeRes,
	memo: Dictionary,
	assumption_memo: Dictionary,
	state: Dictionary
) -> String:
	var proof_ids: Array[String] = []
	for proof_block in block.get_proof_blocks():
		if proof_block == null:
			_fail(state, "%s has an empty proof input" % rule_id)
			return ""
		var proof_id := _build_block(proof_block, tree, memo, assumption_memo, state)
		if proof_id.is_empty():
			return ""
		proof_ids.append(proof_id)
	if not bool(state["ok"]):
		return ""

	var assumption_ids: Array[String] = []
	for assumption_block in block.get_selected_assumption_blocks():
		if assumption_block == null:
			_fail(state, "%s has an unselected assumption edge" % rule_id)
			return ""
		var assumption_id := _build_block(
			assumption_block,
			tree,
			memo,
			assumption_memo,
			state
		)
		if assumption_id.is_empty():
			return ""
		assumption_ids.append(assumption_id)

	var applied = tree.apply_scoped(rule_id, proof_ids, assumption_ids)
	if not applied.ok:
		_fail(state, "%s: %s" % [rule_id, applied.error])
		return ""
	return applied.node.id

## Record the first build error.
static func _fail(state: Dictionary, message: String) -> void:
	if bool(state["ok"]):
		state["ok"] = false
		state["error"] = message

## Build a ValidationResult representing an adapter/build failure.
static func _failure(message: String) -> ValidationResultRes:
	var result := ValidationResultRes.new()
	result.ok = false
	var errors: Array[String] = [message]
	result.errors = errors
	return result
