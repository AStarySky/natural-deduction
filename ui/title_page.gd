extends Control

## Title screen: big logo, a few rule icons and Play / Levels navigation.
## A slow paper idle animation keeps the handmade scene alive.

signal play_pressed
signal levels_pressed
signal hovered
signal rule_swapped(rule_id: String)

const DotBackgroundRes = preload("res://ui/dot_background.gd")
const PaperMotesRes = preload("res://ui/paper_motes.gd")
const RuleIconRes = preload("res://ui/rule_icon.gd")
const CardWearRes = preload("res://ui/card_wear.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const FormulaArrowRes = preload("res://ui/formula_arrow.gd")
const RulesRes = preload("res://logic/rules.gd")
const RuleMetaRes = preload("res://ui/rule_meta.gd")
const UiStyle = preload("res://ui/ui_style.gd")
const CreditsModalRes = preload("res://ui/credits_modal.gd")
const SettingsModalRes = preload("res://ui/settings_modal.gd")

const TAU_F := TAU

var controller = null
var _bg = null
var _motes = null
var _tagline: Label = null
var _title: Control = null
var _subtitle: Control = null
var _proof_chip: Control = null
var _icon_plates: Array[Control] = []
var _icon_nodes: Array[Control] = []
var _icon_rule_ids: Array[String] = []
var _plate_hover: Array[bool] = []
var _plate_pop: Array[float] = []
var _play: Button = null
var _levels: Button = null
var _credits: Button = null
var _settings: Button = null
var _modal_layer: Control = null
var _modal: Control = null

var _idle_enabled := DisplayServer.get_name() != "headless"
var _idle_time := 0.0
var _parallax := Vector2.ZERO
var _target_parallax := Vector2.ZERO
var _intro_playing := false
var _intro_tween: Tween = null
var _intro_pending := false
var _rest_ready := false
var _intro_capture_attempts := 0
var _play_hovered := false
var _levels_hovered := false
var _credits_hovered := false
var _settings_hovered := false
var _breeze := 0.0

var _title_rest := {}
var _tagline_rest := {}
var _subtitle_rest := {}
var _plate_rest: Array[Dictionary] = []
var _play_rest := {}
var _levels_rest := {}
var _credits_rest := {}
var _settings_rest := {}
var _proof_rest := {}

func setup(p_controller) -> void:
	controller = p_controller

func _ready() -> void:
	_bg = DotBackgroundRes.new()
	add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.set_drift(Vector2(2.0, -1.2))
	_build_hero_sheets()

	_motes = PaperMotesRes.new()
	add_child(_motes)
	_motes.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_motes.setup()
	if not _idle_enabled:
		_motes.set_process(false)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	_tagline = UiStyle.make_hint("A BLOCK PROOF PUZZLE", 24)
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_tagline)

	var title_row := HBoxContainer.new()
	title_row.alignment = BoxContainer.ALIGNMENT_CENTER
	title_row.add_theme_constant_override("separation", 14)
	title_row.custom_minimum_size = Vector2(960, 120)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var natural := UiStyle.make_outlined_title("Natural", 88, UiStyle.coral())
	natural.clip_text = false
	natural.custom_minimum_size = Vector2(320, 120)
	natural.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	natural.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(natural)
	var title_arrow := FormulaArrowRes.new()
	title_arrow.setup(false, 96, 56, 6.0)
	title_arrow.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	title_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(title_arrow)
	var deduction := UiStyle.make_outlined_title("Deduction", 88, UiStyle.lavender())
	deduction.clip_text = false
	deduction.custom_minimum_size = Vector2(400, 120)
	deduction.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	deduction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_row.add_child(deduction)
	_title = title_row
	box.add_child(_wrap_center(title_row))

	var subtitle_row := HBoxContainer.new()
	subtitle_row.alignment = BoxContainer.ALIGNMENT_CENTER
	subtitle_row.add_theme_constant_override("separation", 10)
	subtitle_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subtitle_row.add_child(_word_label("PLUG", 30, UiStyle.muted_text()))
	subtitle_row.add_child(_word_label("&", 30, UiStyle.border_color()))
	subtitle_row.add_child(_word_label("CHAIN", 30, UiStyle.muted_text()))
	var iff_arrow := FormulaArrowRes.new()
	iff_arrow.setup(true, 46, 28, 2.8)
	iff_arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	subtitle_row.add_child(iff_arrow)
	subtitle_row.add_child(_word_label("PROOF", 30, UiStyle.muted_text()))
	_subtitle = subtitle_row
	box.add_child(subtitle_row)

	_proof_chip = _formula_chip("(P -> Q) & P -> Q", 24, 12, "E.G.")
	box.add_child(_proof_chip)

	var icon_row := HBoxContainer.new()
	icon_row.alignment = BoxContainer.ALIGNMENT_CENTER
	icon_row.add_theme_constant_override("separation", 18)
	icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon_row)
	for rule_id in ["impl_elim", "and_intro", "or_intro_left", "double_neg_elim"]:
		var index := _icon_plates.size()
		var plate := PanelContainer.new()
		plate.custom_minimum_size = Vector2(96, 96)
		plate.mouse_filter = Control.MOUSE_FILTER_STOP
		plate.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		plate.tooltip_text = RuleMetaRes.title(rule_id)
		plate.add_theme_stylebox_override(
			"panel",
			UiStyle.panel_style(UiStyle.cream(), UiStyle.border_color(), 14, 3, true)
		)
		var icon = RuleIconRes.new()
		icon.setup(rule_id)
		icon.custom_minimum_size = Vector2(70, 70)
		plate.add_child(icon)
		var wrap := CenterContainer.new()
		wrap.custom_minimum_size = Vector2(96, 96)
		wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		wrap.add_child(plate)
		icon_row.add_child(wrap)
		_icon_plates.append(plate)
		_icon_nodes.append(icon)
		_icon_rule_ids.append(rule_id)
		_plate_hover.append(false)
		_plate_pop.append(0.0)
		plate.gui_input.connect(_on_rule_plate_input.bind(index))
		plate.mouse_entered.connect(_on_rule_plate_hover.bind(index, true))
		plate.mouse_exited.connect(_on_rule_plate_hover.bind(index, false))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	box.add_child(buttons)

	_play = Button.new()
	_play.text = "PLAY"
	_play.custom_minimum_size = Vector2(300, 82)
	UiStyle.style_button(_play, UiStyle.coral(), 30)
	_play.pressed.connect(func() -> void: play_pressed.emit())
	_play.mouse_entered.connect(_on_button_hover.bind(_play, true))
	_play.mouse_exited.connect(_on_button_hover.bind(_play, false))
	var play_wrap := _wrap_center(_play)
	play_wrap.custom_minimum_size = Vector2(300, 82)
	buttons.add_child(play_wrap)

	_levels = Button.new()
	_levels.text = "LEVELS"
	_levels.custom_minimum_size = Vector2(300, 82)
	UiStyle.style_button(_levels, UiStyle.lavender(), 24)
	_levels.pressed.connect(func() -> void: levels_pressed.emit())
	_levels.mouse_entered.connect(_on_button_hover.bind(_levels, true))
	_levels.mouse_exited.connect(_on_button_hover.bind(_levels, false))
	var levels_wrap := _wrap_center(_levels)
	levels_wrap.custom_minimum_size = Vector2(300, 82)
	buttons.add_child(levels_wrap)

	var utility := HBoxContainer.new()
	utility.alignment = BoxContainer.ALIGNMENT_CENTER
	utility.add_theme_constant_override("separation", 16)
	box.add_child(utility)
	_credits = _add_utility_button(utility, "CREDITS", UiStyle.sky())
	_settings = _add_utility_button(utility, "SETTINGS", UiStyle.yellow())
	_credits.tooltip_text = "View credits and licenses."
	_settings.tooltip_text = "Adjust music, SFX and fullscreen."
	_credits.pressed.connect(_open_credits)
	_settings.pressed.connect(_open_settings)

	set_process(_idle_enabled)
	visibility_changed.connect(_on_visibility_changed)
	call_deferred("_capture_rest_transforms")

