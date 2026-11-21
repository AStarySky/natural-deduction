extends SceneTree

## Recorded walkthrough for the five-level Assume nesting layout.
## Run with:
##   godot --windowed --resolution 1280x720 \
##     --write-movie build/promo/nested-five.avi --fixed-fps 30 \
##     -s res://tools/record_nested_five.gd

const ParserRes = preload("res://logic/formula_parser.gd")
const UiStyle = preload("res://ui/ui_style.gd")

var _main = null
var _caption: Label = null

func _initialize() -> void:
	call_deferred("_run")

func _f(text: String):
	return ParserRes.new(text).parse().formula

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _label(text: String) -> void:
	if _caption != null:
		_caption.text = text

func _run() -> void:
	_main = load("res://ui/main.tscn").instantiate()
	_main.progress_path = ""
	root.add_child(_main)
	await _wait(20)

	_caption = UiStyle.make_display_label("", 18, UiStyle.text_color())
	_caption.z_index = 300
	_caption.position = Vector2(310, 88)
	_caption.custom_minimum_size = Vector2(700, 28)
	_caption.clip_text = false
	_caption.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_color_override("font_outline_color", Color(1.0, 0.98, 0.92, 0.85))
	_caption.add_theme_constant_override("outline_size", 5)
	_main._game_page.add_child(_caption)

	_main.open_level_by_id("ch2-1")
	await _wait(16)
	_main._close_rule_intro()
	await _wait(16)

	_label("Five nested Assume windows")
	var records: Array = []
	for text in ["P", "Q", "R", "S", "T"]:
		_main.open_scope_for_formula(_f(text))
		await _wait(18)
		records.append(_main._scope_open[-1])
	_label("P > Q > R > S > T")
	await _wait(30)

	for index in range(records.size() - 1, -1, -1):
		_label("Maximize " + ["P", "Q", "R", "S", "T"][index])
		_main.maximize_scope_window(records[index]["window"])
		await _wait(28)

	_label("All five maximized; fullscreen P")
	await _wait(30)
	_label("Restore P; descendants stay maximized")
	_main.resume_scope_window(records[0]["window"])
	await _wait(34)

	_label("Fullscreen P again")
	_main.maximize_scope_window(records[0]["window"])
	await _wait(30)
	_label("Restore Q only")
	_main.resume_scope_window(records[1]["window"])
	await _wait(34)
	_label("Restore R only")
	_main.resume_scope_window(records[2]["window"])
	await _wait(34)
	_label("Restore S only")
	_main.resume_scope_window(records[3]["window"])
	await _wait(34)
	_label("Restore T only")
	_main.resume_scope_window(records[4]["window"])
	await _wait(34)

	_label("Re-maximize Q: every descendant updates")
	_main.maximize_scope_window(records[1]["window"])
	await _wait(34)
	_label("Restore Q again")
	_main.resume_scope_window(records[1]["window"])
	await _wait(30)

	_label("Five-level propagation complete")
	await _wait(40)
	_main._close_all_scope_windows()
	await _wait(20)
	_main.queue_free()
	await process_frame
	quit()
