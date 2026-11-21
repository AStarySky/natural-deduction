extends Control

## Hand-drawn pencil + cubic Bezier arrow for the cover. The tip sits at the
## arrow head; the pencil body trails up-right across the title sheet edge.

const UiStyle = preload("res://ui/ui_style.gd")

var start := Vector2.ZERO
var control_a := Vector2.ZERO
var control_b := Vector2.ZERO
var end := Vector2.ZERO
var _use_arc := false
var _arc_center := Vector2.ZERO
var _arc_radius := 0.0
var _use_v := false
var _v_left := Vector2.ZERO
var _v_point := Vector2.ZERO
var _v_right := Vector2.ZERO
var _pencil_tip := Vector2.ZERO

func setup(p_start: Vector2, p_control_a: Vector2, p_control_b: Vector2, p_end: Vector2) -> void:
	_use_arc = false
	_use_v = false
	start = p_start
	control_a = p_control_a
	control_b = p_control_b
	end = p_end
	_pencil_tip = p_end
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

## Quarter-circle from above the center to the right of the center.
func setup_arc(center: Vector2, radius: float) -> void:
	_use_arc = true
	_use_v = false
	_arc_center = center
	_arc_radius = radius
	start = center + Vector2(0.0, -radius)
	end = center + Vector2(radius, 0.0)
	control_a = start
	control_b = end
	_pencil_tip = end
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

## Quarter-circle into an open V; the pencil sits at the right tail of the V.
func setup_arc_v(
	center: Vector2,
	radius: float,
	left_tail: Vector2,
	right_tail: Vector2
) -> void:
	_use_arc = true
	_use_v = true
	_arc_center = center
	_arc_radius = radius
	start = center + Vector2(0.0, -radius)
	end = center + Vector2(radius, 0.0)
	control_a = start
	control_b = end
	_v_left = left_tail
	_v_point = end
	_v_right = right_tail
	_pencil_tip = right_tail
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func _draw() -> void:
	if size.x < 8.0 or size.y < 8.0:
		return
	var ink := UiStyle.border_color()
	var curve := _curve_points(48)

	# Slight offset shadow under the arrow.
	var shadow := PackedVector2Array()
	for point in curve:
		shadow.append(point + Vector2(2.0, 3.0))
	draw_polyline(shadow, Color(0.25, 0.16, 0.28, 0.16), 7.0, true)

	draw_polyline(curve, ink, 5.5, true)
	if _use_v:
		_draw_v(ink)
	else:
		_draw_arrow_head(ink)
	_draw_pencil(ink)

