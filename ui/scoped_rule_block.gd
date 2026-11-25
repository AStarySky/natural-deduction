extends "res://ui/block_base.gd"

## Rule card with proof branches and discharged assumptions. Assumptions are
## ordinary free AssumptionBlocks; this card selects the ones it binds.

const FormulaRes = preload("res://logic/formula.gd")
const BlockSocketRes = preload("res://ui/block_socket.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const RuleIconRes = preload("res://ui/rule_icon.gd")
const RuleMetaRes = preload("res://ui/rule_meta.gd")
const RulesRes = preload("res://logic/rules.gd")
const ScopedRulesRes = preload("res://logic/scoped_rules.gd")

enum State { EMPTY, PENDING, ERROR, VALID }

signal state_changed(previous: int, current: int)

var rule_id: String = ""
var sockets: Array = []
var result_formula = null
var error_text: String = ""
var _previous_state: int = State.EMPTY
var state: State = State.EMPTY

var _body_panel: PanelContainer = null
var _warning_badge: PanelContainer = null
var _result_visual = null
var _out_tab: ColorRect = null
var _proof_flows: Array = []
var _binder_slots: Array = []
var _candidates: Array = []
var _free_assumptions: Array = []

func setup(p_rule_id: String, p_controller) -> void:
	rule_id = p_rule_id
	controller = p_controller
	custom_minimum_size = Vector2(260, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = RuleMetaRes.tooltip(rule_id)
	add_theme_stylebox_override("panel", UiStyle.empty_style())

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	var proof_row := HBoxContainer.new()
	proof_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	proof_row.alignment = BoxContainer.ALIGNMENT_CENTER
	proof_row.add_theme_constant_override("separation", 6)
	root.add_child(proof_row)

	var labels := _proof_labels()
	for index in range(labels.size()):
		var socket := BlockSocketRes.new()
		socket.setup(self, labels[index], controller)
		socket.tooltip_text = "Proof branch: drop a proven block here."
		proof_row.add_child(socket)
		sockets.append(socket)

	_body_panel = PanelContainer.new()
	_body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_body_panel)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 4)
	_body_panel.add_child(body)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(header)
	_warning_badge = PanelContainer.new()
	_warning_badge.custom_minimum_size = Vector2(22, 22)
	_warning_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_badge.visible = false
	var warning_label := UiStyle.make_display_label("!", 15, UiStyle.cream())
	warning_label.custom_minimum_size = Vector2(14, 14)
	warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_badge.add_child(warning_label)
	header.add_child(_warning_badge)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(icon_center)
	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(76, 76)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon = RuleIconRes.new()
	icon.setup(rule_id)
	plate.add_child(icon)
	icon_center.add_child(plate)

	for slot in range(RulesRes.assumption_count(rule_id)):
		var row := VBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", 1)
		body.add_child(row)
		var caption := UiStyle.make_display_label("DISCHARGE", 10, UiStyle.muted_text())
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(caption)
		var flow := HFlowContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.alignment = FlowContainer.ALIGNMENT_CENTER
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 2)
		row.add_child(flow)
		_proof_flows.append(flow)
		_binder_slots.append(-1)

	var out_panel := PanelContainer.new()
	out_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_panel.add_theme_stylebox_override(
		"panel",
		UiStyle.slot_style(UiStyle.cream(), UiStyle.border_color())
	)
	body.add_child(out_panel)
	var out_row := HBoxContainer.new()
	out_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	out_row.add_theme_constant_override("separation", 5)
	out_panel.add_child(out_row)
	var out_icon := UiStyle.make_display_label(">", 17, UiStyle.border_color())
	out_icon.custom_minimum_size = Vector2(16, 20)
	out_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	out_row.add_child(out_icon)
	_result_visual = FormulaVisualRes.new()
	_result_visual.setup(null, 22, 13)
	_result_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_visual.custom_minimum_size = Vector2(0, 32)
	_result_visual.alignment = BoxContainer.ALIGNMENT_CENTER
	out_row.add_child(_result_visual)

	_out_tab = ColorRect.new()
	_out_tab.color = UiStyle.border_color()
	_out_tab.custom_minimum_size = Vector2(52, 5)
	_out_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_out_tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(_out_tab)

	refresh()

func _proof_labels() -> Array:
	match rule_id:
		"or_elim":
			return ["disj", "case 1", "case 2"]
		"iff_intro":
			return ["->", "<-"]
		"not_intro", "not_elim":
			return ["psi", "not psi"]
		_:
			return ["proof"]

func get_rule_id() -> String:
	return rule_id

func get_result_formula():
	return result_formula

