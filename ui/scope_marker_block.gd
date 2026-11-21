extends "res://ui/block_base.gd"

## Compact marker left on the parent canvas after an assumption window is closed.
## It represents A -> conclusion and can be opened again or plugged into rules.

const FormulaRes = preload("res://logic/formula.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")

var assumption_formula: FormulaRes = null
var assumption_group: int = 0
var scope_color: Color = Color8(226, 211, 248)
var conclusion_block = null
var result_formula: FormulaRes = null
var window_record = null

var _result_visual = null
var _open_button: Button = null
var _assumption_label: Label = null

func setup_marker(formula: FormulaRes, group: int, p_controller, tint: Color = Color8(226, 211, 248)) -> void:
	assumption_formula = formula
	assumption_group = group
	scope_color = tint
	controller = p_controller
	custom_minimum_size = Vector2(168, 82)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(tint, UiStyle.border_color(), 12)
	)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 4)
	box.add_child(header)
	_assumption_label = UiStyle.make_display_label(
		"Assume [" + assumption_formula.to_display_string() + "]",
		10,
		UiStyle.muted_text()
	)
	_assumption_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_assumption_label.clip_text = true
	_assumption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_assumption_label.tooltip_text = "Assume " + assumption_formula.to_display_string()
	header.add_child(_assumption_label)
	_open_button = Button.new()
	_open_button.text = "OPEN"
	_open_button.custom_minimum_size = Vector2(46, 20)
	UiStyle.style_button(_open_button, tint, 9)
	_open_button.pressed.connect(_on_open)
	header.add_child(_open_button)

	_result_visual = FormulaVisualRes.new()
	_result_visual.setup(null, 20, 11)
	_result_visual.custom_minimum_size = Vector2(0, 30)
	_result_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_result_visual.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_result_visual)

func _on_open() -> void:
	if controller != null and controller.has_method("open_scope_marker"):
		controller.open_scope_marker(self)

func is_scope_block() -> bool:
	return true

func get_scope_color() -> Color:
	return scope_color

func get_rule_id() -> String:
	return "impl_intro"

func get_assumption_group() -> int:
	return assumption_group

func get_scope_assumption_formula():
	return assumption_formula

func get_scope_proof_block():
	return conclusion_block

func get_window_record():
	return window_record

func set_conclusion(block) -> void:
	conclusion_block = block
	refresh_bottom_pin()
	refresh()

func get_result_formula():
	return result_formula

func get_display_text() -> String:
	if result_formula != null:
		return "assume %s => %s" % [assumption_formula.to_display_string(), result_formula.to_display_string()]
	return "assume " + assumption_formula.to_display_string()

func get_free_assumptions() -> Array:
	var result: Array = []
	if conclusion_block == null or not is_instance_valid(conclusion_block):
		return result
	for assumption in conclusion_block.get_free_assumptions():
		if assumption == null or not is_instance_valid(assumption):
			continue
		if assumption.get_assumption_group() == assumption_group:
			continue
		result.append(assumption)
	return result

func refresh() -> void:
	result_formula = null
	if conclusion_block != null and is_instance_valid(conclusion_block):
		conclusion_block.refresh()
		var consequent = conclusion_block.get_result_formula()
		if consequent != null:
			result_formula = FormulaRes.new(
				FormulaRes.Kind.IMPLIES,
				"",
				assumption_formula,
				consequent
			)
	refresh_visuals()

func refresh_visuals() -> void:
	if _assumption_label != null and assumption_formula != null:
		_assumption_label.text = "Assume [" + assumption_formula.to_display_string() + "]"
		_assumption_label.tooltip_text = "Assume " + assumption_formula.to_display_string()
	if _result_visual != null:
		_result_visual.set_formula(result_formula)
		_result_visual.tooltip_text = (
			result_formula.to_display_string() if result_formula != null else "open the assumption window"
		)
	tooltip_text = (
		"Assume " + assumption_formula.to_display_string()
		+ "\nOpen the floating sub-canvas to edit this proof."
	)
