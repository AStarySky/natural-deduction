extends Control

## A few soft paper scraps drifting upward behind the title content.

const UiStyle = preload("res://ui/ui_style.gd")

const MOTE_COUNT := 20
const PAPER_COLORS := [
	Color8(247, 240, 227),
	Color8(231, 154, 168),
	Color8(185, 241, 141),
	Color8(199, 166, 216),
	Color8(166, 211, 225),
	Color8(255, 210, 120),
]

var _motes: Array[Dictionary] = []
var _time := 0.0
var _breeze := 0.0
var _parallax := Vector2.ZERO

func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x51F0A
	for index in range(MOTE_COUNT):
		_motes.append({
			"x": rng.randf_range(0.02, 0.98),
			"y": rng.randf_range(-0.2, 1.1),
			"speed": rng.randf_range(6.0, 18.0),
			"sway": rng.randf_range(12.0, 24.0),
			"sway_speed": rng.randf_range(0.25, 0.7),
			"phase": rng.randf_range(0.0, TAU),
			"rotation": rng.randf_range(0.0, TAU),
			"rotation_speed": rng.randf_range(-0.35, 0.35),
			"size": rng.randf_range(10.0, 28.0),
			"alpha": rng.randf_range(0.18, 0.35),
			"color": PAPER_COLORS[index % PAPER_COLORS.size()],
		})
	set_process(true)

func set_breeze(value: float) -> void:
	_breeze = clampf(value, 0.0, 1.0)

func set_parallax(value: Vector2) -> void:
	_parallax = value

func _process(delta: float) -> void:
	if DisplayServer.get_name() == "headless" or not is_visible_in_tree() or size.x <= 0.0 or size.y <= 0.0:
		return
	_time += delta
	for mote in _motes:
		mote["y"] -= mote["speed"] * (1.0 + _breeze * 0.8) * delta / size.y
		mote["x"] += sin(_time * mote["sway_speed"] + mote["phase"]) * 0.0008 * delta
		mote["x"] = fposmod(mote["x"], 1.08) - 0.04
		mote["rotation"] += mote["rotation_speed"] * (1.0 + _breeze * 0.5) * delta
		if mote["y"] < -0.12:
			mote["y"] = 1.12
	queue_redraw()

func _draw() -> void:
	var shadow := Color(UiStyle.shadow_color().r, UiStyle.shadow_color().g, UiStyle.shadow_color().b, 0.12)
	for mote in _motes:
		var center := Vector2(
			mote["x"] * size.x + sin(_time * mote["sway_speed"] + mote["phase"]) * mote["sway"] + _parallax.x,
			mote["y"] * size.y + _parallax.y
		)
		var half: float = float(mote["size"]) * 0.5
		var points := _paper_points(center, half, mote["rotation"])
		var shadow_points := PackedVector2Array()
		for point in points:
			shadow_points.append(point + Vector2(3.0, 4.0))
		draw_colored_polygon(shadow_points, shadow)
		var fill: Color = mote["color"]
		fill.a = mote["alpha"]
		draw_colored_polygon(points, fill)
		var edge := UiStyle.border_color()
		edge.a = mote["alpha"] * 0.45
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, edge, 1.2, true)

func _paper_points(center: Vector2, half: float, angle: float) -> PackedVector2Array:
	var local := [
		Vector2(-half, -half),
		Vector2(half * 0.92, -half * 0.9),
		Vector2(half, half * 0.88),
		Vector2(-half * 0.96, half),
		Vector2(-half * 0.72, -half * 0.15),
	]
	var points := PackedVector2Array()
	for point in local:
		points.append(center + point.rotated(angle))
	return points
