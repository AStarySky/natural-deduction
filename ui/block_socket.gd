extends PanelContainer

## A single input socket. Holds at most one block (formula or rule subtree).
## Empty sockets also emit [signal activated] on a clean click, which the OR
## cards use to open the formula builder for the other side.

signal activated

const BlockBaseRes = preload("res://ui/block_base.gd")
const UiStyle = preload("res://ui/ui_style.gd")

const EMPTY_SIZE := Vector2(68, 64)

## Under-damped spring used for the drop preview: ~18% overshoot, settles in 0.32s.
const SPRING_DURATION := 0.32
const SPRING_ZETA := 0.48
const SPRING_OMEGA := 33.0

var owner_block = null
var controller = null
var attached_block: BlockBaseRes = null
var accepts_replacement: bool = false

var _placeholder: Label = null
var _drag_hover: bool = false
var _previewing: bool = false
var _size_tween: Tween = null
var _press_active := false
var _press_position := Vector2.ZERO

func _ready() -> void:
	add_to_group("nd_socket")

## Build the empty socket; [param hint] is shown until a block is attached.
func setup(p_owner, hint: String, p_controller) -> void:
	owner_block = p_owner
	controller = p_controller
	custom_minimum_size = EMPTY_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_vertical = Control.SIZE_SHRINK_END
	tooltip_text = "Input slot: drop a premise or a derived block here."

	var empty_text := hint if not hint.is_empty() else "+"
	var empty_size := 12 if not hint.is_empty() else 22
	_placeholder = UiStyle.make_display_label(empty_text, empty_size, UiStyle.muted_text())
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_placeholder)
	if not hint.is_empty():
		tooltip_text = "Other side of the disjunction: drop a formula block here."
	refresh_slot_visuals()

## Value sockets (the OR "other" side) can swap their block on drop.
func set_accepts_replacement(value: bool) -> void:
	accepts_replacement = value

## Return the block currently plugged in, or null.
func get_attached_block() -> BlockBaseRes:
	return attached_block

## True when no block is attached.
func is_empty() -> bool:
	return attached_block == null

## Attach an existing block (moving it from its old parent if needed).
func attach_block(block: BlockBaseRes, notify: bool = true) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	if block == owner_block:
		return false
	if owner_block != null and block.is_ancestor_of(owner_block):
		return false
	if attached_block != null:
		if not accepts_replacement or attached_block == block:
			return false
		var previous := attached_block
		attached_block = null
		if previous.get_parent() == self:
			remove_child(previous)
		previous.queue_free()

	var old_parent := block.get_parent()
	if old_parent != null:
		if old_parent == self:
			return true
		if old_parent.has_method("detach_block"):
			old_parent.detach_block(false)
		else:
			old_parent.remove_child(block)

	_stop_size_tween()
	_previewing = false
	custom_minimum_size = EMPTY_SIZE
	attached_block = block
	_placeholder.visible = false
	block.set_bottom_pinned(false)
	block.scale = Vector2.ONE
	add_child(block)
	block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block.size_flags_vertical = Control.SIZE_EXPAND_FILL
	block.reset_size()
	if accepts_replacement and block.has_method("set_value_only"):
		var click := Callable()
		if owner_block != null and owner_block.has_method("_on_extra_socket_activated"):
			click = Callable(owner_block, "_on_extra_socket_activated")
		block.set_value_only(true, click)
	refresh_slot_visuals()
	if notify:
		notify_board_changed()
	return true

## Remove and return the attached block without freeing it.
func detach_block(notify: bool = true) -> BlockBaseRes:
	if attached_block == null:
		return null
	var block := attached_block
	attached_block = null
	if accepts_replacement and block.has_method("set_value_only"):
		block.set_value_only(false)
	block.set_bottom_pinned(false)
	if block.get_parent() == self:
		remove_child(block)
	_animate_size(EMPTY_SIZE)
	_placeholder.visible = true
	refresh_slot_visuals()
	if notify:
		notify_board_changed()
	return block

## Tell the board to recompute after a structural change.
func notify_board_changed() -> void:
	if controller != null and controller.has_method("refresh_machine"):
		controller.refresh_machine()

## True when this empty socket can accept [param block].
func can_accept_block(block) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	if not block is Control or not block.has_method("get_result_formula"):
		return false
	if block == owner_block:
		return false
	if owner_block != null and block.is_ancestor_of(owner_block):
		return false
	if attached_block != null:
		return accepts_replacement and attached_block != block
	return true

