extends PanelContainer

## Clickable level card. Shows lock/completion/challenge state for chapters.

signal pressed(level_id: String)
signal hovered(level_id: String, active: bool)

const ParserRes = preload("res://logic/formula_parser.gd")
const CardWearRes = preload("res://ui/card_wear.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var level_id: String = ""
var level_index: int = 0
var local_number: int = 0
var level_data: Dictionary = {}
var base_color: Color = Color.WHITE
var locked: bool = false
var completed: bool = false
var optional: bool = false
var _paper = null
var _hover: bool = false
var _down: bool = false
var _status: Label = null

func setup(
	p_level_id: String,
	p_local_number: int,
	data: Dictionary,
	color: Color,
	p_locked: bool,
	p_completed: bool,
	p_optional: bool
) -> void:
	level_id = p_level_id
	local_number = p_local_number
	level_data = data
	base_color = color
	locked = p_locked
	completed = p_completed
	optional = p_optional
	add_to_group("nd_level_card")
	custom_minimum_size = Vector2(260, 145)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	)
	tooltip_text = _tooltip_text()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_refresh_style()
	_paper = CardWearRes.apply_to(self, hash(level_id), base_color)

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", 12)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 12)
	content.add_theme_constant_override("margin_bottom", 8)
	add_child(content)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	content.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	var number_text := str(local_number)
	var number := UiStyle.make_display_label(number_text, 18, UiStyle.text_color())
	number.custom_minimum_size = Vector2(42, 26)
	number.clip_text = false
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var number_box := UiStyle.panel_style(UiStyle.cream(), UiStyle.border_color(), 8, 2, false)
	number_box.content_margin_left = 6.0
	number_box.content_margin_top = 3.0
	number_box.content_margin_right = 6.0
	number_box.content_margin_bottom = 3.0
	number.add_theme_stylebox_override("normal", number_box)
	header.add_child(number)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)
	_status = UiStyle.make_display_label(_status_text(), 10, _status_color())
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(_status)

	var title := UiStyle.make_display_label(str(data.get("title", "Level")), 18, UiStyle.text_color())
	box.add_child(title)
	var subtitle := UiStyle.make_hint(str(data.get("subtitle", "")), 12)
	box.add_child(subtitle)

	var stretch := Control.new()
	stretch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stretch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stretch)

	var goal_row := HBoxContainer.new()
	goal_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_row.add_theme_constant_override("separation", 6)
	box.add_child(goal_row)
	var goal_tag := UiStyle.make_display_label("GOAL", 12, UiStyle.muted_text())
	goal_tag.custom_minimum_size = Vector2(42, 16)
	goal_row.add_child(goal_tag)
	var goal_text := str(data.get("goal", ""))
	var parsed := ParserRes.new(goal_text).parse()
	if parsed.ok:
		# Keep the formula visual at every length. A plain Control wrapper has
		# a fixed minimum width, so a long goal cannot widen the whole grid;
		# the visual is scaled down to fit inside the wrapper instead.
		var goal_wrap := Control.new()
		goal_wrap.custom_minimum_size = Vector2(0, 30)
		goal_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		goal_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		goal_wrap.clip_contents = true
		goal_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		goal_row.add_child(goal_wrap)
		var visual = FormulaVisualRes.new()
		visual.setup(parsed.formula, 22, 13)
		visual.custom_minimum_size = Vector2(0, 30)
		visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		visual.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		visual.tooltip_text = goal_text
		goal_wrap.add_child(visual)
		goal_wrap.resized.connect(func() -> void: _fit_goal_visual(goal_wrap, visual))
		call_deferred("_fit_goal_visual", goal_wrap, visual)
	else:
		goal_row.add_child(UiStyle.make_label(goal_text, 13))

func _fit_goal_visual(wrapper: Control, visual: Control) -> void:
	if wrapper == null or not is_instance_valid(wrapper):
		return
	if visual == null or not is_instance_valid(visual):
		return
	var available: float = wrapper.size.x
	if available <= 0.0:
		return
	var natural: Vector2 = visual.get_combined_minimum_size()
	if natural.x <= 0.0:
		return
	var scale := minf(1.0, available / natural.x)
	visual.scale = Vector2(scale, scale)
	visual.position = Vector2(
		0.0,
		maxf(0.0, (wrapper.size.y - natural.y * scale) * 0.5)
	)

func _tooltip_text() -> String:
	var text: String = str(level_data.get("title", "Level")) + "\n" + str(level_data.get("subtitle", ""))
	if locked:
		text += "\nLocked: complete the previous level."
	elif completed:
		text += "\nCompleted."
	elif optional:
		text += "\nOptional challenge."
	return text

func _status_text() -> String:
	if locked:
		return "LOCKED"
	if completed:
		return "DONE"
	if optional:
		return "OPTIONAL"
	return ""

func _status_color() -> Color:
	if locked:
		return UiStyle.muted_text()
	if completed:
		return UiStyle.valid_color()
	if optional:
		return UiStyle.pending_color()
	return UiStyle.muted_text()

func _on_hover(active: bool) -> void:
	if locked:
		return
	_hover = active
	hovered.emit(level_id, active)
	_refresh_style()

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			_refresh_style()
		else:
			var inside := Rect2(Vector2.ZERO, size).has_point(event.position)
			_down = false
			_refresh_style()
			if inside:
				pressed.emit(level_id)

func _refresh_style() -> void:
	var fill := base_color
	if _hover:
		fill = fill.lightened(0.12)
	if _down:
		fill = fill.darkened(0.08)
	add_theme_stylebox_override("panel", UiStyle.empty_style())
	if _paper != null:
		_paper.set_fill(fill)
	modulate = Color(1.0, 1.0, 1.0, 0.72) if locked else Color.WHITE
	if _status != null:
		_status.text = _status_text()
		_status.add_theme_color_override("font_color", _status_color())
