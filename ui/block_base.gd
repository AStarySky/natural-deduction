extends PanelContainer

## Shared behavior for formula and rule blocks.
##
## Dragging is custom rather than Godot's built-in drag preview: the actual
## block is lifted to the board's drag layer and follows the mouse. Results are
## refreshed explicitly by the board; no long-lived result signals are used.

const UiStyle = preload("res://ui/ui_style.gd")

## Main/board controller; set when the block is created.
var controller = null
var _goal_linked: bool = false
var _refreshing: bool = false
var _press_active: bool = false
var _press_position := Vector2.ZERO
var _bottom_pinned: bool = false
var _pinned_bottom_y: float = 0.0
var _pin_guard: bool = false
var _value_only: bool = false
var _value_click: Callable = Callable()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG

func _ready() -> void:
	minimum_size_changed.connect(_on_minimum_size_changed)

## Keep this block's bottom edge fixed while its inputs grow upward.
## Only meaningful for free blocks on the canvas, not for blocks inside sockets.
func set_bottom_pinned(enabled: bool) -> void:
	var parent := get_parent()
	_bottom_pinned = enabled and parent != null and not (parent is Container)
	if _bottom_pinned:
		_pinned_bottom_y = position.y + size.y

## Recompute the pin after an external move/placement.
func refresh_bottom_pin() -> void:
	set_bottom_pinned(get_parent() != null and not (get_parent() is Container))

func _on_minimum_size_changed() -> void:
	if not _bottom_pinned or _pin_guard:
		return
	_pin_guard = true
	call_deferred("_apply_bottom_pin")

## After layout, move the block upward so its previous bottom stays fixed.
func _apply_bottom_pin() -> void:
	_pin_guard = false
	if not _bottom_pinned or not is_inside_tree():
		return
	var parent := get_parent()
	if parent == null or parent is Container:
		_bottom_pinned = false
		return
	reset_size()
	var target_y := _pinned_bottom_y - size.y
	position.y = maxf(8.0, target_y)
	if position.y > target_y:
		_pinned_bottom_y = position.y + size.y

## Formula produced by this block, or null when incomplete/invalid.
func get_result_formula():
	return null

## Open assumptions this block still depends on (AssumptionBlock instances).
func get_free_assumptions() -> Array:
	return []

## Merge assumption lists by group id, preserving the first representative.
func merge_assumption_blocks(sources: Array) -> Array:
	var seen: Dictionary = {}
	var merged: Array = []
	for source in sources:
		if source == null or not is_instance_valid(source):
			continue
		if not source.has_method("get_free_assumptions"):
			continue
		for assumption in source.get_free_assumptions():
			if assumption == null or not is_instance_valid(assumption):
				continue
			var group: int = assumption.get_assumption_group()
			if seen.has(group):
				continue
			seen[group] = true
			merged.append(assumption)
	return merged

## Recompute this block and its inputs. Subclasses override.
func refresh() -> void:
	pass

## One-line description used while dragging.
func get_display_text() -> String:
	return "block"

## Called by the board after a full refresh pass.
func refresh_visuals() -> void:
	pass

## Mark the block currently submitted to the goal bar.
func set_goal_linked(value: bool) -> void:
	_goal_linked = value
	refresh_visuals()

func is_goal_linked() -> bool:
	return _goal_linked

## Value-only blocks (the OR "other" slot) are formula values, not premises.
func set_value_only(enabled: bool, click_callback: Callable = Callable()) -> void:
	_value_only = enabled
	_value_click = click_callback
	mouse_default_cursor_shape = (
		Control.CURSOR_POINTING_HAND if enabled else Control.CURSOR_DRAG
	)

func is_value_only() -> bool:
	return _value_only

## True when this node is an ancestor of [param other].
func is_ancestor_of(other: Node) -> bool:
	var node := other
	while node != null:
		if node == self:
			return true
		node = node.get_parent()
	return false

## Notify the board after a structural edit.
func notify_board_changed() -> void:
	if controller != null and controller.has_method("refresh_machine"):
		controller.refresh_machine()

## Press-and-drag detection on the block body. Child sockets and chips consume
## their own input, so they drag themselves instead.
func _gui_input(event: InputEvent) -> void:
	if _value_only:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_active = true
				_press_position = event.global_position
			else:
				var clicked: bool = (
					_press_active
					and event.global_position.distance_to(_press_position) <= 6.0
				)
				_press_active = false
				if clicked and _value_click.is_valid():
					_value_click.call()
		elif event is InputEventMouseMotion and _press_active:
			if event.global_position.distance_to(_press_position) > 6.0:
				_press_active = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_active = true
				_press_position = event.global_position
			else:
				_press_active = false
	elif event is InputEventMouseMotion and _press_active:
		if event.global_position.distance_to(_press_position) > 6.0:
			_press_active = false
			if controller != null:
				if event.ctrl_pressed and controller.has_method("begin_copy_drag"):
					controller.begin_copy_drag(self, event.global_position)
				elif controller.has_method("begin_block_drag"):
					controller.begin_block_drag(self, event.global_position)