func _build_hero_sheets() -> void:
	var hero_wrap := CenterContainer.new()
	hero_wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hero_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero_wrap)

	var stack := Control.new()
	stack.custom_minimum_size = Vector2(1120, 680)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hero_wrap.add_child(stack)

	var back := Control.new()
	back.custom_minimum_size = Vector2(1100, 650)
	back.size = Vector2(1100, 650)
	back.position = Vector2(10, 10)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(back)
	var back_paper = CardWearRes.apply_to(back, 0x71A1E, Color8(199, 166, 216, 102))
	back_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.rotation = deg_to_rad(-1.4)

	var front := Control.new()
	front.custom_minimum_size = Vector2(1040, 620)
	front.size = Vector2(1040, 620)
	front.position = Vector2(40, 30)
	front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(front)
	var front_paper = CardWearRes.apply_to(front, 0x5EED, Color8(247, 240, 227, 240))
	front_paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	front.rotation = deg_to_rad(0.5)

	var tape_left := ColorRect.new()
	tape_left.color = Color(0.906, 0.604, 0.659, 0.55)
	tape_left.position = Vector2(72, -8)
	tape_left.size = Vector2(150, 22)
	tape_left.rotation = deg_to_rad(-4.0)
	tape_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(tape_left)
	var tape_right := ColorRect.new()
	tape_right.color = Color(0.780, 0.651, 0.847, 0.55)
	tape_right.position = Vector2(830, -5)
	tape_right.size = Vector2(130, 20)
	tape_right.rotation = deg_to_rad(3.0)
	tape_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	front.add_child(tape_right)

	for tag in [
		["A -> B", Vector2(48, 46), -7.0],
		["A & B", Vector2(830, 52), 5.0],
		["A | B", Vector2(44, 454), 4.0],
		["~~A -> A", Vector2(814, 446), -4.0],
	]:
		var chip = _formula_chip(str(tag[0]), 18, 10, "")
		chip.position = Vector2(tag[1])
		chip.rotation = deg_to_rad(float(tag[2]))
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		front.add_child(chip)

