extends Control

## Custom-drawn geometric pictograms for the current rule set.
## Icons are decorative; the owning block provides a rule-name tooltip.

const UiStyle = preload("res://ui/ui_style.gd")

var rule_id: String = ""
var ink: Color = Color8(91, 63, 102)
var accent: Color = Color8(166, 211, 225)

func setup(p_rule_id: String) -> void:
	rule_id = p_rule_id
	ink = UiStyle.border_color()
	accent = UiStyle.rule_color(p_rule_id)
	custom_minimum_size = Vector2(60, 60)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	if rule_id.is_empty() or size.x <= 0.0 or size.y <= 0.0:
		return
	var k: float = minf(size.x, size.y) / 56.0
	var off := (size - Vector2(56, 56) * k) * 0.5
	match rule_id:
		"impl_elim":
			_draw_impl(k, off)
		"impl_intro":
			_draw_impl(k, off)
		"and_intro":
			_draw_and_intro(k, off)
		"and_elim_left":
			_draw_and_elim(k, off, -1.0)
		"and_elim_right":
			_draw_and_elim(k, off, 1.0)
		"or_intro_left":
			_draw_or_intro(k, off, -1.0)
		"or_intro_right":
			_draw_or_intro(k, off, 1.0)
		"ds":
			_draw_or_elim(k, off)
		"or_elim":
			_draw_or_elim(k, off)
		"or_elim_impl":
			_draw_or_elim(k, off)
		"iff_intro":
			_draw_iff(k, off, true)
		"iff_intro_impl":
			_draw_iff(k, off, true)
		"iff_elim":
			_draw_iff(k, off, false)
		"not_intro":
			_draw_not_rule(k, off, true)
		"not_intro_impl":
			_draw_not_rule(k, off, true)
		"not_elim":
			_draw_not_rule(k, off, false)
		"not_elim_impl":
			_draw_not_rule(k, off, false)
		"lem":
			_draw_lem(k, off)
		"double_neg_elim":
			_draw_double_neg(k, off, false)
		"double_neg_intro":
			_draw_double_neg(k, off, true)
		_:
			_draw_unknown(k, off)
	if rule_id.ends_with("_impl") and rule_id != "iff_intro_impl":
		_draw_derived_badge(k, off)

## Small double-chevron badge marking implication-derived simple rules.
func _draw_derived_badge(k: float, off: Vector2) -> void:
	var center := off + Vector2(47, 9) * k
	var radius := 7.0 * k
	draw_circle(center, radius, UiStyle.cream())
	draw_arc(center, radius, 0.0, TAU, 24, ink, 2.0 * k, true)
	var thickness := 2.0 * k
	draw_line(center + Vector2(-3, -3) * k, center, ink, thickness, true)
	draw_line(center, center + Vector2(-3, 3) * k, ink, thickness, true)
	draw_line(center + Vector2(1, -3) * k, center + Vector2(4, 0) * k, ink, thickness, true)
	draw_line(center + Vector2(4, 0) * k, center + Vector2(1, 3) * k, ink, thickness, true)

func _draw_impl(k: float, off: Vector2) -> void:
	_tile(_rect(4, 18, 16, 20, k, off), accent)
	_tile(_rect(36, 18, 16, 20, k, off), accent)
	_arrow(Vector2(21, 28), Vector2(34, 28), k, off)

func _draw_and_intro(k: float, off: Vector2) -> void:
	_tile(_rect(3, 6, 16, 16, k, off), accent)
	_tile(_rect(3, 34, 16, 16, k, off), accent)
	_plus(Vector2(11, 28), 7.0, k, off)
	_arrow(Vector2(22, 28), Vector2(33, 28), k, off)
	_tile(_rect(36, 18, 17, 20, k, off), accent)

func _draw_and_elim(k: float, off: Vector2, direction: float) -> void:
	_tile(_rect(20, 3, 16, 16, k, off), accent)
	var left_tile := _rect(5, 37, 16, 16, k, off)
	var right_tile := _rect(35, 37, 16, 16, k, off)
	_tile(left_tile, accent if direction < 0.0 else _faded())
	_tile(right_tile, accent if direction > 0.0 else _faded())
	_arrow(Vector2(28, 20), Vector2(28 + direction * 15, 36), k, off)
	_line(Vector2(28, 20), Vector2(28 - direction * 15, 36), k, off, _faded_color())

func _draw_or_intro(k: float, off: Vector2, direction: float) -> void:
	_tile(_rect(20, 37, 16, 16, k, off), accent)
	var left_tile := _rect(5, 3, 16, 16, k, off)
	var right_tile := _rect(35, 3, 16, 16, k, off)
	_tile(left_tile, accent if direction < 0.0 else _faded())
	_tile(right_tile, accent if direction > 0.0 else _faded())
	_arrow(Vector2(28, 36), Vector2(28 + direction * 15, 20), k, off)
	_line(Vector2(28, 36), Vector2(28 - direction * 15, 20), k, off, _faded_color())

func _draw_or_elim(k: float, off: Vector2) -> void:
	# A | B in one split bar, with both cases converging on the same result.
	_tile(_rect(4, 4, 48, 16, k, off), accent)
	_line(Vector2(28, 6), Vector2(28, 18), k, off, ink)
	_arrow(Vector2(18, 22), Vector2(24, 35), k, off)
	_arrow(Vector2(38, 22), Vector2(32, 35), k, off)
	_tile(_rect(19, 37, 18, 16, k, off), accent)

