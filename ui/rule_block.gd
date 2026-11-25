extends "res://ui/block_base.gd"

## Icon-first, square-ish rule card. Inputs sit on top, the rule pictogram and
## the result strip live in the body. Rule names are tooltips, never labels.

const BlockSocketRes = preload("res://ui/block_socket.gd")
const FormulaBlockRes = preload("res://ui/formula_block.gd")
const IconButtonRes = preload("res://ui/icon_button.gd")
const RuleIconRes = preload("res://ui/rule_icon.gd")
const RuleSideSwitchRes = preload("res://ui/rule_side_switch.gd")
const RuleMetaRes = preload("res://ui/rule_meta.gd")
const FormulaRes = preload("res://logic/formula.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const RulesRes = preload("res://logic/rules.gd")
const CardMetrics = preload("res://ui/card_metrics.gd")

enum State { EMPTY, PENDING, ERROR, VALID }

signal state_changed(previous: int, current: int)

var rule_id: String = ""
var side: int = 0
var sockets: Array = []
var extra_socket = null
var result_formula: FormulaRes = null
var extra_formula: FormulaRes = null
var state: State = State.EMPTY
var error_text: String = ""
var _previous_state: int = State.EMPTY

var _body_panel: PanelContainer = null
var _icon_plate: PanelContainer = null
var _warning_badge: PanelContainer = null
var _result_visual = null
var _out_tab: ColorRect = null
var _inputs_row: HBoxContainer = null
var _or_separator: Label = null
var _rule_icon = null
var _side_switch = null
var _header: HBoxContainer = null
var _overlay: Control = null
var _corner_warning: PanelContainer = null
var _corner_side_switch = null
var _corner_copy = null
var _mode := CardMetrics.DEFAULT

func setup(p_rule_id: String, p_controller) -> void:
	rule_id = p_rule_id
	side = 1 if rule_id.ends_with("_right") else 0
	controller = p_controller
	_mode = _resolve_mode()
	add_to_group("nd_rule_block")
	custom_minimum_size = Vector2(230, 0)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = RuleMetaRes.tooltip(rule_id)
	add_theme_stylebox_override("panel", UiStyle.empty_style())

	var root := VBoxContainer.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_theme_constant_override("separation", 2)
	add_child(root)

	var inputs := HBoxContainer.new()
	inputs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inputs.alignment = BoxContainer.ALIGNMENT_CENTER
	inputs.add_theme_constant_override("separation", 6)
	inputs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(inputs)
	_inputs_row = inputs

	var has_extra := RulesRes.takes_extra(rule_id)
	var is_lem := rule_id == "lem"
	var extra_on_left := rule_id == "or_intro_right"
	if has_extra and is_lem:
		# Excluded middle has no proof input; just one external "other" slot.
		_add_extra_socket(inputs)
	elif has_extra and extra_on_left:
		_add_extra_socket(inputs)
		_or_separator = _make_or_separator()
		inputs.add_child(_or_separator)

	var arity := RulesRes.arity(rule_id)
	for index in range(arity):
		var socket := BlockSocketRes.new()
		socket.setup(self, "", controller)
		inputs.add_child(socket)
		sockets.append(socket)

	if has_extra and not is_lem and not extra_on_left:
		_or_separator = _make_or_separator()
		inputs.add_child(_or_separator)
		_add_extra_socket(inputs)

	_body_panel = PanelContainer.new()
	_body_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(_body_panel)

	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 4)
	_body_panel.add_child(body)

	_header = HBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(_header)
	var header := _header

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

	if _is_switchable():
		_side_switch = RuleSideSwitchRes.new()
		_side_switch.setup(side)
		_side_switch.tooltip_text = _side_switch_hint()
		_side_switch.changed.connect(_on_side_changed)
		if controller != null and controller.has_method("play_sfx"):
			_side_switch.mouse_entered.connect(
				func() -> void: controller.play_sfx("button_hover")
			)
		header.add_child(_side_switch)

	var copy_button = IconButtonRes.new()
	copy_button.setup("copy", "Duplicate this rule and its inputs.")
	copy_button.pressed.connect(_on_copy_pressed)
	header.add_child(copy_button)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_body_panel.add_child(_overlay)

	_corner_warning = PanelContainer.new()
	_corner_warning.custom_minimum_size = Vector2(22, 22)
	_corner_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner_warning.visible = false
	var corner_warning_label := UiStyle.make_display_label("!", 15, UiStyle.cream())
	corner_warning_label.custom_minimum_size = Vector2(14, 14)
	corner_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	corner_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_corner_warning.add_child(corner_warning_label)
	_corner_warning.position = Vector2(6, 6)
	_overlay.add_child(_corner_warning)

	if _is_switchable():
		_corner_side_switch = RuleSideSwitchRes.new()
		_corner_side_switch.setup(side)
		_corner_side_switch.tooltip_text = _side_switch_hint()
		_corner_side_switch.changed.connect(_on_side_changed)
		_corner_side_switch.anchor_left = 1.0
		_corner_side_switch.anchor_right = 1.0
		_corner_side_switch.offset_left = -100.0
		_corner_side_switch.offset_top = 6.0
		_corner_side_switch.offset_right = -42.0
		_corner_side_switch.offset_bottom = 32.0
		_overlay.add_child(_corner_side_switch)

	_corner_copy = IconButtonRes.new()
	_corner_copy.setup("copy", "Duplicate this rule and its inputs.")
	_corner_copy.pressed.connect(_on_copy_pressed)
	_corner_copy.anchor_left = 1.0
	_corner_copy.anchor_right = 1.0
	_corner_copy.offset_left = -36.0
	_corner_copy.offset_top = 6.0
	_corner_copy.offset_right = -6.0
	_corner_copy.offset_bottom = 36.0
	_overlay.add_child(_corner_copy)
	_apply_mode_geometry()

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(icon_center)

	_icon_plate = PanelContainer.new()
	_icon_plate.custom_minimum_size = Vector2(76, 76)
	_icon_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule_icon = RuleIconRes.new()
	_rule_icon.setup(rule_id)
	_icon_plate.add_child(_rule_icon)
	icon_center.add_child(_icon_plate)

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
	out_icon.tooltip_text = "Derived formula"
	out_row.add_child(out_icon)
	_result_visual = FormulaVisualRes.new()
	_result_visual.setup(null, 24, 14)
	_result_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_visual.custom_minimum_size = Vector2(0, 34)
	_result_visual.alignment = BoxContainer.ALIGNMENT_CENTER
	out_row.add_child(_result_visual)

	_out_tab = ColorRect.new()
	_out_tab.color = UiStyle.border_color()
	_out_tab.custom_minimum_size = Vector2(52, 5)
	_out_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_out_tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(_out_tab)

	refresh()