func _word_label(text: String, font_size: int, color: Color) -> Label:
	var label := UiStyle.make_display_label(text, font_size, color)
	label.clip_text = false
	label.custom_minimum_size = Vector2(float(text.length()) * font_size * 0.58 + 8.0, font_size + 10.0)
	label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

func _formula_chip(text: String, token_size: int, font_size: int, tag: String) -> PanelContainer:
	var parsed := ParserRes.new(text).parse()
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override(
		"panel",
		UiStyle.panel_style(UiStyle.cream(), UiStyle.border_color(), 10, 2, true)
	)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 5)
	panel.add_child(row)
	if not tag.is_empty():
		var tag_label := UiStyle.make_display_label(tag, 9, UiStyle.muted_text())
		tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(tag_label)
	var visual := FormulaVisualRes.new()
	if parsed.ok:
		visual.setup(parsed.formula, token_size, font_size)
	else:
		visual.setup(null, token_size, font_size)
	visual.custom_minimum_size = Vector2(0, token_size + 6)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(visual)
	panel.reset_size()
	return panel

## gui_input passes the event first; the bound plate index arrives after it.
func _on_rule_plate_input(event: InputEvent, index: int) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_randomize_rule(index)

func _on_rule_plate_hover(index: int, active: bool) -> void:
	if index < 0 or index >= _plate_hover.size():
		return
	_plate_hover[index] = active
	if active:
		hovered.emit()

func _randomize_rule(index: int) -> void:
	if index < 0 or index >= _icon_rule_ids.size():
		return
	var current := _icon_rule_ids[index]
	var used := {}
	for other in range(_icon_rule_ids.size()):
		if other != index:
			used[_icon_rule_ids[other]] = true
	var candidates: Array[String] = []
	for rule_id in RulesRes.palette_ids():
		var candidate := str(rule_id)
		if candidate != current and not used.has(candidate):
			candidates.append(candidate)
	if candidates.is_empty():
		for rule_id in RulesRes.palette_ids():
			var fallback := str(rule_id)
			if fallback != current:
				candidates.append(fallback)
	if candidates.is_empty():
		return
	var chosen := candidates[randi() % candidates.size()]
	_icon_rule_ids[index] = chosen
	_icon_nodes[index].setup(chosen)
	_icon_plates[index].tooltip_text = RuleMetaRes.title(chosen)
	_plate_pop[index] = 1.0
	rule_swapped.emit(chosen)

