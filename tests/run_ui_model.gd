extends SceneTree

## Headless model test for the block UI. No rendering or mouse simulation:
## instantiates blocks/sockets, attaches inputs, refreshes and validates.

const FormulaRes = preload("res://logic/formula.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const FormulaBlockRes = preload("res://ui/formula_block.gd")
const RuleBlockRes = preload("res://ui/rule_block.gd")
const ProofAdapterRes = preload("res://ui/proof_adapter.gd")

class CueSink extends RefCounted:
	var cues: Array = []
	func play(cue: String, _options: Dictionary = {}) -> void:
		cues.append(cue)

var _checks: int = 0
var _failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_test_all_rules()
	_test_side_switch_toggle()
	_test_feedback_once()
	_test_rain_chain()
	_test_invalid_and_cycle()
	await _test_scene_drops()
	await _test_feedback_scene()
	print("UI MODEL RESULT: %d checks, %d failed" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)

func _test_all_rules() -> void:
	var double_neg = _make_rule("double_neg_elim", [_f("~~A")])
	_expect_result(double_neg, "A", "double_neg_elim")

	var impl = _make_rule("impl_elim", [_f("A"), _f("A -> B")])
	_expect_result(impl, "B", "impl_elim")

	var and_left = _make_rule("and_elim_left", [_f("A & B")])
	_expect_result(and_left, "A", "and_elim_left")

	var and_right = _make_rule("and_elim_right", [_f("A & B")])
	_expect_result(and_right, "B", "and_elim_right")

	var and_intro = _make_rule("and_intro", [_f("A"), _f("B")])
	_expect_result(and_intro, "A & B", "and_intro")

	var or_left = _make_rule("or_intro_left", [_f("A")], "B")
	_expect_result(or_left, "A | B", "or_intro_left")

	var or_right = _make_rule("or_intro_right", [_f("B")], "A")
	_expect_result(or_right, "A | B", "or_intro_right")

	for card in [double_neg, impl, and_left, and_right, and_intro, or_left, or_right]:
		card.free()

func _test_feedback_once() -> void:
	var card := RuleBlockRes.new()
	card.setup("and_intro", null)
	var valid_events: Array = []
	card.state_changed.connect(
		func(_previous: int, current: int) -> void:
			if current == 3:
				valid_events.append(true)
	)
	var left := _chip("A")
	var right := _chip("B")
	card.sockets[0].attach_block(left, false)
	card.sockets[1].attach_block(right, false)
	card.refresh()
	_check(valid_events.size() == 1, "first completion emits one valid feedback")
	card.refresh()
	_check(valid_events.size() == 1, "plain refresh does not replay valid feedback")
	card.sockets[0].detach_block(false)
	card.refresh()
	card.sockets[0].attach_block(left, false)
	card.refresh()
	_check(
		valid_events.size() == 2,
		"detach and reassemble replays valid feedback"
	)
	card.free()

func _test_side_switch_toggle() -> void:
	var card = RuleBlockRes.new()
	card.setup("and_elim_left", null)
	var toggle = card._side_switch
	_check(toggle != null, "side switch exists")
	if toggle == null:
		card.free()
		return
	toggle.size = Vector2(58, 26)
	_click_side_switch(toggle, Vector2(6, 13))
	_check(card.side == 1 and card.rule_id == "and_elim_right", "left click switches to R")
	_click_side_switch(toggle, Vector2(6, 13))
	_check(card.side == 0 and card.rule_id == "and_elim_left", "same-side click switches back to L")
	card.free()

	var double_neg := RuleBlockRes.new()
	double_neg.setup("double_neg_elim", null)
	_check(double_neg._side_switch == null, "double-negation elimination has no E/I switch")
	_check(double_neg.rule_id == "double_neg_elim", "double-negation card stays in elimination mode")
	double_neg.free()

func _click_side_switch(toggle, position: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = position
	toggle._gui_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = position
	toggle._gui_input(release)

func _test_rain_chain() -> void:
	var double_neg := RuleBlockRes.new()
	double_neg.setup("double_neg_elim", null)
	_attach(double_neg, 0, _chip("~~Rain"))
	double_neg.refresh()
	_expect_result(double_neg, "Rain", "rain: double negation")

	var impl_one := RuleBlockRes.new()
	impl_one.setup("impl_elim", null)
	_attach(impl_one, 0, double_neg)
	_attach(impl_one, 1, _chip("Rain -> Wet"))
	impl_one.refresh()
	_expect_result(impl_one, "Wet", "rain: first modus ponens")

	var impl_two := RuleBlockRes.new()
	impl_two.setup("impl_elim", null)
	_attach(impl_two, 0, impl_one)
	_attach(impl_two, 1, _chip("Wet -> (Slippery & Dangerous)"))
	impl_two.refresh()
	_expect_result(impl_two, "Slippery & Dangerous", "rain: second modus ponens")

	var and_left := RuleBlockRes.new()
	and_left.setup("and_elim_left", null)
	_attach(and_left, 0, impl_two)
	and_left.refresh()
	_expect_result(and_left, "Slippery", "rain: conjunction elimination")

	var goal := _f("Slippery")
	var valid := ProofAdapterRes.validate(and_left, goal)
	_check(valid.ok, "rain: formal proof adapter validates")
	if not valid.ok:
		for error in valid.errors:
			print("  adapter error: " + str(error))

	var mismatch := ProofAdapterRes.validate(and_left, _f("Wet"))
	_check(not mismatch.ok, "rain: formal adapter rejects a mismatched goal")
	and_left.free()

func _test_invalid_and_cycle() -> void:
	var bad := _make_rule("impl_elim", [_f("A"), _f("B")])
	_check(bad.get_result_formula() == null, "invalid: impl_elim input rejected")
	_check(not bad.error_text.is_empty(), "invalid: readable error retained")
	var bad_validation := ProofAdapterRes.validate(bad, _f("A"))
	_check(not bad_validation.ok, "invalid: adapter rejects incomplete/error block")

	var outer := RuleBlockRes.new()
	outer.setup("and_elim_left", null)
	var inner := RuleBlockRes.new()
	inner.setup("double_neg_elim", null)
	_attach(outer, 0, inner)
	var cycle_ok: bool = inner.sockets[0].attach_block(outer, false)
	_check(not cycle_ok, "cycle: ancestor cannot be attached inside its subtree")
	bad.free()
	outer.free()

func _test_scene_drops() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	main.open_level(0)
	await process_frame
	await process_frame
	_check(main.canvas != null, "scene: main canvas built")
	if main.canvas == null:
		main.queue_free()
		return

	main.canvas._drop_data(
		Vector2(120, 120),
		{"kind": "spawn_rule", "rule_id": "double_neg_elim"}
	)
	var roots: Array = main.canvas.get_root_blocks()
	_check(roots.size() == 1, "scene: rule spawn on canvas")
	if roots.is_empty():
		main.queue_free()
		return
	var block = roots[0]

	var payload := {"kind": "spawn_premise", "formula": _f("~~Rain")}
	_check(block.sockets[0]._can_drop_data(Vector2.ZERO, payload), "scene: socket accepts premise")
	block.sockets[0]._drop_data(Vector2.ZERO, payload)
	block.refresh()
	_expect_result(block, "Rain", "scene: socket spawn/drop")

	var link_payload := {"kind": "move_block", "block": block}
	_check(main.goal_bar._can_drop_data(Vector2.ZERO, link_payload), "scene: goal accepts block")
	main.goal_bar._drop_data(Vector2.ZERO, link_payload)
	_check(main.goal_bar.linked_block == block, "scene: goal stores reference")
	main.goal_bar.refresh()
	_check(main.goal_bar._status_label.text == "MISMATCH", "scene: goal reports mismatch")

	main.canvas._drop_data(
		Vector2(520, 420),
		{"kind": "spawn_rule", "rule_id": "and_elim_left"}
	)
	var roots2: Array = main.canvas.get_root_blocks()
	var outer = roots2[roots2.size() - 1]
	outer.sockets[0]._drop_data(
		Vector2.ZERO,
		{"kind": "spawn_rule", "rule_id": "double_neg_elim"}
	)
	var inner = outer.sockets[0].get_attached_block()
	_check(inner != null, "scene: rule spawn directly into socket")
	if inner != null:
		_check(
			not inner.sockets[0]._can_drop_data(Vector2.ZERO, {"kind": "move_block", "block": outer}),
			"scene: cycle rejected by socket"
		)
		main.canvas._drop_data(Vector2(840, 260), {"kind": "move_block", "block": inner})
		_check(inner.get_parent() == main.canvas, "scene: nested block dragged out to canvas")
		_check(outer.sockets[0].is_empty(), "scene: old socket clears after drag out")

	# Quality of life: drop targets are padded beyond the visible cards.
	var trash_rect: Rect2 = main.trash_bin.get_global_rect()
	var trash_hit: Rect2 = main._trash_hit_rect()
	var near_trash := Vector2(trash_rect.position.x - 20.0, trash_rect.get_center().y)
	_check(trash_hit.size.x > trash_rect.size.x + 40.0, "scene: trash drop area is expanded")
	_check(not trash_rect.has_point(near_trash), "scene: near-miss is outside the visible bin")
	_check(trash_hit.has_point(near_trash), "scene: near-miss still lands in the trash area")
	_check(main.trash_bin.tooltip_text.contains("nearby"), "scene: trash explains its padded area")

	var goal_rect: Rect2 = main.goal_bar.get_global_rect()
	var goal_hit: Rect2 = main._goal_hit_rect()
	var near_goal := Vector2(goal_rect.get_center().x, goal_rect.position.y - 4.0)
	_check(not goal_rect.has_point(near_goal), "scene: near-miss is outside the goal chip")
	_check(goal_hit.has_point(near_goal), "scene: near-miss still lands on the goal")

	# Escape aborts a palette drag and discards the provisional block.
	main.begin_palette_drag("spawn_premise", "", _f("~~Rain"), Vector2(400, 400))
	_check(main._dragging, "scene: palette drag starts")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	main._input(escape)
	_check(not main._dragging, "scene: Escape cancels the active drag")
	_check(main._dragged_block == null, "scene: Escape clears the dragged block")

	main.queue_free()
	await process_frame

func _test_feedback_scene() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await process_frame
	await process_frame
	main.open_level(0)
	await process_frame
	await process_frame
	main._close_rule_intro()
	var sink := CueSink.new()
	main._sfx = sink

	var p: Control = main.create_formula_block(_f("P"))
	var pq: Control = main.create_formula_block(_f("P -> Q"))
	var rule: Control = main.create_rule_block("impl_elim")
	rule.sockets[0].attach_block(p, false)
	rule.sockets[1].attach_block(pq, false)
	rule.refresh()
	main.canvas.add_child(rule)
	rule.reset_size()
	rule.position = Vector2(300, 300)
	main.goal_bar.set_linked_block(rule, false)
	main.refresh_machine()
	_check(main.goal_bar.is_solved(), "feedback scene: valid proof reaches GOAL")

	sink.cues.clear()
	main.begin_block_drag(rule, rule.get_global_rect().get_center())
	main._place_on_canvas(rule, Vector2(420, 300), main.canvas, main._canvas_view)
	main._end_drag()
	await process_frame
	_check(
		_feedback_cues(sink).is_empty(),
		"picking up and replacing a whole proof is silent"
	)

	sink.cues.clear()
	var child: Control = rule.sockets[0].get_attached_block()
	rule.sockets[0].detach_block(false)
	rule.refresh()
	main.refresh_machine()
	rule.sockets[0].attach_block(child, false)
	rule.refresh()
	main.refresh_machine()
	var reassembled = _feedback_cues(sink)
	_check(reassembled.has("rule_valid"), "detach and reassemble replays rule feedback")
	_check(reassembled.has("goal_valid"), "detach and reassemble replays goal feedback")

	sink.cues.clear()
	main._push_undo_snapshot()
	var removable: Control = rule.sockets[0].get_attached_block()
	rule.sockets[0].detach_block(false)
	removable.queue_free()
	rule.refresh()
	main.refresh_machine()
	sink.cues.clear()
	main._on_undo()
	await process_frame
	_check(
		_feedback_cues(sink).is_empty(),
		"undo restores the proof without replaying feedback"
	)

	main.queue_free()
	await process_frame

func _feedback_cues(sink) -> Array:
	var result: Array = []
	for cue in sink.cues:
		if cue == "rule_valid" or cue == "goal_valid":
			result.append(cue)
	return result

func _make_rule(rule_id: String, inputs: Array, extra_text: String = "") -> Control:
	var card := RuleBlockRes.new()
	card.setup(rule_id, null)
	for index in range(inputs.size()):
		_attach(card, index, _chip_formula(inputs[index]))
	if extra_text != "":
		card.set_extra_text(extra_text)
	card.refresh()
	return card

func _chip(text: String) -> Control:
	return _chip_formula(_f(text))

func _chip_formula(formula: FormulaRes) -> Control:
	var chip := FormulaBlockRes.new()
	chip.setup(formula)
	return chip

func _attach(card: Control, index: int, block: Control) -> void:
	var attached: bool = card.sockets[index].attach_block(block, false)
	_check(attached, "attach %s input %d" % [card.get_rule_id(), index])

func _expect_result(card: Control, expected: String, label: String) -> void:
	var result = card.get_result_formula()
	_check(result != null, "%s: result is not null" % label)
	if result != null:
		_check(result.to_string() == expected, "%s: expected '%s', got '%s'" % [label, expected, result.to_string()])

func _f(text: String) -> FormulaRes:
	var parsed := ParserRes.new(text).parse()
	_check(parsed.ok, "parse '%s'" % text)
	return parsed.formula

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		print("UI MODEL CHECK FAILED: " + message)
