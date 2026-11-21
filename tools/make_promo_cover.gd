extends SceneTree

## Render a 1260x1000 key-art cover, then a 630x500 itch.io cover.
## The pile is made from the game's real RuleBlock / FormulaBlock components:
## several complete nested proof chains are laid across a wooden desk, with
## the two-line title on a paper sheet on top.
## Run the game renderer (not headless):
##   godot --path . -s res://tools/make_promo_cover.gd

const UiStyle = preload("res://ui/ui_style.gd")
const CardWearRes = preload("res://ui/card_wear.gd")
const RuleBlockRes = preload("res://ui/rule_block.gd")
const FormulaBlockRes = preload("res://ui/formula_block.gd")
const AssumptionBlockRes = preload("res://ui/assumption_block.gd")
const ScopeWindowRes = preload("res://ui/scope_window.gd")
const ParserRes = preload("res://logic/formula_parser.gd")
const DeskRes = preload("res://tools/promo_desk.gd")
const PencilArrowRes = preload("res://tools/promo_pencil.gd")

const COVER_SIZE := Vector2i(1260, 1000)
## Render the same composition at 2x for a high-resolution cover source.
const RENDER_SCALE := 2
const RENDER_SIZE := Vector2i(COVER_SIZE.x * RENDER_SCALE, COVER_SIZE.y * RENDER_SCALE)
const FORMULA_SCALE := 0.85

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("res://build/promo")
	)
	var viewport := SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var cover := Control.new()
	cover.custom_minimum_size = Vector2(COVER_SIZE)
	cover.size = Vector2(COVER_SIZE)
	cover.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport.add_child(cover)

	var desk = DeskRes.new()
	cover.add_child(desk)
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var pieces := _build_pile(cover)
	var scopes := _build_scope_windows(cover)
	await _wait(8)
	for piece in pieces:
		_place(piece)
	for scope_piece in scopes:
		_place(scope_piece)
	_build_title(cover)
	var intrusions := _build_title_intrusions(cover)
	await _wait(4)
	for intrusion in intrusions:
		_place(intrusion)

	var pencil = PencilArrowRes.new()
	pencil.setup_arc_v(
		Vector2(880, 505),
		70.0,
		Vector2(915, 475),
		Vector2(985, 475)
	)
	pencil.position = Vector2.ZERO
	pencil.size = Vector2(COVER_SIZE)
	pencil.z_index = 30
	cover.add_child(pencil)

	for i in range(14):
		await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.save_png("res://build/promo/cover-2520x2000.png")
	var standard := image.duplicate()
	standard.resize(1260, 1000, Image.INTERPOLATE_LANCZOS)
	standard.save_png("res://build/promo/cover-1260x1000.png")
	var small := image.duplicate()
	small.resize(630, 500, Image.INTERPOLATE_LANCZOS)
	small.save_png("res://build/promo/cover-630x500.png")
	print("cover saved ", image.get_size(), " -> ", standard.get_size(), " -> ", small.get_size())
	quit()

func _build_pile(cover: Control) -> Array:
	var pieces: Array = []

	# Real nested proof trees, inspired by the harder exercises in NDpack.pdf:
	# De Morgan, biconditional chaining, disjunction case work and distribution.
	var de_morgan := _de_morgan_tree()
	cover.add_child(de_morgan)
	pieces.append(_piece(de_morgan, Vector2(235, 175), FORMULA_SCALE, -14.0))

	var biconditional := _biconditional_tree()
	cover.add_child(biconditional)
	pieces.append(_piece(biconditional, Vector2(1115, 100), FORMULA_SCALE, 12.0))

	var distribution := _distribution_tree()
	cover.add_child(distribution)
	pieces.append(_piece(distribution, Vector2(235, 825), FORMULA_SCALE, 8.0))

	var cases := _disjunction_tree()
	cover.add_child(cases)
	pieces.append(_piece(cases, Vector2(1025, 825), FORMULA_SCALE, -10.0))



	return pieces

