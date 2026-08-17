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

Variable ordering dominates practical size; callers should measure node counts.
