extends HBoxContainer

## macOS-style window controls with no text:
## red = close, yellow = minimize, green = zoom/fullscreen.
## Hovering reveals the action glyph inside each dot.

const UiStyle = preload("res://ui/ui_style.gd")

signal delete_requested
signal toggle_size_requested
signal minimize_requested

var delete_button: Button = null
var minimize_button: Button = null
var zoom_button: Button = null
var _delete_glyph: DotGlyph = null
var _minimize_glyph: DotGlyph = null
var _zoom_glyph: DotGlyph = null
var _maximized := false

## Small overlay that draws the action glyph on top of a traffic-light dot.
class DotGlyph:
	extends Control

	var mode: String = "close"
	var hovered := false
	var maximized := false
	var ink := Color8(91, 63, 102)

	func setup(p_mode: String) -> void:
		mode = p_mode
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_hovered(value: bool) -> void:
		if hovered == value:
			return
		hovered = value
		queue_redraw()

	func set_maximized(value: bool) -> void:
		if maximized == value:
			return
		maximized = value
		queue_redraw()

	func _draw() -> void:
		if not hovered or size.x < 8.0 or size.y < 8.0:
			return
		match mode:
			"close":
				draw_line(Vector2(4.5, 4.5), Vector2(11.5, 11.5), ink, 1.8, true)
				draw_line(Vector2(11.5, 4.5), Vector2(4.5, 11.5), ink, 1.8, true)
			"minimize":
				draw_line(Vector2(4.5, 8.0), Vector2(11.5, 8.0), ink, 2.0, true)
			_:
				_draw_size()

	func _draw_size() -> void:
		# Outward corner triangles for maximize; matching inward arrowheads for
		# restore. The inward pair is mirrored exactly across the centre.
		if maximized:
			_head(Vector2(9.2, 6.8), Vector2(12, 4))
			_head(Vector2(6.8, 9.2), Vector2(4, 12))
		else:
			_triangle(Vector2(9, 3), Vector2(13, 3), Vector2(13, 7))
			_triangle(Vector2(3, 9), Vector2(3, 13), Vector2(7, 13))

	func _triangle(first: Vector2, second: Vector2, third: Vector2) -> void:
		draw_colored_polygon(PackedVector2Array([first, second, third]), ink)

	func _head(tip: Vector2, base_center: Vector2) -> void:
		var direction := (base_center - tip).normalized()
		var perpendicular := Vector2(-direction.y, direction.x)
		draw_colored_polygon(
			PackedVector2Array([
				tip,
				base_center + perpendicular * 1.8,
				base_center - perpendicular * 1.8,
			]),
			ink
		)

func setup() -> void:
	add_theme_constant_override("separation", 7)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	delete_button = _make_dot(
		Color8(232, 101, 93),
		"Close — discard this scope and its marker."
	)
	_delete_glyph = _add_glyph(delete_button, "close")
	minimize_button = _make_dot(
		Color8(245, 190, 76),
		"Minimize — keep the proof as a scope marker."
	)
	_minimize_glyph = _add_glyph(minimize_button, "minimize")
	zoom_button = _make_dot(
		Color8(96, 190, 92),
		"Enlarge this window."
	)
	_zoom_glyph = _add_glyph(zoom_button, "size")
	add_child(delete_button)
	add_child(minimize_button)
	add_child(zoom_button)
	delete_button.pressed.connect(func() -> void: delete_requested.emit())
	minimize_button.pressed.connect(func() -> void: minimize_requested.emit())
	zoom_button.pressed.connect(func() -> void: toggle_size_requested.emit())
	set_maximized(false)

func set_maximized(maximized: bool) -> void:
	_maximized = maximized
	if zoom_button != null:
		zoom_button.tooltip_text = (
			"Shrink this window." if maximized else "Enlarge this window."
		)
	if _zoom_glyph != null:
		_zoom_glyph.set_maximized(maximized)

func _add_glyph(button: Button, mode: String) -> DotGlyph:
	var glyph := DotGlyph.new()
	glyph.setup(mode)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(glyph)
	button.mouse_entered.connect(func() -> void: glyph.set_hovered(true))
	button.mouse_exited.connect(func() -> void: glyph.set_hovered(false))
	return glyph

func _make_dot(color: Color, tooltip: String) -> Button:
	var button := Button.new()
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(16, 16)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.tooltip_text = tooltip
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _dot_style(color, UiStyle.border_color()))
	button.add_theme_stylebox_override("hover", _dot_style(color.lightened(0.14), UiStyle.border_color()))
	button.add_theme_stylebox_override("pressed", _dot_style(color.darkened(0.10), UiStyle.border_color()))
	var disabled := color.lightened(0.45)
	disabled.a = 0.52
	button.add_theme_stylebox_override("disabled", _dot_style(disabled, Color(1, 1, 1, 0.0)))
	return button

func _dot_style(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 1
	box.corner_radius_top_left = 8
	box.corner_radius_top_right = 8
	box.corner_radius_bottom_left = 8
	box.corner_radius_bottom_right = 8
	return box
