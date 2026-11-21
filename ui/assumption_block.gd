extends "res://ui/block_base.gd"

## A freely created hypothesis. It is a formula leaf, not a premise, and carries
## a group id so copies can represent the same hypothesis in multiple branches.

const FormulaRes = preload("res://logic/formula.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const IconButtonRes = preload("res://ui/icon_button.gd")

var formula: FormulaRes = null
var assumption_group: int = 0
var _visual = null

func setup_assumption(p_formula: FormulaRes, p_group: int) -> void:
	formula = p_formula
	assumption_group = p_group
	custom_minimum_size = Vector2(104, 92)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = "Assume " + formula.to_display_string() + "\nOpen hypothesis; discharge it with an intro rule."
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	add_theme_stylebox_override("panel", UiStyle.card_style(
		Color8(244, 219, 255),
		UiStyle.border_color(),
		12
	))

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 9)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 9)
	margin.add_theme_constant_override("margin_bottom", 7)
	add_child(margin)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 2)
	box.add_child(header)
	var tag := UiStyle.make_display_label("ASSUME", 10, UiStyle.muted_text())
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(tag)
	var copy := IconButtonRes.new()
	copy.setup("copy", "Duplicate this assumption (same hypothesis group).")
	copy.pressed.connect(_on_copy)
	header.add_child(copy)

	_visual = FormulaVisualRes.new()
	_visual.setup(formula, 24, 13)
	_visual.custom_minimum_size = Vector2(0, 38)
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_visual)

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
