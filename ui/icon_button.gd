extends Control

## Small chunky icon button (copy/reset/trash). Draws its own plate and glyph,
## so it can sit on rule cards without a text label.

signal pressed
signal secondary_pressed

const UiStyle = preload("res://ui/ui_style.gd")

var kind: String = "copy"
var _hover: bool = false
var _down: bool = false

func setup(p_kind: String, tip: String) -> void:
	kind = p_kind
	add_to_group("nd_icon_button")
	tooltip_text = tip
	custom_minimum_size = Vector2(30, 30)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _on_hover(active: bool) -> void:
	_hover = active
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_RIGHT
		and event.pressed
		and Rect2(Vector2.ZERO, size).has_point(event.position)
	):
		secondary_pressed.emit()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_down = true
			queue_redraw()
		else:
			var inside := Rect2(Vector2.ZERO, size).has_point(event.position)
			_down = false
			queue_redraw()
			if inside:
				pressed.emit()

func _draw() -> void:
	var bg := UiStyle.lavender() if _hover else UiStyle.cream()
	if _down:
		bg = UiStyle.coral()
	draw_style_box(
		UiStyle.panel_style(bg, UiStyle.border_color(), 9, 3, true),
		Rect2(Vector2.ZERO, size)
	)
	match kind:
		"reset":
			_draw_reset()
		"trash":
			_draw_trash()
		"sound":
			_draw_sound(false)
		"mute":
			_draw_sound(true)
		_:
			_draw_copy()

func _draw_copy() -> void:
	var unit: float = minf(size.x, size.y)
	var back := Rect2(size * 0.24, Vector2(unit * 0.34, unit * 0.34))
	var front := Rect2(size * 0.40, Vector2(unit * 0.34, unit * 0.34))
	draw_style_box(_small_box(UiStyle.accent()), back)
	draw_style_box(_small_box(UiStyle.cream()), front)

func _draw_reset() -> void:
	var c := size * 0.5
	var r: float = minf(size.x, size.y) * 0.24
	draw_arc(c, r, -PI * 0.2, PI * 1.4, 24, UiStyle.border_color(), maxf(2.0, r * 0.32), true)
	var tip := c + Vector2(cos(-PI * 0.2), sin(-PI * 0.2)) * r
	draw_colored_polygon(
		PackedVector2Array([tip + Vector2(5, -1), tip + Vector2(-1, 5), tip + Vector2(-5, -4)]),
		UiStyle.border_color()
	)

func _draw_trash() -> void:
	var unit: float = minf(size.x, size.y)
	var body := Rect2(size * 0.5 - Vector2(unit * 0.18, unit * 0.02), Vector2(unit * 0.36, unit * 0.36))
	draw_style_box(_small_box(UiStyle.coral()), body)
	draw_line(
		Vector2(size.x * 0.28, size.y * 0.38),
		Vector2(size.x * 0.72, size.y * 0.38),
		UiStyle.border_color(),
		maxf(1.5, unit * 0.05),
		true
	)

func _draw_sound(muted: bool) -> void:
	var c := size * 0.5
	var ink := UiStyle.border_color()
	var body := PackedVector2Array([
		c + Vector2(-8, -4),
		c + Vector2(-3, -4),
		c + Vector2(2, -9),
		c + Vector2(2, 9),
		c + Vector2(-3, 4),
		c + Vector2(-8, 4),
	])
	draw_colored_polygon(body, ink)
	if muted:
		draw_line(c + Vector2(7, -5), c + Vector2(14, 2), ink, 2.4, true)
		draw_line(c + Vector2(14, -5), c + Vector2(7, 2), ink, 2.4, true)
	else:
		draw_arc(c + Vector2(2, 0), 8.0, -0.75, 0.75, 14, ink, 2.2, true)
		draw_arc(c + Vector2(2, 0), 13.0, -0.7, 0.7, 18, ink, 2.2, true)

func _small_box(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = UiStyle.border_color()
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 4
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_left = 4
	box.corner_radius_bottom_right = 4
	return box
