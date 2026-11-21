extends Control

## Free-form canvas for root blocks. Blocks can be dragged here or out of
## sockets; nested blocks remain children of their sockets.

const BlockBaseRes = preload("res://ui/block_base.gd")

var controller = null

## Initialize the drop target and free-form canvas.
func setup(p_controller) -> void:
	controller = p_controller
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO

## Refresh every free root block; nested blocks refresh recursively.
func refresh_all() -> void:
	for child in get_children():
		if child is BlockBaseRes:
			child.refresh()
			child.reset_size()

## Remove and free all free root blocks.
func clear_all() -> void:
	for child in get_children():
		if child is BlockBaseRes:
			child.queue_free()

## Return the current free root blocks in child order.
func get_root_blocks() -> Array:
	var blocks: Array = []
	for child in get_children():
		if child is BlockBaseRes:
			blocks.append(child)
	return blocks

## Accept moved blocks and palette spawns.
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var kind: String = str(data.get("kind", ""))
	if kind == "move_block":
		var block = data.get("block")
		return is_instance_valid(block) and block is BlockBaseRes
	if kind == "spawn_rule" or kind == "spawn_premise":
		return controller != null
	return false

## Materialize or move the dropped block at the canvas-relative position.
func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var kind: String = str(data.get("kind", ""))
	var block = null
	if kind == "move_block":
		block = data.get("block")
		var old_parent: Node = block.get_parent()
		if old_parent == self:
			block.position = _position_for(block, at_position)
			return
		if old_parent != null:
			if old_parent.has_method("detach_block"):
				old_parent.detach_block(false)
			else:
				old_parent.remove_child(block)
	elif kind == "spawn_rule":
		block = controller.create_rule_block(str(data.get("rule_id", "")))
	elif kind == "spawn_premise":
		block = controller.create_formula_block(data.get("formula"))
	if block == null:
		return

	add_child(block)
	block.reset_size()
	block.position = _position_for(block, at_position)
	block.set_bottom_pinned(true)
	block.notify_board_changed()

## Place a block near the drop point while keeping it inside the canvas.
func _position_for(block: Control, at_position: Vector2) -> Vector2:
	var x := at_position.x - block.size.x * 0.5
	var y := at_position.y - 18.0
	x = clampf(x, 8.0, maxf(8.0, custom_minimum_size.x - block.size.x - 8.0))
	y = clampf(y, 8.0, maxf(8.0, custom_minimum_size.y - block.size.y - 8.0))
	return Vector2(x, y)
