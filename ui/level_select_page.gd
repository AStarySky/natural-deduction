extends Control

## Chapter browser: chapter tabs, a chapter banner with new-rule chips, and a
## grid of level cards. refresh() is safe to call every time the page opens.

signal level_selected(level_id: String)
signal back_requested
signal hovered(kind: String, active: bool)

const DotBackgroundRes = preload("res://ui/dot_background.gd")
const LevelBankRes = preload("res://ui/level_bank.gd")
const LevelCardRes = preload("res://ui/level_card.gd")
const ChapterTabRes = preload("res://ui/chapter_tab.gd")
const RuleIconRes = preload("res://ui/rule_icon.gd")
const RuleMetaRes = preload("res://ui/rule_meta.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var progress = null
var _selected_chapter_id: String = ""
var _tabs_row: HBoxContainer = null
var _banner: PanelContainer = null
var _grid: GridContainer = null
var _total_label: Label = null

func setup(p_progress) -> void:
	progress = p_progress
	if is_inside_tree() and _grid != null:
		refresh()

func _ready() -> void:
	_build_static()
	refresh()

func _build_static() -> void:
	var bg = DotBackgroundRes.new()
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.set_drift(Vector2(2.0, -1.2))

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(110, 42)
	UiStyle.style_button(back, UiStyle.lavender(), 16)
	back.pressed.connect(func() -> void: back_requested.emit())
	back.mouse_entered.connect(func() -> void: hovered.emit("button", true))
	back.mouse_exited.connect(func() -> void: hovered.emit("button", false))
	header.add_child(back)

	var title := UiStyle.make_outlined_title("CHOOSE A CHAPTER", 34, UiStyle.cream())
	title.clip_text = false
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_total_label = UiStyle.make_display_label("", 13, UiStyle.text_color())
	_total_label.custom_minimum_size = Vector2(150, 24)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_total_label)
	# Keep clear of the floating sound control in the top-right corner.
	var sound_space := Control.new()
	sound_space.custom_minimum_size = Vector2(54, 0)
	sound_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(sound_space)

	var tabs_scroll := ScrollContainer.new()
	tabs_scroll.custom_minimum_size = Vector2(0, 84)
	tabs_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	tabs_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(tabs_scroll)

	_tabs_row = HBoxContainer.new()
	_tabs_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_tabs_row.add_theme_constant_override("separation", 8)
	_tabs_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs_scroll.add_child(_tabs_row)

	_banner = PanelContainer.new()
	_banner.custom_minimum_size = Vector2(0, 132)
	column.add_child(_banner)

	var levels_scroll := ScrollContainer.new()
	levels_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	levels_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	levels_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	levels_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	column.add_child(levels_scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	levels_scroll.add_child(center)

	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 6)
	center.add_child(_grid)

## Rebuild chapter tabs, banner and level grid from the current progress.
func refresh(p_progress = null, preferred_chapter_id: String = "") -> void:
	if p_progress != null:
		progress = p_progress
	if progress == null or _tabs_row == null or _grid == null or _banner == null:
		return

	if not preferred_chapter_id.is_empty() and progress.is_chapter_unlocked(preferred_chapter_id):
		_selected_chapter_id = preferred_chapter_id
	elif _selected_chapter_id.is_empty() or not progress.is_chapter_unlocked(_selected_chapter_id):
		_selected_chapter_id = _default_chapter_id()
	elif not _is_chapter_available(_selected_chapter_id):
		_selected_chapter_id = _default_chapter_id()

	_refresh_tabs()
	_refresh_banner()
	_refresh_grid()
	_refresh_total()

func _default_chapter_id() -> String:
	for chapter in LevelBankRes.CHAPTERS:
		var chapter_id := str(chapter.get("id", ""))
		if not progress.is_chapter_unlocked(chapter_id):
			continue
		var summary: Dictionary = progress.chapter_progress(chapter_id)
		if int(summary.get("core_done", 0)) < int(summary.get("core_total", 6)):
			return chapter_id
	for index in range(LevelBankRes.CHAPTERS.size() - 1, -1, -1):
		var chapter_id := str(LevelBankRes.CHAPTERS[index].get("id", ""))
		if progress.is_chapter_unlocked(chapter_id):
			return chapter_id
	return "ch1"

func _is_chapter_available(chapter_id: String) -> bool:
	return progress.is_chapter_unlocked(chapter_id)

