extends Control

## Hand-made card paper: an irregular polygon with inward triangular bites,
## a chunky plum outline, a soft offset shadow and a tiny random tilt.

const UiStyle = preload("res://ui/ui_style.gd")

var _seed: int = 0
var _fill: Color = Color.WHITE
var _outline: Color = UiStyle.border_color()

func setup(seed_value: int, fill: Color) -> void:
	_seed = seed_value
	_fill = fill
	_outline = UiStyle.border_color()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

## Update the card face colour (used by hover states).
func set_fill(fill: Color) -> void:
	_fill = fill
	queue_redraw()

## Small deterministic angle for a hand-placed card.
static func angle_for(seed_value: int) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return deg_to_rad(rng.randf_range(-2.8, 2.8))

## Attach the polygon paper and rotation to a card root.
static func apply_to(card: Control, seed_value: int, fill: Color):
	var paper = load("res://ui/card_wear.gd").new()
	paper.setup(seed_value, fill)
	card.add_child(paper)
	card.move_child(paper, 0)
	card.rotation = angle_for(seed_value)
	card.resized.connect(func() -> void: card.pivot_offset = card.size * 0.5)
	card.pivot_offset = card.size * 0.5
	return paper

func _draw() -> void:
	if size.x < 24.0 or size.y < 24.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	var points := _build_polygon(rng)

	var shadow := PackedVector2Array()
	for point in points:
		shadow.append(point + Vector2(3.0, 4.0))
	draw_colored_polygon(shadow, UiStyle.shadow_color())
	draw_colored_polygon(points, _fill)

	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, _outline, 3.5, true)

## Build a rectangle-like polygon with jittered corners and two inward bites.
func _build_polygon(rng: RandomNumberGenerator) -> PackedVector2Array:
	var pad := 2.0
	var tl := Vector2(pad + rng.randf_range(0.0, 3.0), pad + rng.randf_range(0.0, 3.0))
	var tr := Vector2(size.x - pad - rng.randf_range(0.0, 3.0), pad + rng.randf_range(0.0, 3.0))
	var br := Vector2(size.x - pad - rng.randf_range(0.0, 3.0), size.y - pad - rng.randf_range(0.0, 3.0))
	var bl := Vector2(pad + rng.randf_range(0.0, 3.0), size.y - pad - rng.randf_range(0.0, 3.0))

	var bitten: Array = []
	var bite_count := rng.randi_range(1, 2)
	while bitten.size() < bite_count:
		var edge := rng.randi_range(0, 3)
		if not bitten.has(edge):
			bitten.append(edge)

	var points := PackedVector2Array()
	points.append(tl)
	_append_edge(points, tl, tr, 0, bitten.has(0), rng)
	_append_edge(points, tr, br, 1, bitten.has(1), rng)
	_append_edge(points, br, bl, 2, bitten.has(2), rng)
	_append_edge(points, bl, tl, 3, bitten.has(3), rng)
	if points.size() > 1 and points[points.size() - 1].is_equal_approx(points[0]):
		points.remove_at(points.size() - 1)
	return points

## Append one edge, optionally with an inward triangular bite.
func _append_edge(
	points: PackedVector2Array,
	start: Vector2,
	end: Vector2,
	edge_index: int,
	has_bite: bool,
	rng: RandomNumberGenerator
) -> void:
	if not has_bite:
		points.append(end)
		return
	var direction := end - start
	var length := direction.length()
	if length < 24.0:
		points.append(end)
		return
	var along := rng.randf_range(0.32, 0.68)
	var half_width := rng.randf_range(5.0, 9.0)
	var depth := rng.randf_range(5.0, 9.0)
	var normal := Vector2.ZERO
	match edge_index:
		0:
			normal = Vector2(0, 1)      # top edge bites down
		1:
			normal = Vector2(-1, 0)     # right edge bites left
		2:
			normal = Vector2(0, -1)     # bottom edge bites up
		3:
			normal = Vector2(1, 0)      # left edge bites right
	var unit := direction / length
	var center := start + direction * along
	points.append(center - unit * half_width)
	points.append(center + normal * depth)
	points.append(center + unit * half_width)
	points.append(end)
