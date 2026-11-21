extends Control

## Small edge boxes for root blocks whose centre is outside the canvas view.
## Lives above the world inside CanvasView, so both the main canvas and nested
## assumption canvases get the same indicator.

const UiStyle = preload("res://ui/ui_style.gd")

var view = null

func setup(p_view) -> void:
	view = p_view
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 0
	z_as_relative = true

func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()

func _draw() -> void:
	if view == null or view.world == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var pad := 12.0
	var edge_rect := Rect2(Vector2(pad, pad), size - Vector2(pad, pad) * 2.0)
	var inverse: Transform2D = view.get_global_transform().affine_inverse()
	for child in view.world.get_children():
		if not child is Control or not child.visible or not is_instance_valid(child):
			continue
		var block := child as Control
		var screen_center: Vector2 = block.get_global_rect().get_center()
		var local_center: Vector2 = inverse * screen_center
		if edge_rect.has_point(local_center):
			continue
		var edge_point := Vector2(
			clampf(local_center.x, edge_rect.position.x, edge_rect.end.x),
			clampf(local_center.y, edge_rect.position.y, edge_rect.end.y)
		)
		_draw_off_screen_box(edge_point, local_center - edge_point, block)

func _draw_off_screen_box(center: Vector2, direction: Vector2, block: Control) -> void:
	var fill := UiStyle.cream()
	if block.has_method("get_scope_color"):
		fill = block.get_scope_color()
	elif block.has_method("is_scope_block") and block.is_scope_block():
		fill = Color8(226, 211, 248)
	elif block.has_method("get_rule_id"):
		fill = UiStyle.rule_color(str(block.get_rule_id()))
	elif block.has_method("is_assumption_block") and block.is_assumption_block():
		fill = Color8(244, 219, 255)
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = UiStyle.border_color()
	box.border_width_left = 2
	box.border_width_top = 2
	box.border_width_right = 2
	box.border_width_bottom = 2
	box.corner_radius_top_left = 5
	box.corner_radius_top_right = 5
	box.corner_radius_bottom_left = 5
	box.corner_radius_bottom_right = 5
	var rect := Rect2(center - Vector2(9, 7), Vector2(18, 14))
	draw_style_box(box, rect)

	if direction.length_squared() > 1.0:
		var normal := direction.normalized()
		var tip := center + normal * 16.0
		var side := Vector2(-normal.y, normal.x) * 4.0
		var base := center + normal * 10.0
		draw_colored_polygon(
			PackedVector2Array([tip, base + side, base - side]),
			UiStyle.border_color()
		)