func _refresh_tabs() -> void:
	_clear_children(_tabs_row)
	for index in range(LevelBankRes.CHAPTERS.size()):
		var chapter: Dictionary = LevelBankRes.CHAPTERS[index]
		var chapter_id := str(chapter.get("id", ""))
		var summary: Dictionary = progress.chapter_progress(chapter_id)
		var tab = ChapterTabRes.new()
		tab.setup(chapter, index, summary, chapter_id == _selected_chapter_id)
		tab.pressed.connect(_select_chapter)
		tab.hovered.connect(func(_id: String, active: bool) -> void: hovered.emit("button", active))
		_tabs_row.add_child(tab)

func _refresh_banner() -> void:
	_clear_children(_banner)
	var chapter := LevelBankRes.find_chapter(_selected_chapter_id)
	if chapter.is_empty():
		return
	var tint: Color = chapter.get("color", UiStyle.sky())
	_banner.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(tint.lightened(0.48), UiStyle.border_color(), 14)
	)

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", 14)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 14)
	content.add_theme_constant_override("margin_bottom", 8)
	_banner.add_child(content)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	content.add_child(box)

	var chapter_number := LevelBankRes.chapter_index(_selected_chapter_id) + 1
	var title := UiStyle.make_display_label(
		"CHAPTER %d · %s" % [chapter_number, str(chapter.get("title", "")).to_upper()],
		22,
		UiStyle.text_color()
	)
	box.add_child(title)
	var blurb := UiStyle.make_label_colored(str(chapter.get("blurb", "")), 12, UiStyle.muted_text())
	blurb.clip_text = false
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.custom_minimum_size = Vector2(0, 18)
	box.add_child(blurb)

	var new_rules := LevelBankRes.chapter_new_rules(_selected_chapter_id)
	var caption := UiStyle.make_display_label(
		"NEW RULES" if not new_rules.is_empty() else "ALL RULES UNLOCKED",
		10,
		UiStyle.muted_text()
	)
	box.add_child(caption)
	if new_rules.is_empty():
		box.add_child(
			UiStyle.make_label_colored("Mix everything you have learned.", 11, UiStyle.text_color())
		)
		return

	var flow := HFlowContainer.new()
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	box.add_child(flow)
	for rule_id in new_rules:
		flow.add_child(_make_rule_chip(rule_id, tint))

func _make_rule_chip(rule_id: String, tint: Color) -> Control:
	var chip := PanelContainer.new()
	chip.custom_minimum_size = Vector2(218, 40)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_stylebox_override(
		"panel",
		UiStyle.slot_style(UiStyle.cream(), UiStyle.border_color())
	)
	chip.tooltip_text = RuleMetaRes.tooltip(rule_id)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	chip.add_child(row)
	var icon = RuleIconRes.new()
	icon.setup(rule_id)
	icon.custom_minimum_size = Vector2(34, 34)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	var name_label := UiStyle.make_display_label(RuleMetaRes.title(rule_id), 11, UiStyle.text_color())
	name_label.clip_text = true
	text.add_child(name_label)
	var desc_label := UiStyle.make_label_colored(
		RuleMetaRes.description(rule_id),
		9,
		UiStyle.muted_text()
	)
	desc_label.clip_text = true
	text.add_child(desc_label)
	return chip

func _refresh_grid() -> void:
	_clear_children(_grid)
	var chapter := LevelBankRes.find_chapter(_selected_chapter_id)
	if chapter.is_empty():
		return
	var tint: Color = chapter.get("color", UiStyle.sky())
	var levels: Array = []
	for entry in LevelBankRes.all_levels():
		if str(entry.get("chapter_id", "")) == _selected_chapter_id:
			levels.append(entry)
	for level in levels:
		var level_id := str(level.get("id", ""))
		var optional := bool(level.get("optional", false))
		var lock: bool = not progress.is_level_unlocked(level_id)
		var done: bool = progress.is_completed(level_id)
		var card = LevelCardRes.new()
		card.setup(
			level_id,
			int(level.get("index_in_chapter", 0)) + 1,
			level,
			tint,
			lock,
			done,
			optional
		)
		card.pressed.connect(func(chosen: String) -> void: level_selected.emit(chosen))
		card.hovered.connect(func(_id: String, active: bool) -> void: hovered.emit("card", active))
		_grid.add_child(card)

func _refresh_total() -> void:
	if _total_label == null:
		return
	var done := 0
	var total := 0
	for chapter in LevelBankRes.CHAPTERS:
		for level in chapter.get("levels", []):
			if bool(level.get("optional", false)):
				continue
			total += 1
			if progress.is_completed(str(level.get("id", ""))):
				done += 1
	_total_label.text = "CORE %d / %d" % [done, total]

func _select_chapter(chapter_id: String) -> void:
	if chapter_id == _selected_chapter_id:
		return
	if progress == null or not progress.is_chapter_unlocked(chapter_id):
		return
	_selected_chapter_id = chapter_id
	refresh()
	hovered.emit("button", true)

func _clear_children(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
