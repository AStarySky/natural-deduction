extends Control

## Shared paper-card shell for title-screen overlays (Credits / Settings).
## Subclasses fill `_body` by overriding `_build_body`.

signal closed

const CardWearRes = preload("res://ui/card_wear.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var controller = null
var _card: PanelContainer = null
var _body: VBoxContainer = null
var _close_button: Button = null

func setup(p_controller) -> void:
	controller = p_controller
	add_to_group("nd_ui_overlay")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_shell(_modal_title(), _modal_width())
	_build_body(_body)
	set_process_input(true)

func _modal_title() -> String:
	return "CREDITS"

func _modal_width() -> float:
	return 720.0

func _build_shell(title_text: String, width: float) -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.16, 0.10, 0.18, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_shade_input)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_card = PanelContainer.new()
	_card.custom_minimum_size = Vector2(width, 0)
	_card.add_theme_stylebox_override("panel", UiStyle.empty_style())
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_card)
	CardWearRes.apply_to(_card, 0x71A2C, UiStyle.cream())
	_card.rotation = 0.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)

	var title := UiStyle.make_display_label(title_text, 28, UiStyle.text_color())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_close_button = Button.new()
	_close_button.text = "X"
	_close_button.custom_minimum_size = Vector2(44, 38)
	UiStyle.style_button(_close_button, UiStyle.lavender(), 16)
	_bind_button(_close_button)
	_close_button.pressed.connect(_on_close)
	header.add_child(_close_button)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_body)

## Subclass hook. Default is intentionally empty.
func _build_body(_target: VBoxContainer) -> void:
	pass

func _make_action_button(
	text: String,
	color: Color,
	font_size: int = 16,
	width: float = 180.0
) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 46)
	UiStyle.style_button(button, color, font_size)
	_bind_button(button)
	return button

func _add_footer(target: VBoxContainer, label: String = "CLOSE") -> void:
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(actions)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)
	var done := _make_action_button(label, UiStyle.coral(), 18, 132)
	done.pressed.connect(_on_close)
	actions.add_child(done)

func _bind_button(button: Button) -> void:
	button.mouse_entered.connect(func() -> void: _play_ui("button_hover"))
	button.pressed.connect(func() -> void: _play_ui("button_click"))

func _play_ui(cue: String) -> void:
	if controller != null and controller.has_method("play_sfx"):
		controller.play_sfx(cue)

func _on_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_close()

func _on_close() -> void:
	closed.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_on_close()
		get_viewport().set_input_as_handled()
