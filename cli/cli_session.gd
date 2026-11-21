extends RefCounted

## Stateful command processor for one proof session.
##
## execute() parses exactly one command line and returns a structured
## CommandResult. It never prints; cli/main.gd and the test runner decide how
## to display the returned lines.

const FormulaRes = preload("res://logic/formula.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const ProofTreeRes = preload("res://logic/proof_tree.gd")
const CommandResultRes = preload("res://cli/command_result.gd")
const RulesRes = preload("res://logic/rules.gd")

## Proof tree owned by this session.
var tree: ProofTreeRes
## Current goal formula; null until the goal command succeeds.
var goal: FormulaRes = null

func _init() -> void:
	tree = ProofTreeRes.new()

## Execute one command line, returning display lines and structured data.
func execute(line: String) -> CommandResultRes:
	var trimmed := line.strip_edges()
	if trimmed.is_empty() or trimmed.begins_with("#"):
		return _ignored()

	var parts := _split_command(trimmed)
	var command: String = parts["name"]
	var rest: String = parts["rest"]
	match command:
		"premise":
			return _cmd_premise(rest)
		"assume":
			return _cmd_assume(rest)
		"goal":
			return _cmd_goal(rest)
		"apply":
			return _cmd_apply(rest)
		"tree":
			return _cmd_tree()
		"validate":
			return _cmd_validate()
		"help":
			return _cmd_help()
		"quit":
			return _cmd_quit()
	return _failure(
		"unknown command '%s'; type 'help' for usage" % command
	)

## Split "command rest" at the first whitespace.
func _split_command(line: String) -> Dictionary:
	var index := -1
	for position in range(line.length()):
		var character := line.substr(position, 1)
		if character == " " or character == "\t":
			index = position
			break
	if index < 0:
		return {"name": line, "rest": ""}
	return {
		"name": line.substr(0, index),
		"rest": line.substr(index + 1).strip_edges(),
	}

## premise <formula>
func _cmd_premise(rest: String) -> CommandResultRes:
	if rest.is_empty():
		return _failure("premise: missing formula; usage: premise <formula>")
	var parsed := ParserRes.new(rest).parse()
	if not parsed.ok:
		return _failure("premise: parse error: %s" % parsed.error)
	var node := tree.add_premise(parsed.formula)
	var lines: Array[String] = [node.to_line()]
	var result := _success(lines)
	result.node = node
	return result

## assume <formula>
func _cmd_assume(rest: String) -> CommandResultRes:
	if rest.is_empty():
		return _failure("assume: missing formula; usage: assume <formula>")
	var parsed := ParserRes.new(rest).parse()
	if not parsed.ok:
		return _failure("assume: parse error: %s" % parsed.error)
	var node := tree.add_assumption(parsed.formula)
	var lines: Array[String] = [node.to_line()]
	var result := _success(lines)
	result.node = node
	return result

## goal <formula>
func _cmd_goal(rest: String) -> CommandResultRes:
	if rest.is_empty():
		return _failure("goal: missing formula; usage: goal <formula>")
	var parsed := ParserRes.new(rest).parse()
	if not parsed.ok:
		return _failure("goal: parse error: %s" % parsed.error)
	goal = parsed.formula
	var lines: Array[String] = ["goal: " + goal.to_string()]
	return _success(lines)

## apply <rule> <id1> [id2] [extra_formula]
func _cmd_apply(rest: String) -> CommandResultRes:
	var normalized := rest.replace("\t", " ").strip_edges()
	if normalized.is_empty():
		return _failure(
			"apply: missing rule id; usage: apply <rule> <id1> [id2] [extra_formula]"
		)

	var tokens := normalized.split(" ", false)
	if tokens.is_empty():
		return _failure(
			"apply: missing rule id; usage: apply <rule> <id1> [id2] [extra_formula]"
		)

	var rule_id: String = tokens[0]
	if not RulesRes.RULES.has(rule_id):
		return _failure(
			"apply: unknown rule '%s'; available rules: %s"
			% [rule_id, RulesRes.rule_names_text()]
		)
	if RulesRes.is_scoped(rule_id):
		return _cmd_apply_scoped(rule_id, tokens)

	var expected_arity := RulesRes.arity(rule_id)

	var supplied_ids := tokens.size() - 1
	if supplied_ids < expected_arity:
		return _failure(
			"apply %s: expected %d premise id(s), got %d"
			% [rule_id, expected_arity, supplied_ids]
		)

	var premise_ids: Array[String] = []
	for index in range(1, 1 + expected_arity):
		premise_ids.append(tokens[index])

	var extra_text := _join_tokens(tokens, 1 + expected_arity)
	var extra_formula = null
	if extra_text != "":
		if not RulesRes.takes_extra(rule_id):
			return _failure(
				"apply %s: this rule takes no extra formula; unexpected '%s'"
				% [rule_id, extra_text]
			)
		var parsed := ParserRes.new(extra_text).parse()
		if not parsed.ok:
			return _failure(
				"apply %s: extra formula parse error: %s" % [rule_id, parsed.error]
			)
		extra_formula = parsed.formula

	var applied := tree.apply_rule(rule_id, premise_ids, extra_formula)
	if not applied.ok:
		return _failure(applied.error)

	var lines: Array[String] = [applied.node.to_line()]
	var result := _success(lines)
	result.node = applied.node
	return result

## apply for a rule with proof branches and explicit assumption binders.
func _cmd_apply_scoped(rule_id: String, tokens: PackedStringArray) -> CommandResultRes:
	var layout := RulesRes.scoped_cli_layout(rule_id)
	if layout.is_empty():
		return _failure("apply %s: missing scoped argument layout" % rule_id)
	if tokens.size() != 1 + layout.size():
		return _failure(
			"apply %s: expected %d argument(s); usage: apply %s %s"
			% [
				rule_id,
				layout.size(),
				rule_id,
				" ".join(layout),
			]
		)

	var proof_ids: Array[String] = []
	var assumption_ids: Array[String] = []
	for index in range(layout.size()):
		var token := str(tokens[index + 1])
		if str(layout[index]) == "assumption":
			assumption_ids.append(token)
		else:
			proof_ids.append(token)

	var applied := tree.apply_scoped(rule_id, proof_ids, assumption_ids)
	if not applied.ok:
		return _failure(applied.error)

	var lines: Array[String] = [applied.node.to_line()]
	var result := _success(lines)
	result.node = applied.node
	return result

## tree
func _cmd_tree() -> CommandResultRes:
	var text := tree.to_text()
	var lines: Array[String] = []
	for rendered in text.split("\n"):
		lines.append(rendered)
	return _success(lines)

## validate
func _cmd_validate() -> CommandResultRes:
	if goal == null:
		return _failure("validate: goal is not set; use 'goal <formula>' first")
	var root_id := tree.last_rule_node_id()
	if root_id.is_empty():
		return _failure("validate: no rule node to validate; apply a rule first")

	var validation := tree.validate(root_id, goal)
	var root := tree.get_node(root_id)
	var lines: Array[String] = []
	if validation.ok:
		lines.append(
			"valid: [%s] %s proves goal %s"
			% [root.id, root.formula.to_string(), goal.to_string()]
		)
	else:
		lines.append("invalid: %d error(s)" % validation.errors.size())
		for problem in validation.errors:
			lines.append("  " + problem)

	var result := _success(lines)
	result.ok = validation.ok
	result.validation = validation
	if not validation.ok:
		result.error = _join_lines(validation.errors)
	return result

## help
func _cmd_help() -> CommandResultRes:
	var lines: Array[String] = [
		"Commands:",
		"  premise <formula>                     add a premise (p1, p2, ...)",
		"  assume <formula>                      add an open assumption (a1, a2, ...)",
		"  goal <formula>                        set the goal formula",
		"  apply <rule> <args...>                apply a rule (n1, n2, ...)",
		"  tree                                  render the current proof tree",
		"  validate                              check the last rule node against the goal",
		"  help                                  show this help",
		"  quit                                  exit",
		"Rules:",
		"  impl_elim <id> <id>                   A, A -> B  =>  B",
		"  and_elim_left <id>                    A & B      =>  A",
		"  and_elim_right <id>                   A & B      =>  B",
		"  and_intro <id> <id>                   A, B       =>  A & B",
		"  or_intro_left <id> <formula>          A, B       =>  A | B",
		"  or_intro_right <id> <formula>         B, A       =>  A | B",
		"  ds <id> <id>                          A | B, ~A  =>  B",
		"  or_elim_impl <id> <id> <id>           A | B, A -> C, B -> C => C",
		"  iff_intro_impl <id> <id>              A -> B, B -> A => A <-> B",
		"  not_intro_impl <id> <id>              A -> B, A -> ~B => ~A",
		"  not_elim_impl <id> <id>               ~A -> B, ~A -> ~B => A",
		"  iff_elim <id> <id>                    A, A <-> B =>  B",
		"  lem <formula>                         P          =>  P | ~P",
		"  double_neg_elim <id>                  ~~A        =>  A",
		"  double_neg_intro <id>                 A          =>  ~~A",
		"Scoped rules (assumption ids bind proof branches):",
		"  impl_intro <assumption> <proof>       [A] ... B  =>  A -> B",
		"  or_elim <disj> <assumption> <proof> <assumption> <proof>",
		"                                        A | B, [A]...C, [B]...C => C",
		"  iff_intro <assumption> <proof> <assumption> <proof>",
		"                                        [A]...B, [B]...A => A <-> B",
		"  not_intro <assumption> <proof> <proof>",
		"                                        [A]...B, ~B => ~A",
		"  not_elim <assumption> <proof> <proof>",
		"                                        [~A]...B, ~B => A",
		"The extra formula is the other side, e.g. apply or_intro_left p1 B.",
		"Assumption ids are produced by 'assume'; a proof may be any node id.",
		"Formulas use ~ & | -> <-> and parentheses; -> and <-> are right-associative.",
	]
	return _success(lines)

## quit
func _cmd_quit() -> CommandResultRes:
	var lines: Array[String] = ["bye"]
	var result := _success(lines)
	result.quit_requested = true
	return result

## Build a successful command result with display lines.
func _success(output_lines: Array[String]) -> CommandResultRes:
	var result := CommandResultRes.new()
	result.ok = true
	result.lines = output_lines.duplicate()
	return result

## Build a failed command result whose only display line is an error.
func _failure(message: String) -> CommandResultRes:
	var result := CommandResultRes.new()
	result.ok = false
	result.error = message
	var output: Array[String] = ["error: " + message]
	result.lines = output
	return result

## Build a no-op result for blank lines and comments.
func _ignored() -> CommandResultRes:
	var result := CommandResultRes.new()
	result.ok = true
	return result

## Join token indices [from_index, size) with single spaces.
func _join_tokens(tokens: PackedStringArray, from_index: int) -> String:
	var text := ""
	for index in range(from_index, tokens.size()):
		if text != "":
			text += " "
		text += tokens[index]
	return text

## Join array entries with newlines for an aggregate error field.
func _join_lines(lines: Array[String]) -> String:
	var text := ""
	for index in range(lines.size()):
		if index > 0:
			text += "\n"
		text += lines[index]
	return text
