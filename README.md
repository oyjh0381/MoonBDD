# MoonBDD

MoonBDD is an original Apache-2.0 MoonBit library and Native CLI for canonical
reduced ordered binary decision diagrams (ROBDDs) and bounded symbolic
finite-state reachability. It targets configuration constraints, digital logic,
policy analysis, feature modelling, SAT-style model inspection, and protocol
state-space exploration.

Public MoonBit and Mooncakes searches performed on 2026-08-17 found state
machine, workflow, parser, regex, CRDT, schema, compression, and Unicode
projects, but no MoonBit ROBDD package. MoonBDD represents Boolean Functions
canonically; it is not a workflow runtime or a general CTL/LTL model checker.

## Highlights

- Explicit `Manager` ownership and stable Variable Order; foreign BDD Handles
  are rejected instead of being silently combined.
- Canonical unique table, computed ITE cache, and NOT/AND/OR/XOR/implication/
  equivalence operations.
- Parser for `true`, `false`, identifiers, `!`, `&`, `|`, `^`, `->`, `<->`,
  and parentheses with positioned diagnostics.
- Restriction, Composition, support, existential and universal Quantification.
- One Model, bounded Model enumeration, overflow-checked UInt64 Model Count,
  and exact decimal Model Count backed by an internal non-negative big integer.
- Bounded Truth Tables, compact disjoint satisfying Cubes, partial evaluation,
  semantic relation witnesses, Backbone discovery, and named Constraint
  diagnosis with redundant policies or deletion-minimal conflicts.
- Deterministic JSON Schema v1, deterministic DOT, statistics, and canonical
  parser-compatible Shannon expressions.
- Non-destructive explicit and adjacent-window Variable reordering: old
  Managers and BDD Handles remain valid.
- Finite symbolic Reachability Fixed Points with optional invariant witnesses.
- Explicit Resource Budgets on nodes, cache entries, work, input, output,
  depth, enumeration, reordering, and reachability iterations.
- Portable core checked on Wasm, Wasm-GC, JavaScript, and Native; Native CLI for
  scripting and stdin integration.

## Install and verify

After publication, install with `moon add oyjh0381/moonbdd`. From source:

```sh
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
```

## Library quick start

```moonbit
let manager = @moonbdd.Manager::new(
  ["database", "cache", "single_node"],
  @moonbdd.ResourceBudget::default(),
).unwrap()
let valid = manager
  .compile("database & (cache -> database) & !single_node")
  .unwrap()
println(manager.sat_count_decimal(valid).unwrap())
println(manager.encode_json(valid).unwrap())
```

Every BDD Handle belongs to exactly one Manager. Use `reorder` to translate a
Boolean Function into a new Manager; do not combine the returned Handle with
the source Manager.

## CLI quick start

```sh
moon run cmd/moonbdd --target native -- stats a,b "a & b"
moon run cmd/moonbdd --target native -- count a,b "a | b"
moon run cmd/moonbdd --target native -- truth-table a,b "a ^ b" 4
moon run cmd/moonbdd --target native -- cubes a,b,c "(a & b) | (!a & c)" 8
moon run cmd/moonbdd --target native -- backbone a,b,c "a & !b"
moon run cmd/moonbdd --target native -- diagnose a,b,c "enable-a=a;needs-b=!a | b;disable-b=!b"
moon run cmd/moonbdd --target native -- sat-one a,b "a ^ b"
moon run cmd/moonbdd --target native -- compile a,b "a -> b"
moon run cmd/moonbdd --target native -- dot a,b "a & b" constraint
moon run cmd/moonbdd --target native -- reorder a,c,b,d a,b,c,d "(a & b) | (c & d)"
moon run cmd/moonbdd --target native -- reach
# Read an expression from a file (PowerShell users should quote the @ argument)
moon run cmd/moonbdd --target native -- count a,b "@constraints.bdd"
```

Pass `-` as the expression argument to read UTF-8 text from stdin, or `@PATH`
to read an explicit UTF-8 file. Successful machine-readable commands write to
stdout. Failures write `MOONBDD_ERROR` followed by a JSON object to stderr and
use the categorized exit codes documented in [CLI](docs/CLI.md).

## Runnable examples

```sh
moon run examples/feature_constraints
moon run examples/digital_logic
moon run examples/mutex_reachability
```

The mutual-exclusion example computes a finite Reachability Fixed Point and
checks that both participants are never in the critical section together. It
is an algorithm demonstration, not a production protocol claim.

## Correctness, safety, and scope

ROBDDs are canonical only for one Variable Order and may still grow
exponentially for adverse formulas. Callers choose Resource Budgets and receive
structured errors on exhaustion; no semantic result is silently truncated.

Tests observe only the public Manager/BDD API and CLI process contract. Evidence
includes independent truth tables, Boolean algebra laws, parser precedence,
malformed artifacts, exact counts above 64 bits, reordering permutations,
reachability fixed points, and boundary limits.

MoonBDD 0.1 does not implement CTL/LTL, infinite-state proofs, SAT/SMT solving,
parallel Managers, automatic background reordering, stable binary persistence,
ZDD/ADD/MDD variants, Graphviz rendering, or caller-code sandboxing.

See [API](docs/API.md), [algorithms](docs/ALGORITHMS.md),
[architecture](docs/ARCHITECTURE.md), [CLI](docs/CLI.md),
[resource limits](docs/RESOURCE_LIMITS.md), [testing](docs/TESTING.md), and
[security](SECURITY.md). Maintainers use the reproducible
[release checklist](docs/RELEASE.md).

## Provenance and license

The MoonBit implementation is original and does not port CUDD, BuDDy, Sylvan,
or another BDD implementation. Public prior art is documented in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Licensed under
[Apache-2.0](LICENSE).