func _resolve_mode() -> String:
	if controller != null and controller.has_method("get_card_size_mode"):
		return CardMetrics.normalize(str(controller.get_card_size_mode()))
	return CardMetrics.DEFAULT

func apply_card_size_mode(mode: String) -> void:
	var normalized := CardMetrics.normalize(mode)
	if normalized == _mode:
		return
	_mode = normalized
	_apply_mode_geometry()
	refresh_visuals()
	update_minimum_size()
	reset_size()

func _apply_mode_geometry() -> void:
	var compact := _mode == CardMetrics.COMPACT
	if _header != null:
		_header.visible = not compact
	if _overlay != null:
		_overlay.visible = compact
	if _corner_side_switch != null:
		_corner_side_switch.visible = compact and _is_switchable()
		_corner_side_switch.anchor_left = 0.0
		_corner_side_switch.anchor_right = 0.0
		_corner_side_switch.offset_left = 4.0
		_corner_side_switch.offset_top = 0.0
		_corner_side_switch.offset_right = 62.0
		_corner_side_switch.offset_bottom = 26.0
	if _corner_copy != null:
		_corner_copy.visible = compact
		_corner_copy.anchor_left = 1.0
		_corner_copy.anchor_right = 1.0
		_corner_copy.offset_left = -36.0
		_corner_copy.offset_top = 0.0
		_corner_copy.offset_right = -6.0
		_corner_copy.offset_bottom = 30.0
	if _corner_warning != null:
		_corner_warning.visible = compact and state == State.ERROR
		_corner_warning.position = Vector2(6.0, 32.0 if _is_switchable() else 0.0)

