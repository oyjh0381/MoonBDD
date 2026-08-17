# Algorithms and Complexity

Let `N` be reachable Decision Nodes and `V` declared Variables. ROBDD size can
be exponential in `V`; no Variable Order avoids that for every function.

- Unique lookup is expected O(1); cached ITE has a worst-case O(N³) tuple space.
- Restriction and support are O(N) with memoisation, excluding new ITE work.
- One Model is O(V + path); enumeration is proportional to emitted Models.
- Model Count visits `(node, level)` states plus exact big-integer digit work.
- JSON and DOT are O(N + output bytes).
- Reordering reconstructs the reachable function per attempted order.
- Reachability multiplies relational BDD cost by bounded fixed-point iterations.

Analysis operations remain explicitly bounded:

- A Truth Table visits at most `O(min(2^V, R) * V)` assignment states and
  stores `O(min(2^V, R) * V)` name/value pairs for row limit `R`.
- Cube enumeration visits at most the reachable paths needed for `C` emitted
  true-terminal Cubes; its worst case is `O(N + C * V)` time and output space.
- Partial evaluation is one Restriction, while Backbone discovery performs two
  Restrictions per support Variable: worst-case `O(V * N)` excluding unique-
  table reuse and exact BDD-operation costs.
- Relation checks construct one Boolean difference/intersection and find at
  most one Model. Their cost is the corresponding cached ITE space plus `O(V)`
  witness completion.
- For `K` named constraints, deterministic redundancy and deletion-minimal
  conflict diagnosis perform `O(K^2)` conjunction inputs and at most `O(K)`
  semantic/SAT checks. BDD work inside each check remains subject to
  `max_work`; orchestration is bounded by `max_constraints` and
  `max_analysis_steps`.

Variable ordering dominates practical size; callers should measure node counts.
