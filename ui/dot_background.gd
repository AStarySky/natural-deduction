extends Control

## Pastel polka-dot backdrop. The dot tile is pre-rendered so animated drift
## costs one draw call instead of ~1,000 draw_circle calls per frame.

const UiStyle = preload("res://ui/ui_style.gd")

const SPACING := 30.0
const DOT_RADIUS := 2.4
const DOT_COLOR := Color(1.0, 1.0, 1.0, 0.30)

var _drift_velocity := Vector2.ZERO
var _drift := Vector2.ZERO
var _dot_texture: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	set_process(false)
	queue_redraw()

## Enable a seamless slow drift. Zero leaves the background static.
func set_drift(velocity: Vector2) -> void:
	if DisplayServer.get_name() == "headless":
		_drift_velocity = Vector2.ZERO
		set_process(false)
		return
	_drift_velocity = velocity
	set_process(velocity.length_squared() > 0.0001)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or _drift_velocity == Vector2.ZERO:
		return
	_drift += _drift_velocity * delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), UiStyle.sky())
	var texture := _ensure_dot_texture()
	if texture == null:
		return
	var tile := SPACING
	var offset := Vector2(
		fposmod(_drift.x, tile),
		fposmod(_drift.y, tile)
	)
	var origin := offset - Vector2(tile, tile)
	var cover := size + Vector2(tile, tile) * 2.0
	draw_texture_rect(texture, Rect2(origin, cover), true, DOT_COLOR)

func _ensure_dot_texture() -> Texture2D:
	if _dot_texture != null:
		return _dot_texture
	var tile := int(round(SPACING))
	var image := Image.create(tile, tile, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var center := Vector2(tile, tile) * 0.5
	for y in range(tile):
		for x in range(tile):
			var distance := Vector2(x + 0.5, y + 0.5).distance_to(center) - DOT_RADIUS
			var alpha := clampf(0.5 - distance, 0.0, 1.0)
			if alpha > 0.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	_dot_texture = ImageTexture.create_from_image(image)
	return _dot_texture
