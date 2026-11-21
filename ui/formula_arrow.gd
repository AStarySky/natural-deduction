extends Control

## A drawn implication / biconditional operator. Fonts often contain only a
## tiny arrow glyph at card sizes, so draw a thick, legible one instead.

const UiStyle = preload("res://ui/ui_style.gd")

var double_headed := false
var thickness := 2.6

func setup(p_double_headed: bool, p_width: float, p_height: float, p_thickness: float) -> void:
	double_headed = p_double_headed
	thickness = p_thickness
	custom_minimum_size = Vector2(p_width, p_height)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_text = "<->" if double_headed else "->"
	queue_redraw()

func _draw() -> void:
	var color := UiStyle.border_color()
	var mid := size.y * 0.5
	var pad := 3.0
	var left := Vector2(pad, mid)
	var right := Vector2(size.x - pad, mid)
	var head_len := _head_length()
	if double_headed:
		draw_line(
			left + Vector2(head_len, 0.0),
			right - Vector2(head_len, 0.0),
			color,
			thickness,
			true
		)
		_arrow_head(right, false, color)
		_arrow_head(left, true, color)
		return
	# A single arrow is exactly two elements: one horizontal line and one V.
	draw_line(left, right - Vector2(head_len, 0.0), color, thickness, true)
	_arrow_head(right, false, color)

## Both dimensions scale with the stroke so the arrow keeps its proportions.
func _head_length() -> float:
	return minf(maxf(4.0, thickness * 2.20), maxf(3.0, size.x * 0.45))

func _head_wing() -> float:
	return minf(maxf(2.0, thickness * 1.25), maxf(2.0, size.y * 0.42))

func _arrow_head(tip: Vector2, points_left: bool, color: Color) -> void:
	var direction := -1.0 if points_left else 1.0
	var head_len := _head_length()
	var wing := _head_wing()
	var back_x := tip.x - direction * head_len
	draw_polyline(
		PackedVector2Array([
			Vector2(back_x, tip.y - wing),
			tip,
			Vector2(back_x, tip.y + wing),
		]),
		color,
		thickness,
		true
	)
