extends RefCounted

## Structured outcome of ProofTree.apply_rule().
## Constructed directly by ProofTree via its preloaded RuleResultRes alias.

const ProofNodeRes = preload("res://logic/proof_node.gd")

## True only when a node was created and added to the tree.
var ok: bool = false
## Newly created node on success, null on failure.
var node: ProofNodeRes = null
## Human-readable failure reason on failure, empty on success.
var error: String = ""
