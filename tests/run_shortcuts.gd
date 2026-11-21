extends SceneTree

## Headless checks for numbered rule cards, number-key spawning and A/ASSUME.

const ParserRes = preload("res://logic/formula_parser.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await process_frame
	await process_frame

	main.open_level_by_id("ch1-1")
	await process_frame
	await process_frame
	_check(main._rules_row.get_child_count() == 4, "chapter 1 shelf has four cards")
	for index in range(4):
		_check(
			int(main._rules_row.get_child(index).shortcut_number) == index + 1,
			"chapter 1 card %d is numbered %d" % [index, index + 1]
		)

	var before: int = main.canvas.get_root_blocks().size()
	_press(main, KEY_1)
	await process_frame
	var roots: Array = main.canvas.get_root_blocks()
	_check(roots.size() == before + 1, "number 1 spawns one rule card")
	if roots.size() > 0:
		_check(str(roots[roots.size() - 1].get_rule_id()) == "impl_elim", "number 1 spawns impl_elim")

	before = roots.size()
	_press(main, KEY_KP_2)
	await process_frame
	roots = main.canvas.get_root_blocks()
	_check(roots.size() == before + 1, "keypad 2 also spawns a rule card")
	if roots.size() > 0:
		_check(
			str(roots[roots.size() - 1].get_rule_id()) == "and_elim_left",
			"keypad 2 maps to the conjunction card"
		)

	before = roots.size()
	_press(main, KEY_5)
	await process_frame
	_check(main.canvas.get_root_blocks().size() == before, "out-of-range number is ignored")
	_press(main, KEY_A)
	await process_frame
	_check(main._formula_builder == null, "A does nothing before ASSUME is unlocked")

	main.open_level_by_id("ch2-1")
	await process_frame
	await process_frame
	_check(main._assume_button.visible, "chapter 2 exposes ASSUME")
	_press(main, KEY_A)
	await process_frame
	_check(main._formula_builder != null, "A opens the assumption builder in chapter 2")
	before = main.canvas.get_root_blocks().size()
	_press(main, KEY_1)
	await process_frame
	_check(
		main.canvas.get_root_blocks().size() == before,
		"number shortcuts are blocked while Formula Builder is open"
	)
	_press(main, KEY_ENTER)
	await process_frame
	_check(main.goal_bar.linked_block == null, "Enter is owned by Formula Builder")
	main._close_formula_builder()
	await process_frame

	before = main.canvas.get_root_blocks().size()
	_press(main, KEY_2)
	await process_frame
	roots = main.canvas.get_root_blocks()
	_check(roots.size() == before + 1, "chapter 2 number 2 spawns a card")
	if roots.size() > 0:
		_check(
			str(roots[roots.size() - 1].get_rule_id()) == "and_elim_left",
			"chapter 2 number 2 maps to the conjunction card"
		)

	main.begin_palette_drag("spawn_rule", "impl_elim", null, Vector2(400, 400))
	var before_drag: int = main.canvas.get_root_blocks().size()
	_press(main, KEY_1)
	await process_frame
	_check(main._dragging, "drag is still active")
	_check(main.canvas.get_root_blocks().size() == before_drag, "number shortcuts are blocked during a drag")
	_press(main, KEY_ENTER)
	await process_frame
	_check(main.goal_bar.linked_block == null, "Enter does not check during a drag")
	main._cancel_drag()
	await process_frame

	main.open_level_by_id("ch6-1")
	await process_frame
	await process_frame
	_check(main._rules_row.get_child_count() == 9, "chapter 6 shelf has nine cards")
	_check(
		int(main._rules_row.get_child(8).shortcut_number) == 9,
		"chapter 6 last card is numbered 9"
	)

	before = main.canvas.get_root_blocks().size()
	_press(main, KEY_1, true)
	await process_frame
	_check(main.canvas.get_root_blocks().size() == before, "shifted digits are ignored")

	main._rule_intro = Control.new()
	_press(main, KEY_1)
	await process_frame
	_check(main.canvas.get_root_blocks().size() == before, "number shortcuts are blocked by the rule intro")
	main._rule_intro.queue_free()
	main._rule_intro = null

	# Enter checks the last root block against the level goal.
	main.open_level_by_id("ch1-1")
	await process_frame
	await process_frame
	_check(main.goal_bar.linked_block == null, "fresh level starts without a goal link")
	_press(main, KEY_ENTER)
	await process_frame
	_check(main.goal_bar.linked_block == null, "Enter with an empty canvas keeps WAITING")
	_check(main.goal_bar.get_status_text() == "WAITING", "empty check leaves the goal waiting")

	var parsed_p := ParserRes.new("P").parse()
	var parsed_q := ParserRes.new("Q").parse()
	main.canvas._drop_data(
		Vector2(220, 220),
		{"kind": "spawn_rule", "rule_id": "and_intro"}
	)
	await process_frame
	var roots_final: Array = main.canvas.get_root_blocks()
	_check(roots_final.size() == 1, "rule block is on the canvas")
	if roots_final.size() == 1:
		var rule = roots_final[0]
		rule.sockets[0]._drop_data(
			Vector2.ZERO,
			{"kind": "spawn_premise", "formula": parsed_p.formula}
		)
		rule.sockets[1]._drop_data(
			Vector2.ZERO,
			{"kind": "spawn_premise", "formula": parsed_q.formula}
		)
		rule.refresh()
		await process_frame
		_press(main, KEY_ENTER)
		await process_frame
		_check(main.goal_bar.linked_block == rule, "Enter links the last root rule block")
		_check(main.goal_bar.get_status_text() == "MISMATCH", "Enter checks the block against GOAL")

		# A scope window owns the canvas, so Enter must not check the outer goal.
		main.open_scope_for_formula(ParserRes.new("P").parse().formula)
		await process_frame
		_press(main, KEY_ENTER)
		await process_frame
		_check(main.goal_bar.linked_block == rule, "Enter does not re-check inside a scope window")
		_check(
			main._scope_check_hint != null and main._scope_check_hint.visible,
			"Enter with an open scope shows the finish-assumption hint"
		)
		main._close_scope_check_hint()
		main._on_check_requested()
		await process_frame
		_check(
			main._scope_check_hint != null and main._scope_check_hint.visible,
			"GOAL click with an open scope also shows the hint"
		)
		_check(main.goal_bar.linked_block == rule, "GOAL click with an open scope does not check")
		main._close_all_scope_windows()
		await process_frame
		_check(main._scope_check_hint == null, "closing scopes dismisses the hint")

	main.queue_free()
	await process_frame
	print("SHORTCUTS RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _press(main, keycode: int, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = keycode
	event.shift_pressed = shift
	main._input(event)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("SHORTCUTS CHECK FAILED: " + label)
