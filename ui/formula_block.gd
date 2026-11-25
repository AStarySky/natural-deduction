extends "res://ui/block_base.gd"

## Square-ish cream premise tile. Formula propositions render as SVG pictures
## (with a letter-tile fallback for unknown atoms); rule blocks are icon-only.

const FormulaRes = preload("res://logic/formula.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const CardMetrics = preload("res://ui/card_metrics.gd")

var formula: FormulaRes = null
var _visual = null
var _vbox: VBoxContainer = null
var _header: HBoxContainer = null
var _badge: Panel = null
var _corner_badge: Panel = null
var _tab: ColorRect = null
var _overlay: Control = null
var _mode := CardMetrics.DEFAULT
var _card_fill: Color = UiStyle.cream()
var _accent_fill: Color = UiStyle.accent()

func setup(p_formula: FormulaRes) -> void:
	formula = p_formula
	_mode = _resolve_mode()
	add_to_group("nd_formula_card")
	var metrics := CardMetrics.formula_block(_mode)
	custom_minimum_size = metrics["min_size"]
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = formula.to_display_string() + "\nPremise"

	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_theme_constant_override("separation", int(metrics["separation"]))
	add_child(_vbox)

	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)

	_header = HBoxContainer.new()
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vbox.add_child(_header)

	_badge = Panel.new()
	_badge.custom_minimum_size = Vector2(metrics["badge_size"], metrics["badge_size"])
	_badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(_badge)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.add_child(spacer)

	# In Compact mode the header row is removed; this corner badge keeps the
	# same status cue without spending a full row of card height.
	_corner_badge = Panel.new()
	_corner_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corner_badge.visible = false
	_overlay.add_child(_corner_badge)

	_visual = FormulaVisualRes.new()
	_visual.setup(formula, int(metrics["token_size"]), int(metrics["font_size"]))
	_visual.custom_minimum_size = Vector2(0, float(metrics["visual_min_height"]))
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vbox.add_child(_visual)

	_tab = ColorRect.new()
	_tab.color = UiStyle.accent()
	_tab.custom_minimum_size = metrics["tab_size"]
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_vbox.add_child(_tab)

	_apply_mode_geometry()
	refresh_visuals()

func _resolve_mode() -> String:
	if controller != null and controller.has_method("get_card_size_mode"):
		return CardMetrics.normalize(str(controller.get_card_size_mode()))
	return CardMetrics.DEFAULT

## Apply a Compact/Comfort mode without rebuilding the formula or its subtree.
func apply_card_size_mode(mode: String) -> void:
	var normalized := CardMetrics.normalize(mode)
	if normalized == _mode:
		return
	_mode = normalized
	_apply_mode_geometry()
	refresh_visuals()
	update_minimum_size()
	reset_size()

func _apply_mode_geometry() -> void:
	var metrics := CardMetrics.formula_block(_mode)
	var atom := formula != null and formula.kind == FormulaRes.Kind.ATOM
	custom_minimum_size = metrics["min_size"]
	if _vbox != null:
		_vbox.add_theme_constant_override("separation", int(metrics["separation"]))
	if _header != null:
		_header.visible = bool(metrics["show_header"]) and not atom
	if _badge != null:
		_badge.visible = not atom
	if _corner_badge != null:
		_corner_badge.visible = (not bool(metrics["show_header"])) and not atom
		_corner_badge.custom_minimum_size = Vector2(
			float(metrics["badge_size"]),
			float(metrics["badge_size"])
		)
		var badge_size: float = float(metrics["badge_size"])
		# The overlay lives inside the panel's content margins. Place the dot's
		# centre on the rounded corner's arc centre (radius 12), not at the
		# content origin.
		var arc_center := Vector2(12.0, 12.0)
		_corner_badge.position = (
			arc_center - Vector2(badge_size, badge_size) * 0.5
			- Vector2(float(metrics["margin_side"]), float(metrics["margin_top"]))
		)
		_corner_badge.size = Vector2(badge_size, badge_size)
	if _badge != null:
		_badge.custom_minimum_size = Vector2(
			float(metrics["badge_size"]),
			float(metrics["badge_size"])
		)
	if _visual != null:
		_visual.set_metrics(
			int(metrics["token_size"]),
			int(metrics["font_size"]),
			float(metrics["visual_min_height"])
		)
	if _tab != null:
		_tab.custom_minimum_size = metrics["tab_size"]

func get_result_formula():
	return formula

func get_display_text() -> String:
	if formula == null:
		return "premise"
	return formula.to_display_string()

func refresh() -> void:
	if formula == null:
		return
	if _visual != null:
		_visual.set_formula(formula)
	if tooltip_text.is_empty() and formula != null:
		tooltip_text = formula.to_display_string() + "\nPremise"

func refresh_visuals() -> void:
	if _visual == null:
		return
	var metrics := CardMetrics.formula_block(_mode)
	var border := UiStyle.valid_color() if is_goal_linked() else UiStyle.border_color()
	if formula == null:
		border = UiStyle.error_color()
	add_theme_stylebox_override(
		"panel",
		CardMetrics.formula_card_style(_card_fill, border, _mode)
	)
	for badge in [_badge, _corner_badge]:
		if badge == null:
			continue
		badge.add_theme_stylebox_override(
			"panel",
			UiStyle.panel_style(
				_accent_fill,
				UiStyle.border_color(),
				int(metrics["badge_radius"]),
				2,
				false
			)
		)
	if _tab != null:
		_tab.color = UiStyle.valid_color() if is_goal_linked() else _accent_fill
