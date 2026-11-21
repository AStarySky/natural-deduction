extends SceneTree

## Headless acceptance runner for scripts A-G in tests/mur_cli_script.txt.
##
## Run:
##   godot --headless --path <project> -s res://tests/run_cli_script.gd
##
## Each "# === Script X" header starts a fresh CliSession, because the
## sections are independent proofs and reuse the same pN/nN ids.

const CliSessionRes = preload("res://cli/cli_session.gd")

const DEFAULT_SCRIPT := "res://tests/mur_cli_script.txt"
const HEADER_PREFIX := "# === Script "
const SECTION_LETTERS := ["A", "B", "C", "D", "E", "F", "G"]

var _check_count: int = 0
var _failure_count: int = 0

## MainLoop entry: run all sections, print a summary, exit nonzero on failure.
func _initialize() -> void:
	var script_path := DEFAULT_SCRIPT
	var args := OS.get_cmdline_user_args()
	var index := 0
	while index < args.size():
		if args[index] == "--file" and index + 1 < args.size():
			script_path = args[index + 1]
			index += 2
			continue
		index += 1
	var exit_code := _run(script_path)
	quit(exit_code)

## Load, execute and assert the whole multi-session script file.
func _run(script_path: String) -> int:
	var file := FileAccess.open(script_path, FileAccess.READ)
	if file == null:
		print(
			"FAIL: cannot open script '%s' (error %d)"
			% [script_path, FileAccess.get_open_error()]
		)
		return 1
	var text := file.get_as_text()
	file.close()
	if not text.is_empty() and text.unicode_at(0) == 0xFEFF:
		text = text.substr(1)

	var sections := _parse_sections(text)
	for letter in sections.keys():
		if not SECTION_LETTERS.has(str(letter)):
			_fail("unexpected section header for '%s'" % str(letter))

	var passed_sections := 0
	for letter in SECTION_LETTERS:
		print("")
		print("--- Script %s ---" % letter)
		if not sections.has(letter):
			_fail("missing section %s" % letter)
			print("FAIL Script %s" % letter)
			continue

		var commands: Array = sections[letter]
		var session := CliSessionRes.new()
		var results: Array = []
		for command in commands:
			var result := session.execute(str(command))
			results.append(result)
			print("> " + str(command))
			for line in result.lines:
				print("  " + str(line))

		var failures_before := _failure_count
		_check_script(letter, results, session)
		if _failure_count == failures_before:
			passed_sections += 1
			print("PASS Script %s" % letter)
		else:
			print("FAIL Script %s" % letter)

	print("")
	print(
		"RESULT: %d/%d scripts passed; %d checks, %d failed"
		% [passed_sections, SECTION_LETTERS.size(), _check_count, _failure_count]
	)
	return 0 if _failure_count == 0 else 1

## Split the file into ordered, independent command sections.
func _parse_sections(text: String) -> Dictionary:
	var sections: Dictionary = {}
	var current := ""
	var normalized := text.replace("\r\n", "\n").replace("\r", "\n")
	for raw_line in normalized.split("\n"):
		var line := str(raw_line).strip_edges()
		if line.begins_with(HEADER_PREFIX):
			var rest := line.substr(HEADER_PREFIX.length())
			if rest.is_empty():
				_fail("malformed section header: %s" % line)
				current = ""
				continue
			current = rest.substr(0, 1)
			if sections.has(current):
				_fail("duplicate section header for '%s'" % current)
			else:
				sections[current] = []
		elif line.is_empty() or line.begins_with("#"):
			continue
		elif current == "":
			_fail("command outside any section: %s" % line)
		else:
			var commands: Array = sections[current]
			commands.append(line)
	return sections

## Dispatch the spec assertions for one script section.
func _check_script(letter: String, results: Array, session: CliSessionRes) -> void:
	match letter:
		"A":
			_check_a(results)
		"B":
			_check_b(results)
		"C":
			_check_c(results)
		"D":
			_check_d(results)
		"E":
			_check_e(results)
		"F":
			_check_f(results)
		"G":
			_check_g(results, session)
		_:
			_fail("no assertion set for script '%s'" % letter)

## A: two modus ponens steps produce B and C; validate succeeds; tree shows n2.
func _check_a(results: Array) -> void:
	if not _require_count(results, 8, "A"):
		return
	_check(results[0].ok and results[0].node.formula.to_string() == "A", "A: p1 should be A")
	_check(results[1].ok and results[1].node.formula.to_string() == "A -> B", "A: p2 should be A -> B")
	_check(results[2].ok and results[2].node.formula.to_string() == "B -> C", "A: p3 should be B -> C")
	_check(results[3].ok, "A: goal command should succeed")
	_check(
		results[4].ok and results[4].node != null and results[4].node.formula.to_string() == "B",
		"A: first impl_elim should derive B"
	)
	_check(
		results[5].ok and results[5].node != null and results[5].node.formula.to_string() == "C",
		"A: second impl_elim should derive C"
	)
	_check(
		results[6].validation != null and results[6].validation.ok,
		"A: validate should report ok"
	)
	_check(results[6].ok, "A: validate command result should mirror validation.ok")
	var tree_text := _join_lines(results[7].lines)
	_check(tree_text.contains("[n2] C"), "A: tree should contain [n2] C")
	_check(tree_text.count("impl_elim") >= 2, "A: tree should contain two impl_elim derivations")

