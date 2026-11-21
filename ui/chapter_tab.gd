extends PanelContainer

## Chapter tab used by the level select page. Shows progress and lock state.

signal pressed(chapter_id: String)
signal hovered(chapter_id: String, active: bool)

const CardWearRes = preload("res://ui/card_wear.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var chapter_id: String = ""
var chapter_index: int = 0
var chapter_data: Dictionary = {}
var progress: Dictionary = {}
var selected: bool = false
var locked: bool = false
var _paper = null
var _hover: bool = false
var _status: Label = null

func setup(
	data: Dictionary,
	p_index: int,
	p_progress: Dictionary,
	p_selected: bool
) -> void:
	chapter_data = data
	chapter_index = p_index
	chapter_id = str(data.get("id", ""))
	progress = p_progress
	selected = p_selected
	locked = not bool(p_progress.get("unlocked", false))
	add_to_group("nd_chapter_tab")
	custom_minimum_size = Vector2(168, 76)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = (
		Control.CURSOR_ARROW if locked else Control.CURSOR_POINTING_HAND
	)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	tooltip_text = _tooltip_text()
	_refresh_style()
	var tint: Color = data.get("color", UiStyle.sky())
	_paper = CardWearRes.apply_to(self, hash(chapter_id), tint)

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", 10)
	content.add_theme_constant_override("margin_top", 7)
	content.add_theme_constant_override("margin_right", 10)
	content.add_theme_constant_override("margin_bottom", 7)
	add_child(content)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 1)
	content.add_child(box)

	var number_text := "%02d" % (p_index + 1)
	var title_text := "%s %s" % [number_text, str(data.get("title", "")).to_upper()]
	var title := UiStyle.make_display_label(title_text, 13, UiStyle.text_color())
	title.clip_text = true
	box.add_child(title)

	var subtitle := UiStyle.make_display_label(
		str(data.get("subtitle", "")),
		9,
		UiStyle.border_color()
	)
	subtitle.clip_text = true
	box.add_child(subtitle)

	_status = UiStyle.make_display_label(_progress_text(), 10, UiStyle.muted_text())
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(_status)
	_refresh_style()

func _progress_text() -> String:
	if locked:
		return "LOCKED"
	var core_done := int(progress.get("core_done", 0))
	var core_total := int(progress.get("core_total", 6))
	var text := "%d/%d CORE" % [core_done, core_total]
	# Optional levels are numbered normally; core completion is the gate.
	return text

func _tooltip_text() -> String:
	var text := str(chapter_data.get("title", ""))
	var blurb := str(chapter_data.get("blurb", ""))
	if not blurb.is_empty():
		text += "\n" + blurb
	if locked:
		text += "\nLocked: complete the previous chapter."
	else:
		text += "\n" + _progress_text()
	return text

func _on_hover(active: bool) -> void:
	if locked:
		return
	_hover = active
	hovered.emit(chapter_id, active)
	_refresh_style()

func _gui_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
			pressed.emit(chapter_id)

func _refresh_style() -> void:
	var fill: Color = chapter_data.get("color", UiStyle.sky())
	if _hover:
		fill = fill.lightened(0.12)
	if selected:
		fill = fill.lightened(0.18)
	add_theme_stylebox_override("panel", UiStyle.empty_style())
	if _paper != null:
		_paper.set_fill(fill)
	modulate = Color(1.0, 1.0, 1.0, 0.72) if locked else Color.WHITE
	if _status != null:
		_status.text = _progress_text()
		_status.add_theme_color_override(
			"font_color",
			UiStyle.muted_text() if locked else UiStyle.text_color()
		)
