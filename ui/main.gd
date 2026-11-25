extends Control

## Rough block-puzzle UI entry: palette + scrollable canvas + fixed goal bar.
## Owns the explicit refresh pass; no gameplay result signals are used.

const FormulaRes = preload("res://logic/formula.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const RulesRes = preload("res://logic/rules.gd")
const CanvasViewRes = preload("res://ui/canvas_view.gd")
const FormulaBlockRes = preload("res://ui/formula_block.gd")
const RuleBlockRes = preload("res://ui/rule_block.gd")
const AssumptionBlockRes = preload("res://ui/assumption_block.gd")
const ScopeWindowRes = preload("res://ui/scope_window.gd")
const ScopeMarkerRes = preload("res://ui/scope_marker_block.gd")
const ScopedRuleBlockRes = preload("res://ui/scoped_rule_block.gd")
const GoalBarRes = preload("res://ui/goal_bar.gd")
const TrashBinRes = preload("res://ui/trash_bin.gd")
const WindowDotsRes = preload("res://ui/window_dots.gd")
const PaletteItemRes = preload("res://ui/palette_item.gd")
const LevelBankRes = preload("res://ui/level_bank.gd")
const TitlePageRes = preload("res://ui/title_page.gd")
const LevelSelectPageRes = preload("res://ui/level_select_page.gd")
const FormulaBuilderRes = preload("res://ui/formula_builder.gd")
const ProofAdapterRes = preload("res://ui/proof_adapter.gd")
const UiStyle = preload("res://ui/ui_style.gd")
const SfxRes = preload("res://audio/sfx.gd")
const MusicRes = preload("res://audio/music.gd")
const SoundControlRes = preload("res://ui/sound_control.gd")
const ProgressStoreRes = preload("res://ui/progress_store.gd")
const UiSettingsStoreRes = preload("res://ui/ui_settings_store.gd")
const CardMetrics = preload("res://ui/card_metrics.gd")
const RuleIntroCardRes = preload("res://ui/rule_intro_card.gd")

## Empty inputs start welcoming a dragged block from this many screen pixels away.
const SOCKET_APPROACH_MARGIN := 36.0
## Drop targets are intentionally larger than their visible cards.
const TRASH_DROP_MARGIN := 32.0
const GOAL_DROP_MARGIN := 6.0

## Spring that pulls the released block into the socket (~9% overshoot).
const SETTLE_DURATION := 0.30
const SETTLE_ZETA := 0.58
const SETTLE_OMEGA := 40.0

## Floating UI must stay above every nested scope window. The drag layer,
## modal and toast sit above the UI layer and are excluded from that rule.
const Z_UI_OVERLAY := 1000
const Z_DRAG_LAYER := 2000
const Z_MODAL_LAYER := 3000
const Z_TOAST := 4000

## Keep the nested-window desktop legible and bounded.
const MAX_OPEN_SCOPES := 5
const MAX_MAXIMIZED_SCOPES := 3

var canvas = null
var goal_bar = null
var trash_bin = null
var _palette_list: VBoxContainer = null
var _premise_flow: HFlowContainer = null
var _palette_panel: Control = null
var _palette_column: VBoxContainer = null
var _palette_top_space: Control = null
var _palette_clearance_dirty := 0
var _game_title_label: Label = null
var _level_label: Label = null
var _level_row: HBoxContainer = null
var _rules_button: Button = null
var _next_button: Button = null
var _next_chapter_button: Button = null
var _undo_button: Button = null
var _undo_stack: Array = []
var _undo_restoring := false
const UNDO_LIMIT := 40
var _assume_button: Button = null
var _rules_row: HBoxContainer = null
var _goal_formula: FormulaRes = null
var _current_level: int = -1
var _current_level_id := ""
var _current_chapter_id := ""
var _current_level_pos := -1
var _progress = null
var progress_path := "user://progress.cfg"
var settings_path := "user://ui_settings.cfg"
var _ui_settings = null
var _rule_intro = null
var _scope_check_hint = null

var _game_page: Control = null
var _title_page = null
var _level_page = null

var _canvas_view = null
var _drag_layer: Control = null
var _modal_layer: Control = null
var _toast_panel: PanelContainer = null
var _toast_label: Label = null
var _toast_tween: Tween = null
var _formula_builder = null
var _formula_builder_target = null
var _formula_builder_action := ""
var _formula_builder_committed := false
var _formula_builder_scope_record = null
var _next_assumption_group := 1
var _scope_layer: Control = null
var _scope_open: Array = []
var _base_canvas = null
var _base_canvas_view = null
var _ui_overlay: Control = null
var _top_bar: Control = null
var _scope_hud: Control = null
var _scope_hud_bar: PanelContainer = null
var _scope_hud_label: Label = null
var _scope_hud_dots = null
var _next_scope_color: int = 0
var _dragged_block = null
var _drag_offset := Vector2.ZERO
var _drag_scale: float = 1.0
var _dragging := false
var _panning := false
var _pan_last := Vector2.ZERO
var _pan_button: int = 0
var _pan_view = null
var _origin_kind := ""
var _origin_socket = null
var _origin_canvas = null
var _origin_position := Vector2.ZERO
var _hover_socket = null
var _hover_goal := false
var _hover_trash := false
var _settling := false
var _settle_tween: Tween = null
var _settle_block = null
var _settle_socket = null
var _settle_drop := Vector2.ZERO
var _sfx = null
var _music = null
var _sound_control = null
## In-memory fallbacks keep the settings panel functional in headless tests
## and if the audio runtime is unavailable.
var _fallback_sfx_volume := 0.8
var _fallback_music_volume := 0.8
var _fallback_muted := false
var _refresh_depth := 0
var _pending_rule_feedback := 0
var _suppress_rule_feedback := false
var _goal_user_action := false

func _ready() -> void:
	_ui_settings = UiSettingsStoreRes.new(settings_path)
	_progress = ProgressStoreRes.new(progress_path)
	set_process_input(true)
	_setup_audio()
	_build_pages()
	_show_title()
	_setup_sound_control()

## Presentation-only card density. This never touches proof state or Undo.
func get_card_size_mode() -> String:
	if _ui_settings == null:
		return CardMetrics.DEFAULT
	return CardMetrics.normalize(str(_ui_settings.card_size_mode))

func set_card_size_mode(mode: String) -> void:
	if _ui_settings == null:
		return
	var normalized := CardMetrics.normalize(mode)
	if normalized == _ui_settings.card_size_mode:
		return
	_ui_settings.set_card_size_mode(normalized)
	get_tree().call_group("nd_formula_card", "apply_card_size_mode", normalized)
	get_tree().call_group("nd_rule_block", "apply_card_size_mode", normalized)

func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_sfx = SfxRes.new()
	add_child(_sfx)
	_sfx.setup(self)
	_music = MusicRes.new()
	add_child(_music)
	_music.setup(self)
	_music.set_muted(_sfx.muted)
	_music.set_volume(_sfx.music_volume)
	_fallback_sfx_volume = _sfx.volume
	_fallback_music_volume = _sfx.music_volume
	_fallback_muted = _sfx.muted

func _setup_sound_control() -> void:
	if _sfx == null:
		return
	_sound_control = SoundControlRes.new()
	add_child(_sound_control)
	_sound_control.setup(self)

func play_sfx(cue: String, options: Dictionary = {}) -> void:
	if _sfx != null:
		_sfx.play(cue, options)

func is_audio_muted() -> bool:
	if _sfx != null:
		return bool(_sfx.muted)
	return _fallback_muted

func get_audio_volume() -> float:
	return get_sfx_volume()

func get_sfx_volume() -> float:
	if _sfx != null:
		return float(_sfx.volume)
	return _fallback_sfx_volume

func get_music_volume() -> float:
	if _music != null:
		return float(_music.volume)
	if _sfx != null:
		return float(_sfx.music_volume)
	return _fallback_music_volume

func toggle_audio_muted() -> void:
	var muted_now := is_audio_muted()
	if _sfx != null:
		_sfx.set_muted(not muted_now)
	else:
		_fallback_muted = not muted_now
	if _music != null:
		_music.set_muted(not muted_now)
	if muted_now:
		play_sfx("audio_toggle")
	_refresh_sound_controls()

## Master volume: the speaker popover and M shortcut keep both buses together.
func set_audio_volume(value: float) -> void:
	var level := clampf(value, 0.0, 1.0)
	_fallback_sfx_volume = level
	_fallback_music_volume = level
	if _sfx != null:
		_sfx.set_volume(level)
		_sfx.set_music_volume(level)
	if _music != null:
		_music.set_volume(level)
	if _sfx != null and not _sfx.muted:
		play_sfx("audio_slider_tick")
	_refresh_sound_controls()

func set_sfx_volume(value: float) -> void:
	var level := clampf(value, 0.0, 1.0)
	_fallback_sfx_volume = level
	if _sfx != null:
		_sfx.set_volume(level)
	if _sfx != null and not _sfx.muted:
		play_sfx("audio_slider_tick")
	_refresh_sound_controls()

func set_music_volume(value: float) -> void:
	var level := clampf(value, 0.0, 1.0)
	_fallback_music_volume = level
	if _sfx != null:
		_sfx.set_music_volume(level)
	if _music != null:
		_music.set_volume(level)
	if _sfx != null and not _sfx.muted:
		play_sfx("audio_slider_tick")
	_refresh_sound_controls()

func _refresh_sound_controls() -> void:
	if _sound_control != null and _sound_control.has_method("refresh_state"):
		_sound_control.refresh_state()

func is_fullscreen() -> bool:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return false
	var mode := DisplayServer.window_get_mode()
	return (
		mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	)

func set_fullscreen(enabled: bool) -> void:
	if DisplayServer.get_name() == "headless" or OS.has_feature("web"):
		return
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN
		if enabled
		else DisplayServer.WINDOW_MODE_WINDOWED
	)

func toggle_fullscreen() -> void:
	set_fullscreen(not is_fullscreen())

## Build the three pages and start on the title screen.
func _build_pages() -> void:
	_game_page = Control.new()
	_game_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_game_page)
	_build_layout()
	_build_game_scaffold()

	_title_page = TitlePageRes.new()
	_title_page.setup(self)
	_title_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_title_page)
	_title_page.play_pressed.connect(_on_title_play)
	_title_page.levels_pressed.connect(_on_title_levels)
	_title_page.hovered.connect(func() -> void: play_sfx("button_hover"))
	_title_page.rule_swapped.connect(func(_rule_id: String) -> void: play_sfx("switch_click"))
	_title_page.visible = false

	_level_page = LevelSelectPageRes.new()
	_level_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_level_page.setup(_progress)
	add_child(_level_page)
	_level_page.level_selected.connect(_on_level_selected)
	_level_page.back_requested.connect(_on_level_back)
	_level_page.hovered.connect(_on_level_page_hovered)
	_level_page.visible = false

## Full-page canvas with floating UI: top bar, premises, rules shelf, trash.
func _build_layout() -> void:
	_canvas_view = CanvasViewRes.new()
	_canvas_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_game_page.add_child(_canvas_view)
	_canvas_view.setup(self)
	canvas = _canvas_view.world
	_base_canvas = canvas
	_base_canvas_view = _canvas_view

	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_to_group("nd_ui_overlay")
	overlay.z_index = Z_UI_OVERLAY
	_game_page.add_child(overlay)
	_ui_overlay = overlay

	var shell := MarginContainer.new()
	shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shell.add_theme_constant_override("margin_left", 16)
	shell.add_theme_constant_override("margin_top", 12)
	shell.add_theme_constant_override("margin_right", 16)
	shell.add_theme_constant_override("margin_bottom", 12)
	shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(shell)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(column)

	_top_bar = _build_top_bar()
	column.add_child(_top_bar)

	var middle := HBoxContainer.new()
	middle.add_theme_constant_override("separation", 10)
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(middle)
	_palette_column = VBoxContainer.new()
	_palette_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette_column.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_palette_column.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_palette_column.add_theme_constant_override("separation", 0)
	_palette_top_space = Control.new()
	_palette_top_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_palette_top_space.custom_minimum_size = Vector2.ZERO
	_palette_column.add_child(_palette_top_space)
	_palette_column.add_child(_build_palette())
	middle.add_child(_palette_column)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(spacer)

	var bottom_center := CenterContainer.new()
	bottom_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bottom_center)
	bottom_center.add_child(_build_rules_row())

	trash_bin = TrashBinRes.new()
	trash_bin.setup()
	trash_bin.add_to_group("nd_ui_overlay")
	trash_bin.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	trash_bin.offset_left = -116.0
	trash_bin.offset_top = -136.0
	trash_bin.offset_right = -24.0
	trash_bin.offset_bottom = -24.0
	# Keep the bin on the floating UI layer so a full-screen scope cannot
	# paint over it.
	overlay.add_child(trash_bin)

	_scope_layer = Control.new()
	_scope_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_layer.z_index = 80
	_game_page.add_child(_scope_layer)
	if _scope_layer.get_index() > _ui_overlay.get_index():
		_game_page.move_child(_scope_layer, _ui_overlay.get_index())
	_build_scope_hud()

	_drag_layer = Control.new()
	_drag_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_drag_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_layer.z_index = Z_DRAG_LAYER
	_game_page.add_child(_drag_layer)

	_modal_layer = Control.new()
	_modal_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_modal_layer.z_index = Z_MODAL_LAYER
	_game_page.add_child(_modal_layer)

	_toast_panel = PanelContainer.new()
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.z_index = Z_TOAST
	_toast_panel.visible = false
	_toast_panel.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(UiStyle.coral().lightened(0.62), UiStyle.error_color(), 14)
	)
	_toast_label = UiStyle.make_display_label(
		"Want to cheat huh, no way.",
		17,
		UiStyle.error_color()
	)
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Display labels normally clip with ellipsis, which hides the toast text
	# inside its minimum-width panel. Let the toast take its natural width.
	_toast_label.clip_text = false
	_toast_label.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_toast_panel.add_child(_toast_label)
	_game_page.add_child(_toast_panel)