func _wrap_center(child: Control) -> CenterContainer:
	var wrap := CenterContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(child)
	return wrap

func _add_utility_button(parent: HBoxContainer, text: String, color: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 48)
	UiStyle.style_button(button, color, 15)
	button.mouse_entered.connect(_on_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_button_hover.bind(button, false))
	var wrap := _wrap_center(button)
	wrap.custom_minimum_size = Vector2(180, 48)
	parent.add_child(wrap)
	return button

func play_intro() -> void:
	if not _idle_enabled or not is_visible_in_tree():
		return
	if _intro_pending or _intro_playing:
		return
	_intro_pending = true
	call_deferred("_begin_intro")

func _begin_intro() -> void:
	_intro_pending = false
	if not _idle_enabled or not is_visible_in_tree():
		return
	_capture_rest_transforms()
	if not _rest_ready:
		_intro_capture_attempts += 1
		if _intro_capture_attempts < 12:
			_intro_pending = true
			call_deferred("_begin_intro")
		return
	_intro_capture_attempts = 0
	_reset_to_rest()
	_intro_playing = true
	_idle_time = 0.0
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()

	_intro_tween = create_tween().set_parallel(true)
	_intro_item(_tagline, _tagline_rest, 0.00, Vector2.ZERO, 1.0, false)
	_intro_item(_title, _title_rest, 0.06, Vector2(0, 12), 0.96)
	_intro_item(_subtitle, _subtitle_rest, 0.14, Vector2.ZERO, 1.0, false)
	_intro_item(_proof_chip, _proof_rest, 0.20, Vector2.ZERO, 0.94, false)
	for index in range(_icon_plates.size()):
		_intro_item(
			_icon_plates[index],
			_plate_rest[index],
			0.20 + index * 0.055,
			Vector2(0, 8),
			0.72
		)
	_intro_item(_play, _play_rest, 0.38, Vector2(0, 8), 0.94)
	_intro_item(_levels, _levels_rest, 0.43, Vector2(0, 8), 0.94)
	_intro_item(_credits, _credits_rest, 0.47, Vector2(0, 6), 0.94)
	_intro_item(_settings, _settings_rest, 0.50, Vector2(0, 6), 0.94)
	_intro_tween.chain().tween_callback(_finish_intro)

func _intro_item(item: Control, rest: Dictionary, delay: float, offset: Vector2, from_scale: float, move: bool = true) -> void:
	if item == null or rest.is_empty():
		return
	item.modulate.a = 0.0
	item.scale = Vector2(rest["scale"]) * from_scale
	if move:
		item.position = Vector2(rest["position"]) + offset
	_intro_tween.tween_property(
		item, "modulate:a", 1.0, 0.30
	).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if move:
		_intro_tween.tween_property(
			item, "position", rest["position"], 0.42
		).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(
		item, "scale", rest["scale"], 0.38
	).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _finish_intro() -> void:
	_intro_playing = false
	_intro_tween = null
	_idle_time = 0.0

func _capture_rest_transforms() -> void:
	if _rest_ready or _title == null:
		return
	if _title.size.x <= 1.0:
		return
	_title_rest = _rest_for(_title)
	_tagline_rest = _rest_for(_tagline)
	_subtitle_rest = _rest_for(_subtitle)
	_play_rest = _rest_for(_play)
	_levels_rest = _rest_for(_levels)
	if _credits != null:
		_credits_rest = _rest_for(_credits)
	if _settings != null:
		_settings_rest = _rest_for(_settings)
	if _proof_chip != null:
		_proof_rest = _rest_for(_proof_chip)
	_plate_rest.clear()
	for plate in _icon_plates:
		_plate_rest.append(_rest_for(plate))
	_rest_ready = true

