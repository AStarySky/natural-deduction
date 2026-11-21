extends Control

## Persistent paper speaker control: left click toggles mute; right click opens
## the small music + SFX volume popover.

const IconButtonRes = preload("res://ui/icon_button.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var controller = null
var _button = null
var _popup: PanelContainer = null
var _slider: HSlider = null
var _status: Label = null

func setup(p_controller) -> void:
	controller = p_controller
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 60
	add_to_group("nd_ui_overlay")

	_button = IconButtonRes.new()
	_button.setup("sound", "Audio: click to mute · right-click for volume")
	_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_button.offset_left = -56
	_button.offset_top = 14
	_button.offset_right = -20
	_button.offset_bottom = 50
	_button.pressed.connect(_on_toggle_mute)
	_button.secondary_pressed.connect(_toggle_popup)
	_button.mouse_entered.connect(func() -> void:
		if controller != null and controller.has_method("play_sfx"):
			controller.play_sfx("button_hover")
	)
	add_child(_button)

	_popup = PanelContainer.new()
	_popup.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_popup.offset_left = -268
	_popup.offset_top = 58
	_popup.offset_right = -20
	_popup.offset_bottom = 174
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.add_theme_stylebox_override(
		"panel", UiStyle.card_style(UiStyle.cream(), UiStyle.border_color(), 12)
	)
	_popup.visible = false
	add_child(_popup)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	_popup.add_child(box)
	_status = UiStyle.make_display_label("AUDIO", 13, UiStyle.text_color())
	box.add_child(_status)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.01
	_slider.custom_minimum_size = Vector2(220, 24)
	_slider.value = 0.8
	_slider.tooltip_text = "Music + SFX volume"
	_slider.value_changed.connect(_on_volume_changed)
	box.add_child(_slider)
	_sync_from_controller()

func refresh_state() -> void:
	_sync_from_controller()

func _sync_from_controller() -> void:
	if controller == null:
		return
	var muted: bool = controller.is_audio_muted() if controller.has_method("is_audio_muted") else false
	var volume: float = controller.get_audio_volume() if controller.has_method("get_audio_volume") else 0.8
	_slider.set_value_no_signal(volume)
	_button.kind = "mute" if muted else "sound"
	_button.tooltip_text = "Audio muted · click to unmute · right-click for volume" if muted else "Audio: click to mute · right-click for volume"
	_button.queue_redraw()
	_status.text = "AUDIO · MUTED" if muted else "AUDIO"

func _toggle_popup() -> void:
	_popup.visible = not _popup.visible
	if _popup.visible:
		_sync_from_controller()

func _on_toggle_mute() -> void:
	if controller != null and controller.has_method("toggle_audio_muted"):
		controller.toggle_audio_muted()
	_sync_from_controller()

func _on_volume_changed(value: float) -> void:
	if controller != null and controller.has_method("set_audio_volume"):
		controller.set_audio_volume(value)
	_status.text = "AUDIO" if value > 0.001 else "AUDIO · OFF"
