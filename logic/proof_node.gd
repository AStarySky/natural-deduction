extends RefCounted

## One immutable entry in a proof tree.

const FormulaRes = preload("res://logic/formula.gd")
const RulesRes = preload("res://logic/rules.gd")

## Dictionary key used by or_intro_* to record the explicitly supplied
## formula on the other side of the disjunction.
const EXTRA_OTHER: String = "other"

## Unique node id: p1, p2, ... for premises and n1, n2, ... for rule nodes.
var id: String = ""
## Formula established by this node.
var formula: FormulaRes = null
## Rule that produced the node; premises use the literal "premise".
var rule_id: String = ""
## Source node ids in the rule's canonical slot order.
var premise_ids: Array[String] = []
## Rule-specific extra data; or_intro_* stores the other side under "other".
var extra: Dictionary = {}
## Undischarged assumption ids this node depends on.
var context: Array[String] = []
## Assumption ids discharged by this rule (empty for simple rules).
var discharged: Array[String] = []

func _init(
	p_id: String,
	p_formula: FormulaRes,
	p_rule_id: String,
	p_premise_ids: Array[String],
	p_extra: Dictionary = {},
	p_context: Array[String] = [],
	p_discharged: Array[String] = []
) -> void:
	id = p_id
	formula = p_formula
	rule_id = p_rule_id
	premise_ids = p_premise_ids.duplicate()
	extra = p_extra.duplicate()
	context = p_context.duplicate()
	discharged = p_discharged.duplicate()

## Render this node in the one-line proof-tree/CLI format.
func to_line() -> String:
	var line := "[%s] %s  (rule: %s" % [id, formula.to_string(), rule_id]
	if not premise_ids.is_empty():
		var label := "proofs" if RulesRes.is_scoped(rule_id) else "premises"
		line += ", %s: %s" % [label, _join_ids(premise_ids)]
	if extra.has(EXTRA_OTHER):
		var other: FormulaRes = extra[EXTRA_OTHER]
		if other != null:
			line += ", extra: " + other.to_string()
	if not discharged.is_empty():
		line += ", discharged: " + _join_ids(discharged)
	if not context.is_empty():
		line += ", context: " + _join_ids(context)
	line += ")"
	return line

## Join node ids with commas without relying on PackedStringArray conversion.
func _join_ids(ids: Array[String]) -> String:
	var text := ""
	for index in range(ids.size()):
		if index > 0:
			text += ", "
		text += ids[index]
	return text
