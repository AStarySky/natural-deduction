extends PanelContainer

## Floating assumption window with its own infinite canvas, dots, pan and zoom.

const CanvasViewRes = preload("res://ui/canvas_view.gd")
const FormulaRes = preload("res://logic/formula.gd")
const UiStyle = preload("res://ui/ui_style.gd")
const WindowDotsRes = preload("res://ui/window_dots.gd")

var controller = null
var assumption_formula: FormulaRes = null
var assumption_group: int = 0
var scope_color: Color = Color8(226, 211, 248)
var inner_view = null
var inner_canvas = null
var scope_record = null
## Desktop layer inside this window; nested scope windows live here and are
## clipped to this rectangle, just like windows on a physical desktop.
var desktop_layer: Control = null
var nested_window: bool = false

var _title_bar: PanelContainer = null
var _status: Label = null
var _window_dots = null
var _drag_active := false
var _drag_offset := Vector2.ZERO
var _fullscreen := false
var _contained_maximized := false
var _contained_normal_position := Vector2.ZERO
var _contained_normal_size := Vector2(680, 460)
var _contained_target_size := Vector2(680, 460)
## Cascading offset used when a contained window is laid out fresh.
var contained_offset_y := 0.0

func setup_window(p_controller, formula: FormulaRes, group: int, tint: Color = Color8(226, 211, 248)) -> void:
	controller = p_controller
	assumption_formula = formula
	assumption_group = group
	scope_color = tint
	custom_minimum_size = Vector2(680, 460)
	size = Vector2(680, 460)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("nd_ui_overlay")
	add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(tint.lightened(0.52), UiStyle.border_color(), 16)
	)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_title_bar = PanelContainer.new()
	_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_bar.mouse_default_cursor_shape = Control.CURSOR_DRAG
	_title_bar.add_theme_stylebox_override(
		"panel",
		UiStyle.panel_style(tint, UiStyle.border_color(), 12, 2, false)
	)
	root.add_child(_title_bar)
	_title_bar.gui_input.connect(_on_title_input)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override("separation", 6)
	_title_bar.add_child(title_row)
	_window_dots = WindowDotsRes.new()
	_window_dots.setup()
	_window_dots.delete_requested.connect(_on_delete)
	_window_dots.toggle_size_requested.connect(_on_toggle_size)
	_window_dots.minimize_requested.connect(_on_done)
	title_row.add_child(_window_dots)

	var title := UiStyle.make_display_label("ASSUME " + formula.to_display_string(), 15, UiStyle.text_color())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)

	_status = UiStyle.make_display_label("", 10, UiStyle.muted_text())
	_status.custom_minimum_size = Vector2(130, 18)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	title_row.add_child(_status)

	var body := Control.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(body)

	inner_view = CanvasViewRes.new()
	inner_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner_view.custom_minimum_size = Vector2.ZERO
	body.add_child(inner_view)
	inner_view.setup(controller)
	inner_view.set_background_color(tint.lightened(0.22))
	inner_canvas = inner_view.world

	desktop_layer = Control.new()
	desktop_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desktop_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desktop_layer.clip_contents = true
	# Keep contained scope windows above this window's own canvas.
	desktop_layer.z_index = 10
	body.add_child(desktop_layer)
	# The body grows only after the container relayouts (not synchronously in
	# set_fullscreen), so maximize nested windows again when that happens.
	desktop_layer.resized.connect(_on_desktop_resized)

func _on_title_input(event: InputEvent) -> void:
	if _fullscreen:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			_drag_offset = get_global_mouse_position() - global_position
			if controller != null and controller.has_method("play_sfx"):
				controller.play_sfx("scope_move_start")
		else:
			if _drag_active and controller != null and controller.has_method("play_sfx"):
				controller.play_sfx("scope_move_end")
			_drag_active = false
	elif event is InputEventMouseMotion and _drag_active:
		if _contained_maximized:
			return
		if nested_window and get_parent() is Control:
			var layer := get_parent() as Control
			var layer_scale := layer.get_global_transform().get_scale()
			var desired := get_global_mouse_position() - _drag_offset
			var local := (desired - layer.global_position) / layer_scale
			position = Vector2(
				clampf(local.x, 0.0, maxf(0.0, layer.size.x - size.x)),
				clampf(local.y, 0.0, maxf(0.0, layer.size.y - size.y))
			)
		else:
			global_position = get_global_mouse_position() - _drag_offset
			if controller != null and controller.has_method("scope_window_moved"):
				controller.scope_window_moved(self)
		get_viewport().set_input_as_handled()

func _contained_default_size(bounds: Vector2) -> Vector2:
	var target := Vector2(
		clampf(bounds.x * 0.82, 360.0, 640.0),
		clampf(bounds.y * 0.82, 250.0, 420.0)
	)
	target.x = minf(target.x, maxf(260.0, bounds.x - 8.0))
	target.y = minf(target.y, maxf(190.0, bounds.y - 8.0))
	return target

## Nested windows are sized to fit the parent desktop and clipped there.
func configure_contained(bounds: Vector2) -> void:
	nested_window = true
	custom_minimum_size = Vector2.ZERO
	if _status != null:
		_status.visible = false
	_contained_target_size = _contained_default_size(bounds)
	size = _contained_target_size
	_clamp_contained()

