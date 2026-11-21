extends SceneTree

const ParserRes = preload("res://logic/formula_parser.gd")
const FormulaVisualRes = preload("res://ui/formula_visual.gd")
const UiStyle = preload("res://ui/ui_style.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/promo")
	)
	await _render_formula_pair()
	quit()

func _formula(text: String):
	return ParserRes.new(text).parse().formula

func _render_formula_pair() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 240)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	center.add_child(row)

	for text in ["P", "P -> Q"]:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(410, 145)
		panel.add_theme_stylebox_override(
			"panel",
			UiStyle.card_style(UiStyle.cream(), UiStyle.border_color(), 18)
		)
		row.add_child(panel)
		var visual = FormulaVisualRes.new()
		visual.setup(_formula(text), 32, 19)
		visual.custom_minimum_size = Vector2(0, 70)
		visual.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		visual.size_flags_vertical = Control.SIZE_EXPAND_FILL
		visual.alignment = BoxContainer.ALIGNMENT_CENTER
		panel.add_child(visual)

	for i in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://build/promo/report-formula-pair.png")
	print("report formula pair saved")
	viewport.queue_free()
