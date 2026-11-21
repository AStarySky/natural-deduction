extends Control

## Modal formula builder. Atoms and connectives are pressed as big blocks, or
## the formula is typed directly; the expression is parsed live and only a
## valid formula can be submitted.

signal submitted(formula)
signal cancelled
signal token_added(index: int, token: String)
signal token_undone
signal tokens_cleared
signal preview_changed(valid: bool)
signal key_typed(kind: String)
signal button_clicked
signal hovered

const FormulaRes = preload("res://logic/formula.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const CardWearRes = preload("res://ui/card_wear.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const UiStyle = preload("res://ui/ui_style.gd")

const CONNECTIVES := ["~", "&", "|", "->", "<->", "(", ")"]
const ATOM_COLORS := {
	"Rain": Color8(166, 211, 225),
	"Wet": Color8(123, 200, 232),
	"Slippery": Color8(255, 212, 94),
	"Dangerous": Color8(231, 154, 168),
}

var _atoms: Array[String] = []
var _input_text: String = ""
var _preview_visual = null
var _preview_label: Label = null
var _status_label: Label = null
var _done_button: Button = null
var _finished := false
var _preview_state := 0  # -1 empty, 0 invalid, 1 valid

func setup(atoms: Array[String]) -> void:
	_atoms = atoms.duplicate()
	if _atoms.is_empty():
		_atoms = ["A", "B"]
	add_to_group("nd_ui_overlay")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process_input(true)
	_build()

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.16, 0.10, 0.18, 0.42)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(720, 0)
	card.add_theme_stylebox_override("panel", UiStyle.empty_style())
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	CardWearRes.apply_to(card, 0x0B11D, UiStyle.cream())
	card.rotation = 0.0

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(header)

	var title := UiStyle.make_display_label("FORMULA BUILDER", 30, UiStyle.text_color())
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(44, 38)
	UiStyle.style_button(close, UiStyle.lavender(), 16)
	close.pressed.connect(_on_cancel)
	_bind_hover(close)
	header.add_child(close)

	var preview_panel := PanelContainer.new()
	preview_panel.custom_minimum_size = Vector2(0, 92)
	preview_panel.add_theme_stylebox_override(
		"panel",
		UiStyle.card_style(UiStyle.cream(), UiStyle.border_color(), 12)
	)
	preview_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(preview_panel)

	var preview_box := VBoxContainer.new()
	preview_box.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_box.add_theme_constant_override("separation", 2)
	preview_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_panel.add_child(preview_box)

	_preview_visual = FormulaVisualRes.new()
	_preview_visual.setup(null, 25, 14)
	_preview_visual.custom_minimum_size = Vector2(0, 46)
	_preview_visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview_visual.visible = false
	preview_box.add_child(_preview_visual)

	_preview_label = UiStyle.make_display_label(
		"Tap atoms and connectives, or type directly",
		16,
		UiStyle.muted_text()
	)
	_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_preview_label.clip_text = true
	_preview_label.custom_minimum_size = Vector2(0, 26)
	_preview_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_box.add_child(_preview_label)

	_status_label = UiStyle.make_display_label("", 12, UiStyle.muted_text())
	_status_label.custom_minimum_size = Vector2(0, 18)
	root.add_child(_status_label)

	root.add_child(_section_caption("ATOMS"))
	var atom_flow := HFlowContainer.new()
	atom_flow.add_theme_constant_override("h_separation", 8)
	atom_flow.add_theme_constant_override("v_separation", 8)
	atom_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(atom_flow)
	for atom in _atoms:
		atom_flow.add_child(_make_atom_button(atom))

	root.add_child(_section_caption("CONNECTIVES"))
	var op_flow := HFlowContainer.new()
	op_flow.add_theme_constant_override("h_separation", 8)
	op_flow.add_theme_constant_override("v_separation", 8)
	op_flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(op_flow)
	var op_colors := [
		UiStyle.lavender(),
		UiStyle.yellow(),
		UiStyle.lime(),
		UiStyle.sky(),
		UiStyle.coral(),
		UiStyle.cream(),
		UiStyle.cream(),
	]
	for index in range(CONNECTIVES.size()):
		var op: String = str(CONNECTIVES[index])
		var button := Button.new()
		button.text = op
		var button_width := 58.0 if op.length() <= 1 else 76.0
		button.custom_minimum_size = Vector2(button_width, 44)
		UiStyle.style_button(button, op_colors[index], 19)
		button.pressed.connect(_append_token.bind(op))
		_bind_button(button)
		op_flow.add_child(button)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(actions)

	var undo := Button.new()
	undo.text = "UNDO"
	undo.custom_minimum_size = Vector2(96, 42)
	UiStyle.style_button(undo, UiStyle.cream(), 14)
	undo.pressed.connect(_undo_token)
	_bind_button(undo)
	actions.add_child(undo)

	var clear := Button.new()
	clear.text = "CLEAR"
	clear.custom_minimum_size = Vector2(96, 42)
	UiStyle.style_button(clear, UiStyle.cream(), 14)
	clear.pressed.connect(_clear_tokens)
	_bind_button(clear)
	actions.add_child(clear)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.add_child(spacer)

	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(108, 42)
	UiStyle.style_button(cancel, UiStyle.lavender(), 15)
	cancel.pressed.connect(_on_cancel)
	_bind_hover(cancel)
	actions.add_child(cancel)

	_done_button = Button.new()
	_done_button.text = "DONE"
	_done_button.custom_minimum_size = Vector2(128, 46)
	UiStyle.style_button(_done_button, UiStyle.coral(), 18)
	_done_button.disabled = true
	_done_button.pressed.connect(_on_done)
	_bind_button(_done_button)
	actions.add_child(_done_button)

	_refresh_preview()

