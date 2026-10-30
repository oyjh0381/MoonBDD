# API Guide

## Ownership and construction

`Manager::new(variable_names, budget)` validates a unique non-empty Variable
Order. Names follow the parser-compatible ASCII grammar
`[A-Za-z_][A-Za-z0-9_.]*`; reserved literals `true` and `false` are rejected.
This guarantees canonical expressions can be parsed by a Manager with the same
order. All returned BDD Handles belong to that exact Manager object.
`validate` reports `ForeignHandle` for any other Manager, even with identical
names. Use `variable` or `compile`; `evaluate` consumes assignments and
`Bdd::same` provides constant-time canonical equality within one Manager.

## Operations and transformations

`ite` is the primitive. Convenience operations are `not_bdd`, `and_bdd`,
`or_bdd`, `xor_bdd`, `implies`, and `equivalent`. `restrict` fixes Variables,
`compose` replaces one Variable with a Boolean Function, `exists`/`forall`
quantify Variables, and `support` returns material names in Variable Order.

## Models and inspection

`sat_one` returns a complete witness or `None`. `enumerate_models` is bounded.
`sat_count_u64` reports overflow while `sat_count_decimal` remains exact.
`statistics`, `to_dot`, and `canonical_expression` are deterministic.

## Analysis and Constraint diagnosis

`evaluate_partial` returns `AlwaysFalse`, `AlwaysTrue`, or `Undetermined` after
applying a partial assignment. `truth_table` emits deterministic rows in
Variable Order under an explicit row limit. `enumerate_cubes` follows ROBDD
true-terminal paths to emit pairwise-disjoint partial assignments; omitted
variables are don't-care dimensions. `cube_to_bdd` converts a Cube back to its
canonical conjunction, enabling coverage and disjointness checks. `check_entailment`,
`check_equivalence`, and `check_disjoint` return complete counterexample Models
when a relation fails. `backbone` returns exactly the assignments forced in
every satisfying Model.

`diagnose_constraints` compiles named expressions as one conjunction. A
satisfiable report contains a witness and deterministically removable redundant
constraints, with earlier declarations taking precedence. An unsatisfiable
report contains a deletion-minimal conflict in input order. Deletion-minimal
means no reported member can be removed while preserving the conflict; it does
not promise the globally smallest-cardinality conflict.

## Artifacts and reordering

`encode_json` and `Manager::decode_json` implement deterministic Schema v1.
The decoder creates a fresh Manager after validating order, topology,
canonical reduction, references, and budgets. `reorder` returns a new Manager;
`optimize_order` accepts deterministic adjacent swaps that strictly reduce
reachable nodes. Source Handles stay valid.

## Reachability

`state_encoding` creates disjoint current/next pairs. `reach` computes
successors through conjunction, existential Quantification, and Composition
until a fixed point or iteration budget. An optional invariant returns a
witness Model when violated.

The initial set and invariant may depend only on current-state Variables.
The Transition Relation may depend only on the paired current/next Variables.
Unpaired dimensions return `InvalidArgument`; explicitly quantify environmental
inputs before calling `reach`. Constants are valid in all three positions.
Manager internals and StateEncoding pairs are private. Variable-name accessors
return detached copies, so changing caller arrays cannot change the Variable
Order or invalidate a previously checked encoding.
