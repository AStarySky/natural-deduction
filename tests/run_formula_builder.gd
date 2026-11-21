extends SceneTree

## Headless checks for the modal formula builder: palette insertion, direct
## keyboard input, live validation, typing-cue signals and submission.

const BuilderRes = preload("res://ui/formula_builder.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var builder = BuilderRes.new()
	builder.setup(["A", "B"])
	root.add_child(builder)
	await process_frame
	await process_frame

	_check(builder._done_button.disabled, "empty builder cannot submit")

	var atom_button: Button = null
	for child in builder.find_children("*", "Button", true, false):
		if child is Button and child.text == "A":
			atom_button = child
			break
	_check(atom_button != null, "atom button exists")
	var button_clicks := [0]
	builder.button_clicked.connect(func() -> void: button_clicks[0] += 1)
	if atom_button != null:
		atom_button.pressed.emit()
	_check(button_clicks[0] == 1, "palette button emits a button-click cue")
	_check(builder._input_text == "A", "palette button appends its atom")
	builder._clear_tokens()

	builder._append_token("A")
	builder._append_token("&")
	builder._append_token("B")
	_check(builder._input_text == "A & B", "palette insert builds 'A & B'")
	_check(builder._preview_state == 1, "palette expression parses")
	_check(not builder._done_button.disabled, "valid palette expression enables DONE")

	builder._undo_token()
	_check(builder._input_text.begins_with("A &"), "UNDO removes one character")
	builder._clear_tokens()
	_check(builder._input_text == "", "CLEAR empties the buffer")
	_check(builder._done_button.disabled, "empty input disables DONE")

	_type_text(builder, "A -> (B & A)")
	_check(builder._input_text == "A -> (B & A)", "keyboard fills the expression buffer")
	_check(builder._preview_state == 1, "typed expression parses live")
	_check(not builder._done_button.disabled, "typed valid expression enables DONE")

	builder._clear_tokens()
	_type_text(builder, "A ->")
	_check(builder._preview_state == 0, "incomplete typed expression is invalid")
	_check(builder._done_button.disabled, "invalid typed expression disables DONE")

	builder._clear_tokens()
	var keys: Array[String] = []
	var undos := [0]
	builder.key_typed.connect(func(kind: String) -> void: keys.append(kind))
	builder.token_undone.connect(func() -> void: undos[0] += 1)
	_type_text(builder, "A")
	_check(keys == ["key"], "typing emits a key cue")
	_press(builder, KEY_BACKSPACE)
	_check(builder._input_text == "", "keyboard backspace removes a character")
	_check(keys == ["key", "back"], "backspace emits a typing cue")
	_check(undos[0] == 1, "backspace still updates the buffer")

	var submitted: Array = []
	builder.submitted.connect(func(formula) -> void: submitted.append(formula))
	_type_text(builder, "A -> B")
	_press(builder, KEY_ENTER)
	_check(keys.has("enter"), "Enter emits a key cue")
	_check(submitted.size() == 1, "Enter submits exactly once")
	if submitted.size() == 1:
		_check(submitted[0].to_string() == "A -> B", "submitted formula matches typed text")

	builder.queue_free()
	await process_frame
	print("FORMULA BUILDER RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

## Send one printable character per code point through the modal input path.
func _type_text(builder, text: String) -> void:
	for index in range(text.length()):
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = text.unicode_at(index)
		builder._input(key)

func _press(builder, keycode: int) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	builder._input(key)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FORMULA BUILDER CHECK FAILED: " + label)
