extends SceneTree

## Capture 1920x1080 promotional screenshots from real game states.
## Run the game renderer (not headless):
##   godot --path . -s res://tools/make_promo_screens.gd

const LevelBankRes = preload("res://ui/level_bank.gd")
const ParserRes = preload("res://logic/formula_parser.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/promo")
	)
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	root.add_child(main)
	await _wait(110)

	# 01 — title / menu
	await _shot("01-title")

	# Unlock enough progress to show a lived-in chapter browser.
	for chapter_id in ["ch1", "ch2", "ch3"]:
		main._progress.mark_intro_seen(chapter_id)
	for chapter_id in ["ch1", "ch2"]:
		for level in LevelBankRes.chapter_levels(chapter_id, false):
			main._progress.mark_completed(str(level.get("id", "")))
	var ch3_core := LevelBankRes.chapter_levels("ch3", false)
	for index in range(mini(3, ch3_core.size())):
		main._progress.mark_completed(str(ch3_core[index].get("id", "")))
	main._progress.mark_intro_seen("ch4")
	main._show_levels()
	main._level_page.refresh(main._progress, "ch3")
	await _wait(10)

	# 02 — chapter browser
	await _shot("02-chapters")

	# 03 — a completed case split with a green goal.
	main.open_level_by_id("ch3-3")
	await _wait(4)
	main._close_rule_intro()
	main._canvas_view.reset_view()
	var final_block := _build_case_split(main)
	main.goal_bar.set_linked_block(final_block)
	main.refresh_machine()
	await _wait(2)
	_center_proof(main, final_block, 0.82, Vector2(820, 330))
	await _wait(18)
	await _shot("03-proof")

	# 04 — assumption window with an inner proof.
	main.open_level_by_id("ch2-3")
	await _wait(4)
	main._close_rule_intro()
	main.open_scope_for_formula(_f("P"))
	await _wait(8)
	main._canvas_view.reset_view()
	var scope_block := _build_chain(main, Vector2.ZERO)
	await _wait(2)
	_center_proof(main, scope_block, 0.65, main._canvas_view.size * 0.5)
	await _wait(18)
	await _shot("04-assumption")
	main._close_all_scope_windows()
	await _wait(4)

	# 05 — formula builder with a valid preview.
	main.open_level_by_id("ch2-3")
	await _wait(4)
	main._close_rule_intro()
	main.open_assumption_builder()
	await _wait(8)
	if main._formula_builder != null:
		main._formula_builder._input_text = "P -> Q"
		main._formula_builder._refresh_preview()
	await _wait(10)
	await _shot("05-formula-builder")
	main._close_formula_builder()

	# 06 — chapter rule introduction card.
	main.open_level_by_id("ch4-1")
	await _wait(4)
	main._close_rule_intro()
	main._show_rule_intro("ch4", true)
	await _wait(8)
	await _shot("06-new-rules")

	main.queue_free()
	await process_frame
	quit()

func _build_case_split(main) -> Control:
	var rule = main.create_rule_block("or_elim_impl")
	main.canvas.add_child(rule)
	rule.sockets[0].attach_block(main.create_formula_block(_f("P | Q")), false)
	rule.sockets[1].attach_block(main.create_formula_block(_f("P -> R")), false)
	rule.sockets[2].attach_block(main.create_formula_block(_f("Q -> R")), false)
	rule.refresh()
	return rule

func _build_chain(main, origin: Vector2) -> Control:
	var p1 = main.create_formula_block(_f("P"))
	var p2 = main.create_formula_block(_f("P -> Q"))
	var p3 = main.create_formula_block(_f("Q -> R"))
	var impl1 = main.create_rule_block("impl_elim")
	var impl2 = main.create_rule_block("impl_elim")
	main.canvas.add_child(impl2)
	impl2.position = origin
	impl2.sockets[0].attach_block(impl1, false)
	impl2.sockets[1].attach_block(p3, false)
	impl1.sockets[0].attach_block(p1, false)
	impl1.sockets[1].attach_block(p2, false)
	impl2.refresh()
	impl2.reset_size()
	impl2.position = origin
	main.refresh_machine()
	return impl2

func _center_proof(main, block: Control, zoom: float, screen_center: Vector2) -> void:
	main._canvas_view.zoom = zoom
	main._canvas_view.world.scale = Vector2(zoom, zoom)
	var block_center := block.position + block.size * 0.5
	main._canvas_view.pan = screen_center - block_center * zoom
	main._canvas_view.world.position = main._canvas_view.pan

func _f(text: String):
	var parsed := ParserRes.new(text).parse()
	return parsed.formula

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame

func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_width() != 1920 or image.get_height() != 1080:
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	image.save_png("res://build/promo/%s.png" % name)
	print("saved ", name, " ", image.get_size())
