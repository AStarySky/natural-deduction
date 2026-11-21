extends "res://ui/block_base.gd"

## Square-ish cream premise tile. Formula propositions render as SVG pictures
## (with a letter-tile fallback for unknown atoms); rule blocks are icon-only.

const FormulaRes = preload("res://logic/formula.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")

var formula: FormulaRes = null
var _visual = null
var _badge: Panel = null
var _tab: ColorRect = null

func setup(p_formula: FormulaRes) -> void:
	formula = p_formula
	custom_minimum_size = Vector2(64, 104)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tooltip_text = formula.to_display_string() + "\nPremise"

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 3)
	add_child(vbox)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	_badge = Panel.new()
	_badge.custom_minimum_size = Vector2(12, 12)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(_badge)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(spacer)

	_visual = FormulaVisualRes.new()
	_visual.setup(formula, 34, 17)
	_visual.custom_minimum_size = Vector2(0, 44)
	_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_visual)

	_tab = ColorRect.new()
	_tab.color = UiStyle.accent()
	_tab.custom_minimum_size = Vector2(46, 5)
	_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(_tab)

	refresh_visuals()

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
	var border := UiStyle.valid_color() if is_goal_linked() else UiStyle.border_color()
	if formula == null:
		border = UiStyle.error_color()
	add_theme_stylebox_override("panel", UiStyle.card_style(UiStyle.cream(), border, 12))
	if _badge != null:
		_badge.add_theme_stylebox_override(
			"panel",
			UiStyle.panel_style(UiStyle.accent(), UiStyle.border_color(), 6, 2, false)
		)
	if _tab != null:
		_tab.color = UiStyle.valid_color() if is_goal_linked() else UiStyle.accent()
