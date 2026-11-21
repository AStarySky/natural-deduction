extends SceneTree

## Validates the whole chapter curriculum:
## - seven chapters, each with six core levels and optional challenges
## - every level has metadata and a solution
## - every solution validates through the same CLI/ProofTree path as the UI
## - solutions only use rules unlocked by their chapter

const LevelBankRes = preload("res://ui/level_bank.gd")
const SolutionsRes = preload("res://tests/level_solutions.gd")
const CliSessionRes = preload("res://cli/cli_session.gd")

const FORBIDDEN_RULES := [
	"ds",
	"lem",
	"not_elim_impl",
	"or_elim",
	"iff_intro",
	"not_intro",
	"not_elim",
]

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run()
	print("CURRICULUM RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _run() -> void:
	_check(LevelBankRes.CHAPTERS.size() == 7, "curriculum has seven chapters")
	_check(LevelBankRes.all_levels().size() == 61, "curriculum has 61 levels")
	_check(LevelBankRes.chapter_rules("ch1").size() == 4, "chapter 1 palette has four cards")
	_check(LevelBankRes.chapter_rules("ch6").size() == 9, "chapter 6 palette has nine cards")
	_check(LevelBankRes.chapter_rules("ch7").size() == 9, "chapter 7 palette has nine cards")
	_check(LevelBankRes.chapter_new_rules("ch7").is_empty(), "chapter 7 introduces no new cards")
	_check(
		not LevelBankRes.unlocked_rule_ids("ch1-1").has("impl_intro"),
		"chapter 1 has no assumption rule"
	)
	_check(
		LevelBankRes.unlocked_rule_ids("ch2-1").has("impl_intro"),
		"chapter 2 unlocks assumption introduction"
	)

	var seen_ids: Dictionary = {}
	for chapter in LevelBankRes.CHAPTERS:
		var chapter_id := str(chapter.get("id", ""))
		var core_count := 0
		var optional_count := 0
		for level in chapter.get("levels", []):
			if bool(level.get("optional", false)):
				optional_count += 1
			else:
				core_count += 1
		_check(core_count == 6, "%s has six core levels" % chapter_id)
		var expected_optional := 1 if chapter_id == "ch7" else 3
		_check(
			optional_count == expected_optional,
			"%s has %d challenge levels" % [chapter_id, expected_optional]
		)
		_check(not str(chapter.get("blurb", "")).is_empty(), "%s has a blurb" % chapter_id)
		_check(not LevelBankRes.chapter_rules(chapter_id).is_empty(), "%s has palette rules" % chapter_id)

	for level in LevelBankRes.all_levels():
		var level_id := str(level.get("id", ""))
		_check(not level_id.is_empty(), "level has a stable id")
		_check(not seen_ids.has(level_id), "level id is unique: %s" % level_id)
		seen_ids[level_id] = true
		_check(not str(level.get("teaches", "")).is_empty(), "%s has a teaching tag" % level_id)
		_check(level.has("premises"), "%s has premises" % level_id)
		_check(not str(level.get("goal", "")).is_empty(), "%s has a goal" % level_id)
		_validate_level(level)

	print(
		"Checked %d levels across %d chapters." % [
			seen_ids.size(),
			LevelBankRes.CHAPTERS.size(),
		]
	)

func _validate_level(level: Dictionary) -> void:
	var level_id := str(level.get("id", ""))
	var solution: Array = SolutionsRes.SOLUTIONS.get(level_id, [])
	_check(not solution.is_empty(), "%s has a solution script" % level_id)
	if solution.is_empty():
		return

	var session := CliSessionRes.new()
	for premise in level.get("premises", []):
		session.execute("premise " + str(premise))
	session.execute("goal " + str(level.get("goal", "")))

	var last = null
	for command in solution:
		last = session.execute(str(command))
	if str(solution[solution.size() - 1]) != "validate":
		last = session.execute("validate")

	if last == null:
		_check(false, "%s solution produced no result" % level_id)
		return
	if last.validation == null:
		_check(false, "%s solution did not return a validation" % level_id)
		return
	_check(last.validation.ok, "%s solution validates%s" % [level_id, _error_suffix(last.validation)])

	var allowed := LevelBankRes.unlocked_rule_ids(level_id)
	for node_id in session.tree.node_ids():
		var node = session.tree.get_node(node_id)
		var rule_id := str(node.rule_id)
		if rule_id == "premise" or rule_id == "assume":
			continue
		_check(allowed.has(rule_id), "%s uses unlocked rule '%s'" % [level_id, rule_id])
		_check(
			not FORBIDDEN_RULES.has(rule_id),
			"%s avoids CLI-only rule '%s'" % [level_id, rule_id]
		)

func _error_suffix(validation) -> String:
	if validation == null or validation.errors.is_empty():
		return ""
	var text := ""
	for error in validation.errors:
		if not text.is_empty():
			text += " | "
		text += str(error)
	return ": " + text

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("CURRICULUM CHECK FAILED: " + label)