func _piece(node: Control, center: Vector2, scale_value: float, angle: float) -> Dictionary:
	return {
		"node": node,
		"center": center,
		"scale": scale_value,
		"rotation": angle,
	}

func _place(piece: Dictionary) -> void:
	var node: Control = piece["node"]
	node.reset_size()
	node.pivot_offset = node.size * 0.5
	node.position = Vector2(piece["center"]) - node.size * 0.5
	node.scale = Vector2(float(piece["scale"]), float(piece["scale"]))
	node.rotation = deg_to_rad(float(piece["rotation"]))

func _make_rule(rule_id: String) -> Control:
	var block := RuleBlockRes.new()
	block.setup(rule_id, null)
	return block

func _f(text: String):
	var parsed := ParserRes.new(text).parse()
	return parsed.formula

func _formula_block(text: String) -> Control:
	var block := FormulaBlockRes.new()
	block.setup(_f(text))
	return block

## De Morgan-style tree (NDpack 4.6 #8):
## ~(P | Q)  |-  ~P & ~Q, built from the two implication pairs.
func _de_morgan_tree() -> Control:
	var not_p := _make_rule("not_intro_impl")
	not_p.sockets[0].attach_block(_formula_block("P -> (P | Q)"), false)
	not_p.sockets[1].attach_block(_formula_block("P -> ~(P | Q)"), false)
	not_p.refresh()

	var not_q := _make_rule("not_intro_impl")
	not_q.sockets[0].attach_block(_formula_block("Q -> (P | Q)"), false)
	not_q.sockets[1].attach_block(_formula_block("Q -> ~(P | Q)"), false)
	not_q.refresh()

	var root := _make_rule("and_intro")
	root.sockets[0].attach_block(not_p, false)
	root.sockets[1].attach_block(not_q, false)
	root.refresh()
	return root

## Biconditional chain: two implications become P <-> Q, then a mixed
## elim/intro/or path gives (Q & R) | S.
func _biconditional_tree() -> Control:
	var iff := _make_rule("iff_intro_impl")
	iff.sockets[0].attach_block(_formula_block("P -> Q"), false)
	iff.sockets[1].attach_block(_formula_block("Q -> P"), false)
	iff.refresh()

	var elim := _make_rule("iff_elim")
	elim.sockets[0].attach_block(_formula_block("P"), false)
	elim.sockets[1].attach_block(iff, false)
	elim.refresh()

	var and_node := _make_rule("and_intro")
	and_node.sockets[0].attach_block(elim, false)
	and_node.sockets[1].attach_block(_formula_block("R"), false)
	and_node.refresh()

	var or_node := _make_rule("or_intro_left")
	or_node.sockets[0].attach_block(and_node, false)
	or_node.set_extra_formula(_f("S"))
	or_node.refresh()
	return or_node

## Distribution tree (NDpack 4.4 #8):
## P & (Q | R)  |-  (P & Q) | (P & R)
func _distribution_tree() -> Control:
	var right := _make_rule("and_elim_right")
	right.sockets[0].attach_block(_formula_block("P & (Q | R)"), false)
	right.refresh()

	var root := _make_rule("or_elim_impl")
	root.sockets[0].attach_block(right, false)
	root.sockets[1].attach_block(
		_formula_block("Q -> ((P & Q) | (P & R))"),
		false
	)
	root.sockets[2].attach_block(
		_formula_block("R -> ((P & Q) | (P & R))"),
		false
	)
	root.refresh()
	return root

## Disjunction case work: or-elim to R, and-intro with S, or-intro with T.
func _disjunction_tree() -> Control:
	var cases := _make_rule("or_elim_impl")
	cases.sockets[0].attach_block(_formula_block("P | Q"), false)
	cases.sockets[1].attach_block(_formula_block("P -> R"), false)
	cases.sockets[2].attach_block(_formula_block("Q -> R"), false)
	cases.refresh()

	var and_node := _make_rule("and_intro")
	and_node.sockets[0].attach_block(cases, false)
	and_node.sockets[1].attach_block(_formula_block("S"), false)
	and_node.refresh()

	var or_node := _make_rule("or_intro_left")
	or_node.sockets[0].attach_block(and_node, false)
	or_node.set_extra_formula(_f("T"))
	or_node.refresh()
	return or_node

