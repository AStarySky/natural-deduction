extends Control

## Infinite canvas viewport: draws a dot grid and transforms the world
## (pan + zoom). Blocks live in [member world], so their coordinates are
## unbounded and are easier to manipulate than a fixed-size ScrollContainer.

const CanvasRes = preload("res://ui/canvas.gd")
const EdgeIndicatorsRes = preload("res://ui/edge_indicators.gd")

var controller = null
var world: Control = null
var zoom: float = 1.0
var pan := Vector2.ZERO

const MIN_ZOOM := 0.3
const MAX_ZOOM := 3.0
const GRID_STEP := 28.0
const DOT_RADIUS := 2.4

var background_color: Color = Color8(166, 211, 225)
var dot_color: Color = Color(1.0, 1.0, 1.0, 0.30)

## A pre-rendered, seamlessly tiling dot tile. Panning only updates the tile
## offset instead of issuing one draw_circle per dot (~1,200 commands/frame).
var _dot_texture: Texture2D = null
var _dot_tile_px: int = 0

## Create the world and prepare the drawing/input surface.
## Tint a nested world while keeping the main canvas on its original sky.
func set_background_color(color: Color) -> void:
	background_color = color
	dot_color = (
		Color(1.0, 1.0, 1.0, 0.30)
		if color.get_luminance() < 0.62
		else Color(0.25, 0.16, 0.28, 0.14)
	)
	queue_redraw()

func setup(p_controller) -> void:
	controller = p_controller
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	world = CanvasRes.new()
	world.setup(p_controller)
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.position = pan
	world.scale = Vector2(zoom, zoom)
	add_child(world)

	var edge_layer = EdgeIndicatorsRes.new()
	add_child(edge_layer)
	edge_layer.setup(self)

	resized.connect(queue_redraw)
	queue_redraw()

## Move the world by a screen-space delta.
func pan_by(delta: Vector2) -> void:
	pan += delta
	world.position = pan
	queue_redraw()

## Zoom around a view-local point so the world point under it stays fixed.
func zoom_at(local_point: Vector2, factor: float) -> void:
	var old_zoom := zoom
	var next_zoom := clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(next_zoom, old_zoom):
		return
	var world_point := (local_point - pan) / old_zoom
	zoom = next_zoom
	pan = local_point - world_point * zoom
	world.scale = Vector2(zoom, zoom)
	world.position = pan
	_dot_texture = null
	queue_redraw()

## Return to the initial view (does not clear blocks).
func reset_view() -> void:
	zoom = 1.0
	pan = Vector2.ZERO
	if world != null:
		world.scale = Vector2.ONE
		world.position = pan
	_dot_texture = null
	queue_redraw()

## Draw the background and one repeating dot texture aligned to the pan.
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), background_color)
	var texture := _ensure_dot_texture()
	var tile := float(_dot_tile_px)
	var offset := Vector2(fposmod(pan.x, tile), fposmod(pan.y, tile))
	# The dot sits at the texture centre; start 1.5 tiles back so a dot
	# lands exactly on the current pan offset and still covers the corners.
	var origin := offset - Vector2(tile, tile) * 1.5
	var cover := size + Vector2(tile, tile) * 3.0
	draw_texture_rect(texture, Rect2(origin, cover), true, dot_color)

## Build (or reuse) the tiling tile for the current zoom level.
func _ensure_dot_texture() -> Texture2D:
	var spacing := GRID_STEP * zoom
	while spacing < 16.0:
		spacing *= 2.0
	var tile := maxi(8, int(round(spacing)))
	if _dot_texture != null and _dot_tile_px == tile:
		return _dot_texture
	_dot_tile_px = tile
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
