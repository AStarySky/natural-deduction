extends PanelContainer

## Compact Goal / Check chip. Shows the goal picture and validation status,
## accepts the final block as a drop target, and checks on click.

signal check_requested
signal solved_changed(solved: bool)

const FormulaRes = preload("res://logic/formula.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const ProofAdapterRes = preload("res://ui/proof_adapter.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var controller = null
var goal_formula: FormulaRes = null
var linked_block = null

var _goal_visual = null
var _status_label: Label = null
var _drag_hover: bool = false
var _solved: bool = false

## Build (or rebuild) the compact goal chip.
func setup(p_goal: FormulaRes, p_controller) -> void:
	if linked_block != null and is_instance_valid(linked_block):
		linked_block.set_goal_linked(false)
	linked_block = null
	_drag_hover = false
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_goal_visual = null
	_status_label = null

	goal_formula = p_goal
	controller = p_controller
	tooltip_text = "Goal: " + (p_goal.to_display_string() if p_goal != null else "?")
	custom_minimum_size = Vector2(300, 48)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_refresh_bar_style()

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	var goal_tag := UiStyle.make_display_label("GOAL", 11, UiStyle.muted_text())
	goal_tag.custom_minimum_size = Vector2(34, 16)
	row.add_child(goal_tag)
	_goal_visual = FormulaVisualRes.new()
	_goal_visual.setup(goal_formula, 18, 11)
	_goal_visual.custom_minimum_size = Vector2(0, 26)
	_goal_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_goal_visual.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(_goal_visual)

	_status_label = UiStyle.make_display_label("WAITING", 12, UiStyle.muted_text())
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status_label.custom_minimum_size = Vector2(74, 16)
	row.add_child(_status_label)

	refresh()

## Link a block as the submitted conclusion (does not reparent it).
func set_linked_block(block, notify: bool = true) -> void:
	if linked_block != null and is_instance_valid(linked_block):
		linked_block.set_goal_linked(false)
	linked_block = block
	if linked_block != null and is_instance_valid(linked_block):
		linked_block.set_goal_linked(true)
	if notify and controller != null and controller.has_method("refresh_machine"):
		controller.refresh_machine()
	else:
		refresh()

## Remove the current submission.
func clear_link() -> void:
	if linked_block != null and is_instance_valid(linked_block):
		linked_block.set_goal_linked(false)
	linked_block = null
	refresh()

## Recompute the compact status badge.
func refresh() -> void:
	if linked_block != null and not is_instance_valid(linked_block):
		linked_block = null
	var goal_text := goal_formula.to_display_string() if goal_formula != null else "?"

	if linked_block == null:
		_set_status("WAITING", UiStyle.muted_text(), "Goal: " + goal_text)
		return

	linked_block.refresh()
	var result = linked_block.get_result_formula()
	if result == null:
		_set_status("INCOMPLETE", UiStyle.pending_color(), "Goal: " + goal_text + "\nProof is incomplete.")
		return
	if not result.equals(goal_formula):
		_set_status("MISMATCH", UiStyle.error_color(), "Goal: " + goal_text + "\nConclusion does not match.")
		return

	var validation := ProofAdapterRes.validate(linked_block, goal_formula)
	if validation.ok:
		_set_status("VALID", UiStyle.valid_color(), "Goal: " + goal_text + "\nProof verified.")
	else:
		_set_status("INVALID", UiStyle.error_color(), "Goal: " + goal_text + "\n" + _join_errors(validation.errors))

## Set the status label and tooltip without adding a bulky detail row.
func _set_status(title: String, color: Color, tip: String) -> void:
	if _status_label != null:
		_status_label.text = title
		_status_label.add_theme_color_override("font_color", color)
	tooltip_text = tip
	var solved := title == "VALID"
	if solved != _solved:
		_solved = solved
		solved_changed.emit(_solved)

func is_solved() -> bool:
	return _solved

func get_status_text() -> String:
	return _status_label.text if _status_label != null else ""

## Highlight the chip while a block is dragged over it.
func set_drag_hover(active: bool) -> void:
	if _drag_hover == active:
		return
	_drag_hover = active
	_refresh_bar_style()

## Clicking the chip checks the last rule block (handled by the board).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
			check_requested.emit()

## Cream chip with a strong border; green while hovered by a dragged block.
func _refresh_bar_style() -> void:
	var border := UiStyle.border_color()
	if _drag_hover:
		border = UiStyle.valid_color()
	add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(UiStyle.cream(), border, 12)
	)

## Direct drop hooks retained for the headless model test.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if str(data.get("kind", "")) != "move_block":
		return false
	var block = data.get("block")
	return is_instance_valid(block) and block is Control and block.has_method("get_result_formula")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data):
		return
	set_linked_block(data.get("block"), true)

## Join structured validation errors for a tooltip.
func _join_errors(errors: Array[String]) -> String:
	var text := ""
	for index in range(errors.size()):
		if index > 0:
			text += "\n"
		text += errors[index]
	return text