func _draw_iff(k: float, off: Vector2, introduce: bool) -> void:
	if introduce:
		# A -> B on the top row, B -> A on the bottom row.
		_tile(_rect(4, 6, 16, 16, k, off), accent)
		_tile(_rect(36, 6, 16, 16, k, off), accent)
		_arrow(Vector2(22, 14), Vector2(34, 14), k, off)
		_tile(_rect(4, 34, 16, 16, k, off), accent)
		_tile(_rect(36, 34, 16, 16, k, off), accent)
		_arrow(Vector2(34, 42), Vector2(22, 42), k, off)
		return
	_tile(_rect(4, 18, 18, 20, k, off), accent)
	_tile(_rect(34, 18, 18, 20, k, off), accent)
	var start := Vector2(8, 28)
	var end := Vector2(48, 28)
	_arrow(start, end, k, off)
	_arrow(end, start, k, off)

func _draw_not_rule(k: float, off: Vector2, introduce: bool) -> void:
	_tile(_rect(6, 8, 18, 18, k, off), accent)
	_line(Vector2(12, 13), Vector2(18, 13), k, off, ink)
	_line(Vector2(12, 13), Vector2(12, 21), k, off, ink)
	_arrow(Vector2(28, 17), Vector2(35, 17), k, off, ink)
	_tile(_rect(38, 30, 14, 14, k, off), accent)
	_arrow(Vector2(17, 30), Vector2(17, 38), k, off, ink)
	_tile(_rect(30, 36, 16, 12, k, off), accent)
	if introduce:
		_line(Vector2(41, 40), Vector2(45, 40), k, off, ink)

func _draw_lem(k: float, off: Vector2) -> void:
	# P | ~P: a pair of tiles with a pipe and a negation mark.
	_tile(_rect(5, 16, 18, 24, k, off), accent)
	_line(Vector2(27, 20), Vector2(27, 36), k, off, ink)
	_tile(_rect(31, 16, 20, 24, k, off), accent)
	_line(Vector2(36, 28), Vector2(40, 23), k, off, ink)
	_line(Vector2(40, 23), Vector2(46, 28), k, off, ink)
	_line(Vector2(38, 34), Vector2(44, 34), k, off, ink)

func _draw_double_neg(k: float, off: Vector2, introduce: bool) -> void:
	_tile(_rect(2, 18, 22, 20, k, off), accent)
	_tile(_rect(32, 18, 22, 20, k, off), accent)
	if not introduce:
		# ~~A -> A: marks live in the left tile.
		_draw_neg_marks(Vector2(6, 24), Vector2(15, 24), k, off)
	else:
		# A -> ~~A: marks live in the right tile.
		_draw_neg_marks(Vector2(36, 24), Vector2(45, 24), k, off)
	_arrow(Vector2(25, 28), Vector2(31, 28), k, off)

func _draw_neg_marks(first: Vector2, second: Vector2, k: float, off: Vector2) -> void:
	# Two separated ¬ marks: horizontal top, vertical drop at the right end.
	_line(first, first + Vector2(4, 0), k, off, ink)
	_line(first + Vector2(4, 0), first + Vector2(4, 8), k, off, ink)
	_line(second, second + Vector2(4, 0), k, off, ink)
	_line(second + Vector2(4, 0), second + Vector2(4, 8), k, off, ink)

func _draw_unknown(k: float, off: Vector2) -> void:
	_plus(Vector2(28, 28), 16.0, k, off)

# --- drawing helpers -----------------------------------------------------

func _rect(x: float, y: float, w: float, h: float, k: float, off: Vector2) -> Rect2:
	return Rect2(off + Vector2(x, y) * k, Vector2(w, h) * k)

func _tile(rect: Rect2, fill: Color) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = ink
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	var radius := int(maxf(3.0, rect.size.x * 0.18))
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	draw_style_box(box, rect)

func _faded() -> Color:
	return Color(1.0, 1.0, 1.0, 0.35)

func _faded_color() -> Color:
	return Color(ink.r, ink.g, ink.b, 0.35)

func _arrow(from: Vector2, to: Vector2, k: float, off: Vector2, color: Color = Color(0, 0, 0, 0)) -> void:
	var paint := ink if color.a == 0.0 else color
	var a := off + from * k
	var b := off + to * k
	draw_line(a, b, paint, 3.0 * k, true)
	draw_circle(a, 1.5 * k, paint)
	draw_circle(b, 1.5 * k, paint)
	var direction := (b - a).normalized()
	var perp := Vector2(-direction.y, direction.x)
	var head := 5.0 * k
	var tip := b + direction * 2.0 * k
	var base := b - direction * 4.0 * k
	draw_colored_polygon(
		PackedVector2Array([tip, base + perp * head, base - perp * head]),
		paint
	)

func _line(from: Vector2, to: Vector2, k: float, off: Vector2, color: Color) -> void:
	var a := off + from * k
	var b := off + to * k
	draw_line(a, b, color, 2.4 * k, true)
	draw_circle(a, 1.2 * k, color)
	draw_circle(b, 1.2 * k, color)

func _plus(center: Vector2, radius: float, k: float, off: Vector2) -> void:
	var c := off + center * k
	var r := radius * k
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), ink, 3.0 * k, true)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), ink, 3.0 * k, true)