## A second, visually separate socket for the other side of a disjunction.
func _add_extra_socket(parent: HBoxContainer) -> void:
	extra_socket = BlockSocketRes.new()
	extra_socket.setup(self, "other", controller)
	extra_socket.set_accepts_replacement(true)
	extra_socket.activated.connect(_on_extra_socket_activated)
	parent.add_child(extra_socket)

func _on_extra_socket_activated() -> void:
	if controller != null and controller.has_method("open_formula_builder"):
		controller.open_formula_builder(self)

func _make_or_separator() -> Label:
	var label := UiStyle.make_display_label("|", 20, UiStyle.border_color())
	label.custom_minimum_size = Vector2(12, 0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.tooltip_text = "Disjunction: one side | the other side"
	return label

func _is_switchable() -> bool:
	return rule_id in [
		"and_elim_left",
		"and_elim_right",
		"or_intro_left",
		"or_intro_right",
	]

func _side_switch_hint() -> String:
	if rule_id.begins_with("and_elim"):
		return "Click to switch: take the left or right conjunct."
	return "Click to switch: prove the left or right disjunct."

func _on_side_changed(new_side: int) -> void:
	if new_side == side:
		return
	if controller != null and controller.has_method("record_undo"):
		controller.record_undo()
	side = new_side
	if rule_id.begins_with("and_elim"):
		rule_id = "and_elim_right" if side == 1 else "and_elim_left"
	elif rule_id.begins_with("or_intro"):
		rule_id = "or_intro_right" if side == 1 else "or_intro_left"
	else:
		return
	if _rule_icon != null:
		_rule_icon.setup(rule_id)
	if _side_switch != null:
		_side_switch.set_side(side)
		_side_switch.tooltip_text = _side_switch_hint()
	if _corner_side_switch != null:
		_corner_side_switch.set_side(side)
		_corner_side_switch.tooltip_text = _side_switch_hint()
	_reorder_side_inputs()
	tooltip_text = RuleMetaRes.tooltip(rule_id)
	if controller != null and controller.has_method("play_sfx"):
		controller.play_sfx("switch_click")
	refresh()
	notify_board_changed()

## Keep the visual disjunction order matching the selected side.
func _reorder_side_inputs() -> void:
	if _inputs_row == null or _or_separator == null:
		return
	if extra_socket == null or sockets.is_empty():
		return
	if rule_id == "or_intro_left":
		_inputs_row.move_child(sockets[0], 0)
		_inputs_row.move_child(_or_separator, 1)
		_inputs_row.move_child(extra_socket, 2)
	else:
		_inputs_row.move_child(extra_socket, 0)
		_inputs_row.move_child(_or_separator, 1)
		_inputs_row.move_child(sockets[0], 2)

## The root panel is transparent, so its rectangular bounds are larger than
## the visible card. Only the body card and the real input sockets can be
## grabbed; the gap around the inputs falls through to the canvas.
func _has_point(point: Vector2) -> bool:
	var global_point := get_global_transform() * point
	if _body_panel != null and _body_panel.is_visible_in_tree():
		if _body_panel.get_global_rect().has_point(global_point):
			return true
	for socket in sockets:
		if is_instance_valid(socket) and socket.is_visible_in_tree():
			if socket.get_global_rect().has_point(global_point):
				return true
	if extra_socket != null and is_instance_valid(extra_socket) and extra_socket.is_visible_in_tree():
		if extra_socket.get_global_rect().has_point(global_point):
			return true
	return false

## Explicit recursive recompute; no persistent signal graph.
func refresh() -> void:
	if _refreshing:
		return
	_refreshing = true

	var formulas: Array = []
	var missing_count := 0
	var incomplete := false
	for socket in sockets:
		var block = socket.get_attached_block()
		if block == null:
			missing_count += 1
			continue
		block.refresh()
		var child_formula = block.get_result_formula()
		if child_formula == null:
			incomplete = true
		else:
			formulas.append(child_formula)

	result_formula = null
	error_text = ""
	extra_formula = null

	# Read the other side even while proof inputs are still missing, so it
	# survives a partially built card and can be copied/edited independently.
	var extra_missing := false
	var extra_incomplete := false
	if RulesRes.takes_extra(rule_id):
		var extra_block = extra_socket.get_attached_block() if extra_socket != null else null
		if extra_block == null:
			extra_missing = true
		else:
			extra_block.refresh()
			extra_formula = extra_block.get_result_formula()
			if extra_formula == null:
				extra_incomplete = true

	if missing_count > 0:
		state = State.EMPTY
		error_text = "waiting for input"
	elif incomplete:
		state = State.PENDING
		error_text = "an input is incomplete"
	elif extra_missing:
		state = State.PENDING
		error_text = "missing other-side formula"
	elif extra_incomplete:
		state = State.PENDING
		error_text = "other side is incomplete"
	else:
		var derivation := RulesRes.derive(rule_id, formulas, extra_formula)
		if derivation.ok:
			result_formula = derivation.formula
			state = State.VALID
			error_text = ""
		else:
			state = State.ERROR
			error_text = derivation.error

	_refreshing = false
	refresh_visuals()
	if state != _previous_state:
		var previous := _previous_state
		_previous_state = state
		state_changed.emit(previous, state)

func get_result_formula():
	return result_formula

func get_rule_id() -> String:
	return rule_id

## Current other-side formula as text (empty when unset).
func get_extra_text() -> String:
	return extra_formula.to_display_string() if extra_formula != null else ""

## Attach a formula block as the other side of the disjunction.
func set_extra_formula(formula) -> void:
	if extra_socket == null:
		return
	var old = extra_socket.get_attached_block()
	if old != null:
		extra_socket.detach_block(false)
		old.queue_free()
	if formula != null:
		var chip = FormulaBlockRes.new()
		chip.controller = controller
		chip.setup(formula)
		extra_socket.attach_block(chip, false)
	refresh()
	notify_board_changed()

## Compatibility helper for tests and text-style callers.
func set_extra_text(text: String) -> void:
	var trimmed := text.strip_edges()
	if trimmed.is_empty():
		set_extra_formula(null)
		return
	var parsed := ParserRes.new(trimmed).parse()
	set_extra_formula(parsed.formula if parsed.ok else null)

func get_display_text() -> String:
	if result_formula != null:
		return "%s => %s" % [rule_id, result_formula.to_display_string()]
	return rule_id

## Input blocks in socket order, with null holes for empty sockets.
func get_input_blocks() -> Array:
	var blocks: Array = []
	for socket in sockets:
		blocks.append(socket.get_attached_block())
	return blocks

## Simple rules keep every assumption used by their proof inputs.
func get_free_assumptions() -> Array:
	var sources: Array = []
	for socket in sockets:
		var block = socket.get_attached_block()
		if block != null:
			sources.append(block)
	return merge_assumption_blocks(sources)

## Parsed explicit other-side formula for or_intro_* after refresh.
func get_extra_formula():
	return extra_formula

## Rebuild body/port colors from the current state.
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
	_body_panel.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(bg, border, 14)
	)
	if _icon_plate != null:
		_icon_plate.add_theme_stylebox_override(
			"panel",
			UiStyle.panel_style(UiStyle.cream(), UiStyle.border_color(), 12, 3, false)
		)
	if _warning_badge != null:
		var compact := _mode == CardMetrics.COMPACT
		_warning_badge.visible = state == State.ERROR and not compact
		if _corner_warning != null:
			_corner_warning.visible = state == State.ERROR and compact
		var warning_box := UiStyle.panel_style(UiStyle.error_color(), UiStyle.border_color(), 11, 2, false)
		warning_box.content_margin_left = 2.0
		warning_box.content_margin_top = 1.0
		warning_box.content_margin_right = 2.0
		warning_box.content_margin_bottom = 1.0
		_warning_badge.add_theme_stylebox_override("panel", warning_box)
		if _corner_warning != null:
			_corner_warning.add_theme_stylebox_override("panel", warning_box)

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

## Duplicate this block via the board.
func _on_copy_pressed() -> void:
	if controller != null and controller.has_method("duplicate_to_canvas"):
		controller.duplicate_to_canvas(self)