## Open the modal formula builder for a rule card's "other side" socket.
func open_formula_builder(target_block) -> void:
	if _game_page == null or not _game_page.visible:
		return
	if _modal_layer == null or _formula_builder != null:
		return
	if target_block == null or not is_instance_valid(target_block):
		return
	if not target_block.has_method("set_extra_formula"):
		return
	_formula_builder_target = target_block
	_formula_builder_action = "extra"
	_open_formula_builder_modal()

func open_assumption_builder() -> void:
	if _game_page == null or not _game_page.visible:
		return
	if _modal_layer == null or _formula_builder != null:
		return
	_formula_builder_target = null
	_formula_builder_scope_record = null
	_formula_builder_action = "assumption"
	_open_formula_builder_modal()

## Edit the hypothesis behind a maximized Assume window and all of its copies.
func edit_scope_assumption(window) -> void:
	if window == null or not is_instance_valid(window):
		return
	var record = window.scope_record
	if record == null:
		return
	if _game_page == null or not _game_page.visible or _formula_builder != null:
		return
	_formula_builder_target = null
	_formula_builder_scope_record = record
	_formula_builder_action = "edit_assumption"
	_open_formula_builder_modal()

func _open_formula_builder_modal() -> void:
	_formula_builder_committed = false
	play_sfx("builder_open")
	_formula_builder = FormulaBuilderRes.new()
	_formula_builder.setup(_current_level_atoms())
	if _formula_builder_action == "edit_assumption" and _formula_builder_scope_record != null:
		var current_formula = _formula_builder_scope_record.get("formula")
		if current_formula != null:
			_formula_builder.set_initial_text(current_formula.to_display_string())
	_formula_builder.submitted.connect(_on_formula_builder_submitted)
	_formula_builder.cancelled.connect(func() -> void: _close_formula_builder(true))
	_formula_builder.button_clicked.connect(func() -> void: play_sfx("button_click"))
	_formula_builder.key_typed.connect(_on_builder_key_typed)
	_formula_builder.preview_changed.connect(
		func(valid: bool) -> void: play_sfx("preview_ok" if valid else "preview_bad")
	)
	_formula_builder.hovered.connect(func() -> void: play_sfx("button_hover"))
	_modal_layer.add_child(_formula_builder)
	_formula_builder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

## Physical keys in the builder: distinct pitches for typing, backspace, Enter.
func _on_builder_key_typed(kind: String) -> void:
	if kind == "back":
		_on_builder_key_back()
	elif kind == "enter":
		play_sfx("typing_key", {"pitch": 0.78, "volume_db": 1.0})
	else:
		play_sfx("typing_key")

func _on_builder_key_back() -> void:
	play_sfx("typing_key", {"pitch": 0.86, "volume_db": -1.0})

func _on_formula_builder_submitted(formula) -> void:
	var target = _formula_builder_target
	var action := _formula_builder_action
	var edit_record = _formula_builder_scope_record
	_formula_builder_committed = true
	if action != "assumption":
		play_sfx("confirm_two")
	_close_formula_builder()
	if action == "assumption":
		_create_assumption_on_canvas(formula)
		return
	if action == "edit_assumption":
		if edit_record != null:
			_apply_assumption_edit(edit_record, formula)
		return
	if target != null and is_instance_valid(target):
		_push_undo_snapshot()
		target.set_extra_formula(formula)

func _apply_assumption_edit(record: Dictionary, new_formula) -> void:
	if record == null or new_formula == null:
		return
	var old_formula = record.get("formula")
	if old_formula != null and old_formula.equals(new_formula):
		return
	_undo_stack.append({
		"kind": "assumption_edit",
		"record": record,
		"old_formula": old_formula,
		"new_formula": new_formula,
	})
	while _undo_stack.size() > UNDO_LIMIT:
		var old = _undo_stack.pop_front()
		_free_snapshot(old)
	_update_undo_button()
	_apply_assumption_formula(record, new_formula)

func _apply_assumption_formula(record: Dictionary, new_formula) -> void:
	if record == null or new_formula == null:
		return
	var group := int(record.get("group", -1))
	record["formula"] = new_formula
	var window = record.get("window")
	if window != null and is_instance_valid(window) and window.has_method("set_assumption_formula"):
		window.set_assumption_formula(new_formula)
	var premise_item = record.get("premise_item")
	if premise_item != null and is_instance_valid(premise_item) and premise_item.has_method("set_assumption_formula"):
		premise_item.set_assumption_formula(new_formula)
	for node in get_tree().get_nodes_in_group("nd_formula_card"):
		if node == null or not is_instance_valid(node):
			continue
		if node.has_method("is_assumption_block") and node.is_assumption_block():
			if int(node.get_assumption_group()) == group and node.has_method("set_formula_value"):
				node.set_formula_value(new_formula)
		elif node.has_method("is_scope_block") and node.is_scope_block():
			if int(node.get_assumption_group()) == group and node.has_method("set_assumption_formula"):
				node.set_assumption_formula(new_formula)
	for other_record in _scope_open:
		if int(other_record.get("group", -1)) != group:
			continue
		other_record["formula"] = new_formula
		var other_window = other_record.get("window")
		if other_window != null and is_instance_valid(other_window) and other_window.has_method("set_assumption_formula"):
			other_window.set_assumption_formula(new_formula)
		var other_item = other_record.get("premise_item")
		if other_item != null and is_instance_valid(other_item) and other_item.has_method("set_assumption_formula"):
			other_item.set_assumption_formula(new_formula)
	_refresh_all_canvases()
	refresh_machine()
	_queue_palette_clearance()

func _close_formula_builder(play_cancel: bool = false) -> void:
	if play_cancel and _formula_builder != null:
		play_sfx("cancel_down")
	if _formula_builder != null and is_instance_valid(_formula_builder):
		_formula_builder.queue_free()
	_formula_builder = null
	_formula_builder_target = null
	_formula_builder_scope_record = null
	_formula_builder_action = ""

## Atoms used by the current level, offered as builder tiles.
func _current_level_atoms() -> Array[String]:
	var seen := {}
	var atoms: Array[String] = []
	var data := LevelBankRes.find_level(_current_level_id)
	if data.is_empty():
		var levels := LevelBankRes.all_levels()
		if _current_level >= 0 and _current_level < levels.size():
			data = levels[_current_level]
	if not data.is_empty():
		for text in data.get("premises", []):
			var parsed := ParserRes.new(str(text)).parse()
			if parsed.ok:
				_collect_atoms(parsed.formula, seen, atoms)
		var goal_parsed := ParserRes.new(str(data.get("goal", ""))).parse()
		if goal_parsed.ok:
			_collect_atoms(goal_parsed.formula, seen, atoms)
	if atoms.is_empty():
		atoms.append("A")
		atoms.append("B")
	return atoms

func _collect_atoms(formula, seen: Dictionary, atoms: Array[String]) -> void:
	if formula == null:
		return
	if formula.kind == FormulaRes.Kind.ATOM:
		if not seen.has(formula.atom_name):
			seen[formula.atom_name] = true
			atoms.append(formula.atom_name)
		return
	_collect_atoms(formula.left, seen, atoms)
	if formula.right != null:
		_collect_atoms(formula.right, seen, atoms)

## True when the pointer is hovering any floating UI panel, not the canvas.
func _over_ui() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if not _scope_open.is_empty():
		var active = _scope_open[-1]
		var active_view = active.get("inner_view")
		if active_view != null and (
			hovered == active_view or _node_is_under(active_view, hovered)
		):
			return false
	var node: Node = hovered
	while node != null:
		if node.is_in_group("nd_ui_overlay"):
			return true
		node = node.get_parent()
	return false

## Bottom shelf of draggable rule cards. It is populated per level from the
## current chapter's unlocked palette.
func _build_rules_row() -> Control:
	var shelf := PanelContainer.new()
	shelf.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(UiStyle.cream(), UiStyle.border_color(), 14)
	)
	_rules_row = HBoxContainer.new()
	_rules_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_rules_row.add_theme_constant_override("separation", 8)
	_rules_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shelf.add_child(_rules_row)
	return shelf

## Replace the rule shelf contents for the current chapter.
func _populate_rules_row(rule_ids: Array[String]) -> void:
	if _rules_row == null:
		return
	for child in _rules_row.get_children():
		_rules_row.remove_child(child)
		child.free()
	for index in range(rule_ids.size()):
		var item := PaletteItemRes.new()
		item.controller = self
		item.setup_rule(rule_ids[index], index + 1)
		_rules_row.add_child(item)

## The compact goal chip checks the last free rule block when clicked.
func _on_check_requested() -> void:
	if goal_bar == null:
		return
	if not _scope_open.is_empty():
		_show_scope_check_hint()
		return
	play_sfx("ui_click")
	if goal_bar.linked_block != null and is_instance_valid(goal_bar.linked_block):
		goal_bar.refresh()
		_play_goal_outcome()
		return
	if canvas == null:
		return
	var roots: Array = canvas.get_root_blocks()
	for index in range(roots.size() - 1, -1, -1):
		var block = roots[index]
		if block.has_method("get_rule_id") and block.get_result_formula() != null:
			if _reject_dependent_drop(block, _base_canvas):
				return
			_push_undo_snapshot()
			goal_bar.set_linked_block(block, true)
			_play_goal_outcome()
			return
	goal_bar.refresh()
	play_sfx("goal_check_empty")

func _play_goal_outcome() -> void:
	if goal_bar == null or goal_bar.is_solved():
		return
	var status: String = goal_bar.get_status_text()
	if status == "MISMATCH" or status == "INVALID":
		play_sfx("goal_invalid")

func _on_goal_solved_changed(solved: bool) -> void:
	var level := LevelBankRes.find_level(_current_level_id)
	if solved:
		_pending_rule_feedback = 0
		if not _undo_restoring:
			play_sfx("goal_valid")
		if _progress != null and not _current_level_id.is_empty():
			_progress.mark_completed(_current_level_id)
			_progress.set_last_level(_current_level_id)
		if _level_page != null and _level_page.visible and _level_page.has_method("refresh"):
			_level_page.refresh(_progress, _current_chapter_id)
	if _next_button == null or level.is_empty():
		return
	_next_button.disabled = not solved
	if _is_last_core_level(level) and not _next_chapter_target(level).is_empty():
		_next_chapter_button.visible = solved or (
			_progress != null and _progress.is_completed(str(level.get("id", "")))
		)
	_next_chapter_button.disabled = not solved
	var target := _next_level_target(level)
	var optional := bool(level.get("optional", false))
	if solved:
		if str(target.get("id", "")).is_empty():
			_next_button.tooltip_text = "Return to the chapter level list."
		elif optional:
			_next_button.tooltip_text = "Go to the next optional level."
		else:
			_next_button.tooltip_text = "Go to the next level."
		if _next_chapter_button.visible:
			_next_chapter_button.tooltip_text = "Open the first level of the next chapter."
	else:
		if str(target.get("id", "")).is_empty():
			_next_button.tooltip_text = "Solve the goal to return to the level list."
		else:
			_next_button.tooltip_text = "Solve the goal to unlock the next level."
		if _next_chapter_button.visible:
			_next_chapter_button.tooltip_text = "Solve the goal to open the next chapter."

func _on_next_level() -> void:
	if _next_button == null or _next_button.disabled or _current_level_id.is_empty():
		return
	var level := LevelBankRes.find_level(_current_level_id)
	if level.is_empty():
		return
	var target := _next_level_target(level)
	if not str(target.get("id", "")).is_empty():
		if _progress == null or _progress.is_level_unlocked(str(target.get("id", ""))):
			play_sfx("page_whoosh")
			open_level_by_id(str(target.get("id", "")))
			return
		play_sfx("page_whoosh")
		_show_levels()
		return
	play_sfx("level_complete")
	_show_levels()