func get_proof_blocks() -> Array:
	var blocks: Array = []
	for socket in sockets:
		blocks.append(socket.get_attached_block())
	return blocks

func get_selected_assumption_blocks() -> Array:
	var selected: Array = []
	for slot in range(_binder_slots.size()):
		var group: int = int(_binder_slots[slot])
		if group < 0:
			continue
		var chosen = _find_candidate(slot, group)
		if chosen != null:
			selected.append(chosen)
	return selected

func get_free_assumptions() -> Array:
	return _free_assumptions

func get_display_text() -> String:
	if result_formula != null:
		return "%s => %s" % [rule_id, result_formula.to_display_string()]
	return rule_id

func _find_candidate(slot: int, group: int):
	if slot < 0 or slot >= _candidates.size():
		return null
	for candidate in _candidates[slot]:
		if candidate.get_assumption_group() == group:
			return candidate
	return null

func refresh() -> void:
	if _refreshing:
		return
	_refreshing = true
	result_formula = null
	error_text = ""
	_free_assumptions = []

	var proofs: Array = get_proof_blocks()
	var proof_formulas: Array = []
	var missing := false
	var incomplete := false
	var free_by_proof: Array = []
	for block in proofs:
		if block == null:
			missing = true
			free_by_proof.append([])
			continue
		block.refresh()
		var formula = block.get_result_formula()
		if formula == null:
			incomplete = true
		proof_formulas.append(formula)
		free_by_proof.append(_unique_assumptions(block.get_free_assumptions()))

	_candidates = _candidate_sets(proof_formulas, free_by_proof)
	_auto_select()
	_rebuild_binder_rows()

	if missing:
		state = State.EMPTY
		error_text = "waiting for proof input"
	elif incomplete:
		state = State.PENDING
		error_text = "a proof input is incomplete"
	else:
		var assumption_formulas: Array = []
		var ready := true
		for slot in range(_binder_slots.size()):
			var chosen = _find_candidate(slot, int(_binder_slots[slot]))
			if chosen == null:
				ready = false
				break
			assumption_formulas.append(chosen.get_result_formula())
		if not ready:
			state = State.PENDING
			error_text = "choose the assumption(s) to discharge"
		else:
			var derivation := ScopedRulesRes.derive(rule_id, proof_formulas, assumption_formulas)
			if not derivation.ok:
				state = State.ERROR
				error_text = derivation.error
			else:
				result_formula = derivation.formula
				state = State.VALID

	var sources: Array = []
	for block in proofs:
		if block != null:
			sources.append(block)
	var merged := merge_assumption_blocks(sources)
	var selected_groups: Dictionary = {}
	for slot in range(_binder_slots.size()):
		var group: int = int(_binder_slots[slot])
		if group >= 0:
			selected_groups[group] = true
	for assumption in merged:
		if not selected_groups.has(assumption.get_assumption_group()):
			_free_assumptions.append(assumption)

	_refreshing = false
	refresh_visuals()
	if state != _previous_state:
		var previous := _previous_state
		_previous_state = state
		state_changed.emit(previous, state)

func _candidate_sets(proof_formulas: Array, free_by_proof: Array) -> Array:
	var sets: Array = []
	match rule_id:
		"impl_intro":
			sets.append(free_by_proof[0] if free_by_proof.size() > 0 else [])
		"or_elim":
			var left_set: Array = []
			var right_set: Array = []
			if (
				proof_formulas.size() > 0
				and proof_formulas[0] != null
				and proof_formulas[0].kind == FormulaRes.Kind.OR
			):
				var disjunction = proof_formulas[0]
				for assumption in (free_by_proof[1] if free_by_proof.size() > 1 else []):
					if assumption.get_result_formula().equals(disjunction.left):
						left_set.append(assumption)
				for assumption in (free_by_proof[2] if free_by_proof.size() > 2 else []):
					if assumption.get_result_formula().equals(disjunction.right):
						right_set.append(assumption)
			sets.append(left_set)
			sets.append(right_set)
		"iff_intro":
			sets.append(free_by_proof[0] if free_by_proof.size() > 0 else [])
			sets.append(free_by_proof[1] if free_by_proof.size() > 1 else [])
		"not_intro", "not_elim":
			var common: Array = []
			var second_groups: Dictionary = {}
			for assumption in (free_by_proof[1] if free_by_proof.size() > 1 else []):
				second_groups[assumption.get_assumption_group()] = true
			for assumption in (free_by_proof[0] if free_by_proof.size() > 0 else []):
				if second_groups.has(assumption.get_assumption_group()):
					common.append(assumption)
			sets.append(common)
	return sets