func _section_caption(text: String) -> Label:
	return UiStyle.make_display_label(text, 12, UiStyle.muted_text())

func _bind_hover(button: Button) -> void:
	button.mouse_entered.connect(func() -> void: hovered.emit())

## UI buttons click; physical keyboard input keeps its typing sounds.
func _bind_button(button: Button) -> void:
	_bind_hover(button)
	button.pressed.connect(func() -> void: button_clicked.emit())

func _make_atom_button(atom: String) -> Button:
	var color: Color = ATOM_COLORS.get(atom, UiStyle.lavender())
	var button := Button.new()
	button.text = atom
	button.custom_minimum_size = Vector2(112, 46)
	button.tooltip_text = atom
	UiStyle.style_button(button, color, 15)
	button.pressed.connect(_append_token.bind(atom))
	_bind_button(button)
	return button

## Append a palette token, keeping binary connectives readable.
func _append_token(token: String) -> void:
	var insert := token
	if token in ["&", "|", "->", "<->"]:
		if (
			not _input_text.is_empty()
			and not _input_text.ends_with(" ")
			and not _input_text.ends_with("(")
			and not _input_text.ends_with("~")
		):
			insert = " " + insert
		insert += " "
	_input_text += insert
	token_added.emit(_input_text.length(), token)
	_refresh_preview()

## Remove the last typed character. Returns true when something changed.
func _undo_token() -> bool:
	if _input_text.is_empty():
		return false
	_input_text = _input_text.substr(0, _input_text.length() - 1)
	token_undone.emit()
	_refresh_preview()
	return true

func _clear_tokens() -> void:
	if _input_text.is_empty():
		return
	_input_text = ""
	tokens_cleared.emit()
	_refresh_preview()

func _expression_text() -> String:
	return _input_text.strip_edges()

## Append one keyboard character and refresh the parsed preview.
func _type_character(character: String) -> void:
	_input_text += character
	key_typed.emit("key")
	_refresh_preview()

## Modal keyboard input: the builder owns the keyboard while it is open.
## Printable characters feed the same expression buffer as the token buttons.
func _input(event: InputEvent) -> void:
	if _finished or not visible or not event is InputEventKey:
		return
	var key := event as InputEventKey
	if not key.pressed:
		return
	if key.keycode == KEY_BACKSPACE or key.keycode == KEY_DELETE:
		if _undo_token():
			key_typed.emit("back")
		get_viewport().set_input_as_handled()
		return
	if key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		_on_cancel()
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
		key_typed.emit("enter")
		_on_done()
		get_viewport().set_input_as_handled()
		return
	if key.unicode >= 32 and key.unicode != 127:
		_type_character(char(key.unicode))
		get_viewport().set_input_as_handled()

func _refresh_preview() -> void:
	if _done_button == null:
		return
	var expression := _expression_text()
	if expression.is_empty():
		_preview_visual.visible = false
		_preview_label.visible = true
		_preview_label.text = "Tap atoms and connectives, or type directly"
		_preview_label.add_theme_color_override("font_color", UiStyle.muted_text())
		_status_label.text = "EMPTY"
		_status_label.add_theme_color_override("font_color", UiStyle.muted_text())
		_done_button.disabled = true
		_preview_state = -1
		return

	var parsed := ParserRes.new(expression).parse()
	if parsed.ok:
		_preview_visual.set_formula(parsed.formula)
		_preview_visual.visible = true
		_preview_label.visible = false
		_status_label.text = "READY"
		_status_label.add_theme_color_override("font_color", UiStyle.valid_color())
		_done_button.disabled = false
		if _preview_state != 1:
			_preview_state = 1
			preview_changed.emit(true)
	else:
		_preview_visual.visible = false
		_preview_label.visible = true
		_preview_label.text = expression
		_preview_label.add_theme_color_override("font_color", UiStyle.text_color())
		_status_label.text = parsed.error
		_status_label.add_theme_color_override("font_color", UiStyle.error_color())
		_done_button.disabled = true
		if _preview_state != 0:
			_preview_state = 0
			preview_changed.emit(false)

func _on_done() -> void:
	if _finished:
		return
	var expression := _expression_text()
	if expression.is_empty():
		return
	var parsed := ParserRes.new(expression).parse()
	if not parsed.ok:
		return
	_finished = true
	submitted.emit(parsed.formula)

func _on_cancel() -> void:
	if _finished:
		return
	_finished = true
	cancelled.emit()
