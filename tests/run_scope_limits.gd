extends SceneTree

## Stress the Assume-window stack at its hard limit: containment, rejected
## sixth window, rejected premature DONE, recursive close, and full undo.

const ParserRes = preload("res://logic/formula_parser.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	await _run()
	print("SCOPE LIMITS RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("SCOPE LIMIT CHECK FAILED: " + label)

func _f(text: String):
	return ParserRes.new(text).parse().formula

func _open_five(main) -> Array:
	var records: Array = []
	for text in ["P", "Q", "R", "S", "T"]:
		main.open_scope_for_formula(_f(text))
		await process_frame
		await process_frame
		records.append(main._scope_open[-1])
	return records

func _inside(inner: Control, outer: Control) -> bool:
	return outer.get_global_rect().encloses(inner.get_global_rect())

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await process_frame
	await process_frame
	main.open_level(0)
	await process_frame
	await process_frame

	var records := await _open_five(main)
	_check(main._scope_open.size() == 5, "five windows reach the depth limit")
	for index in range(records.size()):
		var window = records[index]["window"]
		_check(window.size.x > 0.0 and window.size.y > 0.0, "depth %d has positive size" % (index + 1))
		var parent = window.get_parent()
		_check(
			parent is Control and _inside(window, parent),
			"depth %d stays inside its parent" % (index + 1)
		)
		if index > 0:
			_check(bool(records[index]["nested"]), "depth %d is a contained window" % (index + 1))

	main.open_scope_for_formula(_f("U"))
	await process_frame
	_check(main._scope_open.size() == 5, "sixth window is rejected")
	_check(
		main._toast_label.text == "Too many open assumption windows, no way.",
		"sixth window explains the limit"
	)

	main.finish_scope_window(records[0]["window"])
	await process_frame
	_check(main._scope_open.size() == 5, "premature DONE does not close the stack")
	_check(
		records[0]["window"]._status.text == "close nested assumptions first",
		"premature DONE explains the nested dependency"
	)

	for index in range(4, -1, -1):
		main._on_undo()
		await process_frame
	_check(main._scope_open.is_empty(), "five undo steps close every window")
	_check(main.canvas == main._base_canvas, "undo returns to the base canvas")

	main._clear_undo_history()
	records = await _open_five(main)
	main.close_scope_window(records[0]["window"])
	await process_frame
	_check(main._scope_open.is_empty(), "closing the outer window recursively closes children")
	_check(main.canvas == main._base_canvas, "recursive close returns to the base canvas")

	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
