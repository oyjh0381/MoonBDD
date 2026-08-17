# Resource Limits

`ResourceBudget` limits retained nodes, ITE cache entries, operation work,
input bytes, recursion depth, Model/Truth Table enumeration, named constraints,
high-level analysis steps, output bytes, reorder attempts, and reachability
iterations. Defaults are finite demonstration
defaults, not universal service settings. A full ITE cache stops accepting new
entries while computation continues correctly; it is an optimisation bound,
not a semantic truncation.

Exhaustion returns a specific `BddError`, never a silently partial semantic
result. Existing Handles remain valid. A Manager may retain canonical nodes
created before a failed operation. Untrusted-input services should lower node,
cache, work, depth, input, and output limits to their envelope. Exact decimal
counting charges every big-integer doubling to `max_work` and checks the final
decimal text against `max_output_bytes`.