func _bind_hover(button: Button) -> void:
	button.mouse_entered.connect(func() -> void: play_sfx("button_hover"))

## Add the generic UI-button click under any action-specific feedback.
func _bind_press(button: Button) -> void:
	button.pressed.connect(func() -> void: play_sfx("button_click"))

## Corner title on the left, goal/actions on the right. No full-width banner,
## so the canvas stays visible across the top of the screen.
func _build_top_bar() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)

	var title := UiStyle.make_display_label("Natural Deduction", 26, UiStyle.cream())
	title.add_theme_color_override("font_outline_color", UiStyle.border_color())
	title.add_theme_constant_override("outline_size", 5)
	title.clip_text = false
	left.add_child(title)
	_game_title_label = title

	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 6)
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(level_row)
	_level_row = level_row
	_level_label = UiStyle.make_display_label("", 13, UiStyle.text_color())
	_level_label.custom_minimum_size = Vector2(270, 17)
	level_row.add_child(_level_label)
	_rules_button = Button.new()
	_rules_button.text = "?"
	_rules_button.custom_minimum_size = Vector2(24, 22)
	_rules_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(_rules_button, UiStyle.lavender(), 11)
	_rules_button.tooltip_text = "Show this chapter's rules."
	_rules_button.pressed.connect(_on_rules_pressed)
	_bind_hover(_rules_button)
	_bind_press(_rules_button)
	level_row.add_child(_rules_button)

	var right := HBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(right)

	goal_bar = GoalBarRes.new()
	goal_bar.setup(null, self)
	goal_bar.check_requested.connect(_on_check_requested)
	goal_bar.solved_changed.connect(_on_goal_solved_changed)
	right.add_child(goal_bar)

	_next_button = Button.new()
	_next_button.text = "NEXT"
	_next_button.custom_minimum_size = Vector2(104, 36)
	_next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(_next_button, UiStyle.valid_color(), 15)
	_next_button.disabled = true
	_next_button.add_theme_color_override("font_disabled_color", UiStyle.muted_text())
	var disabled_box := UiStyle.panel_style(
		UiStyle.cream().darkened(0.04),
		UiStyle.muted_text(),
		12,
		3,
		false
	)
	_next_button.add_theme_stylebox_override("disabled", disabled_box)
	_next_button.tooltip_text = "Solve the goal to unlock the next level."
	_next_button.pressed.connect(_on_next_level)
	_bind_hover(_next_button)
	_bind_press(_next_button)
	right.add_child(_next_button)

	_next_chapter_button = Button.new()
	_next_chapter_button.text = "NEXT CHAPTER"
	_next_chapter_button.custom_minimum_size = Vector2(132, 36)
	_next_chapter_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(_next_chapter_button, UiStyle.accent(), 15)
	_next_chapter_button.disabled = true
	_next_chapter_button.visible = false
	_next_chapter_button.add_theme_color_override("font_disabled_color", UiStyle.muted_text())
	_next_chapter_button.add_theme_stylebox_override(
		"disabled",
		UiStyle.panel_style(
			UiStyle.cream().darkened(0.04),
			UiStyle.muted_text(),
			12,
			3,
			false
		)
	)
	_next_chapter_button.tooltip_text = "Solve the goal to open the next chapter."
	_next_chapter_button.pressed.connect(_on_next_chapter)
	_bind_hover(_next_chapter_button)
	_bind_press(_next_chapter_button)
	right.add_child(_next_chapter_button)

	var levels := Button.new()
	levels.text = "LEVELS"
	levels.custom_minimum_size = Vector2(100, 36)
	levels.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(levels, UiStyle.lavender(), 15)
	levels.pressed.connect(_on_game_levels)
	_bind_hover(levels)
	_bind_press(levels)
	right.add_child(levels)

	_undo_button = Button.new()
	_undo_button.text = "UNDO"
	_undo_button.custom_minimum_size = Vector2(84, 36)
	_undo_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(_undo_button, UiStyle.accent(), 15)
	_undo_button.tooltip_text = "Undo the last board change (Ctrl+Z)."
	_undo_button.disabled = true
	_undo_button.add_theme_color_override("font_disabled_color", UiStyle.muted_text())
	_undo_button.add_theme_stylebox_override(
		"disabled",
		UiStyle.panel_style(
			UiStyle.cream().darkened(0.04),
			UiStyle.muted_text(),
			12,
			3,
			false
		)
	)
	_undo_button.pressed.connect(_on_undo)
	_bind_hover(_undo_button)
	_bind_press(_undo_button)
	right.add_child(_undo_button)

	var reset := Button.new()
	reset.text = "RESET"
	reset.custom_minimum_size = Vector2(100, 36)
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(reset, UiStyle.coral(), 15)
	reset.pressed.connect(_on_reset)
	_bind_hover(reset)
	_bind_press(reset)
	right.add_child(reset)
	var sound_space := Control.new()
	sound_space.custom_minimum_size = Vector2(44, 0)
	sound_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(sound_space)

	return row

## Left palette with the level premises and the ASSUME control.
func _build_palette() -> Control:
	var panel := PanelContainer.new()
	_palette_panel = panel
	panel.custom_minimum_size = Vector2(300, 250)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(UiStyle.cream(), UiStyle.border_color(), 14)
	)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(UiStyle.make_display_label("PREMISES", 18, UiStyle.text_color()))

	_assume_button = Button.new()
	_assume_button.text = "ASSUME"
	_assume_button.custom_minimum_size = Vector2(120, 34)
	UiStyle.style_button(_assume_button, UiStyle.lavender(), 13)
	_assume_button.tooltip_text = "Create a free assumption and drag it into a proof branch."
	_assume_button.pressed.connect(open_assumption_builder)
	_assume_button.visible = false
	_bind_hover(_assume_button)
	_bind_press(_assume_button)
	box.add_child(_assume_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	box.add_child(scroll)

	_palette_list = VBoxContainer.new()
	_palette_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_palette_list)
	return panel

## Build the parts of the palette that do not change between levels.
func _build_game_scaffold() -> void:
	if _palette_list == null:
		return
	_premise_flow = HFlowContainer.new()
	_premise_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	_premise_flow.add_theme_constant_override("h_separation", 6)
	_premise_flow.add_theme_constant_override("v_separation", 6)
	_premise_flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_palette_list.add_child(_premise_flow)

## Compatibility entry used by older tests and callers: flat curriculum index.
func open_level(index: int) -> void:
	var levels := LevelBankRes.all_levels()
	if index < 0 or index >= levels.size():
		return
	open_level_by_id(str(levels[index].get("id", "")))

## Load one puzzle by stable level id and show it.
func open_level_by_id(level_id: String) -> void:
	var level := LevelBankRes.find_level(level_id)
	if level.is_empty():
		return
	_close_scope_check_hint()
	_clear_undo_history()
	var chapter_id := str(level.get("chapter_id", ""))
	var chapter := LevelBankRes.find_chapter(chapter_id)
	if chapter.is_empty():
		return

	_cancel_settle()
	_close_formula_builder()
	_close_rule_intro()
	_close_all_scope_windows()
	_current_level_id = level_id
	_current_chapter_id = chapter_id
	_current_level_pos = int(level.get("index_in_chapter", 0))
	_current_level = _flat_index_of_level(level_id)
	if _progress != null:
		_progress.set_last_level(level_id)

	if canvas != null:
		canvas.clear_all()
	if _premise_flow != null:
		for child in _premise_flow.get_children():
			_premise_flow.remove_child(child)
			child.queue_free()
		for formula_text in level.get("premises", []):
			var parsed := ParserRes.new(str(formula_text)).parse()
			if not parsed.ok:
				var error_label := UiStyle.make_label("Bad premise: " + parsed.error, 12)
				error_label.add_theme_color_override("font_color", UiStyle.error_color())
				_premise_flow.add_child(error_label)
				continue
			var item := PaletteItemRes.new()
			item.controller = self
			item.setup_premise(parsed.formula)
			_premise_flow.add_child(item)

	_populate_rules_row(LevelBankRes.chapter_rules(chapter_id))
	if _assume_button != null:
		_assume_button.visible = LevelBankRes.allow_assumptions(chapter_id)

	var goal_text := str(level.get("goal", ""))
	var goal_parsed := ParserRes.new(goal_text).parse()
	if goal_parsed.ok:
		_goal_formula = goal_parsed.formula
	else:
		_goal_formula = FormulaRes.new(FormulaRes.Kind.ATOM, "?")
	if goal_bar != null:
		goal_bar.setup(_goal_formula, self)

	_update_level_header(level, chapter)
	_update_next_button(level)
	if _canvas_view != null:
		_canvas_view.reset_view()
	_show_game()
	_maybe_show_chapter_intro(chapter)
	refresh_machine()

## Flat index for the legacy open_level(index) entry.
func _flat_index_of_level(level_id: String) -> int:
	var levels := LevelBankRes.all_levels()
	for index in range(levels.size()):
		if str(levels[index].get("id", "")) == level_id:
			return index
	return -1

func _update_level_header(level: Dictionary, chapter: Dictionary) -> void:
	if _level_label == null:
		return
	var chapter_number := LevelBankRes.chapter_index(str(chapter.get("id", ""))) + 1
	var chapter_levels := LevelBankRes.chapter_levels(str(chapter.get("id", "")), false)
	var position_text := "%d" % (_current_level_pos + 1)
	if not bool(level.get("optional", false)):
		position_text = "%d/%d" % [_current_level_pos + 1, chapter_levels.size()]
	_level_label.text = "CH %d · %s — %s" % [
		chapter_number,
		position_text,
		str(level.get("title", "")).to_upper(),
	]

func _update_next_button(level: Dictionary) -> void:
	if _next_button == null:
		return
	_next_button.disabled = true
	_next_chapter_button.disabled = true
	var can_show_chapter := _is_last_core_level(level)
	if can_show_chapter:
		can_show_chapter = not _next_chapter_target(level).is_empty()
	if can_show_chapter and _progress != null:
		can_show_chapter = _progress.is_completed(str(level.get("id", "")))
	_next_chapter_button.visible = can_show_chapter
	var target := _next_level_target(level)
	if bool(level.get("optional", false)):
		_next_button.disabled = true
		if str(target.get("id", "")).is_empty():
			_next_button.text = "CHAPTERS"
			_next_button.tooltip_text = "Return to the chapter level list."
		else:
			_next_button.text = "NEXT"
			_next_button.tooltip_text = "Go to the next optional level."
		_next_chapter_button.visible = false
	else:
		_next_button.disabled = true
		if str(target.get("id", "")).is_empty():
			_next_button.text = "CHAPTERS"
			_next_button.tooltip_text = "Return to the chapter level list."
		else:
			_next_button.text = "NEXT"
			_next_button.tooltip_text = "Go to the next level."
	if _next_chapter_button.visible:
		_next_chapter_button.tooltip_text = "Solve the goal to open the next chapter."

## The ordinary NEXT chain walks all levels inside the chapter. At the last
## core level it continues with the optional levels 7/8/9; crossing chapters
## is handled by the separate NEXT CHAPTER button.
func _next_level_target(level: Dictionary) -> Dictionary:
	var chapter_id := str(level.get("chapter_id", ""))
	var all_levels := LevelBankRes.all_levels()
	var chapter_levels: Array = []
	for entry in all_levels:
		if str(entry.get("chapter_id", "")) == chapter_id:
			chapter_levels.append(entry)
	var position := -1
	for index in range(chapter_levels.size()):
		if str(chapter_levels[index].get("id", "")) == str(level.get("id", "")):
			position = index
			break
	if position >= 0 and position + 1 < chapter_levels.size():
		return {"id": str(chapter_levels[position + 1].get("id", "")), "final": false}
	return {"id": "", "final": false}

func _next_chapter_target(level: Dictionary) -> Dictionary:
	var chapter_id := str(level.get("chapter_id", ""))
	var chapter_index := LevelBankRes.chapter_index(chapter_id)
	if chapter_index < 0 or chapter_index + 1 >= LevelBankRes.CHAPTERS.size():
		return {}
	var next_chapter: Dictionary = LevelBankRes.CHAPTERS[chapter_index + 1]
	var next_levels := LevelBankRes.chapter_levels(str(next_chapter.get("id", "")), false)
	if next_levels.is_empty():
		return {}
	return {"id": str(next_levels[0].get("id", "")), "final": false}

func _is_last_core_level(level: Dictionary) -> bool:
	if bool(level.get("optional", false)):
		return false
	var chapter_id := str(level.get("chapter_id", ""))
	var core_levels := LevelBankRes.chapter_levels(chapter_id, false)
	if core_levels.is_empty():
		return false
	return str(core_levels[core_levels.size() - 1].get("id", "")) == str(level.get("id", ""))