func _rest_for(item: Control) -> Dictionary:
	item.pivot_offset = item.size * 0.5
	return {
		"position": item.position,
		"rotation": item.rotation,
		"scale": item.scale,
	}

func _reset_to_rest() -> void:
	for pair in [
		[_tagline, _tagline_rest],
		[_title, _title_rest],
		[_subtitle, _subtitle_rest],
		[_play, _play_rest],
		[_levels, _levels_rest],
		[_credits, _credits_rest],
		[_settings, _settings_rest],
		[_proof_chip, _proof_rest],
	]:
		var item: Control = pair[0]
		var rest: Dictionary = pair[1]
		if item == null or rest.is_empty():
			continue
		item.position = rest["position"]
		item.rotation = rest["rotation"]
		item.scale = rest["scale"]
		item.modulate.a = 1.0
	for index in range(_icon_plates.size()):
		var plate := _icon_plates[index]
		var rest := _plate_rest[index]
		plate.position = rest["position"]
		plate.rotation = rest["rotation"]
		plate.scale = rest["scale"]
		plate.modulate.a = 1.0
	_parallax = Vector2.ZERO
	_target_parallax = Vector2.ZERO
	for index in range(_plate_hover.size()):
		_plate_hover[index] = false
		_plate_pop[index] = 0.0
	if _motes != null:
		_motes.set_parallax(Vector2.ZERO)
		_motes.set_breeze(0.0)

func _process(delta: float) -> void:
	if not _idle_enabled or _intro_playing or not is_visible_in_tree() or not _rest_ready:
		return
	_idle_time += delta
	var t := _idle_time
	_update_parallax(delta)
	_breeze = pow(maxf(0.0, sin(t * TAU_F / 9.0)), 8.0)
	if _motes != null:
		_motes.set_breeze(_breeze)
		_motes.set_parallax(_parallax * 2.0)

	_title.position = Vector2(_title_rest["position"]) + Vector2(
		_parallax.x * 3.0,
		sin(t * TAU_F / 5.6) * 4.5 + _parallax.y * 2.0
	)
	_title.rotation = float(_title_rest["rotation"]) + deg_to_rad(0.7) * sin(t * TAU_F / 7.3)
	_title.scale = Vector2(_title_rest["scale"]) * (1.0 + 0.012 * (0.5 + 0.5 * sin(t * TAU_F / 4.8)))

	_tagline.modulate.a = 0.86 + 0.14 * (0.5 + 0.5 * sin(t * TAU_F / 4.2))

	_subtitle.rotation = float(_subtitle_rest["rotation"]) + deg_to_rad(0.4) * sin(t * TAU_F / 6.2)
	_subtitle.modulate.a = 0.85 + 0.15 * (0.5 + 0.5 * sin(t * TAU_F / 5.1 + 0.4))

	for index in range(_icon_plates.size()):
		var plate := _icon_plates[index]
		var rest := _plate_rest[index]
		var phase := t * TAU_F / (3.4 + index * 0.3) + index * 0.8
		var lift := sin(phase) * (4.5 + _breeze * 2.0)
		var pop: float = _plate_pop[index]
		_plate_pop[index] = maxf(0.0, pop - delta * 3.8)
		var hover_boost := 0.035 if _plate_hover[index] else 0.0
		plate.position = Vector2(rest["position"]) + Vector2(
			_parallax.x * (4.0 + index * 0.4),
			lift + _parallax.y * 2.5 - pop * 7.0
		)
		plate.rotation = (
			float(rest["rotation"])
			+ deg_to_rad(2.0) * sin(phase * 0.8 + _breeze)
			+ deg_to_rad(7.0) * pop
		)
		plate.scale = Vector2(rest["scale"]) * (1.0 + 0.025 * sin(phase * 0.7) + hover_boost + pop * 0.12)

	var button_scale := 1.0 + 0.008 * (0.5 + 0.5 * sin(t * TAU_F / 6.0))
	_apply_button_motion(_play, _play_rest, _play_hovered, button_scale)
	_apply_button_motion(_levels, _levels_rest, _levels_hovered, button_scale)
	_apply_button_motion(_credits, _credits_rest, _credits_hovered, button_scale)
	_apply_button_motion(_settings, _settings_rest, _settings_hovered, button_scale)