func _curve_points(count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(count + 1):
		var t := float(index) / float(count)
		if _use_arc:
			var angle := -PI * 0.5 + PI * 0.5 * t
			points.append(
				_arc_center + Vector2(cos(angle), sin(angle)) * _arc_radius
			)
		else:
			var u := 1.0 - t
			points.append(
				start * (u * u * u)
				+ control_a * (3.0 * u * u * t)
				+ control_b * (3.0 * u * t * t)
				+ end * (t * t * t)
			)
	return points

func _draw_pencil(ink: Color) -> void:
	var direction := Vector2(0.5, -0.8660254).normalized()
	var normal := Vector2(-direction.y, direction.x)
	var tip := _pencil_tip
	var body_start := tip + direction * 30.0
	var body_end := tip + direction * 367.0
	var ferrule_end := tip + direction * 391.0
	var eraser_end := tip + direction * 423.0
	var half_width := 12.0

	var wood := Color8(238, 196, 150)
	var body_fill := Color8(255, 212, 94)
	var ferrule := Color8(196, 198, 214)
	var eraser := Color8(231, 154, 168)
	var graphite := Color8(59, 48, 62)

	_draw_pencil_shadow(
		tip, direction, normal, body_start, body_end, ferrule_end, eraser_end, half_width
	)

	# Wooden cone.
	var cone := PackedVector2Array([
		tip,
		body_start + normal * half_width,
		body_start - normal * half_width,
	])
	draw_colored_polygon(cone, wood)
	draw_polyline(
		PackedVector2Array([tip, body_start + normal * half_width, body_start - normal * half_width, tip]),
		ink,
		3.0,
		true
	)

	# Yellow barrel.
	var barrel := PackedVector2Array([
		body_start + normal * half_width,
		body_end + normal * half_width,
		body_end - normal * half_width,
		body_start - normal * half_width,
	])
	draw_colored_polygon(barrel, body_fill)
	draw_polyline(
		PackedVector2Array([
			body_start + normal * half_width,
			body_end + normal * half_width,
			body_end - normal * half_width,
			body_start - normal * half_width,
			body_start + normal * half_width,
		]),
		ink,
		3.0,
		true
	)
	draw_line(
		body_start + normal * 4.0,
		body_end + normal * 4.0,
		Color(1.0, 1.0, 1.0, 0.42),
		2.0,
		true
	)

	# Metal ferrule with two bands.
	var ferrule_poly := PackedVector2Array([
		body_end + normal * (half_width + 1.0),
		ferrule_end + normal * (half_width + 1.0),
		ferrule_end - normal * (half_width + 1.0),
		body_end - normal * (half_width + 1.0),
	])
	draw_colored_polygon(ferrule_poly, ferrule)
	draw_polyline(
		PackedVector2Array([
			body_end + normal * (half_width + 1.0),
			ferrule_end + normal * (half_width + 1.0),
			ferrule_end - normal * (half_width + 1.0),
			body_end - normal * (half_width + 1.0),
			body_end + normal * (half_width + 1.0),
		]),
		ink,
		2.6,
		true
	)
	draw_line(
		body_end + direction * 7.0 + normal * (half_width + 1.0),
		body_end + direction * 7.0 - normal * (half_width + 1.0),
		ink,
		1.8,
		true
	)
	draw_line(
		ferrule_end - direction * 7.0 + normal * (half_width + 1.0),
		ferrule_end - direction * 7.0 - normal * (half_width + 1.0),
		ink,
		1.8,
		true
	)

	# Pink eraser.
	var eraser_poly := PackedVector2Array([
		ferrule_end + normal * (half_width + 1.0),
		eraser_end + normal * (half_width + 1.0),
		eraser_end - normal * (half_width + 1.0),
		ferrule_end - normal * (half_width + 1.0),
	])
	draw_colored_polygon(eraser_poly, eraser)
	draw_polyline(
		PackedVector2Array([
			ferrule_end + normal * (half_width + 1.0),
			eraser_end + normal * (half_width + 1.0),
			eraser_end - normal * (half_width + 1.0),
			ferrule_end - normal * (half_width + 1.0),
			ferrule_end + normal * (half_width + 1.0),
		]),
		ink,
		2.8,
		true
	)

	# Graphite point.
	var graphite_tip := PackedVector2Array([
		tip,
		tip + direction * 9.0 + normal * 4.0,
		tip + direction * 9.0 - normal * 4.0,
	])
	draw_colored_polygon(graphite_tip, graphite)

func _draw_pencil_shadow(
	tip: Vector2,
	direction: Vector2,
	normal: Vector2,
	body_start: Vector2,
	body_end: Vector2,
	ferrule_end: Vector2,
	eraser_end: Vector2,
	half_width: float
) -> void:
	# Anchor the shadow at the graphite point and shear it away from the
	# pencil, so it reads as a cast shadow instead of a second pencil.
	var shadow_dir := Vector2(0.40, 0.9165).normalized()

	for spec in [
		[0.52, 0.11, 7.0],
		[0.36, 0.19, 2.0],
	]:
		var shear: float = spec[0]
		var alpha: float = spec[1]
		var expand: float = spec[2]
		var color := Color(0.055, 0.025, 0.085, alpha)
		var width := half_width + expand

		var p_tip := _shadow_point(tip, tip, direction, shadow_dir, shear)
		var p_body_start := _shadow_point(body_start, tip, direction, shadow_dir, shear)
		var p_body_end := _shadow_point(body_end, tip, direction, shadow_dir, shear)
		var p_ferrule_end := _shadow_point(ferrule_end, tip, direction, shadow_dir, shear)
		var p_eraser_end := _shadow_point(eraser_end, tip, direction, shadow_dir, shear)

		draw_colored_polygon(
			PackedVector2Array([
				p_tip,
				p_body_start + normal * width,
				p_body_start - normal * width,
			]),
			color
		)
		draw_colored_polygon(
			PackedVector2Array([
				p_body_start + normal * width,
				p_body_end + normal * width,
				p_body_end - normal * width,
				p_body_start - normal * width,
			]),
			color
		)
		draw_colored_polygon(
			PackedVector2Array([
				p_body_end + normal * (width + 1.0),
				p_ferrule_end + normal * (width + 1.0),
				p_ferrule_end - normal * (width + 1.0),
				p_body_end - normal * (width + 1.0),
			]),
			color
		)
		draw_colored_polygon(
			PackedVector2Array([
				p_ferrule_end + normal * (width + 1.0),
				p_eraser_end + normal * (width + 1.0),
				p_eraser_end - normal * (width + 1.0),
				p_ferrule_end - normal * (width + 1.0),
			]),
			color
		)

	# Contact shadow stays at the graphite point.
	draw_circle(
		tip + Vector2(2.0, 4.0),
		8.0,
		Color(0.055, 0.025, 0.085, 0.22)
	)

func _shadow_point(
	point: Vector2,
	tip: Vector2,
	pencil_dir: Vector2,
	shadow_dir: Vector2,
	shear: float
) -> Vector2:
	var distance := maxf(0.0, (point - tip).dot(pencil_dir))
	return point + shadow_dir * (distance * shear)

func _draw_v(ink: Color) -> void:
	var v := PackedVector2Array([_v_left, _v_point, _v_right])
	var shadow := PackedVector2Array()
	for point in v:
		shadow.append(point + Vector2(2.0, 3.0))
	draw_polyline(shadow, Color(0.25, 0.16, 0.28, 0.16), 7.0, true)
	draw_polyline(v, ink, 5.5, true)

func _draw_arrow_head(ink: Color) -> void:
	var tangent := Vector2(0.0, 1.0) if _use_arc else end - control_b
	if tangent.length_squared() < 0.0001:
		tangent = end - start
	tangent = tangent.normalized()
	var normal := Vector2(-tangent.y, tangent.x)
	var base := end - tangent * 24.0
	var head := PackedVector2Array([
		end,
		base + normal * 10.0,
		base - normal * 10.0,
	])
	draw_colored_polygon(head, ink)