func _on_next_chapter() -> void:
	play_sfx("button_click")
	if _current_level_id.is_empty():
		return
	var level := LevelBankRes.find_level(_current_level_id)
	var target := _next_chapter_target(level)
	if str(target.get("id", "")).is_empty():
		play_sfx("page_whoosh")
		_show_levels()
		return
	if _progress == null or _progress.is_level_unlocked(str(target.get("id", ""))):
		play_sfx("page_whoosh")
		open_level_by_id(str(target.get("id", "")))
	else:
		play_sfx("page_whoosh")
		_show_levels()

func _show_title() -> void:
	_cancel_settle()
	_close_formula_builder()
	_close_rule_intro()
	_close_all_scope_windows()
	_game_page.visible = false
	_level_page.visible = false
	_title_page.visible = true
	if _title_page.has_method("play_intro"):
		_title_page.play_intro()

func _show_levels() -> void:
	_cancel_settle()
	_close_formula_builder()
	_close_rule_intro()
	_close_all_scope_windows()
	_game_page.visible = false
	_title_page.visible = false
	_level_page.visible = true
	if _level_page.has_method("refresh"):
		_level_page.refresh(_progress, _current_chapter_id)

func _show_game() -> void:
	_title_page.visible = false
	_level_page.visible = false
	_game_page.visible = true

func _on_title_play() -> void:
	play_sfx("button_click")
	play_sfx("start_confirm")
	var next: Dictionary = {}
	if _progress != null:
		next = _progress.next_playable_level()
	if next.is_empty():
		_show_levels()
		return
	open_level_by_id(str(next.get("id", "")))

func _on_title_levels() -> void:
	play_sfx("button_click")
	play_sfx("page_whoosh")
	_show_levels()

func _on_level_page_hovered(kind: String, active: bool) -> void:
	if active:
		play_sfx("card_hover" if kind == "card" else "button_hover")

func _on_level_selected(level_id: String) -> void:
	play_sfx("level_select")
	open_level_by_id(level_id)

func _on_level_back() -> void:
	play_sfx("button_click")
	play_sfx("page_back")
	_show_title()

func _on_game_levels() -> void:
	play_sfx("page_whoosh")
	_show_levels()

func _on_rules_pressed() -> void:
	if not _current_chapter_id.is_empty():
		_show_rule_intro(_current_chapter_id, true)

func _maybe_show_chapter_intro(chapter: Dictionary) -> void:
	if DisplayServer.get_name() == "headless" or _progress == null:
		return
	var chapter_id := str(chapter.get("id", ""))
	if chapter_id.is_empty() or _progress.has_seen_intro(chapter_id):
		return
	_show_rule_intro(chapter_id)

func _show_rule_intro(chapter_id: String, force: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _modal_layer == null or _rule_intro != null:
		return
	var chapter := LevelBankRes.find_chapter(chapter_id)
	if chapter.is_empty():
		return
	if not force and _progress != null and _progress.has_seen_intro(chapter_id):
		return
	play_sfx("scope_open")
	_rule_intro = RuleIntroCardRes.new()
	_rule_intro.setup(self, chapter)
	_rule_intro.closed.connect(_close_rule_intro)
	_modal_layer.add_child(_rule_intro)
	_rule_intro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _progress != null:
		_progress.mark_intro_seen(chapter_id)

func _close_rule_intro() -> void:
	if _rule_intro != null and is_instance_valid(_rule_intro):
		_rule_intro.queue_free()
	_rule_intro = null

## Explain the chapter-2 "minimize before checking" rule when Enter / GOAL is
## pressed while an Assume window still owns the active canvas.
func _show_scope_check_hint() -> void:
	if _scope_check_hint != null and is_instance_valid(_scope_check_hint):
		_scope_check_hint.visible = true
		if _modal_layer != null:
			_modal_layer.move_child(
				_scope_check_hint, _modal_layer.get_child_count() - 1
			)
		return
	if _modal_layer == null:
		return
	play_sfx("soft_reject")

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.04, 0.1, 0.38)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(
		func(event: InputEvent) -> void:
			if (
				event is InputEventMouseButton
				and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed
			):
				_close_scope_check_hint()
	)
	root.add_child(shade)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(UiStyle.cream(), UiStyle.border_color(), 16)
	)
	center.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)

	var title := UiStyle.make_display_label(
		"FINISH THE ASSUMPTION", 22, UiStyle.text_color()
	)
	title.clip_text = false
	title.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var body := UiStyle.make_hint(
		"The GOAL belongs to the outer level. Minimize this Assume window "
		+ "with the yellow dot first, then check again.",
		17
	)
	body.custom_minimum_size = Vector2(510, 0)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(body)

	var button := Button.new()
	button.text = "GOT IT"
	button.custom_minimum_size = Vector2(140, 40)
	UiStyle.style_button(button, UiStyle.accent(), 15)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(
		func() -> void:
			play_sfx("button_click")
			_close_scope_check_hint()
	)
	_bind_hover(button)
	_bind_press(button)
	box.add_child(button)

	_modal_layer.add_child(root)
	_scope_check_hint = root

func _close_scope_check_hint() -> void:
	if _scope_check_hint != null and is_instance_valid(_scope_check_hint):
		_scope_check_hint.queue_free()
	_scope_check_hint = null

## Full explicit refresh after any structural or text change.
func refresh_machine() -> void:
	_refresh_depth += 1
	if canvas != null:
		canvas.refresh_all()
	if goal_bar != null:
		goal_bar.refresh()
	_refresh_depth -= 1
	if _refresh_depth == 0:
		_flush_rule_feedback()

func _on_rule_state_changed(_previous: int, current: int) -> void:
	if _suppress_rule_feedback:
		return
	if current == 3:  # VALID
		_pending_rule_feedback = 1
	elif current == 2 and _pending_rule_feedback != 1:  # ERROR
		_pending_rule_feedback = 2
	if _refresh_depth == 0:
		_flush_rule_feedback()

func _flush_rule_feedback() -> void:
	if _pending_rule_feedback == 0:
		return
	var feedback := _pending_rule_feedback
	_pending_rule_feedback = 0
	if feedback == 1:
		play_sfx("rule_valid")
	elif feedback == 2:
		play_sfx("rule_error")

## Factory used by sockets and the canvas for palette spawns.
func create_formula_block(formula: FormulaRes) -> Control:
	if formula == null:
		return null
	var block := FormulaBlockRes.new()
	block.controller = self
	block.setup(formula)
	return block

## Create a free assumption leaf. Copies can share the same assumption group.
func create_assumption_block(formula: FormulaRes, group: int = 0) -> Control:
	if formula == null:
		return null
	var chosen_group := group
	if chosen_group <= 0:
		chosen_group = _next_assumption_group
		_next_assumption_group += 1
	var block := AssumptionBlockRes.new()
	block.controller = self
	block.setup_assumption(formula, chosen_group)
	return block

func _create_assumption_on_canvas(formula: FormulaRes) -> void:
	open_scope_for_formula(formula)

## Open a floating assumption window with its own infinite canvas.
func open_scope_for_formula(formula: FormulaRes) -> void:
	if formula == null or _scope_layer == null or canvas == null:
		return
	if _scope_open.size() >= MAX_OPEN_SCOPES:
		play_sfx("soft_reject")
		show_toast("Too many open assumption windows, no way.")
		return
	var parent_record = _active_scope_record()
	var group := _next_assumption_group
	_next_assumption_group += 1
	var parent_tint = null
	if not _scope_open.is_empty():
		parent_tint = _scope_open[-1].get("color")
	var tint := _pick_scope_color(parent_tint)
	var window = ScopeWindowRes.new()
	window.setup_window(self, formula, group, tint)
	var parent_desktop = null
	if parent_record != null:
		parent_desktop = parent_record["window"].desktop_layer
	var nested := parent_desktop != null
	var record := {
		"window": window,
		"inner_view": window.inner_view,
		"inner_canvas": window.inner_canvas,
		"formula": formula,
		"group": group,
		"color": tint,
		"parent_canvas": canvas,
		"parent_view": _canvas_view,
		"parent_record": parent_record,
		"nested": nested,
		"base_anchor": null,
		"fullscreen": false,
		"maximized": false,
		"marker": null,
		"opened": false,
		"premise_item": null,
	}
	window.scope_record = record
	record["premise_item"] = _add_scope_assumption_item(record)
	if nested:
		var bounds: Vector2 = parent_desktop.size
		if bounds.x <= 0.0 or bounds.y <= 0.0:
			bounds = parent_record["inner_view"].size
		if bounds.x <= 0.0 or bounds.y <= 0.0:
			bounds = Vector2(640, 380)
		var contained_offset: float = _scope_open.size() * 14.0
		window.contained_offset_y = contained_offset
		window.configure_contained(bounds)
		parent_desktop.add_child(window)
		window.position = (
			(bounds - window.size) * 0.5 + Vector2(0, contained_offset)
		)
		window.relayout_inside_parent()
		window.call_deferred(
			"apply_contained_placement", bounds, contained_offset
		)
	else:
		_scope_layer.add_child(window)
		var base_zoom: float = _base_canvas_view.zoom if _base_canvas_view != null else 1.0
		var center: Vector2 = _game_page.size * 0.5 + Vector2(0, -20 + _scope_open.size() * 24)
		window.scale = Vector2(base_zoom, base_zoom)
		window.global_position = (
			_scope_layer.global_position + center - window.size * base_zoom * 0.5
		)
		_scope_layer.move_child(window, _scope_layer.get_child_count() - 1)
	_scope_open.append(record)
	if not nested:
		_store_scope_base_anchor(record)
	play_sfx("scope_open", {"pitch": 1.0 + _scope_open.size() * 0.04})
	_activate_scope(record)
	_update_scope_hud(record)
	_push_undo_scope_open(record)
	_queue_palette_clearance()

func _push_undo_scope_open(record: Dictionary) -> void:
	if _undo_restoring:
		return
	_undo_stack.append({"kind": "scope_open", "record": record})
	while _undo_stack.size() > UNDO_LIMIT:
		var old = _undo_stack.pop_front()
		_free_snapshot(old)
	_update_undo_button()

func _maximized_scope_count(exclude = null) -> int:
	var count := 0
	for record in _scope_open:
		if record == exclude:
			continue
		if (
			bool(record.get("fullscreen", false))
			or bool(record.get("maximized", false))
		):
			count += 1
	return count

## Keep the Premises panel below the stacked title bars of maximized scope
## windows. Each level's title bar sits at the top of its parent's desktop, so
## the panel follows the lowest visible title bar instead of covering the
## window dots.
func _update_palette_clearance() -> void:
	if _palette_top_space == null or _palette_column == null or _palette_panel == null:
		return
	var title_bottom := 0.0
	for record in _scope_open:
		# Only the contiguous maximized chain from the root reaches the
		# top-left. A normal parent stops the chain; deeper windows are inside
		# that normal window and must not push Premises farther down.
		if not (
			bool(record.get("fullscreen", false))
			or bool(record.get("maximized", false))
		):
			break
		var window = record.get("window")
		if window == null or not is_instance_valid(window):
			break
		if not window.has_method("get_title_bar"):
			break
		var bar = window.get_title_bar()
		if bar == null or not is_instance_valid(bar):
			break
		title_bottom = maxf(title_bottom, bar.get_global_rect().end.y)
	var base_top: float = _palette_column.global_position.y
	var shift := 0.0
	if title_bottom > 0.0:
		shift = maxf(0.0, title_bottom + 8.0 - base_top)
	var parent = _palette_column.get_parent()
	if parent is Control:
		shift = minf(
			shift,
			maxf(0.0, (parent as Control).size.y - _palette_panel.size.y)
		)
	_palette_top_space.custom_minimum_size = Vector2(0, shift)

func _queue_palette_clearance() -> void:
	_palette_clearance_dirty = 3

## Keep top-level scope windows attached to the base canvas transform. The
## anchor is stored in base-world coordinates, so panning/zooming the
## background carries the windows with it.
func _scope_base_anchor(window) -> Vector2:
	if _base_canvas_view == null or window == null:
		return Vector2.ZERO
	return (
		window.global_position
		- _base_canvas_view.global_position
		- _base_canvas_view.pan
	) / _base_canvas_view.zoom

func _store_scope_base_anchor(record: Dictionary) -> void:
	if bool(record.get("nested", false)):
		record["base_anchor"] = null
		return
	var window = record.get("window")
	if window == null or not is_instance_valid(window):
		return
	record["base_anchor"] = _scope_base_anchor(window)

## Called by ScopeWindow after the title-bar drag moves a top-level window.
func scope_window_moved(window) -> void:
	if window == null or not is_instance_valid(window):
		return
	var record = window.scope_record
	if record is Dictionary:
		_store_scope_base_anchor(record)

