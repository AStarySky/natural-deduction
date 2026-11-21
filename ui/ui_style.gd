extends RefCounted

## Wordatro-inspired visual tokens and small Control factories.
## Style only; all gameplay remains in the logic/board layer.

const DisplayFontRes = preload("res://ui/fonts/Baloo2-Variable.ttf")
const BodyFontRes = preload("res://ui/fonts/Nunito-Variable.ttf")
const HandFontRes = preload("res://ui/fonts/PatrickHand-Regular.ttf")

## --- Base surface colors -------------------------------------------------

static func background() -> Color:
	return Color8(166, 211, 225)

static func panel_background() -> Color:
	return Color8(247, 240, 227)

static func body_background() -> Color:
	return Color8(230, 217, 235)

static func text_color() -> Color:
	return Color8(46, 34, 48)

static func muted_text() -> Color:
	return Color8(118, 99, 124)

static func border_color() -> Color:
	return Color8(91, 63, 102)

static func accent() -> Color:
	return Color8(71, 158, 207)

static func valid_color() -> Color:
	return Color8(83, 181, 111)

static func error_color() -> Color:
	return Color8(212, 72, 91)

static func pending_color() -> Color:
	return Color8(224, 174, 55)

static func cream() -> Color:
	return Color8(247, 240, 227)

static func coral() -> Color:
	return Color8(231, 154, 168)

static func sky() -> Color:
	return Color8(166, 211, 225)

static func yellow() -> Color:
	return Color8(255, 212, 94)

static func lime() -> Color:
	return Color8(185, 241, 141)

static func lavender() -> Color:
	return Color8(199, 166, 216)

## Distinct pastel identities for nested assumption scopes.
static func scope_colors() -> Array:
	return [
		Color8(226, 211, 248),
		Color8(166, 211, 225),
		Color8(231, 154, 168),
		Color8(255, 212, 94),
		Color8(185, 241, 141),
		Color8(161, 230, 209),
		Color8(247, 194, 152),
	]

static func shadow_color() -> Color:
	return Color(0.25, 0.16, 0.28, 0.34)

## Rule body fill by logical family.
static func rule_color(rule_id: String) -> Color:
	if rule_id == "impl_elim" or rule_id == "impl_intro":
		return Color8(123, 200, 232)
	if rule_id == "and_elim_left" or rule_id == "and_elim_right":
		return Color8(255, 212, 94)
	if rule_id == "and_intro":
		return Color8(185, 241, 141)
	if rule_id.begins_with("or_intro"):
		return Color8(143, 227, 200)
	if rule_id == "ds" or rule_id == "or_elim":
		return Color8(143, 227, 200)
	if rule_id == "or_elim_impl":
		return Color8(161, 230, 209)
	if rule_id == "iff_intro":
		return Color8(199, 166, 216)
	if rule_id == "iff_intro_impl":
		return Color8(214, 185, 228)
	if rule_id == "iff_elim":
		return Color8(231, 154, 168)
	if rule_id == "not_intro" or rule_id == "not_elim":
		return Color8(246, 204, 141)
	if rule_id == "not_intro_impl" or rule_id == "not_elim_impl":
		return Color8(248, 198, 150)
	if rule_id == "lem":
		return Color8(246, 204, 141)
	if rule_id.begins_with("double_neg"):
		return Color8(199, 166, 216)
	return body_background()

## --- Fonts ---------------------------------------------------------------

static func display_font(weight: int = 800) -> Font:
	var font := FontVariation.new()
	font.base_font = DisplayFontRes
	font.variation_opentype = {"wght": weight}
	return font

static func body_font(weight: int = 800) -> Font:
	var font := FontVariation.new()
	font.base_font = BodyFontRes
	font.variation_opentype = {"wght": weight}
	return font

static func hand_font() -> Font:
	return HandFontRes

## System emoji font used for proposition pictures. Godot's SystemFont picks
## the platform's color emoji face when available.
static func emoji_font() -> Font:
	var font := SystemFont.new()
	font.font_names = PackedStringArray([
		"Segoe UI Emoji",
		"Apple Color Emoji",
		"Noto Color Emoji",
		"Noto Emoji",
	])
	return font

