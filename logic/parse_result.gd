extends RefCounted

## Structured outcome of parsing one formula string.
## Constructed directly by FormulaParser via its preloaded ParseResultRes.

const FormulaRes = preload("res://logic/formula.gd")

## True only when [member formula] is a complete, valid AST.
var ok: bool = false
## Parsed formula on success, null on failure.
var formula: FormulaRes = null
## Human-readable failure reason (ASCII, includes the position).
var error: String = ""
## 1-based character position associated with the failure (0 when unused).
var position: int = 0