func _sync_scope_windows_to_base() -> void:
	if _base_canvas_view == null:
		return
	for record in _scope_open:
		if bool(record.get("nested", false)) or bool(record.get("fullscreen", false)):
			continue
		var window = record.get("window")
		if window == null or not is_instance_valid(window):
			continue
		var anchor = record.get("base_anchor")
		if anchor == null:
			anchor = _scope_base_anchor(window)
			record["base_anchor"] = anchor
		var scale: float = _base_canvas_view.zoom
		window.scale = Vector2(scale, scale)
		window.global_position = (
			_base_canvas_view.global_position
			+ _base_canvas_view.pan
			+ anchor * scale
		)
	_queue_palette_clearance()

## Choose a pastel identity that differs from the parent scope.
func _pick_scope_color(parent_tint) -> Color:
	var colors: Array = UiStyle.scope_colors()
	if colors.is_empty():
		return UiStyle.lavender()
	var tint: Color = colors[_next_scope_color % colors.size()]
	_next_scope_color += 1
	if parent_tint != null and tint == Color(parent_tint):
		tint = colors[_next_scope_color % colors.size()]
		_next_scope_color += 1
	return tint

## Put the current scope hypothesis into the ordinary Premises panel.
func _add_scope_assumption_item(record: Dictionary):
	if _premise_flow == null:
		return null
	var item := PaletteItemRes.new()
	item.controller = self
	item.setup_assumption(record["formula"], int(record["group"]), record["color"])
	_premise_flow.add_child(item)
	return item

func _remove_scope_assumption_item(record: Dictionary) -> void:
	var item = record.get("premise_item")
	record["premise_item"] = null
	if item == null or not is_instance_valid(item):
		return
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	item.queue_free()

func _activate_scope(record: Dictionary) -> void:
	var window = record["window"]
	if window == null or not is_instance_valid(window):
		return
	window.show()
	var window_parent = window.get_parent()
	if window_parent != null:
		window_parent.move_child(window, window_parent.get_child_count() - 1)
	canvas = record["inner_canvas"]
	_canvas_view = record["inner_view"]
	if not bool(record.get("opened", false)):
		record["opened"] = true
		if _canvas_view != null:
			_canvas_view.reset_view()
	_refresh_active_scope()

func _refresh_active_scope() -> void:
	if _canvas_view == null:
		return
	refresh_machine()

func _restore_parent_scope(record: Dictionary) -> void:
	canvas = record["parent_canvas"]
	_canvas_view = record["parent_view"]
	if canvas == null:
		canvas = _base_canvas
	if _canvas_view == null:
		_canvas_view = _base_canvas_view
	refresh_machine()

## Close the active scope and keep/update its implication marker.
func finish_scope_window(window) -> void:
	_close_scope_check_hint()
	var record = window.scope_record if window != null else null
	if record == null:
		return
	var record_index := _scope_open.find(record)
	if record_index >= 0 and record_index < _scope_open.size() - 1:
		play_sfx("scope_not_ready")
		window.set_status("close nested assumptions first", true)
		return
	var parent_full = _parent_fullscreen_record(record)
	if bool(record.get("fullscreen", false)) and parent_full == null:
		_set_scope_fullscreen(record, false, false)
	var inner_canvas = record["inner_canvas"]
	var conclusion = _scope_conclusion(inner_canvas)
	if conclusion == null:
		play_sfx("scope_not_ready")
		window.set_status("no proof conclusion", true)
		return
	var marker = record.get("marker")
	if marker == null or not is_instance_valid(marker):
		marker = ScopeMarkerRes.new()
		marker.controller = self
		marker.setup_marker(record["formula"], int(record["group"]), self, record["color"])
		record["marker"] = marker
		marker.window_record = record
	marker.set_conclusion(conclusion)
	var result = marker.get_result_formula()
	if result == null:
		play_sfx("scope_not_ready")
		window.set_status("incomplete proof", true)
		return
	var validation = ProofAdapterRes.validate(marker, result, false)
	if not validation.ok:
		play_sfx("scope_not_ready")
		window.set_status(_join_errors(validation.errors), true)
		return
	if marker.get_parent() == null:
		var parent_canvas = record["parent_canvas"]
		if parent_canvas == null:
			play_sfx("scope_not_ready")
			window.set_status("parent canvas is missing", true)
			return
		parent_canvas.add_child(marker)
		marker.reset_size()
		var parent_view = record["parent_view"]
		if parent_view != null:
			var screen_center: Vector2 = (
				window.global_position + window.size * window.scale * 0.5
			)
			var local: Vector2 = (
				screen_center - parent_view.global_position - parent_view.pan
			) / parent_view.zoom
			marker.position = local - marker.size * 0.5
		marker.mouse_filter = Control.MOUSE_FILTER_STOP
		marker.set_bottom_pinned(true)
	_clear_undo_history()
	record["finished"] = true
	play_sfx("scope_minimize")
	_remove_scope_assumption_item(record)
	window.set_status("")
	window.hide()
	if not _scope_open.is_empty() and _scope_open[-1] == record:
		_scope_open.pop_back()
	_restore_parent_scope(record)
	if parent_full != null:
		_update_scope_hud(parent_full)
	else:
		_update_scope_hud()
	_queue_palette_clearance()

## Close a scope window; unfinished scopes are discarded.
func close_scope_window(
	window,
	with_sound: bool = false,
	clear_history: bool = true
) -> void:
	_close_scope_check_hint()
	var record = window.scope_record if window != null else null
	if record == null:
		return
	if clear_history:
		_clear_undo_history()
	# Closing a parent window closes the nested windows on its desktop first.
	var record_index := _scope_open.find(record)
	if record_index >= 0:
		while _scope_open.size() > record_index + 1:
			var child_record = _scope_open[-1]
			close_scope_window(child_record["window"], false, false)
			if _scope_open.find(record) < 0:
				return
	var parent_full = _parent_fullscreen_record(record)
	if bool(record.get("fullscreen", false)) and parent_full == null:
		_set_scope_fullscreen(record, false, false)
	_remove_scope_assumption_item(record)
	var marker = record.get("marker")
	if marker != null and is_instance_valid(marker):
		if goal_bar != null and goal_bar.linked_block == marker:
			goal_bar.clear_link()
		if marker.get_parent() != null:
			marker.get_parent().remove_child(marker)
		marker.queue_free()
	record["marker"] = null
	window.queue_free()
	if not _scope_open.is_empty() and _scope_open[-1] == record:
		_scope_open.pop_back()
	_restore_parent_scope(record)
	if parent_full != null:
		_update_scope_hud(parent_full)
	else:
		_update_scope_hud()
	_queue_palette_clearance()

## Re-open an existing assumption scope from its marker.
func open_scope_marker(marker) -> void:
	if marker == null or not is_instance_valid(marker):
		return
	var record = marker.window_record
	if record == null:
		return
	if not _scope_open.has(record) and _scope_open.size() >= MAX_OPEN_SCOPES:
		play_sfx("soft_reject")
		show_toast("Too many open assumption windows, no way.")
		return
	_clear_undo_history()
	if not _scope_open.has(record):
		record["parent_canvas"] = canvas
		record["parent_view"] = _canvas_view
		_scope_open.append(record)
	if record.get("premise_item") == null or not is_instance_valid(record["premise_item"]):
		record["premise_item"] = _add_scope_assumption_item(record)
	play_sfx("scope_marker_open", {"pitch": 1.0 + _scope_open.size() * 0.03})
	_activate_scope(record)
	_update_scope_hud(record)
	_queue_palette_clearance()

func _build_scope_hud() -> void:
	_scope_hud = Control.new()
	_scope_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scope_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_hud.z_index = 12
	_scope_hud.add_to_group("nd_ui_overlay")
	_game_page.add_child(_scope_hud)

	var strip := CenterContainer.new()
	strip.set_anchors_preset(Control.PRESET_TOP_WIDE)
	strip.offset_top = 72.0
	strip.offset_bottom = 128.0
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_hud.add_child(strip)

	_scope_hud_bar = PanelContainer.new()
	_scope_hud_bar.custom_minimum_size = Vector2(430, 46)
	_scope_hud_bar.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(UiStyle.cream(), UiStyle.border_color(), 13)
	)
	strip.add_child(_scope_hud_bar)
	var bar := _scope_hud_bar

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)
	_scope_hud_dots = WindowDotsRes.new()
	_scope_hud_dots.setup()
	_scope_hud_dots.delete_requested.connect(_on_scope_hud_delete)
	_scope_hud_dots.toggle_size_requested.connect(_on_scope_hud_toggle_size)
	_scope_hud_dots.minimize_requested.connect(_on_scope_hud_minimize)
	row.add_child(_scope_hud_dots)
	_scope_hud_label = UiStyle.make_display_label("ASSUME", 14, UiStyle.text_color())
	_scope_hud_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_scope_hud_label)

	_scope_hud.visible = false

func delete_scope_window(window) -> void:
	play_sfx("scope_delete")
	close_scope_window(window, false)

func maximize_scope_window(window) -> void:
	if window == null:
		return
	var record = window.scope_record
	if record == null:
		return
	_set_scope_fullscreen(record, true)

func resume_scope_window(window) -> void:
	if window == null:
		return
	var record = window.scope_record
	if record == null:
		return
	_set_scope_fullscreen(record, false)

func toggle_scope_fullscreen(window) -> void:
	if window == null:
		return
	var record = window.scope_record
	if record == null:
		return
	var current := (
		bool(record.get("maximized", false))
		if bool(record.get("nested", false))
		else bool(record.get("fullscreen", false))
	)
	_set_scope_fullscreen(record, not current)

func _set_scope_fullscreen(record: Dictionary, enabled: bool, with_sound: bool = true) -> void:
	var window = record.get("window")
	if window == null or not is_instance_valid(window):
		return
	_queue_palette_clearance()
	var currently_max := bool(
		record.get(
			"maximized" if bool(record.get("nested", false)) else "fullscreen",
			false
		)
	)
	if enabled and not currently_max and _maximized_scope_count(record) >= MAX_MAXIMIZED_SCOPES:
		play_sfx("soft_reject")
		show_toast("Too many maximized windows, no way.")
		window.set_status("maximized limit reached", true)
		return
	if bool(record.get("nested", false)):
		if enabled == bool(record.get("maximized", false)):
			return
		if with_sound:
			play_sfx("scope_expand" if enabled else "scope_resume")
		var layer = window.get_parent()
		var bounds: Vector2 = layer.size if layer is Control else Vector2(640, 380)
		window.set_contained_maximized(enabled, bounds)
		record["maximized"] = enabled
		return
	if enabled == bool(record.get("fullscreen", false)):
		return
	if with_sound:
		play_sfx("scope_expand" if enabled else "scope_resume")
	if enabled:
		record["normal_position"] = window.position
		record["normal_size"] = window.size
		record["fullscreen"] = true
		_scope_layer.z_index = 5
		# GUI picking follows tree order, so put the full-screen scope below
		# the floating Premises/Rules overlay in input order as well.
		if _ui_overlay != null and _scope_layer.get_index() > _ui_overlay.get_index():
			_game_page.move_child(_scope_layer, _ui_overlay.get_index())
		_set_game_header_visible(false)
		_scope_hud.visible = false
		window.scale = Vector2.ONE
		window.set_fullscreen(true, Rect2(Vector2.ZERO, _game_page.size))
		_scope_layer.move_child(window, _scope_layer.get_child_count() - 1)
		window.show()
	else:
		record["fullscreen"] = false
		var normal_position: Vector2 = record.get("normal_position", Vector2(300, 110))
		var normal_size: Vector2 = record.get("normal_size", Vector2(680, 460))
		window.set_fullscreen(false, Rect2(normal_position, normal_size))
		if _top_bar != null:
			_top_bar.visible = true
		_set_game_header_visible(true)
		_scope_layer.z_index = 80
		if _ui_overlay != null and _scope_layer.get_index() > _ui_overlay.get_index():
			_game_page.move_child(_scope_layer, _ui_overlay.get_index())
		_scope_hud.visible = false
		window.show()
		_sync_scope_windows_to_base()

## Fullscreen scopes hide the game title/level so the compact window control
## strip in the top-left is not obscured.
func _set_game_header_visible(visible: bool) -> void:
	if _game_title_label != null:
		_game_title_label.visible = visible
	if _level_row != null:
		_level_row.visible = visible

func _parent_fullscreen_record(record: Dictionary):
	var index := _scope_open.find(record)
	if index > 0:
		var parent = _scope_open[index - 1]
		if bool(parent.get("fullscreen", false)):
			return parent
	return null

func _update_scope_hud(_record = null) -> void:
	# Fullscreen scopes keep their controls in the top-left title strip; the
	# old centre HUD is retired.
	if _scope_hud != null:
		_scope_hud.visible = false