## --- Styleboxes ----------------------------------------------------------

## Thick-outlined, softly shadowed paper panel. Callers get a fresh box.
static func panel_style(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	radius: int = 12,
	border_width: int = 3,
	with_shadow: bool = true
) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	box.content_margin_left = 10.0
	box.content_margin_top = 8.0
	box.content_margin_right = 10.0
	box.content_margin_bottom = 8.0
	if with_shadow:
		box.shadow_color = shadow_color()
		box.shadow_size = 4
		box.shadow_offset = Vector2(3, 4)
	return box

## Chunky tile/card: thicker outline and a touch more rounding.
static func card_style(bg: Color, border: Color = border_color(), radius: int = 14) -> StyleBoxFlat:
	var box := panel_style(bg, border, radius, 4, true)
	box.content_margin_left = 12.0
	box.content_margin_top = 10.0
	box.content_margin_right = 12.0
	box.content_margin_bottom = 10.0
	return box

## Inset slot/socket: cream or tinted with a plum rim.
static func slot_style(bg: Color = Color(1, 1, 1, 0.28), border: Color = border_color()) -> StyleBoxFlat:
	var box := panel_style(bg, border, 10, 3, false)
	box.content_margin_left = 6.0
	box.content_margin_top = 5.0
	box.content_margin_right = 6.0
	box.content_margin_bottom = 5.0
	return box

static func empty_style() -> StyleBoxEmpty:
	return StyleBoxEmpty.new()

## --- Labels --------------------------------------------------------------

static func make_label(text: String, font_size: int = 15) -> Label:
	return make_label_colored(text, font_size, text_color())

## Body label using Nunito (badges, status, small supporting text).
static func make_label_colored(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", body_font(800))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Chunky display label using Baloo 2 (titles, formulas, results).
static func make_display_label(text: String, font_size: int, color: Color = Color(0, 0, 0, 1)) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", display_font(800))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color() if color.a == 0.0 else color)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## White/cream title with a thick plum outline, like Wordatro headings.
static func make_outlined_title(text: String, font_size: int, fill: Color = cream()) -> Label:
	var label := make_display_label(text, font_size, fill)
	label.add_theme_color_override("font_outline_color", border_color())
	label.add_theme_constant_override("outline_size", maxi(4, int(font_size * 0.18)))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label

## Marker/handwritten hint using Patrick Hand.
static func make_hint(text: String, font_size: int = 13) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", display_font(800))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", border_color())
	label.clip_text = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(0, font_size + 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

## Small formula text factory (content labels on tiles and result strips).
static func make_formula_label(text: String, font_size: int = 15, color: Color = Color(0, 0, 0, 1)) -> Label:
	var label := make_display_label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

## --- Misc factories ------------------------------------------------------

static func make_drag_preview(text: String, accent_color: Color) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		card_style(cream(), accent_color, 12)
	)
	panel.custom_minimum_size = Vector2(190, 44)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1.0, 1.0, 1.0, 0.92)
	var label := make_display_label(text, 15, text_color())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(label)
	return panel

## Apply the chunky Wordatro-style button skin to a standard Button.
static func style_button(button: Button, bg: Color, font_size: int = 16) -> void:
	button.add_theme_font_override("font", display_font(800))
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", text_color())
	button.add_theme_color_override("font_hover_color", text_color())
	button.add_theme_color_override("font_pressed_color", text_color())
	button.add_theme_color_override("font_focus_color", text_color())
	button.add_theme_stylebox_override(
		"normal",
		panel_style(bg, border_color(), 12, 3, true)
	)
	button.add_theme_stylebox_override(
		"hover",
		panel_style(bg.lightened(0.14), border_color(), 12, 3, true)
	)
	button.add_theme_stylebox_override(
		"pressed",
		panel_style(bg.darkened(0.08), border_color(), 12, 3, true)
	)
	button.add_theme_stylebox_override(
		"focus",
		panel_style(bg, accent(), 12, 3, true)
	)

static func state_color(is_valid: bool, has_error: bool, is_pending: bool) -> Color:
	if has_error:
		return error_color()
	if is_valid:
		return valid_color()
	if is_pending:
		return pending_color()
	return border_color()