## Recompute the default contained layout for a new parent size. This is used
## whenever the parent desktop changes, so identical scope paths converge on
## the same Q/R/S layout rather than remembering a previous pixel size.
func apply_default_contained_layout(bounds: Vector2) -> void:
	if not nested_window or bounds.x <= 0.0 or bounds.y <= 0.0:
		return
	_contained_target_size = _contained_default_size(bounds)
	size = _contained_target_size
	position = (bounds - size) * 0.5 + Vector2(0, contained_offset_y)
	_clamp_contained()
	_relayout_contained_children()

## Called by the parent desktop when its size changes. Maximized children
## still fill it; normal children get the default layout for the new bounds.
func sync_contained_layout(bounds: Vector2) -> void:
	if not nested_window or bounds.x <= 0.0 or bounds.y <= 0.0:
		return
	if _contained_maximized:
		position = Vector2.ZERO
		size = bounds
		_clamp_contained()
		_relayout_contained_children()
	else:
		apply_default_contained_layout(bounds)

## Apply after the first layout pass, when the panel's content minimum has
## refreshed; otherwise the initial 680x460 minimum can win for one frame.
func apply_contained_placement(bounds: Vector2, offset_y: float) -> void:
	if not nested_window or _contained_maximized:
		return
	contained_offset_y = offset_y
	apply_default_contained_layout(bounds)

func set_contained_maximized(enabled: bool, bounds: Vector2) -> void:
	if not nested_window:
		return
	if enabled:
		if not _contained_maximized:
			_contained_normal_position = position
			_contained_normal_size = size
		_contained_maximized = true
		position = Vector2.ZERO
		size = bounds
	else:
		_contained_maximized = false
		# Restore to the same default Q you would get by opening a new scope
		# in the current parent, instead of a stale pre-maximize size.
		var parent = get_parent()
		var parent_bounds: Vector2 = (
			(parent as Control).size if parent is Control else bounds
		)
		apply_default_contained_layout(parent_bounds)
	_refresh_window_controls(_contained_maximized)
	_relayout_contained_children()

func relayout_inside_parent() -> void:
	if not nested_window:
		return
	var layer := get_parent()
	if not layer is Control:
		return
	var bounds: Vector2 = (layer as Control).size
	if bounds.x <= 0.0 or bounds.y <= 0.0:
		return
	if _contained_maximized:
		position = Vector2.ZERO
		size = bounds
	else:
		size = Vector2(minf(size.x, bounds.x), minf(size.y, bounds.y))
		position = Vector2(
			clampf(position.x, 0.0, maxf(0.0, bounds.x - size.x)),
			clampf(position.y, 0.0, maxf(0.0, bounds.y - size.y))
		)
	_relayout_contained_children()

func _clamp_contained() -> void:
	if not nested_window:
		return
	var layer := get_parent()
	if not layer is Control:
		return
	var bounds: Vector2 = (layer as Control).size
	if bounds.x <= 0.0 or bounds.y <= 0.0:
		return
	size = Vector2(minf(size.x, bounds.x), minf(size.y, bounds.y))
	position = Vector2(
		clampf(position.x, 0.0, maxf(0.0, bounds.x - size.x)),
		clampf(position.y, 0.0, maxf(0.0, bounds.y - size.y))
	)

func _relayout_contained_children() -> void:
	if desktop_layer == null:
		return
	for child in desktop_layer.get_children():
		if child.has_method("relayout_inside_parent"):
			child.relayout_inside_parent()

## The parent desktop changed size. Non-maximized children snap to the same
## default layout they would get if opened now; maximized children fill it.
func _on_desktop_resized() -> void:
	if desktop_layer == null:
		return
	var bounds: Vector2 = desktop_layer.size
	if bounds.x <= 0.0 or bounds.y <= 0.0:
		return
	for child in desktop_layer.get_children():
		if child.has_method("sync_contained_layout"):
			child.sync_contained_layout(bounds)
		elif child.has_method("relayout_inside_parent"):
			child.relayout_inside_parent()

func set_fullscreen(enabled: bool, rect: Rect2) -> void:
	_fullscreen = enabled
	if _title_bar != null:
		# The fullscreen scope keeps a compact control strip in the top-left
		# instead of hiding every window control.
		_title_bar.visible = true
		_title_bar.size_flags_horizontal = (
			Control.SIZE_SHRINK_BEGIN if enabled else Control.SIZE_FILL
		)
		_title_bar.custom_minimum_size = (
			Vector2(360, 0) if enabled else Vector2.ZERO
		)
		_title_bar.mouse_default_cursor_shape = (
			Control.CURSOR_ARROW if enabled else Control.CURSOR_DRAG
		)
	position = rect.position
	size = rect.size
	if enabled:
		custom_minimum_size = Vector2.ZERO
	else:
		custom_minimum_size = Vector2(680, 460)
	_relayout_contained_children()
	_refresh_window_controls(enabled)

func _on_toggle_size() -> void:
	if controller != null and controller.has_method("toggle_scope_fullscreen"):
		controller.toggle_scope_fullscreen(self)

func _refresh_window_controls(maximized: bool) -> void:
	if _window_dots != null:
		_window_dots.set_maximized(maximized)

func get_title_bar():
	return _title_bar

func set_status(text: String, error: bool = false) -> void:
	if _status == null:
		return
	_status.text = text
	_status.add_theme_color_override(
		"font_color",
		UiStyle.error_color() if error else UiStyle.muted_text()
	)

func _on_done() -> void:
	if controller != null and controller.has_method("finish_scope_window"):
		controller.finish_scope_window(self)

func _on_delete() -> void:
	if controller != null and controller.has_method("delete_scope_window"):
		controller.delete_scope_window(self)