## Peirce-flavoured indirect proof: not-intro gives ~~P, then double-negation.
func _peirce_tree() -> Control:
	var intro := _make_rule("not_intro_impl")
	intro.sockets[0].attach_block(_formula_block("~P -> P"), false)
	intro.sockets[1].attach_block(_formula_block("~P -> ~P"), false)
	intro.refresh()

	var root := _make_rule("double_neg_elim")
	root.sockets[0].attach_block(intro, false)
	root.refresh()
	return root

func _build_scope_windows(cover: Control) -> Array:
	return [
		_scope_cluster(
			cover, "P", "Q", Vector2(630, 250), FORMULA_SCALE, 0.0,
			Color8(226, 211, 248), Color8(166, 211, 225), true
		),
		_scope_cluster(
			cover, "R", "S", Vector2(630, 980), FORMULA_SCALE, 0.0,
			Color8(231, 154, 168), Color8(185, 241, 141), false
		),
	]

func _scope_cluster(
	cover: Control,
	outer_formula: String,
	inner_formula: String,
	center: Vector2,
	scale_value: float,
	angle: float,
	outer_tint: Color,
	inner_tint: Color,
	double_layer: bool
) -> Dictionary:
	var outer = ScopeWindowRes.new()
	outer.setup_window(null, _f(outer_formula), 1, outer_tint)
	outer.custom_minimum_size = Vector2(680, 570)
	outer.size = Vector2(680, 570)
	cover.add_child(outer)

	if double_layer:
		_add_scope_proof(
			outer.inner_canvas,
			_scope_chain_proof(outer_formula, inner_formula, 1),
			Vector2(30, 32)
		)
		var nested = ScopeWindowRes.new()
		nested.setup_window(null, _f(inner_formula), 2, inner_tint)
		outer.desktop_layer.add_child(nested)
		var bounds := Vector2(660, 480)
		nested.configure_contained(bounds)
		var nested_pos: Vector2 = (bounds - nested.size) * 0.5 + Vector2(58, 0)
		nested_pos.x = clampf(nested_pos.x, 0.0, maxf(0.0, bounds.x - nested.size.x))
		nested_pos.y = clampf(nested_pos.y, 0.0, maxf(0.0, bounds.y - nested.size.y))
		nested.position = nested_pos
		_add_scope_proof(
			nested.inner_canvas,
			_scope_chain_proof(inner_formula, "R", 2),
			Vector2(24, 28)
		)
	else:
		_add_scope_proof(
			outer.inner_canvas,
			_scope_single_proof(outer_formula, 3),
			Vector2(30, 0)
		)

	return _piece(outer, center, scale_value, angle)

func _add_scope_proof(canvas: Control, proof: Control, position: Vector2) -> void:
	canvas.add_child(proof)
	proof.reset_size()
	proof.position = position
	proof.scale = Vector2.ONE

func _assumption_block(text: String, group: int) -> Control:
	var block := AssumptionBlockRes.new()
	block.setup_assumption(_f(text), group)
	return block

func _scope_chain_proof(left_formula: String, right_formula: String, group: int) -> Control:
	var rule := _make_rule("impl_elim")
	rule.sockets[0].attach_block(_assumption_block(left_formula, group), false)
	rule.sockets[1].attach_block(
		_formula_block("%s -> %s" % [left_formula, right_formula]),
		false
	)
	rule.refresh()
	return rule

func _scope_single_proof(assumption: String, group: int) -> Control:
	var and_node := _make_rule("and_intro")
	and_node.sockets[0].attach_block(_assumption_block(assumption, group), false)
	and_node.sockets[1].attach_block(_formula_block("S"), false)
	and_node.refresh()
	return and_node

