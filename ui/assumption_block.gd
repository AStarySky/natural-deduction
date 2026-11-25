extends "res://ui/formula_block.gd"

## A freely created hypothesis. It uses the exact FormulaBlock geometry and
## chrome, with only the paper/tab colour changed; copying remains available
## through Ctrl+drag (duplicate_to_canvas in main).

var assumption_group: int = 0

func setup_assumption(p_formula, p_group: int) -> void:
	assumption_group = p_group
	setup(p_formula)
	_card_fill = Color8(244, 219, 255)
	_accent_fill = Color8(199, 166, 216)
	tooltip_text = "Assume " + formula.to_display_string() + "\nOpen hypothesis; Ctrl+drag to copy it."
	refresh_visuals()

func is_assumption_block() -> bool:
	return true

func get_assumption_group() -> int:
	return assumption_group

func get_free_assumptions() -> Array:
	return [self]

func get_display_text() -> String:
	if formula == null:
		return "assume"
	return "assume " + formula.to_display_string()
