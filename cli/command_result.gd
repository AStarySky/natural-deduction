extends RefCounted

## Structured result of executing one CLI command line.
## The session never prints; main.gd renders [member lines].
## Constructed directly by CliSession via its preloaded CommandResultRes alias.

const ProofNodeRes = preload("res://logic/proof_node.gd")
const ValidationResultRes = preload("res://logic/validation_result.gd")

## True when the command succeeded (for validate, mirrors validation.ok).
var ok: bool = false
## Output lines for the CLI, already formatted.
var lines: Array[String] = []
## New proof node for premise/apply commands, otherwise null.
var node: ProofNodeRes = null
## Structured validation for the validate command, otherwise null.
var validation: ValidationResultRes = null
## Command-level error message for failed commands, otherwise empty.
var error: String = ""
## True when the command asked the REPL to stop.
var quit_requested: bool = false
