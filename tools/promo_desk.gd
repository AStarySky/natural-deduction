extends Control

## Warm, softly grained desk surface for the promotional cover.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color8(178, 139, 105))

	var rng := RandomNumberGenerator.new()
	rng.seed = 0xC0FFEE

	# Broad tonal bands under the grain.
	for i in range(18):
		var y := rng.randf_range(-30.0, size.y)
		var band := rng.randf_range(24.0, 86.0)
		draw_rect(
			Rect2(0.0, y, size.x, band),
			Color(0.33, 0.16, 0.08, rng.randf_range(0.012, 0.040))
		)

	# Long, slightly uneven grain lines.
	for i in range(58):
		var y := rng.randf_range(0.0, size.y)
		var alpha := rng.randf_range(0.018, 0.075)
		var color := (
			Color(0.27, 0.13, 0.06, alpha)
			if i % 3
			else Color(1.0, 0.93, 0.82, alpha * 0.55)
		)
		var x := -30.0
		while x < size.x + 30.0:
			var segment := rng.randf_range(55.0, 180.0)
			var dy := rng.randf_range(-2.5, 2.5)
			draw_line(
				Vector2(x, y),
				Vector2(x + segment, y + dy),
				color,
				rng.randf_range(0.8, 2.2)
			)
			x += segment

	# A few quiet knots so the surface reads as a desk, not a flat colour.
	for i in range(5):
		var center := Vector2(
			rng.randf_range(size.x * 0.05, size.x * 0.95),
			rng.randf_range(size.y * 0.05, size.y * 0.95)
		)
		var radius := rng.randf_range(12.0, 32.0)
		draw_arc(
			center,
			radius,
			0.0,
			TAU,
			28,
			Color(0.24, 0.11, 0.05, 0.055),
			rng.randf_range(1.0, 2.4)
		)
		draw_arc(
			center,
			radius * 0.55,
			0.0,
			TAU,
			20,
			Color(0.24, 0.11, 0.05, 0.045),
			1.0
		)

	# Gentle edge darkening.
	for i in range(16):
		var inset := float(i) * 11.0
		draw_rect(
			Rect2(inset, inset, size.x - inset * 2.0, size.y - inset * 2.0),
			Color(0.10, 0.04, 0.02, 0.0075 * float(16 - i)),
			false,
			12.0
		)
