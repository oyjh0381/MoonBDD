# Architecture

The portable root package is the library boundary; Native I/O is isolated in
the CLI. A Manager stores terminals 0/1, a Variable Order, a unique table keyed
by `(variable, low, high)`, and an ITE computed cache. Reduction merges equal
nodes and removes decisions with identical outcomes. A BDD Handle carries a
physical Manager reference and private root ID.

Operations recurse over ordered cofactors with bounded work. Transformations
memoise roots. Exact Model Count uses a private base-1,000,000,000 non-negative
integer. JSON compacts reachable nodes into child-before-parent postorder IDs;
private IDs, unreachable nodes, and caches never enter the format.

The analysis layer uses Restriction for partial evaluation and Backbone
discovery, and Boolean difference/intersection for relation counterexamples.
Truth Tables traverse ordered cofactors directly under row and work limits.
Cube enumeration follows low-before-high paths to true terminals; reduction
makes omitted variables explicit don't-care dimensions and distinct paths
pairwise disjoint.
Constraint diagnosis compiles one named conjunction, removes redundant
constraints in deterministic reverse declaration order, or applies bounded
deletion to produce an irreducible conflict. This conflict is deletion-minimal,
not necessarily minimum-cardinality.

Reordering translates the source DAG through ITE into a fresh Manager.
Reachability conjoins states with a Transition Relation, quantifies current
Variables, composes next Variables into current Variables, and unions successors
until canonical equality proves a fixed point.
