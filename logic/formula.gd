extends RefCounted

## Immutable propositional formula AST, represented as a tagged union.
##
## Build nodes with the script constructor via the preloaded FormulaRes alias:
##   FormulaRes.new(FormulaRes.Kind.ATOM, "A")
##   FormulaRes.new(FormulaRes.Kind.IMPLIES, "", left, right)
## Nodes are never mutated after construction; rules always build new formulas.
## No class_name is declared so headless -s runs do not depend on the editor's
## global class cache.

enum Kind { ATOM, NOT, AND, OR, IMPLIES, IFF }

## Which kind of formula this node is.
var kind: Kind = Kind.ATOM
## Atom name when [member kind] is [constant Kind.ATOM], otherwise empty.
var atom_name: String = ""
## Left operand; for NOT this is the negated child. Untyped for headless
## preload compatibility; values are always Formula script instances or null.
var left = null
## Right operand (unused for atoms and negations).
var right = null

func _init(p_kind: Kind, p_atom_name: String = "", p_left = null, p_right = null) -> void:
	kind = p_kind
	atom_name = p_atom_name
	left = p_left
	right = p_right

## Structural equality; atom names must match exactly.
func equals(other) -> bool:
	if other == null:
		return false
	if kind != other.kind:
		return false
	match kind:
		Kind.ATOM:
			return atom_name == other.atom_name
		Kind.NOT:
			return left.equals(other.left)
		Kind.AND, Kind.OR, Kind.IMPLIES, Kind.IFF:
			return left.equals(other.left) and right.equals(other.right)
	return false

## Render the formula with explicit structure using ASCII connectives.
func to_string() -> String:
	return _render()

## Unicode display form for UI labels and tooltips. The canonical CLI/test
## form stays ASCII so scripts and stored proof text remain stable.
func to_display_string() -> String:
	return _render()

## Keep print()/str() consistent with [method to_string].
func _to_string() -> String:
	return _render()

## Return the display form of this formula.
func _render() -> String:
	match kind:
		Kind.ATOM:
			return atom_name
		Kind.NOT:
			return "~" + _render_child(left, Kind.NOT)
		Kind.AND:
			return _render_child(left, Kind.AND) + " & " + _render_child(right, Kind.AND)
		Kind.OR:
			return _render_child(left, Kind.OR) + " | " + _render_child(right, Kind.OR)
		Kind.IMPLIES:
			return _render_child(left, Kind.IMPLIES) + " -> " + _render_child(right, Kind.IMPLIES)
		Kind.IFF:
			return _render_child(left, Kind.IFF) + " <-> " + _render_child(right, Kind.IFF)
	return ""

## Precedence used only for parenthesization: ~ > & > | > ->.
func _precedence(which: Kind) -> int:
	match which:
		Kind.ATOM:
			return 5
		Kind.NOT:
			return 4
		Kind.AND:
			return 3
		Kind.OR:
			return 2
		Kind.IMPLIES:
			return 1
		Kind.IFF:
			return 0
	return 0

## Render a child, adding parentheses only where structure would change.
func _render_child(child, parent_kind: Kind) -> String:
	if child == null:
		return "<?>"
	var text: String = child._render()
	if parent_kind == Kind.NOT:
		# Negation needs parentheses only around binary expressions.
		if _precedence(child.kind) < _precedence(Kind.NOT):
			return "(" + text + ")"
		return text
	# For binary parents, parenthesize equal-precedence children so the
	# displayed text reflects the actual AST (e.g. A -> (B -> C)).
	if _precedence(child.kind) <= _precedence(parent_kind):
		return "(" + text + ")"
	return text
