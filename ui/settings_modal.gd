extends "res://ui/title_modal.gd"

## Title-screen settings: separate music / SFX levels, mute and fullscreen.

var music_slider: HSlider = null
var sfx_slider: HSlider = null
var mute_button: Button = null
var fullscreen_button: Button = null
var card_size_button: Button = null
var _music_value: Label = null
var _sfx_value: Label = null

func _modal_title() -> String:
	return "SETTINGS"

func _modal_width() -> float:
	return 640.0

func _build_body(body: VBoxContainer) -> void:
	body.add_child(
		UiStyle.make_display_label("AUDIO & DISPLAY", 11, UiStyle.muted_text())
	)

	var music := 0.8
	var sfx := 0.8
	if controller != null:
		if controller.has_method("get_music_volume"):
			music = float(controller.get_music_volume())
		if controller.has_method("get_sfx_volume"):
			sfx = float(controller.get_sfx_volume())

	var music_row := _add_slider_row(body, "MUSIC", music, _on_music_changed)
	music_slider = music_row["slider"]
	_music_value = music_row["value"]

	var sfx_row := _add_slider_row(body, "SFX", sfx, _on_sfx_changed)
	sfx_slider = sfx_row["slider"]
	_sfx_value = sfx_row["value"]

	body.add_child(
		UiStyle.make_display_label("CARDS", 11, UiStyle.muted_text())
	)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 10)
	card_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(card_row)
	var card_label := UiStyle.make_display_label("CARD SIZE", 13, UiStyle.text_color())
	card_label.custom_minimum_size = Vector2(84, 0)
	card_row.add_child(card_label)
	card_size_button = _make_action_button("CARD: COMPACT", UiStyle.sky(), 14, 230)
	card_size_button.pressed.connect(_on_card_size)
	card_row.add_child(card_size_button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(actions)

	mute_button = _make_action_button("MUTE ALL", UiStyle.sky(), 15, 190)
	mute_button.pressed.connect(_on_mute)
	actions.add_child(mute_button)

	if not OS.has_feature("web"):
		fullscreen_button = _make_action_button("FULLSCREEN: OFF", UiStyle.lavender(), 14, 230)
		fullscreen_button.pressed.connect(_on_fullscreen)
		actions.add_child(fullscreen_button)

	if OS.has_feature("web"):
		var web_note := UiStyle.make_label_colored(
			"Use the player's fullscreen button to expand the game.",
			12,
			UiStyle.muted_text()
		)
		web_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		web_note.clip_text = false
		web_note.custom_minimum_size = Vector2(0, 20)
		body.add_child(web_note)

	var saved := UiStyle.make_label_colored(
		"Settings are saved automatically.",
		11,
		UiStyle.muted_text()
	)
	body.add_child(saved)

	_sync_mute()
	_sync_fullscreen()
	_sync_card_size()
	_add_footer(body, "DONE")

func _add_slider_row(
	parent: VBoxContainer,
	label_text: String,
	initial: float,
	callback: Callable
) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(row)

	var label := UiStyle.make_display_label(label_text, 13, UiStyle.text_color())
	label.custom_minimum_size = Vector2(84, 0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = clampf(initial, 0.0, 1.0)
	slider.custom_minimum_size = Vector2(300, 28)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.tooltip_text = "%s volume" % label_text.capitalize()
	row.add_child(slider)

	var value := UiStyle.make_display_label(
		"%d%%" % roundi(slider.value * 100.0),
		13,
		UiStyle.muted_text()
	)
	value.custom_minimum_size = Vector2(52, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)

	slider.value_changed.connect(func(next: float) -> void:
		value.text = "%d%%" % roundi(next * 100.0)
		callback.call(next)
	)
	return {"slider": slider, "value": value}

func _on_card_size() -> void:
	if controller == null:
		return
	var current := "compact"
	if controller.has_method("get_card_size_mode"):
		current = str(controller.get_card_size_mode())
	var next := "comfort" if current == "compact" else "compact"
	if controller.has_method("set_card_size_mode"):
		controller.set_card_size_mode(next)
	_sync_card_size()

func _sync_card_size() -> void:
	if card_size_button == null:
		return
	var mode := "compact"
	if controller != null and controller.has_method("get_card_size_mode"):
		mode = str(controller.get_card_size_mode())
	var compact := mode == "compact"
	card_size_button.text = "CARD: COMPACT" if compact else "CARD: COMFORT"
	card_size_button.tooltip_text = (
		"Compact formula cards. Click for the original Comfort size."
		if compact
		else "Original formula card size. Click for Compact."
	)
	UiStyle.style_button(
		card_size_button,
		UiStyle.sky() if compact else UiStyle.lavender(),
		14
	)

func _on_music_changed(value: float) -> void:
	if controller != null and controller.has_method("set_music_volume"):
		controller.set_music_volume(value)

func _on_sfx_changed(value: float) -> void:
	if controller != null and controller.has_method("set_sfx_volume"):
		controller.set_sfx_volume(value)

func _on_mute() -> void:
	if controller != null and controller.has_method("toggle_audio_muted"):
		controller.toggle_audio_muted()
	_sync_mute()

func _sync_mute() -> void:
	if mute_button == null:
		return
	var muted := false
	if controller != null and controller.has_method("is_audio_muted"):
		muted = bool(controller.is_audio_muted())
	mute_button.text = "UNMUTE" if muted else "MUTE ALL"
	UiStyle.style_button(
		mute_button,
		UiStyle.coral() if muted else UiStyle.sky(),
		15
	)

func _on_fullscreen() -> void:
	if controller == null:
		return
	if controller.has_method("toggle_fullscreen"):
		controller.toggle_fullscreen()
	_sync_fullscreen()

func _sync_fullscreen() -> void:
	if fullscreen_button == null:
		return
	var on := false
	if controller != null and controller.has_method("is_fullscreen"):
		on = bool(controller.is_fullscreen())
	fullscreen_button.text = "FULLSCREEN: ON" if on else "FULLSCREEN: OFF"
	UiStyle.style_button(
		fullscreen_button,
		UiStyle.lavender() if on else UiStyle.sky(),
		14
	)
