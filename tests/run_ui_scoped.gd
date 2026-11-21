extends SceneTree

## Headless model tests for the scoped block UI: AssumptionBlock, proof cards,
## automatic discharge selection, and the ProofAdapter bridge.

const ParserRes = preload("res://logic/formula_parser.gd")
const ProofAdapterRes = preload("res://ui/proof_adapter.gd")
const RulesRes = preload("res://logic/rules.gd")
const LevelBankRes = preload("res://ui/level_bank.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	await _run()
	print("UI SCOPED RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _rect_inside(inner: Control, outer: Control) -> bool:
	return outer.get_global_rect().encloses(inner.get_global_rect())

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("UI SCOPED CHECK FAILED: " + label)

func _f(text: String):
	return ParserRes.new(text).parse().formula

func _chip(main, text: String):
	var block = main.create_formula_block(_f(text))
	block.reset_size()
	return block

func _max_fills_parent(record: Dictionary) -> bool:
	var window = record.get("window")
	if window == null or not is_instance_valid(window):
		return false
	var parent = window.get_parent()
	return parent is Control and window.size.is_equal_approx(parent.size)

func _max_chain_ok(records: Array) -> bool:
	for record in records:
		if bool(record.get("maximized", false)) or bool(record.get("fullscreen", false)):
			if not _max_fills_parent(record):
				return false
	return true

func _nested_layers_above(records: Array) -> bool:
	for index in range(1, records.size()):
		var window = records[index].get("window")
		if window == null or not is_instance_valid(window):
			return false
		if window.desktop_layer.z_index <= window.inner_view.z_index:
			return false
	return true

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await process_frame
	await process_frame
	main.open_level(0)
	await process_frame
	await process_frame

	_check(RulesRes.palette_ids().size() == 9, "full palette has nine cards")
	_check(
		RulesRes.palette_ids().has("not_intro_impl")
		and not RulesRes.palette_ids().has("not_elim_impl"),
		"negation palette is intro-only; elim is composed with double negation"
	)
	_check(LevelBankRes.chapter_rules("ch1").size() == 4, "chapter 1 exposes four cards")
	_check(
		main.get_tree().get_nodes_in_group("nd_rule_card").size() == 4,
		"chapter 1 palette cards are instantiated"
	)
	_check(not main._assume_button.visible, "chapter 1 hides ASSUME")

	var assumption = main.create_assumption_block(_f("A"))
	assumption.reset_size()
	_check(assumption.is_assumption_block(), "assumption block is tagged")
	_check(assumption.get_free_assumptions().size() == 1, "assumption exposes itself")
	var copy = main.duplicate_block(assumption)
	_check(copy != null, "assumption can be copied")
	if copy != null:
		_check(
			copy.get_assumption_group() == assumption.get_assumption_group(),
			"assumption copies share a group"
		)

	# ->Intro: A |- A -> A
	var impl = main.create_rule_block("impl_intro")
	impl.reset_size()
	impl.sockets[0].attach_block(assumption, false)
	impl.refresh()
	_check(
		impl.get_result_formula() != null
		and impl.get_result_formula().to_string() == "A -> A",
		"impl_intro UI derives A -> A"
	)
	_check(impl.get_free_assumptions().is_empty(), "impl_intro UI closes its assumption")
	var impl_validation := ProofAdapterRes.validate(impl, _f("A -> A"))
	_check(impl_validation.ok, "impl_intro UI proof validates")

	main.goal_bar.setup(_f("A -> A"), main)
	main.goal_bar.set_linked_block(impl, true)
	await process_frame
	_check(main.goal_bar.is_solved(), "goal chip accepts a scoped UI proof")
	_check(not main._next_button.disabled, "scoped proof unlocks NEXT")

	# \/Elim: A | B with cases proving A | B
	var a1 = main.create_assumption_block(_f("A")); a1.reset_size()
	var b1 = main.create_assumption_block(_f("B")); b1.reset_size()
	var left = main.create_rule_block("or_intro_left"); left.reset_size()
	left.sockets[0].attach_block(a1, false); left.set_extra_text("B"); left.refresh()
	var right = main.create_rule_block("or_intro_right"); right.reset_size()
	right.sockets[0].attach_block(b1, false); right.set_extra_text("A"); right.refresh()
	var disj = _chip(main, "A | B")
	var or_elim = main.create_rule_block("or_elim"); or_elim.reset_size()
	or_elim.sockets[0].attach_block(disj, false)
	or_elim.sockets[1].attach_block(left, false)
	or_elim.sockets[2].attach_block(right, false)
	or_elim.refresh()
	_check(
		or_elim.get_result_formula() != null
		and or_elim.get_result_formula().to_string() == "A | B",
		"or_elim UI derives its common case result"
	)
	_check(ProofAdapterRes.validate(or_elim, _f("A | B")).ok, "or_elim UI proof validates")

	# <->Intro: A -> B under A and B -> A under B
	var a2 = main.create_assumption_block(_f("A")); a2.reset_size()
	var b2 = main.create_assumption_block(_f("B")); b2.reset_size()
	var forward = main.create_rule_block("impl_elim"); forward.reset_size()
	forward.sockets[0].attach_block(a2, false)
	forward.sockets[1].attach_block(_chip(main, "A -> B"), false)
	forward.refresh()
	var backward = main.create_rule_block("impl_elim"); backward.reset_size()
	backward.sockets[0].attach_block(b2, false)
	backward.sockets[1].attach_block(_chip(main, "B -> A"), false)
	backward.refresh()
	var iff = main.create_rule_block("iff_intro"); iff.reset_size()
	iff.sockets[0].attach_block(forward, false)
	iff.sockets[1].attach_block(backward, false)
	iff.refresh()
	_check(
		iff.get_result_formula() != null
		and iff.get_result_formula().to_string() == "A <-> B",
		"iff_intro UI derives A <-> B"
	)
	_check(ProofAdapterRes.validate(iff, _f("A <-> B")).ok, "iff_intro UI proof validates")

	# ~Intro: A with A -> B and A -> ~B gives ~A
	var contradiction_assumption = main.create_assumption_block(_f("A")); contradiction_assumption.reset_size()
	var contradiction_copy = main.duplicate_block(contradiction_assumption); contradiction_copy.reset_size()
	var b_proof = main.create_rule_block("impl_elim"); b_proof.reset_size()
	b_proof.sockets[0].attach_block(contradiction_assumption, false)
	b_proof.sockets[1].attach_block(_chip(main, "A -> B"), false)
	b_proof.refresh()
	var not_b_proof = main.create_rule_block("impl_elim"); not_b_proof.reset_size()
	not_b_proof.sockets[0].attach_block(contradiction_copy, false)
	not_b_proof.sockets[1].attach_block(_chip(main, "A -> ~B"), false)
	not_b_proof.refresh()
	var not_intro = main.create_rule_block("not_intro"); not_intro.reset_size()
	not_intro.sockets[0].attach_block(b_proof, false)
	not_intro.sockets[1].attach_block(not_b_proof, false)
	not_intro.refresh()
	_check(
		not_intro.get_result_formula() != null
		and not_intro.get_result_formula().to_string() == "~A",
		"not_intro UI derives ~A"
	)
	_check(ProofAdapterRes.validate(not_intro, _f("~A")).ok, "not_intro UI proof validates")

	# ~Elim: ~A with ~A -> A and ~A itself gives A
	var neg_assumption = main.create_assumption_block(_f("~A")); neg_assumption.reset_size()
	var neg_copy = main.duplicate_block(neg_assumption); neg_copy.reset_size()
	var a_under_neg = main.create_rule_block("impl_elim"); a_under_neg.reset_size()
	a_under_neg.sockets[0].attach_block(neg_assumption, false)
	a_under_neg.sockets[1].attach_block(_chip(main, "~A -> A"), false)
	a_under_neg.refresh()
	var not_elim = main.create_rule_block("not_elim"); not_elim.reset_size()
	not_elim.sockets[0].attach_block(a_under_neg, false)
	not_elim.sockets[1].attach_block(neg_copy, false)
	not_elim.refresh()
	_check(
		not_elim.get_result_formula() != null
		and not_elim.get_result_formula().to_string() == "A",
		"not_elim UI derives A"
	)
	_check(ProofAdapterRes.validate(not_elim, _f("A")).ok, "not_elim UI proof validates")

	# ASSUME opens a floating window with its own infinite canvas.
	var scopes_before: int = main._scope_open.size()
	main.open_assumption_builder()
	_check(main._formula_builder != null, "ASSUME opens the formula builder")
	main._on_formula_builder_submitted(_f("A"))
	await process_frame
	await process_frame
	_check(main._scope_open.size() == scopes_before + 1, "ASSUME opens a floating scope window")
	if main._scope_open.size() > scopes_before:
		var opened = main._scope_open[-1]
		_check(opened["window"].visible, "scope window is visible")
		_check(main.canvas == opened["inner_canvas"], "scope window owns the active canvas")
		_check(
			opened["inner_canvas"].get_root_blocks().is_empty(),
			"scope window starts with an empty sub-world"
		)
		var opened_item = opened.get("premise_item")
		_check(
			opened_item != null
			and is_instance_valid(opened_item)
			and opened_item.spawn_kind == "spawn_assumption"
			and opened_item.assumption_group == int(opened["group"]),
			"scope hypothesis is added to the Premises panel"
		)
		_check(opened["window"]._window_dots.delete_button != null, "red close dot exists")
		_check(opened["window"]._window_dots.minimize_button != null, "yellow minimize dot exists")
		_check(opened["window"]._window_dots.zoom_button != null, "green zoom dot exists")
		var minimize_requests := [0]
		opened["window"]._window_dots.minimize_requested.connect(
			func() -> void: minimize_requests[0] += 1
		)
		opened["window"]._window_dots.minimize_button.pressed.emit()
		await process_frame
		_check(minimize_requests[0] == 1, "yellow dot requests minimize")
		opened["window"]._window_dots.zoom_button.pressed.emit()
		await process_frame
		_check(bool(opened.get("fullscreen")), "green zoom dot enlarges the window")
		main._on_scope_hud_toggle_size()
		await process_frame
		_check(not bool(opened.get("fullscreen")), "green HUD dot restores the window")
		opened["window"]._window_dots.delete_button.pressed.emit()
		await process_frame
	_check(main.canvas == main._base_canvas, "closing a scope restores the parent canvas")

	# A→A: drag the Premises hypothesis into the sub-world and close.
	main.open_scope_for_formula(_f("A"))
	await process_frame
	var scope_a_record = main._scope_open[-1]
	var scope_a_assumption = main.create_assumption_block(
		_f("A"), int(scope_a_record["group"])
	)
	scope_a_record["inner_canvas"].add_child(scope_a_assumption)
	scope_a_assumption.reset_size()
	scope_a_assumption.position = Vector2(260, 170)
	main.finish_scope_window(scope_a_record["window"])
	await process_frame
	var scope_a_marker = scope_a_record["marker"]
	_check(scope_a_marker != null, "scope DONE creates a marker block")
	_check(
		scope_a_marker.get_result_formula() != null
		and scope_a_marker.get_result_formula().to_string() == "A -> A",
		"scope DONE derives A -> A"
	)
	_check(ProofAdapterRes.validate(scope_a_marker, _f("A -> A")).ok, "scope marker proof validates")
	_check(main.canvas == main._base_canvas, "scope DONE restores the parent canvas")
	_check(
		scope_a_record.get("premise_item") == null,
		"scope DONE removes its Premises hypothesis"
	)
	main.goal_bar.setup(_f("A -> A"), main)
	main.goal_bar.set_linked_block(scope_a_marker, true)
	await process_frame
	_check(main.goal_bar.is_solved(), "goal chip accepts a scope marker")

	# Vacuous: the inner proof B does not use the hypothesis A.
	main.open_scope_for_formula(_f("A"))
	await process_frame
	var scope_v_record = main._scope_open[-1]
	_check(scope_v_record.get("premise_item") != null, "vacuous scope still lists its hypothesis")
	var vacuous_proof = _chip(main, "B")
	scope_v_record["inner_canvas"].add_child(vacuous_proof)
	vacuous_proof.reset_size()
	vacuous_proof.position = Vector2(280, 180)
	main.finish_scope_window(scope_v_record["window"])
	await process_frame
	var scope_v_marker = scope_v_record["marker"]
	_check(
		scope_v_marker != null
		and scope_v_marker.get_result_formula() != null
		and scope_v_marker.get_result_formula().to_string() == "A -> B",
		"scope window supports vacuous discharge"
	)
	_check(ProofAdapterRes.validate(scope_v_marker, _f("A -> B")).ok, "vacuous window proof validates")

	# Full-screen scope: inner world fills the page while the game UI floats.
	main.open_scope_for_formula(_f("A"))
	await process_frame
	var full_record = main._scope_open[-1]
	var full_assumption = main.create_assumption_block(_f("A"), int(full_record["group"]))
	full_record["inner_canvas"].add_child(full_assumption)
	full_assumption.reset_size()
	full_assumption.position = Vector2(260, 170)
	main.toggle_scope_fullscreen(full_record["window"])
	await process_frame
	_check(bool(full_record.get("fullscreen")), "scope enters fullscreen")
	_check(
		full_record["window"].get_global_rect() == Rect2(Vector2.ZERO, main._game_page.size),
		"scope fullscreen fills the game page"
	)
	_check(main._top_bar.visible, "main top bar stays visible in fullscreen scope")
	_check(not main._scope_hud.visible, "centre HUD is retired in fullscreen")
	_check(full_record["window"]._title_bar.visible, "fullscreen keeps the top-left control strip")
	_check(not main._game_title_label.visible, "fullscreen hides the game title")
	_check(not main._level_row.visible, "fullscreen hides the level name")
	_check(main._scope_layer.z_index == 5, "fullscreen scope sits below floating UI")
	_check(main.trash_bin.get_parent() == main._ui_overlay, "trash stays on the floating UI layer")
	_check(main.trash_bin.is_visible_in_tree(), "trash remains visible in fullscreen")
	_check(
		main._scope_layer.get_index() < main._ui_overlay.get_index(),
		"fullscreen scope is below floating UI in input order"
	)
	_check(main.canvas == full_record["inner_canvas"], "fullscreen scope keeps its inner canvas active")
	main.toggle_scope_fullscreen(full_record["window"])
	await process_frame
	_check(not bool(full_record.get("fullscreen")), "scope leaves fullscreen")
	_check(main._top_bar.visible, "main top bar returns after restore")
	_check(not main._scope_hud.visible, "scope HUD stays retired after restore")
	_check(
		main._game_title_label.visible and main._level_row.visible,
		"game header returns after restore"
	)
	_check(
		main._scope_layer.get_index() < main._ui_overlay.get_index()
		and main._scope_layer.z_index < main._ui_overlay.z_index,
		"restored scope stays below floating UI"
	)
	main.toggle_scope_fullscreen(full_record["window"])
	await process_frame
	main.finish_scope_window(full_record["window"])
	await process_frame
	_check(full_record["marker"] != null, "fullscreen scope DONE creates marker")
	_check(main._top_bar.visible, "DONE exits fullscreen UI")
	_check(not main._scope_hud.visible, "DONE keeps the centre HUD retired")
	_check(main._game_title_label.visible, "DONE restores the game header")
	_check(main.canvas == main._base_canvas, "DONE from fullscreen restores parent canvas")

	# Nested Assume windows are contained by their parent desktop.
	main.open_scope_for_formula(_f("A"))
	await process_frame
	var full_outer = main._scope_open[-1]
	main.toggle_scope_fullscreen(full_outer["window"])
	await process_frame
	main.open_scope_for_formula(_f("B"))
	await process_frame
	await process_frame
	var full_inner = main._scope_open[-1]
	_check(bool(full_outer.get("fullscreen")), "nested Assume keeps its parent full-screen")
	_check(not bool(full_inner.get("fullscreen")), "nested Assume is a normal contained window")
	_check(bool(full_inner.get("nested")), "nested window is tagged as contained")
	_check(
		full_inner["window"].get_parent() == full_outer["window"].desktop_layer,
		"nested window lives on the parent desktop layer"
	)
	_check(
		_rect_inside(full_inner["window"], full_outer["window"].desktop_layer),
		"nested window is completely inside its parent"
	)
	_check(main.canvas == full_inner["inner_canvas"], "nested window owns the active canvas")
	_check(not main._scope_hud.visible, "nested contained window does not revive the centre HUD")
	_check(not main._game_title_label.visible, "nested window keeps the game header hidden")
	_check(full_inner["color"] != full_outer["color"], "nested window has its own color")

	main.toggle_scope_fullscreen(full_inner["window"])
	await process_frame
	_check(bool(full_inner.get("maximized")), "nested MAX is local to the parent desktop")
	_check(not bool(full_inner.get("fullscreen")), "nested MAX does not become global full-screen")
	_check(
		full_inner["window"].size == full_outer["window"].desktop_layer.size,
		"nested MAX fills exactly the parent desktop"
	)
	_check(
		_rect_inside(full_inner["window"], full_outer["window"].desktop_layer),
		"nested MAX remains inside the parent"
	)
	main.toggle_scope_fullscreen(full_inner["window"])
	await process_frame
	_check(not bool(full_inner.get("maximized")), "nested MIN restores the window size")
	_check(
		_rect_inside(full_inner["window"], full_outer["window"].desktop_layer),
		"restored nested window remains inside its parent"
	)

	main.close_scope_window(full_inner["window"])
	await process_frame
	_check(bool(full_outer.get("fullscreen")), "closing nested window returns to full parent")
	_check(
		full_outer["window"]._title_bar.visible and not main._scope_hud.visible,
		"parent fullscreen control strip returns"
	)
	_check(not main._game_title_label.visible, "parent fullscreen keeps the game header hidden")
	main._on_scope_hud_toggle_size()
	await process_frame
	_check(not bool(full_outer.get("fullscreen")), "parent RESTORE exits global full-screen")
	_check(main._top_bar.visible and not main._scope_hud.visible, "parent RESTORE returns to game UI")
	_check(
		main._game_title_label.visible and main._level_row.visible,
		"parent RESTORE returns the game header"
	)
	main.close_scope_window(full_outer["window"])
	await process_frame
	_check(main.canvas == main._base_canvas, "contained window stack closes cleanly")

	# Sub-sub windows are recursively clipped inside their parent window.
	main.open_scope_for_formula(_f("A"))
	await process_frame
	var desktop_a = main._scope_open[-1]
	main.open_scope_for_formula(_f("B"))
	await process_frame
	var desktop_b = main._scope_open[-1]
	main.open_scope_for_formula(_f("C"))
	await process_frame
	await process_frame
	var desktop_c = main._scope_open[-1]
	_check(
		desktop_b["window"].get_parent() == desktop_a["window"].desktop_layer,
		"first nested window is inside the top-level scope"
	)
	_check(
		desktop_c["window"].get_parent() == desktop_b["window"].desktop_layer,
		"sub-sub window is inside the nested window"
	)
	_check(
		_rect_inside(desktop_b["window"], desktop_a["window"].desktop_layer)
		and _rect_inside(desktop_c["window"], desktop_b["window"].desktop_layer),
		"nested desktop rectangles are fully contained"
	)
	_check(
		desktop_a["window"].desktop_layer.clip_contents
		and desktop_b["window"].desktop_layer.clip_contents,
		"desktop layers clip their child windows"
	)
	main.toggle_scope_fullscreen(desktop_b["window"])
	await process_frame
	_check(
		_rect_inside(desktop_c["window"], desktop_b["window"].desktop_layer)
		and _rect_inside(desktop_b["window"], desktop_a["window"].desktop_layer),
		"sub-sub window remains inside after local MAX"
	)
	main.toggle_scope_fullscreen(desktop_b["window"])
	await process_frame
	main.close_scope_window(desktop_c["window"])
	await process_frame
	main.close_scope_window(desktop_b["window"])
	await process_frame
	main.close_scope_window(desktop_a["window"])
	await process_frame
	_check(main.canvas == main._base_canvas, "nested desktop stack closes cleanly")

	# Nested windows: A -> (B -> A).
	main.open_scope_for_formula(_f("A"))
	await process_frame
	var outer_record = main._scope_open[-1]
	var outer_token = main.create_assumption_block(_f("A"), int(outer_record["group"]))
	outer_record["inner_canvas"].add_child(outer_token)
	outer_token.reset_size()
	outer_token.position = Vector2(260, 170)
	main.open_scope_for_formula(_f("B"))
	await process_frame
	var inner_record = main._scope_open[-1]
	_check(
		inner_record.get("premise_item") != null,
		"nested scope adds its own hypothesis to Premises"
	)
	_check(
		inner_record["color"] != outer_record["color"],
		"nested scope color differs from its parent"
	)
	_check(
		inner_record["premise_item"].assumption_color == inner_record["color"],
		"nested Premises hypothesis carries the scope color"
	)
	_check(
		inner_record["inner_view"].background_color != outer_record["inner_view"].background_color,
		"nested scope changes the sub-world background"
	)
	_check(
		outer_record.get("premise_item") != null,
		"outer scope hypothesis remains available in Premises"
	)
	var outer_copy = main.duplicate_block(outer_token)
	inner_record["inner_canvas"].add_child(outer_copy)
	outer_copy.reset_size()
	outer_copy.position = Vector2(260, 170)
	main.finish_scope_window(inner_record["window"])
	await process_frame
	_check(
		inner_record["marker"] != null
		and inner_record["marker"].get_result_formula().to_string() == "B -> A",
		"inner window yields B -> A"
	)
	_check(
		inner_record["marker"].get_scope_color() == inner_record["color"],
		"inner marker keeps the scope color"
	)
	_check(main.canvas == outer_record["inner_canvas"], "closing inner window restores parent scope canvas")
	_check(inner_record.get("premise_item") == null, "inner hypothesis leaves Premises after DONE")
	_check(outer_record.get("premise_item") != null, "outer hypothesis stays in Premises after inner DONE")
	main.finish_scope_window(outer_record["window"])
	await process_frame
	var nested_marker = outer_record["marker"]
	_check(
		nested_marker != null
		and nested_marker.get_result_formula().to_string() == "A -> (B -> A)",
		"nested windows yield A -> (B -> A)"
	)
	_check(ProofAdapterRes.validate(nested_marker, _f("A -> (B -> A)")).ok, "nested window proof validates")
	var marker_copy = main.duplicate_block(nested_marker)
	_check(
		marker_copy != null
		and marker_copy.get_result_formula() != null
		and marker_copy.get_result_formula().to_string() == "A -> (B -> A)",
		"scope marker can be snapshotted"
	)
	if marker_copy != null:
		marker_copy.queue_free()

	# A minimized scope marker must not be dragged into its own window.
	var recursion_record = nested_marker.get_window_record()
	_check(recursion_record != null, "scope marker remembers its window record")
	main.open_scope_marker(nested_marker)
	await process_frame
	_check(
		main._is_recursive_scope_drop(nested_marker, recursion_record["inner_canvas"]),
		"scope marker is rejected inside its own window"
	)
	_check(
		not main._is_recursive_scope_drop(nested_marker, main._base_canvas),
		"scope marker is allowed on the parent canvas"
	)
	_check(
		main._reject_recursive_drop(nested_marker, recursion_record["inner_canvas"]),
		"recursive scope drop is reported"
	)
	_check(
		main._toast_label.text == "Infinite recurrsion huh, no way.",
		"recursive scope drop shows the recursion toast"
	)
	main.close_scope_window(recursion_record["window"])
	await process_frame

	# The OR "other" slot is a formula value, not a draggable premise.
	var other_rule = main.create_rule_block("or_intro_left")
	other_rule.reset_size()
	other_rule.set_extra_formula(_f("B"))
	var other_value = other_rule.extra_socket.get_attached_block()
	var other_parent = other_value.get_parent()
	_check(other_value.is_value_only(), "OR other slot is value-only")
	main.begin_block_drag(other_value, other_value.get_global_rect().get_center())
	_check(not main._dragging, "OR other value cannot start a drag")
	_check(other_value.get_parent() == other_parent, "OR other value stays in its socket")

	# Derived formula-only ∨E consumes two implication-scope outputs.
	var derived_or = main.create_rule_block("or_elim_impl"); derived_or.reset_size()
	derived_or.sockets[0].attach_block(_chip(main, "A | B"), false)
	derived_or.sockets[1].attach_block(_chip(main, "A -> C"), false)
	derived_or.sockets[2].attach_block(_chip(main, "B -> C"), false)
	derived_or.refresh()
	_check(
		derived_or.get_result_formula() != null
		and derived_or.get_result_formula().to_string() == "C",
		"derived or_elim card derives C"
	)
	_check(ProofAdapterRes.validate(derived_or, _f("C")).ok, "derived or_elim card validates")

	# Undischarged simple-rule context remains visible to the formal adapter.
	var open = main.create_rule_block("and_intro"); open.reset_size()
	open.sockets[0].attach_block(main.create_assumption_block(_f("A")), false)
	open.sockets[1].attach_block(_chip(main, "A"), false)
	open.refresh()
	_check(not ProofAdapterRes.validate(open, _f("A & A")).ok, "open assumption is rejected")

	# Green minimize keeps a marker; red delete removes the scope and marker.
	main.open_scope_for_formula(_f("D"))
	await process_frame
	var delete_record = main._scope_open[-1]
	var delete_assumption = main.create_assumption_block(_f("D"), int(delete_record["group"]))
	delete_record["inner_canvas"].add_child(delete_assumption)
	delete_assumption.reset_size()
	delete_assumption.position = Vector2(260, 170)
	main.finish_scope_window(delete_record["window"])
	await process_frame
	var keep_marker = delete_record["marker"]
	_check(keep_marker != null and keep_marker.get_parent() != null, "green minimize keeps a marker")
	main.open_scope_marker(keep_marker)
	await process_frame
	main.delete_scope_window(keep_marker.window_record["window"])
	await process_frame
	_check(delete_record.get("marker") == null, "red delete clears the marker reference")
	_check(not is_instance_valid(keep_marker), "red delete frees the marker")
	_check(main.canvas == main._base_canvas, "red delete restores the parent canvas")

	# Opening an Assume window itself is undoable, including nested windows.
	main.open_level(0)
	await process_frame
	main._clear_undo_history()
	_check(main._undo_button.disabled, "scope undo starts clean")
	main.open_scope_for_formula(_f("E"))
	await process_frame
	await process_frame
	_check(not main._undo_button.disabled, "opening an Assume enables undo")
	_check(main._scope_open.size() == 1, "scope undo setup: outer scope open")
	main.open_scope_for_formula(_f("F"))
	await process_frame
	await process_frame
	_check(main._scope_open.size() == 2, "scope undo setup: nested scope open")
	main._on_undo()
	await process_frame
	_check(main._scope_open.size() == 1, "undo closes the newest Assume window")
	_check(not main._undo_button.disabled, "outer Assume remains undoable")
	main._on_undo()
	await process_frame
	_check(main._scope_open.is_empty(), "undo closes the outer Assume window")
	_check(main.canvas == main._base_canvas, "scope undo restores the base canvas")
	_check(main._undo_button.disabled, "scope undo consumes the history")

	# A block can travel from the base canvas into an inner scope and back out.
	var outer_block = _chip(main, "A")
	main._base_canvas.add_child(outer_block)
	outer_block.reset_size()
	outer_block.position = Vector2(180, 180)
	await process_frame
	outer_block.reset_size()
	main.begin_block_drag(outer_block, outer_block.get_global_rect().get_center())
	_check(
		main._origin_kind == "canvas" and main._origin_canvas == main._base_canvas,
		"base drag origin is tracked"
	)
	main._cancel_drag()
	await process_frame
	_check(outer_block.get_parent() == main._base_canvas, "cancelled base drag restores the base canvas")

	main.open_scope_for_formula(_f("A"))
	await process_frame
	var drag_record = main._scope_open[-1]
	var inner_canvas = drag_record["inner_canvas"]
	var inner_view = drag_record["inner_view"]
	var inner_chip = _chip(main, "A")
	inner_canvas.add_child(inner_chip)
	inner_chip.reset_size()
	inner_chip.position = Vector2(120, 150)
	await process_frame
	_check(main._drop_view_at(outer_block) == main._base_canvas_view, "outer block resolves base view")
	_check(main._drop_view_at(inner_chip) == inner_view, "inner block resolves inner view")

	main.begin_block_drag(outer_block, outer_block.get_global_rect().get_center())
	_check(main._origin_canvas == main._base_canvas, "outer origin stays base under active scope")
	main._place_on_canvas(outer_block, Vector2(320, 300), inner_canvas, inner_view)
	main._end_drag()
	_check(outer_block.get_parent() == inner_canvas, "block moves into the inner scope")

	main.begin_block_drag(outer_block, outer_block.get_global_rect().get_center())
	_check(main._origin_canvas == inner_canvas, "inner drag origin is tracked")
	main._place_on_canvas(outer_block, Vector2(520, 320), main._base_canvas, main._base_canvas_view)
	main._end_drag()
	_check(outer_block.get_parent() == main._base_canvas, "block moves back out to the base canvas")

	main.begin_block_drag(outer_block, outer_block.get_global_rect().get_center())
	main._cancel_drag()
	await process_frame
	_check(
		is_instance_valid(outer_block) and outer_block.get_parent() == main._base_canvas,
		"cancelled outer drag under scope restores the base"
	)

	main.close_scope_window(drag_record["window"])
	await process_frame
	_check(main.canvas == main._base_canvas, "cross-canvas drag leaves a clean scope stack")
	outer_block.queue_free()

	# Undo restores deleted blocks and the goal link without reloading the level.
	main.open_level(0)
	await process_frame
	main._clear_undo_history()
	await process_frame
	_check(main._undo_button.disabled, "undo starts disabled on a clean board")
	var undo_block = _chip(main, "A")
	main._base_canvas.add_child(undo_block)
	undo_block.reset_size()
	undo_block.position = Vector2(210, 210)
	await process_frame
	var roots_before = main._base_canvas.get_root_blocks().size()
	main.begin_block_drag(undo_block, undo_block.get_global_rect().get_center())
	_check(not main._undo_button.disabled, "undo becomes available after a board action")
	main._trash_dragged(undo_block)
	main._end_drag()
	await process_frame
	_check(
		main._base_canvas.get_root_blocks().size() == roots_before - 1,
		"trash removes the block"
	)
	main._on_undo()
	await process_frame
	var restored_roots = main._base_canvas.get_root_blocks()
	_check(restored_roots.size() == roots_before, "undo restores a deleted block")
	var restored_block = restored_roots[-1] if not restored_roots.is_empty() else null
	_check(
		restored_block != null
		and restored_block.get_result_formula().to_string() == "A"
		and restored_block.position.is_equal_approx(Vector2(210, 210)),
		"undo restores the formula and position"
	)
	_check(main._undo_button.disabled, "undo disables again after consuming the snapshot")

	# Undo can restore a block that was moved from the base into a scope.
	main.open_scope_for_formula(_f("B"))
	await process_frame
	var undo_scope = main._scope_open[-1]
	var undo_inner = undo_scope["inner_canvas"]
	var undo_outer = _chip(main, "B")
	main._base_canvas.add_child(undo_outer)
	undo_outer.reset_size()
	undo_outer.position = Vector2(260, 260)
	var undo_inside = _chip(main, "B")
	undo_inner.add_child(undo_inside)
	undo_inside.reset_size()
	undo_inside.position = Vector2(140, 160)
	await process_frame
	main.begin_block_drag(undo_outer, undo_outer.get_global_rect().get_center())
	main._place_on_canvas(undo_outer, Vector2(400, 300), undo_inner, undo_scope["inner_view"])
	main._end_drag()
	_check(not is_instance_valid(undo_outer) or undo_outer.get_parent() == undo_inner, "setup moves a block into the scope")
	main._on_undo()
	await process_frame
	var base_roots = main._base_canvas.get_root_blocks()
	var inner_roots = undo_inner.get_root_blocks()
	var base_has_b = false
	for block in base_roots:
		if block.get_result_formula() != null and block.get_result_formula().to_string() == "B":
			base_has_b = true
	_check(base_has_b, "undo returns a block to the parent canvas")
	var inner_has_b = false
	for block in inner_roots:
		if block.get_result_formula() != null and block.get_result_formula().to_string() == "B":
			inner_has_b = true
	_check(inner_has_b, "undo keeps the inner canvas content")
	main.close_scope_window(undo_scope["window"])
	await process_frame

	# A top-level scope window follows the base canvas zoom and pan.
	main.open_level(0)
	await process_frame
	main.open_scope_for_formula(_f("C"))
	await process_frame
	var follow_record = main._scope_open[-1]
	var follow_window = follow_record["window"]
	var base_view = main._base_canvas_view
	base_view.zoom_at(Vector2(300, 300), 1.5)
	main._sync_scope_windows_to_base()
	_check(
		is_equal_approx(follow_window.scale.x, base_view.zoom),
		"scope window follows the base zoom"
	)
	var follow_before: Vector2 = follow_window.global_position
	base_view.pan_by(Vector2(36, 24))
	main._sync_scope_windows_to_base()
	_check(
		follow_window.global_position.is_equal_approx(follow_before + Vector2(36, 24)),
		"scope window follows the base pan"
	)
	base_view.reset_view()
	main._sync_scope_windows_to_base()
	_check(
		is_equal_approx(follow_window.scale.x, 1.0),
		"scope window returns with the base view"
	)
	main.close_scope_window(follow_record["window"])
	await process_frame

	# A proof that still depends on an Assume hypothesis cannot cross the
	# scope boundary, while an independent block can.
	main.open_level(0)
	await process_frame
	main.open_scope_for_formula(_f("A"))
	await process_frame
	var dep_record = main._scope_open[-1]
	var dep_inner = dep_record["inner_canvas"]
	var dep_assumption = main.create_assumption_block(_f("A"), int(dep_record["group"]))
	dep_inner.add_child(dep_assumption)
	dep_assumption.reset_size()
	dep_assumption.position = Vector2(140, 160)
	var independent = _chip(main, "B")
	dep_inner.add_child(independent)
	independent.reset_size()
	independent.position = Vector2(300, 160)
	var dependent_rule = main.create_rule_block("and_intro")
	dependent_rule.reset_size()
	dependent_rule.sockets[0].attach_block(dep_assumption, false)
	dependent_rule.sockets[1].attach_block(independent, false)
	dependent_rule.refresh()
	_check(
		not main._block_dependencies_ok(dependent_rule, main._base_canvas),
		"assumption-dependent proof cannot leave its scope"
	)
	_check(
		main._block_dependencies_ok(dependent_rule, dep_inner),
		"assumption-dependent proof stays valid inside its scope"
	)
	_check(
		main._block_dependencies_ok(independent, main._base_canvas),
		"independent proof can leave the scope"
	)
	_check(
		main._reject_dependent_drop(dependent_rule, main._base_canvas),
		"cross-scope rejection is reported"
	)
	_check(
		main._toast_panel != null
		and main._toast_panel.visible
		and main._toast_label.text == "Want to cheat huh, no way."
		and main._toast_panel.size.x > 100.0,
		"cross-scope rejection shows the cheat toast"
	)
	_check(
		main._context_groups_for_canvas(dep_inner).has(int(dep_record["group"])),
		"scope context exposes its assumption group"
	)
	main.open_scope_for_formula(_f("B"))
	await process_frame
	var nested_dep = main._scope_open[-1]
	_check(
		main._context_groups_for_canvas(nested_dep["inner_canvas"]).has(int(dep_record["group"]))
		and main._context_groups_for_canvas(nested_dep["inner_canvas"]).has(int(nested_dep["group"])),
		"nested scope inherits its parent's context"
	)
	main.close_scope_window(nested_dep["window"])
	main.close_scope_window(dep_record["window"])
	await process_frame

	# Maximizing a nested window survives its parent going fullscreen.
	main.open_level(0)
	await process_frame
	main.open_scope_for_formula(_f("P"))
	await process_frame
	var full_parent = main._scope_open[-1]
	main.open_scope_for_formula(_f("Q"))
	await process_frame
	var full_child = main._scope_open[-1]
	_check(bool(full_child["nested"]), "nested fullscreen setup: Q is contained")
	main.maximize_scope_window(full_child["window"])
	await process_frame
	await process_frame
	_check(
		bool(full_child["maximized"])
		and full_child["window"].size.is_equal_approx(full_parent["window"].desktop_layer.size),
		"nested Q fills its parent"
	)
	main.maximize_scope_window(full_parent["window"])
	await process_frame
	await process_frame
	_check(bool(full_parent["fullscreen"]), "parent P enters fullscreen")
	_check(bool(full_child["maximized"]), "Q keeps its maximized state")
	_check(
		full_parent["window"].desktop_layer.z_index
		> full_parent["window"].inner_view.z_index,
		"nested scope layer draws above the parent canvas"
	)
	_check(
		full_child["window"].size.is_equal_approx(full_parent["window"].desktop_layer.size),
		"maximized Q follows P into fullscreen"
	)
	await process_frame
	await process_frame
	await process_frame
	var nested_title = full_child["window"].get_title_bar()
	_check(
		main._palette_top_space.custom_minimum_size.y > 0.0,
		"Premises moves down for stacked maximized scopes"
	)
	_check(
		main._palette_panel.get_global_rect().position.y
		>= nested_title.get_global_rect().end.y,
		"Premises clears the nested window title bar"
	)
	main.resume_scope_window(full_parent["window"])
	await process_frame
	await process_frame
	_check(
		full_child["window"].size.is_equal_approx(full_parent["window"].desktop_layer.size),
		"maximized Q follows P back out of fullscreen"
	)
	main._close_all_scope_windows()
	await process_frame

	# Five nested scopes: depth and simultaneous-maximize limits.
	main.open_level(0)
	await process_frame
	var deep_records: Array = []
	for formula_text in ["P", "Q", "R", "S", "T"]:
		main.open_scope_for_formula(_f(formula_text))
		await process_frame
		await process_frame
		deep_records.append(main._scope_open[-1])
	_check(deep_records.size() == 5, "deep nesting: five scopes opened")
	for index in range(1, deep_records.size()):
		_check(bool(deep_records[index]["nested"]), "deep nesting: child %d is contained" % index)

	main.open_scope_for_formula(_f("U"))
	await process_frame
	_check(main._scope_open.size() == 5, "deep nesting: sixth scope is rejected")
	_check(
		main._toast_label.text == "Too many open assumption windows, no way.",
		"deep nesting: depth limit shows the toast"
	)

	for index in [4, 3, 2]:
		main.maximize_scope_window(deep_records[index]["window"])
		await process_frame
		await process_frame
	_check(main._maximized_scope_count() == 3, "deep nesting: three maximized levels allowed")
	_check(
		_max_chain_ok([deep_records[2], deep_records[3], deep_records[4]]),
		"deep nesting: allowed maximized levels fill their parents"
	)
	_check(
		main._palette_top_space.custom_minimum_size.y == 0.0,
		"deep nesting: non-root maximized levels do not move Premises"
	)
	_check(_nested_layers_above(deep_records), "deep nesting: every nested layer draws above its canvas")

	main.maximize_scope_window(deep_records[1]["window"])
	await process_frame
	_check(not bool(deep_records[1]["maximized"]), "deep nesting: fourth maximize is rejected")
	_check(
		main._toast_label.text == "Too many maximized windows, no way.",
		"deep nesting: maximize limit shows the toast"
	)
	main.maximize_scope_window(deep_records[0]["window"])
	await process_frame
	_check(not bool(deep_records[0]["fullscreen"]), "deep nesting: parent fullscreen is rejected at the limit")

	main.resume_scope_window(deep_records[2]["window"])
	await process_frame
	await process_frame
	main.maximize_scope_window(deep_records[1]["window"])
	await process_frame
	await process_frame
	_check(bool(deep_records[1]["maximized"]), "deep nesting: restoring one level frees a maximize slot")
	_check(
		_max_chain_ok([deep_records[1], deep_records[3], deep_records[4]]),
		"deep nesting: replacement maximized chain updates its descendants"
	)

	main.resume_scope_window(deep_records[1]["window"])
	await process_frame
	await process_frame
	_check(not bool(deep_records[1]["maximized"]), "deep nesting: middle scope restores")
	_check(
		_max_chain_ok([deep_records[3], deep_records[4]]),
		"deep nesting: descendants follow middle restore"
	)
	main.resume_scope_window(deep_records[3]["window"])
	await process_frame
	await process_frame
	_check(
		_max_chain_ok([deep_records[4]]),
		"deep nesting: innermost follows its parent restore"
	)
	main.resume_scope_window(deep_records[4]["window"])
	await process_frame
	await process_frame
	_check(not bool(deep_records[4]["maximized"]), "deep nesting: innermost restores independently")
	main._close_all_scope_windows()
	await process_frame

	# Path independence: opening Q after P is fullscreen must match opening Q
	# first and then maximizing P. Restoring either must return Q to the same
	# default layout as a fresh Q in a normal P.
	main.open_level(0)
	await process_frame
	main.open_scope_for_formula(_f("P"))
	await process_frame
	await process_frame
	var path_a_p = main._scope_open[-1]
	main.open_scope_for_formula(_f("Q"))
	await process_frame
	await process_frame
	var path_a_q = main._scope_open[-1]
	main.maximize_scope_window(path_a_p["window"])
	await process_frame
	await process_frame
	await process_frame
	var q_after_p_full_size: Vector2 = path_a_q["window"].size
	var q_after_p_full_pos: Vector2 = path_a_q["window"].position
	main.resume_scope_window(path_a_p["window"])
	await process_frame
	await process_frame
	await process_frame
	var q_after_p_restore_size: Vector2 = path_a_q["window"].size
	var q_after_p_restore_pos: Vector2 = path_a_q["window"].position
	main._close_all_scope_windows()
	await process_frame

	main.open_level(0)
	await process_frame
	main.open_scope_for_formula(_f("P"))
	await process_frame
	await process_frame
	var path_b_p = main._scope_open[-1]
	main.maximize_scope_window(path_b_p["window"])
	await process_frame
	await process_frame
	main.open_scope_for_formula(_f("Q"))
	await process_frame
	await process_frame
	await process_frame
	var path_b_q = main._scope_open[-1]
	_check(
		path_b_q["window"].size.is_equal_approx(q_after_p_full_size)
		and path_b_q["window"].position.is_equal_approx(q_after_p_full_pos),
		"path independence: Q opened in fullscreen P matches Q carried into fullscreen P"
	)
	main.resume_scope_window(path_b_p["window"])
	await process_frame
	await process_frame
	await process_frame
	_check(
		path_b_q["window"].size.is_equal_approx(q_after_p_restore_size)
		and path_b_q["window"].position.is_equal_approx(q_after_p_restore_pos),
		"path independence: restoring P gives the same default Q layout"
	)
	main._close_all_scope_windows()
	await process_frame

	main.open_level(0)
	await process_frame
	main.open_scope_for_formula(_f("P"))
	await process_frame
	await process_frame
	var path_c_p = main._scope_open[-1]
	main.open_scope_for_formula(_f("Q"))
	await process_frame
	await process_frame
	var path_c_q = main._scope_open[-1]
	main.maximize_scope_window(path_c_q["window"])
	await process_frame
	await process_frame
	main.resume_scope_window(path_c_q["window"])
	await process_frame
	await process_frame
	_check(
		path_c_q["window"].size.is_equal_approx(q_after_p_restore_size)
		and path_c_q["window"].position.is_equal_approx(q_after_p_restore_pos),
		"path independence: maximizing then restoring Q returns to the fresh default"
	)
	main._close_all_scope_windows()
	await process_frame
	await process_frame
	await process_frame
	_check(
		main._palette_top_space.custom_minimum_size.y == 0.0,
		"Premises returns to its base position after scopes close"
	)

	main.queue_free()
