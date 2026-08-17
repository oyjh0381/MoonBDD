# Resource Limits

`ResourceBudget` limits retained nodes, operation work, input bytes, recursion
depth, Model enumeration, output bytes, reorder attempts, and reachability
iterations. Defaults are finite demonstration defaults, not universal service
settings.

Exhaustion returns a specific `BddError`, never a silently partial semantic
result. Existing Handles remain valid. A Manager may retain canonical nodes
created before a failed operation. Untrusted-input services should lower node,
work, depth, input, and output limits to their envelope.
