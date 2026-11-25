extends "res://ui/block_base.gd"

## A freely created hypothesis. It is a formula leaf, not a premise, and carries
## a group id so copies can represent the same hypothesis in multiple branches.

const FormulaRes = preload("res://logic/formula.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const IconButtonRes = preload("res://ui/icon_button.gd")
const CardMetrics = preload("res://ui/card_metrics.gd")

var formula: FormulaRes = null
var assumption_group: int = 0
var _visual = null
var _overlay: Control = null
var _margin: MarginContainer = null
var _box: VBoxContainer = null
var _header: HBoxContainer = null
var _tag: Label = null
var _copy = null
var _corner_tag: Label = null
var _corner_copy = null
var _mode := CardMetrics.DEFAULT

func setup_assumption(p_formula: FormulaRes, p_group: int) -> void:
	formula = p_formula
	assumption_group = p_group
	_mode = _resolve_mode()
	add_to_group("nd_formula_card")
	var metrics := CardMetrics.assumption_block(_mode)
	custom_minimum_size = metrics["min_size"]
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = "Assume " + formula.to_display_string() + "\nOpen hypothesis; discharge it with an intro rule."
	mouse_default_cursor_shape = Control.CURSOR_DRAG

	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", int(metrics["separation"]))
	_margin.add_child(_box)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_header = HBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_constant_override("separation", 2)
	_box.add_child(_header)
	_tag = UiStyle.make_display_label("ASSUME", 10, UiStyle.muted_text())
	_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header.add_child(_tag)
	_copy = IconButtonRes.new()
	_copy.setup("copy", "Duplicate this assumption (same hypothesis group).")
	_copy.pressed.connect(_on_copy)
	_header.add_child(_copy)

	# Compact mode removes the header row and places these same controls in
	# the corners so the formula gets the full card height.
	_corner_tag = UiStyle.make_display_label("ASSUME", 8, UiStyle.muted_text())
	_corner_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_corner_tag)
	_corner_copy = IconButtonRes.new()
	_corner_copy.setup("copy", "Duplicate this assumption (same hypothesis group).")
	_corner_copy.pressed.connect(_on_copy)
	_overlay.add_child(_corner_copy)

	_visual = FormulaVisualRes.new()
	_visual.setup(formula, int(metrics["token_size"]), int(metrics["font_size"]))
	_visual.custom_minimum_size = Vector2(0, float(metrics["visual_min_height"]))
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_visual)

	_apply_mode_geometry()
	refresh_visuals()

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
	var metrics := CardMetrics.assumption_block(_mode)
	custom_minimum_size = metrics["min_size"]
	if _box != null:
		_box.add_theme_constant_override("separation", int(metrics["separation"]))
	if _margin != null:
		var side := int(metrics["margin_side"])
		var top := int(metrics["margin_top"])
		var right := int(metrics.get("margin_right", side))
		_margin.add_theme_constant_override("margin_left", side)
		_margin.add_theme_constant_override("margin_top", top)
		_margin.add_theme_constant_override("margin_right", right)
		_margin.add_theme_constant_override("margin_bottom", top)
	if _header != null:
		_header.visible = bool(metrics["show_header"])
	var compact := not bool(metrics["show_header"])
	if _corner_tag != null:
		_corner_tag.visible = compact
		_corner_tag.add_theme_font_size_override("font_size", int(metrics["font_size"]))
		_corner_tag.position = Vector2(float(metrics["corner_inset"]), float(metrics["corner_inset"]))
	if _corner_copy != null:
		_corner_copy.visible = compact
		var inset := float(metrics["corner_inset"])
		_corner_copy.anchor_left = 1.0
		_corner_copy.anchor_right = 1.0
		_corner_copy.offset_left = -30.0 - inset
		_corner_copy.offset_top = inset
		_corner_copy.offset_right = -inset
		_corner_copy.offset_bottom = 30.0 + inset
	if _visual != null:
		_visual.set_metrics(
			int(metrics["token_size"]),
			int(metrics["font_size"]),
			float(metrics["visual_min_height"])
		)

func _on_copy() -> void:
	if controller != null and controller.has_method("duplicate_to_canvas"):
		controller.duplicate_to_canvas(self)

func get_result_formula():
	return formula

func is_assumption_block() -> bool:
	return true

func get_assumption_group() -> int:
	return assumption_group

func get_free_assumptions() -> Array:
	return [self]

func get_display_text() -> String:
	if formula == null:
		return "assume"
	return "assume " + formula.to_display_string()

func refresh() -> void:
	if _visual != null and formula != null:
		_visual.set_formula(formula)

func refresh_visuals() -> void:
	if formula != null:
		tooltip_text = "Assume " + formula.to_display_string() + "\nOpen hypothesis; discharge it with an intro rule."
	var metrics := CardMetrics.assumption_block(_mode)
	add_theme_stylebox_override(
		"panel",
		CardMetrics.formula_card_style_with_margins(
			Color8(244, 219, 255),
			UiStyle.border_color(),
			_mode,
			float(metrics["margin_side"]),
			float(metrics["margin_top"])
		)
	)