func _auto_select() -> void:
	# Prefer distinct assumption groups when both case branches expose the
	# same formula. A | A still allows one group to be reused as a fallback;
	# ProofTree treats that as one discharged occurrence.
	var used: Dictionary = {}
	for slot in range(_binder_slots.size()):
		var current: int = int(_binder_slots[slot])
		var candidates: Array = _candidates[slot] if slot < _candidates.size() else []
		var valid := false
		for candidate in candidates:
			if candidate.get_assumption_group() == current:
				valid = true
				break
		if not valid or used.has(current):
			_binder_slots[slot] = -1
		if int(_binder_slots[slot]) >= 0:
			used[int(_binder_slots[slot])] = true

	for slot in range(_binder_slots.size()):
		if int(_binder_slots[slot]) >= 0:
			continue
		var candidates: Array = _candidates[slot] if slot < _candidates.size() else []
		var fallback := -1
		var chosen := -1
		for candidate in candidates:
			var group: int = candidate.get_assumption_group()
			if fallback < 0:
				fallback = group
			if not used.has(group):
				chosen = group
				break
		if chosen < 0:
			chosen = fallback
		if chosen >= 0:
			_binder_slots[slot] = chosen
			used[chosen] = true

func _rebuild_binder_rows() -> void:
	for slot in range(_proof_flows.size()):
		var flow: HFlowContainer = _proof_flows[slot]
		for child in flow.get_children():
			flow.remove_child(child)
			child.queue_free()
		var candidates: Array = _candidates[slot] if slot < _candidates.size() else []
		if candidates.is_empty():
			var empty := UiStyle.make_display_label("no open assumption", 10, UiStyle.muted_text())
			empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			flow.add_child(empty)
			continue
		for candidate in candidates:
			var group: int = candidate.get_assumption_group()
			var button := Button.new()
			button.text = candidate.get_result_formula().to_display_string()
			button.custom_minimum_size = Vector2(70, UiStyle.BLOCK_CONTROL_HEIGHT)
			UiStyle.style_block_button(
				button,
				UiStyle.valid_color() if group == int(_binder_slots[slot]) else UiStyle.lavender(),
				10
			)
			button.tooltip_text = "Discharge this assumption"
			button.pressed.connect(_on_binder_selected.bind(slot, group))
			flow.add_child(button)

func _on_binder_selected(slot: int, group: int) -> void:
	_binder_slots[slot] = group
	if controller != null and controller.has_method("play_sfx"):
		controller.play_sfx("switch_click")
	refresh()
	notify_board_changed()

func _unique_assumptions(source: Array) -> Array:
	var seen: Dictionary = {}
	var result: Array = []
	for assumption in source:
		if assumption == null or not is_instance_valid(assumption):
			continue
		if not assumption.has_method("get_assumption_group"):
			continue
		var group: int = assumption.get_assumption_group()
		if seen.has(group):
			continue
		seen[group] = true
		result.append(assumption)
	return result

func refresh_visuals() -> void:
	if _body_panel == null:
		return
	var bg := UiStyle.rule_color(rule_id)
	var border := UiStyle.border_color()
	match state:
		State.VALID:
			border = UiStyle.valid_color()
		State.ERROR:
			border = UiStyle.error_color()
		State.PENDING:
			border = UiStyle.pending_color()
		State.EMPTY:
			border = UiStyle.border_color()
	if is_goal_linked():
		border = UiStyle.valid_color() if state == State.VALID else UiStyle.accent()
	_body_panel.add_theme_stylebox_override("panel", UiStyle.card_style(bg, border, 14))
	if _warning_badge != null:
		_warning_badge.visible = state == State.ERROR
		var warning_box := UiStyle.panel_style(UiStyle.error_color(), UiStyle.border_color(), 11, 2, false)
		warning_box.content_margin_left = 2.0
		warning_box.content_margin_top = 1.0
		warning_box.content_margin_right = 2.0
		warning_box.content_margin_bottom = 1.0
		_warning_badge.add_theme_stylebox_override("panel", warning_box)
	if _result_visual != null:
		_result_visual.set_formula(result_formula)
		_result_visual.tooltip_text = (
			result_formula.to_display_string()
			if result_formula != null
			else (error_text if not error_text.is_empty() else "not derived")
		)
	if _out_tab != null:
		_out_tab.color = UiStyle.valid_color() if state == State.VALID else UiStyle.border_color()
	var tip := RuleMetaRes.tooltip(rule_id)
	if not error_text.is_empty():
		tip += "\n" + error_text
	tooltip_text = tip
	for socket in sockets:
		socket.refresh_slot_visuals()
