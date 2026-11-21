extends RefCounted

## Stateless result of applying a natural-deduction rule to formulas.
## ProofTree wraps a successful derivation into a ProofNode/RuleResult.
## Constructed directly by Rules via its preloaded RuleDerivationRes alias.

const FormulaRes = preload("res://logic/formula.gd")

## True when the rule matched and [member formula] was derived.
var ok: bool = false
## Derived conclusion, null on failure.
var formula: FormulaRes = null
## Human-readable failure reason, including the rule id and actual inputs.
var error: String = ""
## Indices into the supplied premise array describing rule slot order.
## Example: impl_elim always returns [antecedent_index, implication_index].
var premise_order: Array = []
