extends "res://ui/formula_block.gd"

## Compact marker left on the parent canvas after an assumption window is closed.
## It uses the same card chrome as a formula leaf, with a small OPEN corner
## button for reopening the sub-canvas.

var assumption_formula: FormulaRes = null
var assumption_group: int = 0
var scope_color: Color = Color8(226, 211, 248)
var conclusion_block = null
var window_record = null

var _open_button: Button = null
var _content_margin: MarginContainer = null

func setup_marker(formula: FormulaRes, group: int, p_controller, tint: Color = Color8(226, 211, 248)) -> void:
	assumption_formula = formula
	assumption_group = group
	scope_color = tint
	controller = p_controller

	# Build the normal formula-leaf chrome first, then tint it and reserve a
	# narrow right gutter for the OPEN button.
	setup(formula)
	_card_fill = scope_color
	_accent_fill = scope_color
	_customize_open_button()

func _customize_open_button() -> void:
	# FormulaBlock puts its content directly under the panel; wrap the VBox so
	# the right gutter can never sit on top of the formula.
	if _vbox != null and _vbox.get_parent() == self:
		remove_child(_vbox)
		_content_margin = MarginContainer.new()
		_content_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_content_margin.add_theme_constant_override("margin_right", 52)
		add_child(_content_margin)
		_content_margin.add_child(_vbox)
		_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _overlay != null:
			move_child(_overlay, get_child_count() - 1)

	_open_button = Button.new()
	_open_button.text = "OPEN"
	_open_button.custom_minimum_size = Vector2(44, 20)
	_open_button.tooltip_text = "Reopen this assumption window."
	UiStyle.style_button(_open_button, scope_color, 9)
	_open_button.pressed.connect(_on_open)
	_open_button.anchor_left = 1.0
	_open_button.anchor_right = 1.0
	_open_button.offset_left = -50.0
	_open_button.offset_top = 6.0
	_open_button.offset_right = -6.0
	_open_button.offset_bottom = 26.0
	_overlay.add_child(_open_button)
	refresh_visuals()

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

func get_display_text() -> String:
	if formula != null:
		return "assume %s => %s" % [assumption_formula.to_display_string(), formula.to_display_string()]
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
	formula = null
	if conclusion_block != null and is_instance_valid(conclusion_block):
		conclusion_block.refresh()
		var consequent = conclusion_block.get_result_formula()
		if consequent != null:
			formula = FormulaRes.new(
				FormulaRes.Kind.IMPLIES,
				"",
				assumption_formula,
				consequent
			)
	if _visual != null:
		_visual.set_formula(formula)
	refresh_visuals()

func refresh_visuals() -> void:
	if _card_fill != scope_color:
		_card_fill = scope_color
		_accent_fill = scope_color
	super.refresh_visuals()
	if _open_button != null:
		_open_button.tooltip_text = (
			"Reopen this assumption window.\nAssume "
			+ assumption_formula.to_display_string()
		)
	tooltip_text = (
		"Assume " + assumption_formula.to_display_string()
		+ "\nOpen the floating sub-canvas to edit this proof."
	)
