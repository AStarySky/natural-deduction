extends PanelContainer

## Fixed trash drop target. The board handles the actual custom drag and
## deletes the dragged block when the pointer is released over this rect.

const UiStyle = preload("res://ui/ui_style.gd")

var _drag_hover: bool = false

## Build the bin label and initial styling.
func setup() -> void:
	custom_minimum_size = Vector2(92, 112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip_text = "Drop a block here (and nearby) to delete it and its inputs."

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)

	var title := UiStyle.make_outlined_title("TRASH", 22, UiStyle.cream())
	box.add_child(title)
	_refresh_style()

## Highlight while a block is dragged over the bin.
func set_drag_hover(active: bool) -> void:
	if _drag_hover == active:
		return
	_drag_hover = active
	_refresh_style()

## Red border normally, bright red when hovered.
func _refresh_style() -> void:
	var border := UiStyle.border_color()
	var bg := UiStyle.coral()
	if _drag_hover:
		border = UiStyle.error_color()
		bg = Color8(242, 177, 190)
	add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(bg, border, 14)
	)