## Grow/shrink the empty socket to the footprint of the incoming block.
func preview_block(block) -> void:
	if attached_block != null:
		return
	if not can_accept_block(block):
		clear_preview()
		return
	_previewing = true
	_animate_size(_preview_target(block))

## Jump straight to the final footprint so the incoming block can home in.
func commit_preview(block) -> void:
	if not can_accept_block(block):
		return
	_previewing = true
	_stop_size_tween()
	custom_minimum_size = _preview_target(block)

func _preview_target(block) -> Vector2:
	var target: Vector2 = block.get_combined_minimum_size() + Vector2(8.0, 6.0)
	target.x = maxf(EMPTY_SIZE.x, target.x)
	target.y = maxf(EMPTY_SIZE.y, target.y)
	return target

## Stop previewing and spring back to the empty footprint.
func clear_preview() -> void:
	if not _previewing:
		return
	_previewing = false
	if attached_block == null:
		_animate_size(EMPTY_SIZE)
	else:
		_stop_size_tween()
		custom_minimum_size = EMPTY_SIZE

func _animate_size(target: Vector2) -> void:
	_stop_size_tween()
	var start := custom_minimum_size
	if start.is_equal_approx(target):
		return
	_size_tween = create_tween()
	_size_tween.tween_method(
		func(t: float) -> void: _apply_spring_size(t, start, target),
		0.0,
		1.0,
		SPRING_DURATION
	)

## Sample the damped spring curve; values above 1.0 overshoot the target.
func _spring_curve(t: float) -> float:
	if t >= 1.0:
		return 1.0
	var decay := exp(-SPRING_ZETA * SPRING_OMEGA * t)
	var damped := SPRING_OMEGA * sqrt(1.0 - SPRING_ZETA * SPRING_ZETA)
	var phase := cos(damped * t) + (SPRING_ZETA * SPRING_OMEGA / damped) * sin(damped * t)
	return 1.0 - decay * phase

func _apply_spring_size(t: float, from: Vector2, to: Vector2) -> void:
	custom_minimum_size = from.lerp(to, _spring_curve(t))

func _stop_size_tween() -> void:
	if _size_tween != null and _size_tween.is_valid():
		_size_tween.kill()
	_size_tween = null

## A clean click on an empty socket emits [signal activated].
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_active = true
			_press_position = event.global_position
		else:
			if (
				_press_active
				and attached_block == null
				and event.global_position.distance_to(_press_position) <= 6.0
			):
				activated.emit()
			_press_active = false
	elif event is InputEventMouseMotion and _press_active:
		if event.global_position.distance_to(_press_position) > 6.0:
			_press_active = false

## Reject occupied sockets, missing blocks, cycles and self-drops.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if attached_block != null:
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var kind: String = str(data.get("kind", ""))
	if kind == "move_block":
		return can_accept_block(data.get("block"))
	if kind == "spawn_rule" or kind == "spawn_premise":
		return controller != null
	return false

## Attach the dropped/moved block.
func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(Vector2.ZERO, data):
		return
	var kind: String = str(data.get("kind", ""))
	if kind == "move_block":
		attach_block(data.get("block"))
	elif kind == "spawn_rule" and controller != null:
		var block = controller.create_rule_block(str(data.get("rule_id", "")))
		attach_block(block)
	elif kind == "spawn_premise" and controller != null:
		var block = controller.create_formula_block(data.get("formula"))
		attach_block(block)

## Highlight the socket while a block is dragged over it.
func set_drag_hover(active: bool) -> void:
	if _drag_hover == active:
		return
	_drag_hover = active
	refresh_slot_visuals()

## Paint the socket as empty/filled and reflect goal linking from its owner.
func refresh_slot_visuals() -> void:
	var border := UiStyle.border_color()
	var bg := Color(1.0, 1.0, 1.0, 0.24)
	if attached_block != null:
		bg = Color(0.0, 0.0, 0.0, 0.0)
		border = Color(0.0, 0.0, 0.0, 0.0)
	if _drag_hover:
		var can_take := attached_block == null or accepts_replacement
		border = UiStyle.valid_color() if can_take else UiStyle.error_color()
		bg = Color(0.0, 0.0, 0.0, 0.0)
	var box := UiStyle.slot_style(bg, border)
	if attached_block != null:
		# Filled inputs sit snug against the rule body below them.
		box.content_margin_left = 4.0
		box.content_margin_top = 4.0
		box.content_margin_right = 4.0
		box.content_margin_bottom = 2.0
	add_theme_stylebox_override("panel", box)
	if _placeholder != null:
		_placeholder.visible = attached_block == null
