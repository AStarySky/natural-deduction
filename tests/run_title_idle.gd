extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("TITLE IDLE CHECK FAILED: " + label)

func _has_text(node: Node, needle: String) -> bool:
	if node is Label and str(node.text).contains(needle):
		return true
	for child in node.get_children():
		if _has_text(child, needle):
			return true
	return false

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	main.settings_path = ""
	root.add_child(main)
	await process_frame
	await process_frame
	var title = main._title_page
	_check(title != null, "title page exists")
	_check(main._title_page.visible, "title page starts visible")
	_check(not title._idle_enabled, "idle motion is disabled in headless")
	_check(title._title != null, "title label exists")
	_check(title._icon_plates.size() == 4, "four idle rule plates")
	_check(title._icon_plates[0].mouse_filter == Control.MOUSE_FILTER_STOP, "rule plates are clickable")
	var old_rule: String = title._icon_rule_ids[0]
	title._randomize_rule(0)
	_check(title._icon_rule_ids[0] != old_rule, "randomizing a rule plate swaps its rule")
	var unique := {}
	for rule_id in title._icon_rule_ids:
		unique[rule_id] = true
	_check(unique.size() == 4, "title rule plates keep four distinct rules")

	# Exercise the real mouse path too: gui_input passes (event, bound index).
	var click_before: String = title._icon_rule_ids[1]
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	title._icon_plates[1].gui_input.emit(click)
	_check(title._icon_rule_ids[1] != click_before, "a real click swaps the rule plate")
	unique.clear()
	for rule_id in title._icon_rule_ids:
		unique[rule_id] = true
	_check(unique.size() == 4, "clicked plates keep four distinct rules")
	_check(title._motes != null, "paper motes exist")
	_check(title._play.custom_minimum_size == Vector2(300, 82), "PLAY size unchanged")
	_check(title._levels.custom_minimum_size == Vector2(300, 82), "LEVELS size unchanged")

	# Hover must grow exactly one button; the other stays at idle size.
	title._idle_enabled = true
	title._play_hovered = false
	title._levels_hovered = false
	title._process(0.016)
	var idle_play: float = title._play.scale.x
	var idle_levels: float = title._levels.scale.x
	_check(is_equal_approx(idle_play, idle_levels), "PLAY and LEVELS share one idle scale")
	title._play_hovered = true
	title._process(0.016)
	_check(title._play.scale.x > idle_play, "hovering PLAY enlarges it")
	_check(
		title._levels.scale.x >= idle_levels - 0.01,
		"hovering PLAY does not shrink LEVELS"
	)
	var levels_before: float = title._levels.scale.x
	title._play_hovered = false
	title._levels_hovered = true
	title._process(0.016)
	_check(title._levels.scale.x > levels_before, "hovering LEVELS enlarges it")
	_check(
		title._play.scale.x >= idle_play - 0.01,
		"hovering LEVELS does not shrink PLAY"
	)
	title._levels_hovered = false
	title._idle_enabled = false

	# Credits / Settings overlays on the title screen.
	_check(title._credits != null, "credits button exists")
	_check(title._settings != null, "settings button exists")
	_check(
		title._credits.custom_minimum_size == Vector2(180, 48),
		"credits button uses the compact utility size"
	)
	title._credits.pressed.emit()
	await process_frame
	await process_frame
	_check(title._modal != null, "credits modal opens")
	_check(
		title._modal != null
		and str(title._modal.get_script().resource_path).ends_with("credits_modal.gd"),
		"credits modal has the credits type"
	)
	_check(title._modal != null and _has_text(title._modal, "Kenney"), "credits mention Kenney")
	_check(title._modal != null and _has_text(title._modal, "CC-BY"), "credits mention CC-BY")
	_check(title._modal != null and _has_text(title._modal, "Godot Engine"), "credits mention Godot")
	title._modal._on_close()
	await process_frame
	_check(title._modal == null, "credits modal closes")

	title._settings.pressed.emit()
	await process_frame
	await process_frame
	_check(title._modal != null, "settings modal opens")
	var settings = title._modal
	_check(
		settings != null
		and str(settings.get_script().resource_path).ends_with("settings_modal.gd"),
		"settings modal has the settings type"
	)
	_check(settings.music_slider != null, "settings has a music slider")
	_check(settings.sfx_slider != null, "settings has an SFX slider")
	_check(settings.mute_button != null, "settings has a mute button")
	_check(settings.fullscreen_button != null, "desktop settings has a fullscreen button")
	_check(settings.card_size_button != null, "settings has a card-size button")
	var card_mode_before: String = main.get_card_size_mode()
	settings.card_size_button.pressed.emit()
	_check(main.get_card_size_mode() != card_mode_before, "card-size button toggles the mode")
	settings.card_size_button.pressed.emit()
	_check(main.get_card_size_mode() == card_mode_before, "card-size button toggles back")
	settings.music_slider.value = 0.3
	_check(
		is_equal_approx(main.get_music_volume(), 0.3),
		"music slider updates the music level"
	)
	settings.sfx_slider.value = 0.4
	_check(
		is_equal_approx(main.get_sfx_volume(), 0.4),
		"SFX slider updates the SFX level"
	)
	var muted_before: bool = main.is_audio_muted()
	settings.mute_button.pressed.emit()
	_check(main.is_audio_muted() != muted_before, "mute button toggles audio")
	_check(
		settings.mute_button.text == ("UNMUTE" if main.is_audio_muted() else "MUTE ALL"),
		"mute button reflects the new state"
	)
	settings.mute_button.pressed.emit()
	_check(main.is_audio_muted() == muted_before, "mute button toggles back")
	settings._on_close()
	await process_frame
	_check(title._modal == null, "settings modal closes")

	title.play_intro()
	title.set_idle_enabled(true)
	_check(not title._idle_enabled, "headless ignores re-enabled motion")
	main._show_levels()
	await process_frame
	_check(title.visible == false, "levels hide the title")
	main._show_title()
	await process_frame
	_check(title.visible, "title returns")
	main._show_game()
	await process_frame
	_check(title.visible == false, "game hides the title")
	main._show_title()
	await process_frame
	_check(title.visible and main._title_page._play != null, "title still usable")
	print("TITLE IDLE RESULT: %d checks, %d failed" % [checks, failures])
	main.queue_free()
	quit(0 if failures == 0 else 1)
