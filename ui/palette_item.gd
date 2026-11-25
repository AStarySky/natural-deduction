extends PanelContainer

## Draggable palette source. Rule entries are square icon tiles; premise
## entries are compact formula tiles.

const FormulaRes = preload("res://logic/formula.gd")
const CardWearRes = preload("res://ui/card_wear.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const RuleIconRes = preload("res://ui/rule_icon.gd")
const RuleMetaRes = preload("res://ui/rule_meta.gd")
const RulesRes = preload("res://logic/rules.gd")
const UiStyle = preload("res://ui/ui_style.gd")
const CardMetrics = preload("res://ui/card_metrics.gd")

var spawn_kind: String = ""
var rule_id: String = ""
var shortcut_number: int = 0
var formula: FormulaRes = null
var assumption_group: int = 0
var assumption_color: Color = Color8(244, 219, 255)
var controller = null
var _rule_color: Color = Color.WHITE
var _paper = null
var _rule_hover: bool = false
var _press_active: bool = false
var _press_position := Vector2.ZERO
var _is_rule_card: bool = false
var _base_rotation: float = 0.0
var _rest_position := Vector2.ZERO
var _hover_tween: Tween = null
var _is_formula_tile := false
var _is_assumption_tile := false
var _mode := CardMetrics.DEFAULT
var _overlay: Control = null
var _margin: MarginContainer = null
var _box: VBoxContainer = null
var _header: HBoxContainer = null
var _formula_badge: Panel = null
var _formula_tag: Label = null
var _formula_visual = null
var _corner_badge: Panel = null
var _corner_tag: Label = null

## Square icon tile for a rule palette entry. A positive shortcut gets a small
## number badge in the top-right corner.
func setup_rule(p_rule_id: String, p_shortcut: int = 0) -> void:
	spawn_kind = "spawn_rule"
	rule_id = p_rule_id
	shortcut_number = p_shortcut
	add_to_group("nd_rule_card")
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	custom_minimum_size = Vector2(92, 112)
	tooltip_text = RuleMetaRes.tooltip(rule_id)
	_rule_color = UiStyle.rule_color(rule_id)
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_refresh_rule_style()
	_paper = CardWearRes.apply_to(self, hash(rule_id), _rule_color)
	_is_rule_card = true
	_base_rotation = rotation

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", 9)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 9)
	content.add_theme_constant_override("margin_bottom", 8)
	add_child(content)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	content.add_child(box)

	var icon_center := CenterContainer.new()
	icon_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(icon_center)

	var plate := PanelContainer.new()
	plate.custom_minimum_size = Vector2(48, 48)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_theme_stylebox_override(
		"panel",
		UiStyle.panel_style(UiStyle.cream(), UiStyle.border_color(), 9, 2, false)
	)
	var icon = RuleIconRes.new()
	icon.setup(rule_id)
	icon.custom_minimum_size = Vector2(42, 42)
	plate.add_child(icon)
	icon_center.add_child(plate)

	var pips := HBoxContainer.new()
	pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pips.alignment = BoxContainer.ALIGNMENT_CENTER
	pips.add_theme_constant_override("separation", 3)
	box.add_child(pips)
	var arity := RulesRes.arity(rule_id)
	for index in range(arity):
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(8, 8)
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pip.add_theme_stylebox_override(
			"panel",
			UiStyle.panel_style(UiStyle.cream(), UiStyle.border_color(), 4, 1, false)
		)
		pips.add_child(pip)
	if RulesRes.takes_extra(rule_id):
		var extra_pip := Panel.new()
		extra_pip.custom_minimum_size = Vector2(8, 8)
		extra_pip.rotation = PI * 0.25
		extra_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		extra_pip.add_theme_stylebox_override(
			"panel",
			UiStyle.panel_style(UiStyle.coral(), UiStyle.border_color(), 2, 1, false)
		)
		pips.add_child(extra_pip)

	if p_shortcut > 0:
		_add_shortcut_badge(p_shortcut)

## Small numbered circle in the top-right corner. The overlay is a plain
## Control because PanelContainer would stretch a direct badge to fill.
func _add_shortcut_badge(number: int) -> void:
	var overlay := Control.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var badge := PanelContainer.new()
	badge.custom_minimum_size = Vector2(20, 20)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -24.0
	badge.offset_top = 2.0
	badge.offset_right = -4.0
	badge.offset_bottom = 22.0
	var badge_box := UiStyle.panel_style(
		UiStyle.cream(), UiStyle.border_color(), 10, 2, false
	)
	badge_box.content_margin_left = 0.0
	badge_box.content_margin_top = 0.0
	badge_box.content_margin_right = 0.0
	badge_box.content_margin_bottom = 0.0
	badge.add_theme_stylebox_override("panel", badge_box)
	var label := UiStyle.make_display_label(str(number), 10, UiStyle.text_color())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(20, 20)
	label.clip_text = false
	badge.add_child(label)
	badge.z_index = 5
	overlay.add_child(badge)

func _on_hover(active: bool) -> void:
	_rule_hover = active
	if active and controller != null and controller.has_method("play_sfx"):
		controller.play_sfx("card_hover")
	if _is_rule_card:
		_refresh_rule_style()
	_animate_hover(active)

func _animate_hover(active: bool) -> void:
	if _hover_tween != null and _hover_tween.is_valid():
		_hover_tween.kill()
	if active:
		_rest_position = position
		var key := rule_id if not rule_id.is_empty() else (
			formula.to_display_string() if formula != null else "card"
		)
		var direction := 1.0 if (hash(key) & 1) == 0 else -1.0
		var tilt := deg_to_rad(2.4) * direction
		z_index = 20
		_hover_tween = create_tween().set_parallel(true)
		_hover_tween.tween_property(
			self, "rotation", _base_rotation + tilt, 0.14
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(
			self, "scale", Vector2(1.045, 1.045), 0.14
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if _is_rule_card:
			_hover_tween.tween_property(
				self, "position", _rest_position - Vector2(0, 7), 0.14
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		z_index = 0
		_hover_tween = create_tween().set_parallel(true)
		_hover_tween.tween_property(
			self, "rotation", _base_rotation, 0.16
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		_hover_tween.tween_property(
			self, "scale", Vector2.ONE, 0.16
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if _is_rule_card:
			_hover_tween.tween_property(
				self, "position", _rest_position, 0.16
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _refresh_rule_style() -> void:
	var fill := _rule_color.lightened(0.12) if _rule_hover else _rule_color
	add_theme_stylebox_override("panel", UiStyle.empty_style())
	if _paper != null:
		_paper.set_fill(fill)

## Compact cream formula tile for a premise palette entry.
func setup_premise(p_formula: FormulaRes) -> void:
	spawn_kind = "spawn_premise"
	formula = p_formula
	assumption_group = 0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = p_formula.to_display_string() + "\nPremise: drag into a rule input."
	_mode = _resolve_formula_mode()
	add_to_group("nd_formula_card")
	_is_formula_tile = true
	_is_assumption_tile = false
	_build_formula_tile(
		p_formula,
		UiStyle.cream(),
		hash(p_formula.to_display_string())
	)

## Scoped hypothesis source. It spawns an AssumptionBlock in the same group,
## so every copy can be discharged together.
func set_assumption_formula(p_formula: FormulaRes) -> void:
	if not _is_formula_tile:
		return
	formula = p_formula
	if _formula_visual != null:
		_formula_visual.set_formula(p_formula)
	_apply_formula_geometry()
	_refresh_formula_badge()
	tooltip_text = p_formula.to_display_string() + "
Assumption in this scope: drag into the sub-world canvas."
	update_minimum_size()
	reset_size()

func setup_assumption(p_formula: FormulaRes, p_group: int, tint: Color = Color8(244, 219, 255)) -> void:
	spawn_kind = "spawn_assumption"
	formula = p_formula
	assumption_group = p_group
	assumption_color = tint
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	tooltip_text = p_formula.to_display_string() + "\nAssumption in this scope: drag into the sub-world canvas."
	_mode = _resolve_formula_mode()
	add_to_group("nd_formula_card")
	_is_formula_tile = true
	_is_assumption_tile = true
	_is_rule_card = false
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))
	_build_formula_tile(
		p_formula,
		tint,
		hash(p_formula.to_display_string() + ":assume:" + str(p_group))
	)

func _resolve_formula_mode() -> String:
	if controller != null and controller.has_method("get_card_size_mode"):
		return CardMetrics.normalize(str(controller.get_card_size_mode()))
	return CardMetrics.DEFAULT

func _build_formula_tile(p_formula: FormulaRes, fill: Color, seed_value: int) -> void:
	var metrics := CardMetrics.palette_assumption(_mode) if _is_assumption_tile else CardMetrics.palette_formula(_mode)
	custom_minimum_size = metrics["min_size"]
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_stylebox_override("panel", UiStyle.empty_style())
	_paper = CardWearRes.apply_to(self, seed_value, fill)
	_base_rotation = rotation

	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_margin)
	_box = VBoxContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", int(metrics["separation"]))
	_margin.add_child(_box)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_header = HBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_theme_constant_override("separation", int(metrics.get("header_separation", 0)))
	_box.add_child(_header)
	_formula_badge = Panel.new()
	_formula_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(_formula_badge)
	if _is_assumption_tile:
		_formula_tag = UiStyle.make_display_label("ASSUME", int(metrics.get("tag_font_size", 9)), UiStyle.muted_text())
		_formula_tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_formula_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_header.add_child(_formula_tag)
	else:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_header.add_child(spacer)

	_corner_badge = Panel.new()
	_corner_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_corner_badge)
	if _is_assumption_tile:
		_corner_tag = UiStyle.make_display_label("ASSUME", int(metrics.get("tag_font_size", 9)), UiStyle.muted_text())
		_corner_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overlay.add_child(_corner_tag)

	_formula_visual = FormulaVisualRes.new()
	_formula_visual.setup(p_formula, int(metrics["token_size"]), int(metrics["font_size"]))
	_formula_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_formula_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.add_child(_formula_visual)

	_apply_formula_geometry()
	_refresh_formula_badge()

func apply_card_size_mode(mode: String) -> void:
	if not _is_formula_tile:
		return
	var normalized := CardMetrics.normalize(mode)
	if normalized == _mode:
		return
	_mode = normalized
	_apply_formula_geometry()
	_refresh_formula_badge()
	update_minimum_size()
	reset_size()

func _apply_formula_geometry() -> void:
	var metrics := CardMetrics.palette_assumption(_mode) if _is_assumption_tile else CardMetrics.palette_formula(_mode)
	custom_minimum_size = metrics["min_size"]
	if _box != null:
		_box.add_theme_constant_override("separation", int(metrics["separation"]))
	var atom := formula != null and formula.kind == FormulaRes.Kind.ATOM
	if _header != null:
		_header.visible = bool(metrics["show_header"]) and not atom
	if _formula_badge != null:
		_formula_badge.visible = not atom
	if _margin != null:
		var side := int(metrics["margin_side"])
		var top := int(metrics["margin_top"])
		_margin.add_theme_constant_override("margin_left", side)
		_margin.add_theme_constant_override("margin_top", top)
		_margin.add_theme_constant_override("margin_right", side)
		_margin.add_theme_constant_override("margin_bottom", top)
	var compact := not bool(metrics["show_header"])
	if _formula_badge != null:
		_formula_badge.custom_minimum_size = Vector2(float(metrics["badge_size"]), float(metrics["badge_size"]))
	if _corner_badge != null:
		_corner_badge.visible = compact and not atom
		_corner_badge.custom_minimum_size = Vector2(float(metrics["badge_size"]), float(metrics["badge_size"]))
		_corner_badge.position = Vector2(float(metrics["corner_inset"]), float(metrics["corner_inset"]))
		_corner_badge.size = Vector2(float(metrics["badge_size"]), float(metrics["badge_size"]))
	if _formula_tag != null:
		_formula_tag.add_theme_font_size_override("font_size", int(metrics.get("tag_font_size", 9)))
	if _corner_tag != null:
		_corner_tag.visible = compact
		_corner_tag.add_theme_font_size_override("font_size", int(metrics.get("tag_font_size", 9)))
		_corner_tag.position = Vector2(float(metrics["corner_inset"]) + float(metrics["badge_size"]) + 4.0, float(metrics["corner_inset"]))
	if _formula_visual != null:
		_formula_visual.set_metrics(
			int(metrics["token_size"]),
			int(metrics["font_size"]),
			float(metrics["visual_min_height"])
		)

func _refresh_formula_badge() -> void:
	if not _is_formula_tile:
		return
	var metrics := CardMetrics.palette_assumption(_mode) if _is_assumption_tile else CardMetrics.palette_formula(_mode)
	var color := UiStyle.accent() if not _is_assumption_tile else assumption_color
	for badge in [_formula_badge, _corner_badge]:
		if badge == null:
			continue
		var box := UiStyle.panel_style(
			color,
			UiStyle.border_color(),
			int(metrics["badge_radius"]),
			1,
			false
		)
		box.content_margin_left = 0.0
		box.content_margin_top = 0.0
		box.content_margin_right = 0.0
		box.content_margin_bottom = 0.0
		badge.add_theme_stylebox_override("panel", box)

## Press-and-drag creates the real block immediately; it follows the mouse.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_active = true
				_press_position = event.global_position
			else:
				_press_active = false
	elif event is InputEventMouseMotion and _press_active:
		if event.global_position.distance_to(_press_position) > 6.0:
			_press_active = false
			if controller != null and controller.has_method("begin_palette_drag"):
				controller.begin_palette_drag(spawn_kind, rule_id, formula, event.global_position, assumption_group)
