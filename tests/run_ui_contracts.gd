extends SceneTree

## Data-driven contracts for the main UI surface. These are intentionally
## behavioural rather than implementation-specific: they exercise the same
## level-loading, palette and block-factory entry points a refactor must keep.

const ParserRes = preload("res://logic/formula_parser.gd")
const RulesRes = preload("res://logic/rules.gd")
const LevelBankRes = preload("res://ui/level_bank.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	await _run()
	print("UI CONTRACTS RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("UI CONTRACT FAILED: " + label)

func _f(text: String):
	return ParserRes.new(text).parse().formula

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await process_frame
	await process_frame

	_check_factories(main)
	await _check_all_levels(main)

	main.queue_free()
	await process_frame

func _check_factories(main) -> void:
	var chip = main.create_formula_block(_f("P -> Q"))
	_check(chip != null, "factory: formula block")
	if chip != null:
		_check(chip.get_result_formula().to_string() == "P -> Q", "factory: formula preserved")
		chip.free()

	var a = main.create_assumption_block(_f("A"))
	var b = main.create_assumption_block(_f("A"))
	_check(a != null and b != null, "factory: assumption blocks")
	if a != null and b != null:
		_check(a.get_assumption_group() != b.get_assumption_group(), "factory: independent ASSUME groups")
		var copy = main.duplicate_block(a)
		_check(copy != null, "factory: assumption copy")
		if copy != null:
			_check(
				copy.get_assumption_group() == a.get_assumption_group(),
				"factory: copy keeps its assumption group"
			)
			copy.free()
		a.free()
		b.free()

	for rule_id in RulesRes.palette_ids():
		var block = main.create_rule_block(str(rule_id))
		_check(block != null, "factory: rule card " + str(rule_id))
		if block == null:
			continue
		_check(str(block.get_rule_id()) == str(rule_id), "factory: rule id " + str(rule_id))
		var expected := (
			RulesRes.proof_count(rule_id)
			if RulesRes.is_scoped(rule_id)
			else RulesRes.arity(rule_id)
		)
		_check(block.sockets.size() == expected, "factory: socket count " + str(rule_id))
		block.free()

	_check(main.create_rule_block("not_a_rule") == null, "factory: unknown rule rejected")

func _check_all_levels(main) -> void:
	var levels := LevelBankRes.all_levels()
	_check(levels.size() == 61, "curriculum: 61 levels")
	for level in levels:
		var level_id := str(level.get("id", ""))
		var chapter_id := str(level.get("chapter_id", ""))
		main.open_level_by_id(level_id)
		await process_frame
		_check(main._current_level_id == level_id, "level: current id " + level_id)
		_check(main._current_chapter_id == chapter_id, "level: chapter id " + level_id)
		_check(
			main._current_level_pos == int(level.get("index_in_chapter", -1)),
			"level: position " + level_id
		)
		var expected_goal := ParserRes.new(str(level.get("goal", ""))).parse()
		_check(
			expected_goal.ok
			and main._goal_formula != null
			and main._goal_formula.equals(expected_goal.formula),
			"level: goal " + level_id
		)

		var premises: Array = level.get("premises", [])
		var premise_items: Array = main._premise_flow.get_children()
		_check(premise_items.size() == premises.size(), "level: premise count " + level_id)
		for index in range(min(premise_items.size(), premises.size())):
			var expected := ParserRes.new(str(premises[index])).parse().formula
			var actual = premise_items[index].formula
			_check(
				actual != null and actual.equals(expected),
				"level: premise %d %s" % [index, level_id]
			)

		var rules := LevelBankRes.chapter_rules(chapter_id)
		var rule_items: Array = main._rules_row.get_children()
		_check(rule_items.size() == rules.size(), "level: rule shelf count " + level_id)
		for index in range(min(rule_items.size(), rules.size())):
			_check(
				str(rule_items[index].rule_id) == str(rules[index]),
				"level: rule shelf %d %s" % [index, level_id]
			)
		_check(
			main._assume_button.visible == LevelBankRes.allow_assumptions(chapter_id),
			"level: ASSUME visibility " + level_id
		)
