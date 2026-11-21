extends Control

## Modal chapter introduction: title, blurb, and the rules introduced here.

signal closed

const LevelBankRes = preload("res://ui/level_bank.gd")
const RuleIconRes = preload("res://ui/rule_icon.gd")
const RuleMetaRes = preload("res://ui/rule_meta.gd")
const CardWearRes = preload("res://ui/card_wear.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var controller = null
var chapter: Dictionary = {}

func setup(p_controller, p_chapter: Dictionary) -> void:
	controller = p_controller
	chapter = p_chapter
	add_to_group("nd_ui_overlay")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.16, 0.10, 0.18, 0.48)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(700, 0)
	card.add_theme_stylebox_override("panel", UiStyle.empty_style())
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	CardWearRes.apply_to(card, hash(str(chapter.get("id", ""))), UiStyle.cream())
	card.rotation = 0.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	var chapter_number := LevelBankRes.chapter_index(str(chapter.get("id", ""))) + 1
	var title := UiStyle.make_display_label(
		"CHAPTER %d · %s" % [chapter_number, str(chapter.get("title", "")).to_upper()],
		28,
		UiStyle.text_color()
	)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(44, 38)
	UiStyle.style_button(close, UiStyle.lavender(), 16)
	close.pressed.connect(_on_close)
	_bind_hover(close)
	header.add_child(close)

	var blurb := UiStyle.make_label_colored(str(chapter.get("blurb", "")), 14, UiStyle.muted_text())
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.clip_text = false
	blurb.custom_minimum_size = Vector2(0, 40)
	box.add_child(blurb)

	box.add_child(UiStyle.make_display_label("NEW IN THIS CHAPTER", 11, UiStyle.muted_text()))
	var new_rules := LevelBankRes.chapter_new_rules(str(chapter.get("id", "")))
	if new_rules.is_empty():
		box.add_child(
			UiStyle.make_label_colored(
				"Everything is unlocked now. Combine the rules freely.",
				14,
				UiStyle.text_color()
			)
		)
	else:
		var flow := VBoxContainer.new()
		flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flow.add_theme_constant_override("separation", 6)
		box.add_child(flow)
		for rule_id in new_rules:
			flow.add_child(_make_rule_row(rule_id))

	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)
	var start := Button.new()
	start.text = "START"
	start.custom_minimum_size = Vector2(128, 46)
	UiStyle.style_button(start, UiStyle.coral(), 18)
	start.pressed.connect(_on_close)
	_bind_hover(start)
	actions.add_child(start)

func _make_rule_row(rule_id: String) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	row.tooltip_text = RuleMetaRes.tooltip(rule_id)
	var icon = RuleIconRes.new()
	icon.setup(rule_id)
	icon.custom_minimum_size = Vector2(46, 46)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	text.add_child(UiStyle.make_display_label(RuleMetaRes.title(rule_id), 14, UiStyle.text_color()))
	var description := UiStyle.make_label_colored(
		RuleMetaRes.description(rule_id),
		11,
		UiStyle.muted_text()
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.clip_text = false
	description.custom_minimum_size = Vector2(0, 18)
	text.add_child(description)
	return row

func _bind_hover(button: Button) -> void:
	button.mouse_entered.connect(func() -> void:
		if controller != null and controller.has_method("play_sfx"):
			controller.play_sfx("button_hover")
	)
	button.pressed.connect(func() -> void:
		if controller != null and controller.has_method("play_sfx"):
			controller.play_sfx("button_click")
	)

func _on_close() -> void:
	closed.emit()
