extends RefCounted

## Shared visual metrics for formula-leaf cards. Rule cards and scope cards
## deliberately live outside this table so this change cannot accidentally
## re-layout the proof machinery.

const UiStyle = preload("res://ui/ui_style.gd")

const COMPACT := "compact"
const COMFORT := "comfort"
const DEFAULT := COMPACT

static func normalize(mode: String) -> String:
	return COMFORT if mode == COMFORT else COMPACT

static func formula_block(mode: String) -> Dictionary:
	if normalize(mode) == COMFORT:
		return {
			"min_size": Vector2(64, 104),
			"margin_side": 12.0,
			"margin_top": 10.0,
			"separation": 3,
			"badge_size": 12.0,
			"badge_radius": 6,
			"tab_size": Vector2(46, 5),
			"token_size": 34,
			"font_size": 17,
			"visual_min_height": 44.0,
			"corner_inset": 7.0,
			"show_header": true,
		}
	return {
		"min_size": Vector2(74, 68),
		"margin_side": 18.0,
		"margin_top": 8.0,
		"separation": 2,
		"badge_size": 8.0,
		"badge_radius": 4,
		"tab_size": Vector2(38, 4),
		"token_size": 28,
		"font_size": 14,
		"visual_min_height": 34.0,
		"corner_inset": 2.0,
		"show_header": false,
	}

static func assumption_block(mode: String) -> Dictionary:
	if normalize(mode) == COMFORT:
		return {
			"min_size": Vector2(104, 92),
			"margin_side": 9.0,
			"margin_top": 7.0,
			"separation": 3,
			"badge_size": 10.0,
			"badge_radius": 5,
			"token_size": 24,
			"font_size": 13,
			"visual_min_height": 38.0,
			"corner_inset": 7.0,
			"show_header": true,
		}
	return {
		"min_size": Vector2(96, 68),
		"margin_side": 8.0,
		"margin_top": 6.0,
		"margin_right": 36.0,
		"separation": 2,
		"badge_size": 8.0,
		"badge_radius": 4,
		"token_size": 22,
		"font_size": 12,
		"visual_min_height": 34.0,
		"corner_inset": 2.0,
		"show_header": false,
	}

static func palette_formula(mode: String) -> Dictionary:
	if normalize(mode) == COMFORT:
		return {
			"min_size": Vector2(80, 84),
			"margin_side": 9.0,
			"margin_top": 8.0,
			"separation": 2,
			"badge_size": 10.0,
			"badge_radius": 5,
			"token_size": 28,
			"font_size": 14,
			"visual_min_height": 44.0,
			"corner_inset": 6.0,
			"show_header": true,
		}
	return {
		"min_size": Vector2(66, 64),
		"margin_side": 16.0,
		"margin_top": 6.0,
		"separation": 2,
		"badge_size": 8.0,
		"badge_radius": 4,
		"token_size": 28,
		"font_size": 14,
		"visual_min_height": 36.0,
		"corner_inset": 5.0,
		"show_header": false,
	}

static func palette_assumption(mode: String) -> Dictionary:
	var metrics := palette_formula(mode)
	if normalize(mode) == COMPACT:
		metrics["min_size"] = Vector2(66, 68)
		metrics["tag_font_size"] = 8
		metrics["header_separation"] = 2
	else:
		metrics["tag_font_size"] = 9
		metrics["header_separation"] = 3
	return metrics

## Only formula-leaf cards use this; rule cards keep UiStyle.card_style.
static func formula_card_style(bg: Color, border: Color, mode: String) -> StyleBoxFlat:
	var box := UiStyle.card_style(bg, border, 12)
	var metrics := formula_block(mode)
	box.content_margin_left = float(metrics["margin_side"])
	box.content_margin_right = float(metrics["margin_side"])
	box.content_margin_top = float(metrics["margin_top"])
	box.content_margin_bottom = float(metrics["margin_top"])
	return box

static func formula_card_style_with_margins(
	bg: Color,
	border: Color,
	mode: String,
	side: float,
	top: float
) -> StyleBoxFlat:
	var box := UiStyle.card_style(bg, border, 12)
	box.content_margin_left = side
	box.content_margin_right = side
	box.content_margin_top = top
	box.content_margin_bottom = top
	return box
