extends Control

## Compact L/R side switch used by conjunction elimination and disjunction
## introduction. A click anywhere on the control toggles to the other side.

signal changed(side: int)

const UiStyle = preload("res://ui/ui_style.gd")

var side: int = 0
var _hovered := false
var _pressed := false
var _left_text := "L"
var _right_text := "R"

func setup(initial_side: int, left_text: String = "L", right_text: String = "R") -> void:
	side = clampi(initial_side, 0, 1)
	_left_text = left_text
	_right_text = right_text
	custom_minimum_size = Vector2(58, 26)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "Click to switch between L and R."
	mouse_entered.connect(func() -> void: _set_hovered(true))
	mouse_exited.connect(func() -> void: _set_hovered(false))
	resized.connect(queue_redraw)
	queue_redraw()

func set_side(value: int, notify: bool = false) -> void:
	var next := clampi(value, 0, 1)
	if next == side:
		return
	side = next
	queue_redraw()
	if notify:
		changed.emit(side)

func _set_hovered(active: bool) -> void:
	if _hovered == active:
		return
	_hovered = active
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
		else:
			if _pressed and Rect2(Vector2.ZERO, size).has_point(event.position):
				side = 1 - side
				queue_redraw()
				changed.emit(side)
			_pressed = false

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var track_fill := UiStyle.cream().lightened(0.12) if _hovered else UiStyle.cream()
	var track := UiStyle.panel_style(track_fill, UiStyle.border_color(), 12, 2, false)
	draw_style_box(track, Rect2(Vector2.ZERO, size))

	var knob_width := (size.x - 6.0) * 0.5
	var knob_x := 3.0 + knob_width * float(side)
	var knob_fill := UiStyle.coral().lightened(0.08) if _hovered else UiStyle.coral()
	var knob := UiStyle.panel_style(knob_fill, UiStyle.border_color(), 9, 2, false)
	draw_style_box(knob, Rect2(Vector2(knob_x, 3.0), Vector2(knob_width, size.y - 6.0)))

	var font := UiStyle.display_font(800)
	var baseline := size.y * 0.5 + 4.0
	var label_color := UiStyle.border_color()
	draw_string(
		font,
		Vector2(0.0, baseline),
		_left_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x * 0.5,
		12,
		label_color
	)
	draw_string(
		font,
		Vector2(size.x * 0.5, baseline),
		_right_text,
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x * 0.5,
		12,
		label_color
	)