## RESTORE from a nested full-screen scope returns the entire active scope
## stack to its floating-window positions instead of jumping one level.
func _exit_scope_fullscreen_stack() -> void:
	var had_full := false
	for record in _scope_open:
		if not bool(record.get("fullscreen", false)):
			continue
		had_full = true
		record["fullscreen"] = false
		var window = record.get("window")
		if window != null and is_instance_valid(window):
			var normal_position: Vector2 = record.get("normal_position", Vector2(300, 110))
			var normal_size: Vector2 = record.get("normal_size", Vector2(680, 460))
			window.set_fullscreen(false, Rect2(normal_position, normal_size))
			window.show()
	if not had_full:
		return
	if _top_bar != null:
		_top_bar.visible = true
	_set_game_header_visible(true)
	_scope_layer.z_index = 80
	if _ui_overlay != null and _scope_layer.get_index() > _ui_overlay.get_index():
		_game_page.move_child(_scope_layer, _ui_overlay.get_index())
	_scope_hud.visible = false
	var top = _active_scope_record()
	if top != null:
		_scope_layer.move_child(top["window"], _scope_layer.get_child_count() - 1)
		_activate_scope(top)
	_sync_scope_windows_to_base()

func _active_scope_record():
	if _scope_open.is_empty():
		return null
	return _scope_open[-1]

func _on_scope_hud_toggle_size() -> void:
	var record = _active_scope_record()
	if record != null:
		toggle_scope_fullscreen(record["window"])

func _on_scope_hud_minimize() -> void:
	var record = _active_scope_record()
	if record != null:
		finish_scope_window(record["window"])

func _on_scope_hud_delete() -> void:
	var record = _active_scope_record()
	if record != null:
		delete_scope_window(record["window"])

func _scope_conclusion(inner_canvas):
	if inner_canvas == null:
		return null
	var roots: Array = inner_canvas.get_root_blocks()
	for index in range(roots.size() - 1, -1, -1):
		var block = roots[index]
		if block.has_method("get_result_formula") and block.get_result_formula() != null:
			return block
	return null

func _join_errors(errors: Array) -> String:
	var text := ""
	for index in range(errors.size()):
		if index > 0:
			text += "; "
		text += str(errors[index])
	return text

## Tear down all scope windows, e.g. when loading another level.
func _close_all_scope_windows() -> void:
	_close_scope_check_hint()
	_clear_undo_history()
	for record in _scope_open:
		_remove_scope_assumption_item(record)
	if _scope_layer != null:
		for child in _scope_layer.get_children():
			child.queue_free()
	_scope_open.clear()
	if _scope_layer != null:
		_scope_layer.z_index = 80
		if _ui_overlay != null and _scope_layer.get_index() > _ui_overlay.get_index():
			_game_page.move_child(_scope_layer, _ui_overlay.get_index())
	if _top_bar != null:
		_top_bar.visible = true
	_set_game_header_visible(true)
	if _scope_hud != null:
		_scope_hud.visible = false
	canvas = _base_canvas
	_canvas_view = _base_canvas_view
	_clear_drag_hover()
	_dragging = false
	_queue_palette_clearance()

## Factory used by sockets and the canvas for rule palette spawns.
func create_rule_block(rule_id: String) -> Control:
	if RulesRes.arity(rule_id) < 0:
		return null
	if RulesRes.is_scoped(rule_id):
		var scoped := ScopedRuleBlockRes.new()
		scoped.controller = self
		scoped.setup(rule_id, self)
		if scoped.has_signal("state_changed"):
			scoped.state_changed.connect(_on_rule_state_changed)
		return scoped
	var block := RuleBlockRes.new()
	block.controller = self
	block.setup(rule_id, self)
	if block.has_signal("state_changed"):
		block.state_changed.connect(_on_rule_state_changed)
	return block

## --- Undo history -------------------------------------------------------

## Record the board before a mutating action. Snapshots are deep copies of the
## root blocks on every open canvas, so an undo can also move a block back
## across an assumption boundary.
func _push_undo_snapshot() -> void:
	if _undo_restoring or _current_level_id.is_empty() or _base_canvas == null:
		return
	# Snapshot copies temporarily become valid rule cards while their inputs
	# are attached. That is bookkeeping, not player feedback.
	var previous_suppress := _suppress_rule_feedback
	_suppress_rule_feedback = true
	var snapshot := {"canvases": []}
	snapshot["canvases"].append(_capture_canvas_state(_base_canvas))
	for record in _scope_open:
		var inner_canvas = record.get("inner_canvas")
		if inner_canvas != null and is_instance_valid(inner_canvas):
			snapshot["canvases"].append(_capture_canvas_state(inner_canvas))
	_suppress_rule_feedback = previous_suppress
	_undo_stack.append(snapshot)
	while _undo_stack.size() > UNDO_LIMIT:
		var old = _undo_stack.pop_front()
		_free_snapshot(old)
	_update_undo_button()

## Public hook for blocks that change themselves (side switches, etc.).
func record_undo() -> void:
	_push_undo_snapshot()

func _capture_canvas_state(target_canvas) -> Dictionary:
	var items: Array = []
	var roots: Array = target_canvas.get_root_blocks()
	var goal_index := -1
	if (
		goal_bar != null
		and goal_bar.linked_block != null
		and is_instance_valid(goal_bar.linked_block)
	):
		goal_index = roots.find(goal_bar.linked_block)
	for block in roots:
		var copy = duplicate_block(block)
		items.append({"block": copy, "position": block.position})
	return {"canvas": target_canvas, "blocks": items, "goal_index": goal_index}

func _free_snapshot(snapshot: Dictionary) -> void:
	for state in snapshot.get("canvases", []):
		for item in state.get("blocks", []):
			var block = item.get("block")
			if block != null and is_instance_valid(block) and block.get_parent() == null:
				block.free()

func _clear_undo_history() -> void:
	for snapshot in _undo_stack:
		_free_snapshot(snapshot)
	_undo_stack.clear()
	_update_undo_button()

func _update_undo_button() -> void:
	if _undo_button == null:
		return
	_undo_button.disabled = _undo_stack.is_empty()

## Undo the most recent board-changing action. Opening a scope is undoable;
## closing/finishing a scope starts a fresh history.
func _on_undo() -> void:
	if (
		_undo_restoring
		or _dragging
		or _settling
		or _undo_stack.is_empty()
	):
		return
	var entry: Dictionary = _undo_stack.pop_back()
	_undo_restoring = true
	var previous_suppress := _suppress_rule_feedback
	_suppress_rule_feedback = true
	if str(entry.get("kind", "")) == "scope_open":
		_undo_scope_open(entry)
	elif str(entry.get("kind", "")) == "assumption_edit":
		_apply_assumption_formula(entry.get("record"), entry.get("old_formula"))
	else:
		_undo_board_snapshot(entry)
	_pending_rule_feedback = 0
	_suppress_rule_feedback = previous_suppress
	_undo_restoring = false
	_update_undo_button()

func _undo_scope_open(entry: Dictionary) -> void:
	var record = entry.get("record")
	if record == null:
		return
	var window = record.get("window")
	if window == null or not is_instance_valid(window):
		return
	if not _scope_open.has(record):
		return
	close_scope_window(window, false, false)
	refresh_machine()

func _undo_board_snapshot(snapshot: Dictionary) -> void:
	_cancel_settle()
	if goal_bar != null:
		goal_bar.clear_link()

	for state in snapshot.get("canvases", []):
		var target_canvas = state.get("canvas")
		if target_canvas != null and is_instance_valid(target_canvas):
			_clear_canvas_blocks(target_canvas)

	var restored_goal = null
	for state in snapshot.get("canvases", []):
		var target_canvas = state.get("canvas")
		if target_canvas == null or not is_instance_valid(target_canvas):
			continue
		var items: Array = state.get("blocks", [])
		for item in items:
			var block = item.get("block")
			if block == null or not is_instance_valid(block):
				continue
			if block.get_parent() != null:
				block.get_parent().remove_child(block)
			target_canvas.add_child(block)
			block.scale = Vector2.ONE
			block.reset_size()
			block.position = item.get("position", Vector2.ZERO)
			block.mouse_filter = Control.MOUSE_FILTER_STOP
			block.set_bottom_pinned(true)
		var goal_index := int(state.get("goal_index", -1))
		if goal_index >= 0 and goal_index < items.size():
			var candidate = items[goal_index].get("block")
			if candidate != null and is_instance_valid(candidate):
				restored_goal = candidate

	if goal_bar != null:
		if restored_goal != null:
			goal_bar.set_linked_block(restored_goal, false)
			goal_bar.refresh()
		else:
			goal_bar.clear_link()
	_refresh_all_canvases()
	refresh_machine()

func _clear_canvas_blocks(target_canvas) -> void:
	for child in target_canvas.get_children():
		if child.has_method("get_result_formula"):
			target_canvas.remove_child(child)
			child.queue_free()

func _refresh_all_canvases() -> void:
	if _base_canvas != null:
		_base_canvas.refresh_all()
	for record in _scope_open:
		var inner_canvas = record.get("inner_canvas")
		if inner_canvas != null and is_instance_valid(inner_canvas):
			inner_canvas.refresh_all()

## Restart the current level (or clear the board if none is loaded).
func _on_reset() -> void:
	play_sfx("reset_sweep")
	_clear_undo_history()
	if not _current_level_id.is_empty():
		open_level_by_id(_current_level_id)
		return
	if goal_bar != null:
		goal_bar.clear_link()
	if canvas != null:
		canvas.clear_all()
	if _canvas_view != null:
		_canvas_view.reset_view()
	refresh_machine()

## Follow the mouse while dragging.
func _process(_delta: float) -> void:
	if _palette_clearance_dirty > 0:
		_palette_clearance_dirty -= 1
		_update_palette_clearance()
	if not _dragging or _dragged_block == null:
		return
	if not is_instance_valid(_dragged_block):
		_dragged_block = null
		_dragging = false
		return
	_dragged_block.global_position = get_global_mouse_position() - _drag_offset
	_update_drag_hover(get_global_mouse_position())

## Global input: finish block drags, pan/zoom the infinite canvas.
## Gameplay-only keyboard shortcuts. They are deliberately blocked while a
## modal, a drag, panning or settling owns the input.
func _handle_gameplay_shortcut(event: InputEventKey) -> bool:
	if _current_level_id.is_empty() or _dragging or _settling or _panning:
		return false
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed or event.shift_pressed:
		return false
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		# The goal bar belongs to the level. If the player forgot to minimize
		# the subproof, explain that instead of silently doing nothing.
		if not _scope_open.is_empty():
			_show_scope_check_hint()
		else:
			_on_check_requested()
		return true
	if event.keycode == KEY_A:
		if _assume_button == null or not _assume_button.visible:
			return false
		open_assumption_builder()
		return true
	var digit := 0
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		digit = event.keycode - KEY_1 + 1
	elif event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
		digit = event.keycode - KEY_KP_1 + 1
	if digit <= 0:
		return false
	var rules := LevelBankRes.chapter_rules(_current_chapter_id)
	if digit > rules.size():
		return false
	_spawn_rule_from_shortcut(digit - 1)
	return true

## Spawn the numbered rule card on the active canvas, centered on the mouse
## when it is over the canvas, otherwise near the canvas centre.
func _spawn_rule_from_shortcut(index: int) -> void:
	var rules := LevelBankRes.chapter_rules(_current_chapter_id)
	if index < 0 or index >= rules.size():
		return
	if canvas == null or _canvas_view == null:
		return
	var block = create_rule_block(str(rules[index]))
	if block == null:
		return
	var mouse := get_global_mouse_position()
	var screen_point := mouse
	if not _canvas_view.get_global_rect().has_point(mouse) or _over_ui():
		screen_point = _canvas_view.global_position + _canvas_view.size * 0.5
	var local: Vector2 = (
		screen_point - _canvas_view.global_position - _canvas_view.pan
	) / _canvas_view.zoom
	canvas.add_child(block)
	block.scale = Vector2.ONE
	block.reset_size()
	block.position = local - block.size * 0.5
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.set_bottom_pinned(true)
	play_sfx("card_place")
	refresh_machine()

