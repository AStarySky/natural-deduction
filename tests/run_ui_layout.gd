extends SceneTree

## Geometry contracts for the compact formula-leaf cards. These assertions
## intentionally read the shared CardMetrics values so a density change does
## not require duplicating literals in every test.

const ParserRes = preload("res://logic/formula_parser.gd")
const CardMetrics = preload("res://ui/card_metrics.gd")
const UiSettingsStoreRes = preload("res://ui/ui_settings_store.gd")
const PaletteItemRes = preload("res://ui/palette_item.gd")

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	await _run()
	print("UI LAYOUT RESULT: %d checks, %d failed" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("UI LAYOUT CHECK FAILED: " + label)

func _f(text: String):
	return ParserRes.new(text).parse().formula

func _run() -> void:
	var main = load("res://ui/main.tscn").instantiate()
	main.progress_path = ""
	main.settings_path = ""
	root.add_child(main)
	await process_frame
	await process_frame
	main.open_level(0)
	await process_frame
	await process_frame
	_check(main.get_card_size_mode() == CardMetrics.COMPACT, "card mode defaults to compact")

	var chip = main.create_formula_block(_f("P"))
	main._base_canvas.add_child(chip)
	chip.reset_size()
	_check(chip.custom_minimum_size == Vector2(74, 68), "compact FormulaBlock min size")
	_check(chip.get_combined_minimum_size() == Vector2(74, 68), "compact FormulaBlock combined min")
	_check(chip._visual._token_size == 28 and chip._visual._font_size == 14, "compact formula metrics")
	_check(chip._visual.custom_minimum_size.y == 34.0, "compact formula visual height")
	_check(not chip._header.visible, "compact formula header hidden")
	_check(not chip._corner_badge.visible, "atom formula hides corner badge")
	var compound = main.create_formula_block(_f("P -> Q"))
	main._base_canvas.add_child(compound)
	compound.reset_size()
	_check(compound._corner_badge.visible, "compound formula keeps corner badge")
	await process_frame
	var badge_rect: Rect2 = compound._corner_badge.get_global_rect()
	var card_rect: Rect2 = compound.get_global_rect()
	_check(
		badge_rect.get_center().distance_to(card_rect.position + Vector2(12, 12)) <= 1.0,
		"corner badge is centred on the rounded-corner arc"
	)
	_check(chip._tab.custom_minimum_size == Vector2(38, 4), "compact formula tab")
	var compact_style: StyleBoxFlat = chip.get_theme_stylebox("panel")
	_check(
		compact_style.content_margin_left == 18.0
		and compact_style.content_margin_top == 8.0,
		"compact formula content margins"
	)

	var assumption = main.create_assumption_block(_f("A"))
	main._base_canvas.add_child(assumption)
	assumption.reset_size()
	_check(assumption.custom_minimum_size == Vector2(74, 68), "compact AssumptionBlock matches FormulaBlock size")
	_check(not assumption._header.visible, "compact assumption header hidden")
	_check(not assumption._corner_badge.visible, "atom assumption hides corner badge")
	_check(assumption._visual._token_size == 28, "compact assumption formula metrics match")

	var premise = PaletteItemRes.new()
	premise.controller = main
	premise.setup_premise(_f("P -> Q"))
	main._premise_flow.add_child(premise)
	premise.reset_size()
	_check(premise.custom_minimum_size == Vector2(66, 64), "compact premise tile min size")
	_check(not premise._header.visible and premise._corner_badge.visible, "compact premise header collapsed")

	var rule_tile = PaletteItemRes.new()
	rule_tile.controller = main
	rule_tile.setup_rule("impl_elim")
	rule_tile.reset_size()
	_check(rule_tile.custom_minimum_size == Vector2(92, 112), "rule palette tile unchanged")

	var rule_card = main.create_rule_block("impl_elim")
	main._base_canvas.add_child(rule_card)
	rule_card.reset_size()
	var compact_rule_h: float = rule_card.size.y
	_check(not rule_card._header.visible, "compact rule header hidden")
	_check(rule_card._overlay.visible and rule_card._corner_copy.visible, "compact rule corner controls visible")

	main.set_card_size_mode(CardMetrics.COMFORT)
	await process_frame
	_check(main.get_card_size_mode() == CardMetrics.COMFORT, "comfort mode active")
	_check(chip.custom_minimum_size == Vector2(64, 104), "comfort FormulaBlock min size")
	_check(chip._visual._token_size == 34 and chip._visual._font_size == 17, "comfort formula metrics")
	_check(compound._header.visible and not compound._corner_badge.visible, "comfort formula header restored")
	_check(assumption.custom_minimum_size == Vector2(64, 104), "comfort AssumptionBlock matches FormulaBlock size")
	_check(premise.custom_minimum_size == Vector2(80, 84), "comfort premise tile min size")
	_check(rule_card._header.visible and not rule_card._overlay.visible, "comfort rule header restored")
	_check(rule_card.size.y > compact_rule_h, "comfort rule card is taller")

	main.set_card_size_mode(CardMetrics.COMPACT)
	await process_frame
	_check(chip.custom_minimum_size == Vector2(74, 68), "round-trip returns to compact formula")
	_check(assumption.custom_minimum_size == Vector2(74, 68), "round-trip returns to compact assumption")
	_check(premise.custom_minimum_size == Vector2(66, 64), "round-trip returns to compact premise")

	var switch_card = main.create_rule_block("and_elim_left")
	main._base_canvas.add_child(switch_card)
	switch_card.reset_size()
	await process_frame
	var side_rect: Rect2 = switch_card._corner_side_switch.get_global_rect()
	var icon_rect: Rect2 = switch_card._icon_plate.get_global_rect()
	var copy_rect: Rect2 = switch_card._corner_copy.get_global_rect()
	_check(not side_rect.intersects(icon_rect), "L/R switch does not cover the rule icon")
	_check(
		absf(copy_rect.position.y - icon_rect.position.y) <= 2.0,
		"copy button aligns with the icon plate top"
	)

	var temp_path := "user://test_card_settings.cfg"
	var store := UiSettingsStoreRes.new(temp_path)
	store.set_card_size_mode(CardMetrics.COMFORT)
	var reloaded := UiSettingsStoreRes.new(temp_path)
	_check(reloaded.card_size_mode == CardMetrics.COMFORT, "card mode persists")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

	main.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
