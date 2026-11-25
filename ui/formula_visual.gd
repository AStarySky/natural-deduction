extends HBoxContainer

## Render a Formula AST as atom pictures plus logical connectives.
## Known demo atoms use SVG pictograms; other atoms fall back to a tiny
## letter tile so arbitrary player-typed formulas remain readable.

const FormulaRes = preload("res://logic/formula.gd")
const FormulaArrowRes = preload("res://ui/formula_arrow.gd")
const UiStyle = preload("res://ui/ui_style.gd")

const PROP_EMOJI := {
	"Rain": "🌧️",
	"Wet": "💧",
	"Slippery": "🍌",
	"Dangerous": "⚠️",
}

const PROP_FALLBACK := {
	"Rain": preload("res://ui/props/rain.svg"),
	"Wet": preload("res://ui/props/wet.svg"),
	"Slippery": preload("res://ui/props/slippery.svg"),
	"Dangerous": preload("res://ui/props/dangerous.svg"),
}

var _formula = null
var _token_size: int = 18
var _font_size: int = 11

func setup(formula, token_size: int = 18, font_size: int = 11) -> void:
	_token_size = token_size
	_font_size = font_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 3)
	_formula = formula
	_rebuild()

## Change only the visual scale and rebuild the token row. Used by formula
## leaf cards when the Compact/Comfort density changes at runtime.
func set_metrics(token_size: int, font_size: int, min_height: float = 0.0) -> void:
	if min_height > 0.0:
		custom_minimum_size.y = min_height
	if token_size == _token_size and font_size == _font_size:
		return
	_token_size = token_size
	_font_size = font_size
	_rebuild()

func set_formula(formula) -> void:
	if _formula != null and formula != null and _formula.equals(formula):
		return
	if _formula == null and formula == null:
		return
	_formula = formula
	_rebuild()

func get_formula_text() -> String:
	return _formula.to_display_string() if _formula != null else ""

func _rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	tooltip_text = get_formula_text()
	if _formula == null:
		add_child(_make_operator("?", 1.0))
		return
	_emit(_formula, -1)

func _emit(node, parent_prec: int) -> void:
	match node.kind:
		FormulaRes.Kind.ATOM:
			add_child(_make_atom(node.atom_name))
		FormulaRes.Kind.NOT:
			add_child(_make_operator("~", 1.0))
			var wrap := _is_binary(node.left)
			if wrap:
				add_child(_make_operator("(", 1.0))
			_emit(node.left, 4)
			if wrap:
				add_child(_make_operator(")", 1.0))
		FormulaRes.Kind.AND, FormulaRes.Kind.OR, FormulaRes.Kind.IMPLIES, FormulaRes.Kind.IFF:
			var prec := _prec(node.kind)
			var left_wrap := _needs_parens(node.left, prec)
			if left_wrap:
				add_child(_make_operator("(", 1.0))
			_emit(node.left, prec)
			if left_wrap:
				add_child(_make_operator(")", 1.0))
			var op_scale := 1.18 if node.kind in [FormulaRes.Kind.IMPLIES, FormulaRes.Kind.IFF] else 1.0
			add_child(_make_operator(_symbol(node.kind), op_scale))
			var right_wrap := _needs_parens(node.right, prec)
			if right_wrap:
				add_child(_make_operator("(", 1.0))
			_emit(node.right, prec)
			if right_wrap:
				add_child(_make_operator(")", 1.0))

func _make_atom(atom_name: String) -> Control:
	if PROP_EMOJI.has(atom_name):
		var emoji_text: String = PROP_EMOJI[atom_name]
		var emoji_font := UiStyle.emoji_font()
		if emoji_font.has_char(emoji_text.unicode_at(0)):
			var emoji := Label.new()
			emoji.text = emoji_text
			emoji.add_theme_font_override("font", emoji_font)
			emoji.add_theme_font_size_override("font_size", maxi(14, _token_size - 2))
			emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			emoji.custom_minimum_size = Vector2(_token_size, _token_size)
			emoji.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
			emoji.tooltip_text = atom_name
			return emoji
		if PROP_FALLBACK.has(atom_name):
			var icon := TextureRect.new()
			icon.texture = PROP_FALLBACK[atom_name]
			icon.custom_minimum_size = Vector2(_token_size, _token_size)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			icon.tooltip_text = atom_name
			return icon

	var tile := PanelContainer.new()
	tile.custom_minimum_size = Vector2(_token_size + 6, _token_size + 4)
	tile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.tooltip_text = atom_name
	var tile_box := UiStyle.panel_style(UiStyle.cream(), UiStyle.border_color(), 5, 2, false)
	tile_box.content_margin_left = 4.0
	tile_box.content_margin_top = 2.0
	tile_box.content_margin_right = 4.0
	tile_box.content_margin_bottom = 2.0
	tile.add_theme_stylebox_override("panel", tile_box)
	var abbreviation := atom_name
	if abbreviation.length() > 3:
		abbreviation = abbreviation.substr(0, 2) + "…"
	var label := UiStyle.make_display_label(
		abbreviation,
		maxi(8, _font_size - 1),
		UiStyle.text_color()
	)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tile.add_child(label)
	return tile

func _make_operator(text: String, scale: float) -> Control:
	if text == "→" or text == "↔":
		var arrow := FormulaArrowRes.new()
		arrow.setup(
			text == "↔",
			maxf(18.0, _token_size * 0.72),
			maxf(12.0, _token_size * 0.48),
			clampf(_font_size * 0.16, 2.0, 3.2)
		)
		return arrow
	var size := maxi(9, int(_font_size * scale))
	var label := UiStyle.make_display_label(text, size, UiStyle.border_color())
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(maxf(size * 0.95, size * 0.55 * text.length()), size + 3)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _prec(kind: int) -> int:
	match kind:
		FormulaRes.Kind.NOT:
			return 4
		FormulaRes.Kind.AND:
			return 3
		FormulaRes.Kind.OR:
			return 2
		FormulaRes.Kind.IMPLIES:
			return 1
		FormulaRes.Kind.IFF:
			return 0
	return 5

func _is_binary(node) -> bool:
	return node != null and node.kind in [
		FormulaRes.Kind.AND,
		FormulaRes.Kind.OR,
		FormulaRes.Kind.IMPLIES,
	]

func _needs_parens(node, parent_prec: int) -> bool:
	if node == null or node.kind == FormulaRes.Kind.ATOM or node.kind == FormulaRes.Kind.NOT:
		return false
	return _prec(node.kind) <= parent_prec

func _symbol(kind: int) -> String:
	match kind:
		FormulaRes.Kind.AND:
			return "&"
		FormulaRes.Kind.OR:
			return "|"
		FormulaRes.Kind.IMPLIES:
			return "→"
		FormulaRes.Kind.IFF:
			return "↔"
	return "?"