func _input(event: InputEvent) -> void:
	if _game_page == null or not _game_page.visible:
		return
	# While a modal owns the keyboard, numbers and letters belong to it.
	if _formula_builder != null or _rule_intro != null:
		return
	if _scope_check_hint != null:
		if (
			event is InputEventKey
			and event.pressed
			and not event.echo
			and event.keycode == KEY_ESCAPE
		):
			_close_scope_check_hint()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if (event.ctrl_pressed or event.meta_pressed) and event.keycode == KEY_Z:
			_on_undo()
			get_viewport().set_input_as_handled()
			return
		if _handle_gameplay_shortcut(event):
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _dragging and not _settling:
			_cancel_drag()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		toggle_audio_muted()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F11:
		toggle_fullscreen()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var hovered := get_viewport().gui_get_hovered_control()
		var hover_view = _drop_view_at(hovered)
		var over_canvas: bool = hover_view != null
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			if over_canvas and not _dragging:
				var before_zoom: float = hover_view.zoom
				hover_view.zoom_at(
					event.position - hover_view.global_position,
					1.12
				)
				if not is_equal_approx(before_zoom, hover_view.zoom):
					play_sfx("ui_zoom", {"pitch": 1.08})
					if hover_view == _base_canvas_view:
						_sync_scope_windows_to_base()
				get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			if over_canvas and not _dragging:
				var before_zoom_out: float = hover_view.zoom
				hover_view.zoom_at(
					event.position - hover_view.global_position,
					1.0 / 1.12
				)
				if not is_equal_approx(before_zoom_out, hover_view.zoom):
					play_sfx("ui_zoom", {"pitch": 0.94})
					if hover_view == _base_canvas_view:
						_sync_scope_windows_to_base()
				get_viewport().set_input_as_handled()
			return

		if event.button_index == MOUSE_BUTTON_MIDDLE or event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed and over_canvas and not _dragging:
				_panning = true
				_pan_button = event.button_index
				_pan_view = hover_view
				_pan_last = event.position
				get_viewport().set_input_as_handled()
				return
			if not event.pressed and _panning and event.button_index == _pan_button:
				_panning = false
				_pan_view = null
				get_viewport().set_input_as_handled()
				return

		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and over_canvas and not _dragging and not _panning:
				if hovered == hover_view:
					_panning = true
					_pan_button = MOUSE_BUTTON_LEFT
					_pan_view = hover_view
					_pan_last = event.position
					get_viewport().set_input_as_handled()
					return
			elif not event.pressed:
				if _dragging:
					_finish_drag()
					return
				if _panning and _pan_button == MOUSE_BUTTON_LEFT:
					_panning = false
					_pan_view = null
					get_viewport().set_input_as_handled()
					return
	elif event is InputEventMouseMotion and _panning:
		var delta: Vector2 = event.position - _pan_last
		_pan_last = event.position
		var pan_view = _pan_view if is_instance_valid(_pan_view) else _canvas_view
		if pan_view != null:
			pan_view.pan_by(delta)
			if pan_view == _base_canvas_view:
				_sync_scope_windows_to_base()
		get_viewport().set_input_as_handled()

## Highlight the socket or goal bar currently under the drag.
func _update_drag_hover(mouse_global: Vector2) -> void:
	var target_view := _drop_view_at(get_viewport().gui_get_hovered_control())
	var target_canvas = target_view.world if target_view != null else null
	var socket := _find_socket_at(mouse_global, target_canvas)
	if socket != _hover_socket:
		if _hover_socket != null and is_instance_valid(_hover_socket):
			_hover_socket.set_drag_hover(false)
			_hover_socket.clear_preview()
		_hover_socket = socket
		if _hover_socket != null:
			_hover_socket.set_drag_hover(true)
			if _dragged_block != null:
				_hover_socket.preview_block(_dragged_block)

	var over_goal: bool = (
		goal_bar != null
		and socket == null
		and _goal_hit_rect().has_point(mouse_global)
	)
	if over_goal != _hover_goal:
		_hover_goal = over_goal
		if goal_bar != null:
			goal_bar.set_drag_hover(_hover_goal)

	var over_trash: bool = (
		trash_bin != null
		and socket == null
		and _trash_hit_rect().has_point(mouse_global)
	)
	if over_trash != _hover_trash:
		_hover_trash = over_trash
		if trash_bin != null:
			trash_bin.set_drag_hover(_hover_trash)
		if _hover_trash:
			play_sfx("trash_hover")

## Screen-space drop rect for the trash, padded so near-misses still delete.
func _trash_hit_rect() -> Rect2:
	if trash_bin == null:
		return Rect2()
	return trash_bin.get_global_rect().grow(TRASH_DROP_MARGIN)

## Screen-space drop rect for the goal chip, slightly padded for easier linking.
func _goal_hit_rect() -> Rect2:
	if goal_bar == null:
		return Rect2()
	return goal_bar.get_global_rect().grow(GOAL_DROP_MARGIN)

## Clear any drop-target highlight.
func _clear_drag_hover() -> void:
	if _hover_socket != null and is_instance_valid(_hover_socket):
		_hover_socket.set_drag_hover(false)
		_hover_socket.clear_preview()
	_hover_socket = null
	if _hover_goal and goal_bar != null:
		goal_bar.set_drag_hover(false)
	_hover_goal = false
	if _hover_trash and trash_bin != null:
		trash_bin.set_drag_hover(false)
	_hover_trash = false

## Lift an existing block (with its subtree) out of its current parent.
func begin_block_drag(block, mouse_global: Vector2) -> void:
	if _dragging or _settling or block == null or not is_instance_valid(block):
		return
	if block.has_method("is_value_only") and block.is_value_only():
		return
	_push_undo_snapshot()
	var grab_offset: Vector2 = mouse_global - block.global_position
	var parent: Node = block.get_parent()
	_origin_kind = "none"
	_origin_socket = null
	_origin_canvas = null
	_origin_position = Vector2.ZERO

	if parent != null:
		if parent.has_method("detach_block"):
			_origin_kind = "socket"
			_origin_socket = parent
			parent.detach_block(false)
		elif parent.has_method("get_root_blocks"):
			# A block may live on any scope canvas, not only the active one.
			_origin_kind = "canvas"
			_origin_canvas = parent
			_origin_position = block.position
			parent.remove_child(block)
		else:
			parent.remove_child(block)
	block.set_bottom_pinned(false)
	play_sfx("card_lift")

	var drag_zoom: float = _canvas_view.zoom if _canvas_view != null else 1.0
	_start_drag(block, grab_offset, mouse_global, drag_zoom)

## Spawn the real block from a palette row and start dragging it immediately.
func begin_palette_drag(kind: String, rule_id: String, formula, mouse_global: Vector2, assumption_group: int = 0) -> void:
	if _dragging or _settling:
		return
	_push_undo_snapshot()
	var block = null
	if kind == "spawn_rule":
		block = create_rule_block(rule_id)
	elif kind == "spawn_premise":
		block = create_formula_block(formula)
	elif kind == "spawn_assumption":
		block = create_assumption_block(formula, assumption_group)
	if block == null:
		return
	play_sfx("card_lift")

	_origin_kind = "none"
	_origin_socket = null
	_origin_canvas = null
	_origin_position = Vector2.ZERO
	_drag_layer.add_child(block)
	block.set_bottom_pinned(false)
	var drag_zoom: float = _canvas_view.zoom if _canvas_view != null else 1.0
	block.scale = Vector2(drag_zoom, drag_zoom)
	block.reset_size()
	var center_offset: Vector2 = block.size * drag_zoom * 0.5
	_start_drag(block, center_offset, mouse_global, drag_zoom)

## Put the block in the top drag layer and start following the mouse.
func _start_drag(block, offset: Vector2, mouse_global: Vector2, drag_zoom: float) -> void:
	if block.get_parent() == null:
		_drag_layer.add_child(block)
	block.set_bottom_pinned(false)
	block.scale = Vector2(drag_zoom, drag_zoom)
	block.reset_size()
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dragged_block = block
	_drag_offset = offset
	_drag_scale = drag_zoom
	_dragging = true
	_clear_drag_hover()
	block.global_position = mouse_global - offset
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	refresh_machine()

## Resolve the drop and restore/attach the real block.
func _finish_drag() -> void:
	if not _dragging or _dragged_block == null:
		return
	var block = _dragged_block
	var mouse := get_global_mouse_position()
	var target_view := _drop_view_at(get_viewport().gui_get_hovered_control())
	var target_canvas = target_view.world if target_view != null else null
	var socket := _find_socket_at(mouse, target_canvas)
	if socket != null:
		if (
			_reject_recursive_drop(block, target_canvas)
			or _reject_dependent_drop(block, target_canvas)
		):
			_restore_origin_or_place(block, mouse, false)
			_end_drag()
			return
		if socket.can_accept_block(block):
			_settle_into_socket(block, socket, mouse)
			return
		play_sfx("soft_reject")
		_restore_origin_or_place(block, mouse, false)
		_end_drag()
		return

	if trash_bin != null and _trash_hit_rect().has_point(mouse):
		_trash_dragged(block)
		play_sfx("trash_delete")
		_end_drag()
		return

	if goal_bar != null and _goal_hit_rect().has_point(mouse):
		if _reject_dependent_drop(block, _base_canvas):
			_restore_origin_or_place(block, mouse, false)
			_end_drag()
			return
		_restore_origin_or_place(block, mouse, true)
		play_sfx("goal_link")
		goal_bar.set_linked_block(block, false)
		_play_goal_outcome()
		_end_drag()
		return

	if target_canvas != null and target_view.get_global_rect().has_point(mouse):
		if (
			_reject_recursive_drop(block, target_canvas)
			or _reject_dependent_drop(block, target_canvas)
		):
			_restore_origin_or_place(block, mouse, false)
			_end_drag()
			return
		_place_on_canvas(block, mouse, target_canvas, target_view)
		play_sfx("card_place")
		_end_drag()
		return

	_restore_origin_or_place(block, mouse, false)
	play_sfx("soft_reject")
	_end_drag()

## Abort the active drag: return an existing block to its origin, or discard a
## block that was just spawned from the palette.
func _cancel_drag() -> void:
	if not _dragging or _dragged_block == null:
		return
	var block = _dragged_block
	_restore_origin_or_place(block, get_global_mouse_position(), false)
	play_sfx("cancel_down")
	_end_drag()

## Find the canvas view under a control. Scope canvases are nested inside
## their windows, so walking up to the first CanvasView gives us the correct
## drop target even when the active scope is deeper than the pointer.
func _drop_view_at(node) -> Control:
	var current: Node = node
	while current != null:
		if (
			current is Control
			and current.has_method("pan_by")
			and current.has_method("reset_view")
		):
			return current
		current = current.get_parent()
	return null

## Find the open scope record whose inner canvas is this canvas.
func _scope_record_for_canvas(target_canvas):
	if target_canvas == null or target_canvas == _base_canvas:
		return null
	for record in _scope_open:
		if record.get("inner_canvas") == target_canvas:
			return record
	return null

func _scope_record_for_group(group: int):
	for record in _scope_open:
		if int(record.get("group", 0)) == group:
			return record
	return null

## Assumption groups visible while editing on a given canvas. A nested scope
## inherits its parent's hypotheses; the base canvas has none.
func _context_groups_for_canvas(target_canvas) -> Dictionary:
	var groups: Dictionary = {}
	var record = _scope_record_for_canvas(target_canvas)
	while record != null:
		groups[int(record.get("group", 0))] = true
		record = record.get("parent_record")
	return groups

## A block may only cross a scope boundary when every free assumption it
## carries is still in context at the destination. This is what stops a proof
## from smuggling an Assume hypothesis out to the base canvas or GOAL.
func _block_dependencies_ok(block, target_canvas) -> bool:
	if block == null or not is_instance_valid(block):
		return true
	if not block.has_method("get_free_assumptions"):
		return true
	var groups := _context_groups_for_canvas(target_canvas)
	for assumption in block.get_free_assumptions():
		if assumption == null or not is_instance_valid(assumption):
			continue
		if not assumption.has_method("get_assumption_group"):
			continue
		if not groups.has(int(assumption.get_assumption_group())):
			return false
	return true

## Play the rejection and surface which assumption is still trapped.
func _reject_dependent_drop(block, target_canvas) -> bool:
	if _block_dependencies_ok(block, target_canvas):
		return false
	play_sfx("soft_reject")
	show_toast("Want to cheat huh, no way.")
	var groups := _context_groups_for_canvas(target_canvas)
	for assumption in block.get_free_assumptions():
		if assumption == null or not is_instance_valid(assumption):
			continue
		if not assumption.has_method("get_assumption_group"):
			continue
		var group := int(assumption.get_assumption_group())
		if groups.has(group):
			continue
		var record = _scope_record_for_group(group)
		if record != null:
			var window = record.get("window")
			if window != null and is_instance_valid(window):
				window.set_status("proof still uses this assumption", true)
		break
	return true

## A finished scope's marker contains a reference to its own window. Dropping
## that marker into that same window (or a descendant scope) would make the
## proof contain itself, so it must be rejected.
func _is_recursive_scope_drop(block, target_canvas) -> bool:
	if block == null or not is_instance_valid(block):
		return false
	if not block.has_method("is_scope_block") or not block.is_scope_block():
		return false
	if not block.has_method("get_window_record"):
		return false
	var marker_record = block.get_window_record()
	if marker_record == null:
		return false
	var marker_window = marker_record.get("window")
	if marker_window == null or not is_instance_valid(marker_window):
		return false
	var target_record = _scope_record_for_canvas(target_canvas)
	while target_record != null:
		if target_record.get("window") == marker_window:
			return true
		target_record = target_record.get("parent_record")
	return false