func _add_window_chip(canvas: Control, text: String, position: Vector2) -> void:
	var chip := _formula_block(text)
	canvas.add_child(chip)
	chip.reset_size()
	chip.position = position
	chip.scale = Vector2.ONE
	chip.pivot_offset = Vector2.ZERO

func _negation_or_tree() -> Control:
	var not_p := _make_rule("not_intro_impl")
	not_p.sockets[0].attach_block(_formula_block("P -> Q"), false)
	not_p.sockets[1].attach_block(_formula_block("P -> ~Q"), false)
	not_p.refresh()

	var or_node := _make_rule("or_intro_left")
	or_node.sockets[0].attach_block(not_p, false)
	or_node.set_extra_formula(_f("Q"))
	or_node.refresh()

	var and_node := _make_rule("and_intro")
	and_node.sockets[0].attach_block(or_node, false)
	and_node.sockets[1].attach_block(_formula_block("R"), false)
	and_node.refresh()
	return and_node

## Actual cards placed after the title sheet, so they visibly intrude over
## its paper edges without covering the two title words.
func _build_title_intrusions(cover: Control) -> Array:
	var pieces: Array = []

	for item in [
		["P & (Q | R)", Vector2(242, 312), FORMULA_SCALE, 5.0],
		["(P | Q) & (P | R)", Vector2(1005, 322), FORMULA_SCALE, 6.0],
		["~(P | Q)", Vector2(228, 690), FORMULA_SCALE, -6.0],
		["(Q & R) | S", Vector2(1052, 704), FORMULA_SCALE, 6.0],
	]:
		var chip := _formula_block(str(item[0]))
		chip.z_index = 20
		cover.add_child(chip)
		pieces.append(_piece(chip, Vector2(item[1]), float(item[2]), float(item[3])))

	return pieces

func _build_title(cover: Control) -> void:
	var backing_sheet := _add_wear_sheet(
		cover,
		Vector2(155, 260),
		Vector2(950, 480),
		1.8,
		Color8(199, 166, 216, 138),
		0x71A1E
	)
	backing_sheet.z_index = 9
	var title_sheet := _add_wear_sheet(
		cover,
		Vector2(180, 280),
		Vector2(900, 440),
		-1.2,
		Color8(247, 240, 227, 252),
		0x5EED
	)
	title_sheet.z_index = 10
	_add_tape(title_sheet, Vector2(70, -7), Vector2(145, 21), -4.0, Color(0.906, 0.604, 0.659, 0.55))
	_add_tape(title_sheet, Vector2(680, -5), Vector2(135, 19), 3.0, Color(0.780, 0.651, 0.847, 0.55))

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_sheet.add_child(center)

	var title_box := VBoxContainer.new()
	title_box.alignment = BoxContainer.ALIGNMENT_CENTER
	title_box.add_theme_constant_override("separation", -110)
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(title_box)

	var natural := UiStyle.make_outlined_title("Natural", 150, UiStyle.coral())
	natural.clip_text = false
	natural.custom_minimum_size = Vector2(840, 160)
	natural.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	natural.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(natural)

	var deduction := UiStyle.make_outlined_title("Deduction", 150, UiStyle.lavender())
	deduction.clip_text = false
	deduction.custom_minimum_size = Vector2(840, 160)
	deduction.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deduction.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_box.add_child(deduction)

func _add_wear_sheet(
	parent: Control,
	position: Vector2,
	size: Vector2,
	angle: float,
	fill: Color,
	seed_value: int
) -> Control:
	var sheet := Control.new()
	sheet.position = position
	sheet.size = size
	sheet.custom_minimum_size = size
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(sheet)
	var paper = CardWearRes.apply_to(sheet, seed_value, fill)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.rotation = deg_to_rad(angle)
	return sheet

func _add_tape(parent: Control, position: Vector2, size: Vector2, angle: float, color: Color) -> void:
	var tape := ColorRect.new()
	tape.color = color
	tape.position = position
	tape.size = size
	tape.rotation = deg_to_rad(angle)
	tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tape)

func _wait(frames: int) -> void:
	for i in range(frames):
		await process_frame
