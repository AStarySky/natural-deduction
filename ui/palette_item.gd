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
	custom_minimum_size = Vector2(80, 84)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = p_formula.to_display_string() + "\nPremise: drag into a rule input."
	add_theme_stylebox_override("panel", UiStyle.empty_style())
	_paper = CardWearRes.apply_to(self, hash(p_formula.to_display_string()), UiStyle.cream())

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", 9)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 9)
	content.add_theme_constant_override("margin_bottom", 8)
	add_child(content)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	content.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(header)
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(10, 10)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override(
		"panel",
		UiStyle.panel_style(UiStyle.accent(), UiStyle.border_color(), 5, 1, false)
	)
	header.add_child(badge)

	var visual = FormulaVisualRes.new()
	visual.setup(p_formula, 28, 14)
	visual.custom_minimum_size = Vector2(0, 44)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(visual)

## Scoped hypothesis source. It spawns an AssumptionBlock in the same group,
## so every copy can be discharged together.
func setup_assumption(p_formula: FormulaRes, p_group: int, tint: Color = Color8(244, 219, 255)) -> void:
	spawn_kind = "spawn_assumption"
	formula = p_formula
	assumption_group = p_group
	assumption_color = tint
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	custom_minimum_size = Vector2(80, 84)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = p_formula.to_display_string() + "
Assumption in this scope: drag into the sub-world canvas."
	add_theme_stylebox_override("panel", UiStyle.empty_style())
	_paper = CardWearRes.apply_to(
		self,
		hash(p_formula.to_display_string() + ":assume:" + str(p_group)),
		tint
	)
	_is_rule_card = false
	_base_rotation = rotation
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))

	var content := MarginContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("margin_left", 9)
	content.add_theme_constant_override("margin_top", 8)
	content.add_theme_constant_override("margin_right", 9)
	content.add_theme_constant_override("margin_bottom", 8)
	add_child(content)

	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	content.add_child(box)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 3)
	box.add_child(header)
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(10, 10)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_stylebox_override(
		"panel",
		UiStyle.panel_style(tint, UiStyle.border_color(), 5, 1, false)
	)
	header.add_child(badge)
	var tag := UiStyle.make_display_label("ASSUME", 9, UiStyle.muted_text())
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(tag)

	var visual = FormulaVisualRes.new()
	visual.setup(p_formula, 28, 14)
	visual.custom_minimum_size = Vector2(0, 44)
	visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(visual)

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
