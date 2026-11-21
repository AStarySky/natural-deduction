extends RefCounted

## Structured outcome of recursively validating a proof tree.
## Constructed directly by ProofTree via its preloaded ValidationResultRes alias.

## True only when every reachable derivation is valid and the root equals the goal.
var ok: bool = false
## Every validation problem, each naming a node id and the expected/actual data.
var errors: Array[String] = []