func _apply_button_motion(button: Button, rest: Dictionary, hovered_state: bool, breath: float) -> void:
	if button == null or rest.is_empty():
		return
	# Hover must always be visibly larger than the idle breath (which tops out
	# at 1.008); otherwise the hover target can shrink a button.
	var target_scale := 1.055 if hovered_state else breath
	button.scale = Vector2(rest["scale"]) * target_scale
	button.pivot_offset = button.size * 0.5
	button.position = Vector2(rest["position"]) + Vector2(0, _parallax.y * 0.6)

func _update_parallax(delta: float) -> void:
	var half := size * 0.5
	if half.x <= 1.0 or half.y <= 1.0:
		return
	var mouse := get_viewport().get_mouse_position()
	_target_parallax = Vector2(
		clampf((mouse.x - half.x) / half.x, -1.0, 1.0),
		clampf((mouse.y - half.y) / half.y, -1.0, 1.0)
	) * 1.6
	_parallax = _parallax.lerp(_target_parallax, 1.0 - exp(-5.0 * delta))

func _on_button_hover(button: Button, active: bool) -> void:
	if button == _play:
		_play_hovered = active
	elif button == _levels:
		_levels_hovered = active
	elif button == _credits:
		_credits_hovered = active
	elif button == _settings:
		_settings_hovered = active
	if active:
		hovered.emit()

func _on_visibility_changed() -> void:
	if not visible:
		_close_modal(false)
		if _intro_tween != null and _intro_tween.is_valid():
			_intro_tween.kill()
		_intro_tween = null
		_intro_playing = false
		_intro_pending = false
		if _rest_ready:
			_reset_to_rest()
		set_process(false)
		if _motes != null:
			_motes.set_process(false)
		if _bg != null:
			_bg.set_process(false)
		return
	if _idle_enabled:
		_capture_rest_transforms()
		set_process(true)
		if _motes != null:
			_motes.set_process(true)
		if _bg != null:
			_bg.set_process(true)

func _open_credits() -> void:
	_play_ui("button_click")
	_open_modal(CreditsModalRes)

func _open_settings() -> void:
	_play_ui("button_click")
	_open_modal(SettingsModalRes)

func _open_modal(modal_script) -> void:
	if not is_visible_in_tree():
		return
	_close_modal(false)
	_ensure_modal_layer()
	_modal = modal_script.new()
	_modal.setup(controller)
	_modal.closed.connect(_on_modal_closed)
	_modal_layer.add_child(_modal)
	_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_play_ui("card_open")

func _ensure_modal_layer() -> void:
	if _modal_layer != null:
		return
	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_layer.z_index = 120
	add_child(_modal_layer)

func _on_modal_closed() -> void:
	_close_modal(true)

func _close_modal(with_sound: bool = true) -> void:
	if _modal == null:
		return
	if with_sound:
		_play_ui("card_place")
	if is_instance_valid(_modal):
		_modal.queue_free()
	_modal = null

func _play_ui(cue: String) -> void:
	if controller != null and controller.has_method("play_sfx"):
		controller.play_sfx(cue)

## Accessibility escape hatch: disable all motion and leave the static layout.
func set_idle_enabled(enabled: bool) -> void:
	_idle_enabled = enabled and DisplayServer.get_name() != "headless"
	if not _idle_enabled:
		if _intro_tween != null and _intro_tween.is_valid():
			_intro_tween.kill()
		_intro_tween = null
		_intro_playing = false
		_intro_pending = false
		if _rest_ready:
			_reset_to_rest()
		set_process(false)
		if _motes != null:
			_motes.set_process(false)
		if _bg != null:
			_bg.set_drift(Vector2.ZERO)
	else:
		set_process(true)
		if _motes != null:
			_motes.set_process(true)
		if _bg != null:
			_bg.set_drift(Vector2(2.0, -1.2))