func _reject_recursive_drop(block, target_canvas) -> bool:
	if not _is_recursive_scope_drop(block, target_canvas):
		return false
	play_sfx("soft_reject")
	show_toast("Infinite recurrsion huh, no way.")
	return true

## A short paper toast for rejected interactions.
func show_toast(text: String) -> void:
	if _toast_panel == null or _toast_label == null:
		return
	_toast_label.text = text
	_toast_panel.visible = true
	_toast_panel.modulate.a = 0.0
	_toast_panel.reset_size()
	_toast_panel.position = Vector2(
		(_game_page.size.x - _toast_panel.size.x) * 0.5,
		88.0
	)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.10)
	_toast_tween.tween_interval(1.55)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.25)
	_toast_tween.tween_callback(_hide_toast)

func _hide_toast() -> void:
	if _toast_panel != null and is_instance_valid(_toast_panel):
		_toast_panel.visible = false

## Find the best empty socket near the mouse, ignoring the dragged subtree.
func _find_socket_at(mouse_global: Vector2, target_canvas = null) -> Control:
	var best: Control = null
	var best_distance := 1e30
	var best_area := 1e30
	if target_canvas == null:
		return null
	for node in get_tree().get_nodes_in_group("nd_socket"):
		if not is_instance_valid(node):
			continue
		var socket := node as Control
		if socket == null or not socket.is_visible_in_tree():
			continue
		if _dragged_block != null and _dragged_block.is_ancestor_of(socket):
			continue
		if target_canvas != null and not _node_is_under(target_canvas, socket):
			continue
		var rect: Rect2 = socket.get_global_rect()
		var empty: bool = socket.is_empty()
		# A block that was just pulled out of a socket must be able to leave;
		# its old home only recaptures it when the cursor is truly inside.
		var from_origin: bool = _origin_kind == "socket" and _origin_socket == socket
		if empty:
			if from_origin:
				if not rect.has_point(mouse_global):
					continue
			elif not rect.grow(SOCKET_APPROACH_MARGIN).has_point(mouse_global):
				continue
		elif not rect.has_point(mouse_global):
			continue
		var distance := _rect_distance(rect, mouse_global)
		var area: float = rect.size.x * rect.size.y
		if distance < best_distance - 0.01:
			best_distance = distance
			best_area = area
			best = socket
		elif absf(distance - best_distance) <= 0.01 and area < best_area:
			best_area = area
			best = socket
	return best

## True when [param node] is [param ancestor] or one of its descendants.
func _node_is_under(ancestor, node) -> bool:
	var current: Node = node
	while current != null:
		if current == ancestor:
			return true
		current = current.get_parent()
	return false

## Shortest distance from a screen point to a rectangle (0 while inside).
func _rect_distance(rect: Rect2, point: Vector2) -> float:
	var dx := maxf(maxf(rect.position.x - point.x, 0.0), point.x - rect.end.x)
	var dy := maxf(maxf(rect.position.y - point.y, 0.0), point.y - rect.end.y)
	return Vector2(dx, dy).length()

## Let go of the drag and spring the real block into the empty socket.
func _settle_into_socket(block, socket: Control, mouse_global: Vector2) -> void:
	if block == null or not is_instance_valid(block):
		return
	if socket == null or not is_instance_valid(socket):
		return
	_settle_block = block
	_settle_socket = socket
	_settle_drop = mouse_global
	_settling = true
	_dragging = false
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var previous = socket.get_attached_block()
	if previous != null and is_instance_valid(previous):
		socket.detach_block(false)
		previous.queue_free()
	socket.commit_preview(block)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

	var start: Vector2 = block.global_position
	if _settle_tween != null and _settle_tween.is_valid():
		_settle_tween.kill()
	_settle_tween = create_tween()
	_settle_tween.tween_method(
		Callable(self, "_apply_settle_position").bind(start),
		0.0,
		1.0,
		SETTLE_DURATION
	)
	_settle_tween.finished.connect(_finish_socket_settle)

## Track the socket's live inner rect while the slot finishes opening.
func _apply_settle_position(t: float, start: Vector2) -> void:
	if _settle_block == null or not is_instance_valid(_settle_block):
		return
	if _settle_socket == null or not is_instance_valid(_settle_socket):
		return
	var target: Vector2 = _socket_inner_rect(_settle_socket).position
	_settle_block.global_position = start.lerp(target, _settle_spring(t))

func _socket_inner_rect(socket: Control) -> Rect2:
	return socket.get_global_rect().grow_individual(-4.0, -4.0, -4.0, -2.0)

## Under-damped spring for the block flying into the slot (~9% overshoot).
func _settle_spring(t: float) -> float:
	if t >= 1.0:
		return 1.0
	var decay := exp(-SETTLE_ZETA * SETTLE_OMEGA * t)
	var damped := SETTLE_OMEGA * sqrt(1.0 - SETTLE_ZETA * SETTLE_ZETA)
	var phase := cos(damped * t) + (SETTLE_ZETA * SETTLE_OMEGA / damped) * sin(damped * t)
	return 1.0 - decay * phase

func _finish_socket_settle() -> void:
	var block = _settle_block
	var socket = _settle_socket
	_settle_block = null
	_settle_socket = null
	_settle_tween = null
	_settling = false

	if block != null and is_instance_valid(block):
		if socket == null or not is_instance_valid(socket) or not socket.attach_block(block, false):
			_restore_origin_or_place(block, _settle_drop, false)
			play_sfx("soft_reject")
		else:
			play_sfx("socket_snap")
	_end_drag()

func _cancel_settle() -> void:
	if not _settling and _settle_tween == null:
		return
	if _settle_tween != null and _settle_tween.is_valid():
		_settle_tween.kill()
	_settle_tween = null
	var block = _settle_block
	_settle_block = null
	_settle_socket = null
	_settling = false
	if block != null and is_instance_valid(block):
		block.queue_free()
	if _dragged_block == block:
		_dragged_block = null
	_dragging = false
	_drag_offset = Vector2.ZERO
	_drag_scale = 1.0
	_origin_kind = ""
	_origin_socket = null
	_origin_canvas = null
	_origin_position = Vector2.ZERO
	_clear_drag_hover()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

## Return the block to its origin; if it was newly spawned, optionally place it.
func _restore_origin_or_place(block, mouse_global: Vector2, place_if_new: bool) -> void:
	if (
		_origin_kind == "socket"
		and _origin_socket != null
		and is_instance_valid(_origin_socket)
		and _origin_socket.is_empty()
	):
		_origin_socket.attach_block(block, false)
		return
	if _origin_kind == "canvas" and _origin_canvas != null:
		_add_to_canvas_at(block, _origin_position, _origin_canvas)
		return
	if place_if_new or _origin_kind == "socket":
		_place_on_canvas(block, mouse_global)
		return
	if is_instance_valid(block):
		block.queue_free()

## Drop the real block onto the canvas at the mouse position.
func _place_on_canvas(
	block,
	mouse_global: Vector2,
	target_canvas = null,
	_target_view = null
) -> void:
	var destination = target_canvas if target_canvas != null else canvas
	if destination == null:
		return
	if block.get_parent() != null:
		block.get_parent().remove_child(block)
	block.scale = Vector2.ONE
	destination.add_child(block)
	block.reset_size()
	# Preserve the exact grab offset used while dragging; the world transform
	# turns this global position into the correct local position at any zoom.
	block.global_position = mouse_global - _drag_offset
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.set_bottom_pinned(true)

## Put the block back on the canvas at an exact local position.
func _add_to_canvas_at(block, local_position: Vector2, target_canvas = null) -> void:
	var destination = target_canvas if target_canvas != null else canvas
	if destination == null:
		return
	if block.get_parent() != null:
		block.get_parent().remove_child(block)
	block.scale = Vector2.ONE
	destination.add_child(block)
	block.reset_size()
	block.position = local_position
	block.mouse_filter = Control.MOUSE_FILTER_STOP
	block.set_bottom_pinned(true)

## Delete the dragged block (and subtree); clear a goal link inside it.
func _trash_dragged(block) -> void:
	if (
		goal_bar != null
		and goal_bar.linked_block != null
		and is_instance_valid(goal_bar.linked_block)
		and block.is_ancestor_of(goal_bar.linked_block)
	):
		goal_bar.clear_link()
	if is_instance_valid(block):
		block.queue_free()

## Ctrl+drag: duplicate the source subtree and drag the copy instead.
func begin_copy_drag(source, mouse_global: Vector2) -> void:
	if _dragging or _settling or source == null or not is_instance_valid(source):
		return
	if source.has_method("is_value_only") and source.is_value_only():
		return
	_push_undo_snapshot()
	_suppress_rule_feedback = true
	var copy = duplicate_block(source)
	_suppress_rule_feedback = false
	if copy == null:
		return
	play_sfx("copy_stamp")
	var grab_offset: Vector2 = mouse_global - source.global_position
	_origin_kind = "none"
	_origin_socket = null
	_origin_position = Vector2.ZERO
	_drag_layer.add_child(copy)
	var drag_zoom: float = _canvas_view.zoom if _canvas_view != null else 1.0
	copy.set_bottom_pinned(false)
	copy.scale = Vector2(drag_zoom, drag_zoom)
	copy.reset_size()
	_start_drag(copy, grab_offset, mouse_global, drag_zoom)

## Deep-copy a block and (for rules) its whole input subtree.
func duplicate_block(source) -> Control:
	if source == null or not is_instance_valid(source):
		return null
	if source.has_method("is_assumption_block") and source.is_assumption_block():
		return create_assumption_block(
			source.get_result_formula(),
			source.get_assumption_group()
		)
	if source.has_method("is_scope_block") and source.is_scope_block():
		# Scope markers wrap a finished subproof. Copy the conclusion as well so
		# undo snapshots keep the marker usable as a proof value.
		if (
			source.has_method("get_scope_assumption_formula")
			and source.has_method("get_scope_proof_block")
		):
			var marker := ScopeMarkerRes.new()
			marker.controller = self
			marker.setup_marker(
				source.get_scope_assumption_formula(),
				int(source.get_assumption_group()),
				self,
				source.get_scope_color()
			)
			var conclusion = duplicate_block(source.get_scope_proof_block())
			if conclusion != null:
				marker.set_conclusion(conclusion)
			marker.refresh()
			return marker
		return null
	if source.has_method("get_rule_id"):
		var card = create_rule_block(str(source.get_rule_id()))
		if card == null:
			return null
		if RulesRes.is_scoped(str(source.get_rule_id())):
			var proof_inputs: Array = source.get_proof_blocks()
			for index in range(proof_inputs.size()):
				if proof_inputs[index] == null or index >= card.sockets.size():
					continue
				var proof_copy = duplicate_block(proof_inputs[index])
				if proof_copy != null:
					card.sockets[index].attach_block(proof_copy, false)
			card.refresh()
			return card
		if card.has_method("set_extra_formula"):
			card.set_extra_formula(source.get_extra_formula())
		var inputs: Array = source.get_input_blocks()
		for index in range(inputs.size()):
			if inputs[index] == null or index >= card.sockets.size():
				continue
			var child_copy = duplicate_block(inputs[index])
			if child_copy != null:
				card.sockets[index].attach_block(child_copy, false)
		card.refresh()
		return card

	var formula = source.get_result_formula()
	if formula == null:
		return null
	return create_formula_block(formula)

## Copy button: place an independent duplicate near the source on the canvas.
func duplicate_to_canvas(source) -> void:
	if source == null or not is_instance_valid(source):
		return
	_push_undo_snapshot()
	_suppress_rule_feedback = true
	var copy = duplicate_block(source)
	_suppress_rule_feedback = false
	if copy == null:
		return
	play_sfx("copy_stamp")
	canvas.add_child(copy)
	copy.scale = Vector2.ONE
	copy.reset_size()
	copy.global_position = source.global_position + Vector2(48.0, 48.0)
	copy.mouse_filter = Control.MOUSE_FILTER_STOP
	copy.set_bottom_pinned(true)
	refresh_machine()

## Restore the dragged block to normal input and refresh the board.
func _end_drag() -> void:
	if _dragged_block != null and is_instance_valid(_dragged_block):
		_dragged_block.mouse_filter = Control.MOUSE_FILTER_STOP
		_dragged_block.scale = Vector2.ONE
		_dragged_block.reset_size()
		_dragged_block.refresh_bottom_pin()
	_clear_drag_hover()
	_dragged_block = null
	_dragging = false
	_drag_offset = Vector2.ZERO
	_drag_scale = 1.0
	_origin_kind = ""
	_origin_socket = null
	_origin_canvas = null
	_origin_position = Vector2.ZERO
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	refresh_machine()