## B: and_intro produces A & (A -> B); validate rejects it against goal B.
func _check_b(results: Array) -> void:
	if not _require_count(results, 5, "B"):
		return
	_check(
		results[3].ok and results[3].node != null and results[3].node.formula.to_string() == "A & (A -> B)",
		"B: and_intro should derive A & (A -> B)"
	)
	_check(results[4].validation != null, "B: validate should return a ValidationResult")
	if results[4].validation == null:
		return
	_check(not results[4].validation.ok, "B: validate should reject the proof")
	_check(not results[4].ok, "B: validate command ok should mirror validation.ok")
	var error_text := _join_lines(results[4].validation.errors)
	_check(error_text.contains("A & (A -> B)"), "B: error should name the root formula")
	_check(error_text.contains("goal 'B'"), "B: error should name the goal B")

## C: impl_elim on A and B must fail with the expected matching error.
func _check_c(results: Array) -> void:
	if not _require_count(results, 3, "C"):
		return
	_check(not results[2].ok, "C: impl_elim should fail")
	var error_text: String = results[2].error
	_check(error_text.contains("impl_elim"), "C: error should name impl_elim")
	_check(error_text.contains("A -> ?"), "C: error should mention the A -> ? form")
	_check(error_text.contains("? -> ?"), "C: error should mention the ? -> ? form")
	_check(error_text.contains("'A'") and error_text.contains("'B'"), "C: error should show actual premises")

## D: conjunction introduction/elimination chain validates against goal B.
func _check_d(results: Array) -> void:
	if not _require_count(results, 6, "D"):
		return
	_check(results[3].ok and results[3].node != null and results[3].node.formula.to_string() == "A & B", "D: and_intro should derive A & B")
	_check(results[4].ok and results[4].node != null and results[4].node.formula.to_string() == "B", "D: and_elim_right should derive B")
	_check(results[5].validation != null and results[5].validation.ok, "D: validate should report ok")

## E: or_intro_left without the extra formula must fail and name the other side.
func _check_e(results: Array) -> void:
	if not _require_count(results, 2, "E"):
		return
	_check(not results[1].ok, "E: or_intro_left should fail without extra formula")
	var error_text: String = results[1].error
	_check(error_text.contains("missing extra formula"), "E: error should mention missing extra formula")
	_check(error_text.contains("other side"), "E: error should mention the other side")

## F: or_intro_left with extra B derives A | B; validate succeeds.
func _check_f(results: Array) -> void:
	if not _require_count(results, 4, "F"):
		return
	_check(results[2].ok and results[2].node != null and results[2].node.formula.to_string() == "A | B", "F: or_intro_left should derive A | B")
	_check(results[3].validation != null and results[3].validation.ok, "F: validate should report ok")

## G: both malformed commands fail readably; nothing is created.
func _check_g(results: Array, session: CliSessionRes) -> void:
	if not _require_count(results, 2, "G"):
		return
	_check(not results[0].ok, "G: malformed premise should fail")
	_check(not results[1].ok, "G: malformed goal should fail")
	_check(results[0].error.contains("parse error"), "G: premise error should be a parse error")
	_check(results[0].error.contains("position"), "G: premise error should include a position")
	_check(results[1].error.contains("parse error"), "G: goal error should be a parse error")
	_check(results[1].error.contains("position"), "G: goal error should include a position")
	_check(session.tree.node_count() == 0, "G: no proof node should be created")
	_check(session.goal == null, "G: goal should remain unset")

## Assert an exact command-result count, recording one check.
func _require_count(results: Array, expected: int, letter: String) -> bool:
	var matches := results.size() == expected
	_check(matches, "Script %s expected %d results, got %d" % [letter, expected, results.size()])
	return matches

## Record one assertion.
func _check(condition: bool, message: String) -> void:
	_check_count += 1
	if not condition:
		_failure_count += 1
		print("CHECK FAILED: " + message)

## Record an unconditional failure.
func _fail(message: String) -> void:
	_check_count += 1
	_failure_count += 1
	print("CHECK FAILED: " + message)

## Join display lines with newlines.
func _join_lines(lines: Array) -> String:
	var text := ""
	for index in range(lines.size()):
		if index > 0:
			text += "\n"
		text += str(lines[index])
	return text
