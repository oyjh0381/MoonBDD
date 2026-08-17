# MoonBDD Project Specification

## Problem Statement

MoonBit developers currently lack a reusable native library for canonical Boolean-function representation and symbolic finite-state analysis. Existing ecosystem projects cover parsers, regular expressions, CRDTs, JSON Schema, compression, Unicode, state-machine execution, IP/CIDR analysis, and deterministic scheduling, but the public MoonBit and Mooncakes searches performed on 2026-08-17 did not find an ROBDD or binary-decision-diagram package. Developers who need configuration-constraint analysis, digital-logic manipulation, compact Boolean sets, exact model counting, or symbolic reachability must therefore build specialised and difficult-to-verify machinery themselves or leave the MoonBit ecosystem.

The project must provide genuine reusable algorithmic value rather than a thin wrapper or teaching demo. It must also remain safe under the exponential worst cases inherent to ROBDDs, make ownership and variable-order rules explicit, provide deterministic and inspectable artifacts, and satisfy OSC 2026 repository, build, test, documentation, CI, licensing, example, and publication expectations.

## Solution

MoonBDD will be an original Apache-2.0 MoonBit library and Native CLI for reduced ordered binary decision diagrams and bounded symbolic state-space analysis. A caller creates an explicit Manager, declares a Variable Order, constructs or parses Boolean Functions, and receives Manager-owned BDD Handles. The library provides canonical construction, cached Boolean operations, transformations, satisfiability queries, exact model counting, deterministic JSON persistence, DOT export, non-destructive reordering, and finite symbolic reachability.

The portable core will target Wasm, Wasm-GC, JavaScript, and Native where supported by the current MoonBit toolchain. Native-only filesystem orchestration will remain in the CLI boundary. All potentially explosive operations will accept Resource Budgets and return structured errors on exhaustion. The project will include executable constraint and reachability examples, public-behaviour tests, performance evidence, multi-platform CI, complete documentation, provenance records, a competition proposal based on the existing MoonOCI proposal style, and mooncakes.io publication preparation.

## User Stories

1. As a MoonBit library author, I want to create an isolated Manager, so that one component cannot corrupt another component's node universe.
2. As a constraint-system author, I want to declare Boolean Variables in a stable order, so that ROBDD identity and performance are reproducible.
3. As a caller, I want constants and variables to produce BDD Handles, so that I can construct Boolean Functions programmatically.
4. As a caller, I want cross-Manager operations to fail explicitly, so that incompatible node identities are never silently combined.
5. As a caller, I want equivalent Boolean Functions to share one canonical representation under the same Variable Order, so that equality is inexpensive and reliable.
6. As a caller, I want NOT, AND, OR, XOR, implication, and equivalence, so that common constraints do not require manual ITE expansion.
7. As an advanced caller, I want a general ITE operation, so that other Boolean operations and decision structures can be expressed uniformly.
8. As a configuration author, I want to parse readable Boolean expressions, so that constraints can be maintained outside source code.
9. As a configuration author, I want stable operator precedence and associativity, so that an expression has one predictable meaning.
10. As a user correcting an invalid expression, I want position-aware diagnostics, so that I can locate and fix the error quickly.
11. As a tooling author, I want a canonical expression printer, so that equivalent parsed syntax can be reviewed deterministically.
12. As a caller, I want to restrict selected Variables, so that I can specialise a Boolean Function for a partial configuration.
13. As a caller, I want to compose a Variable with another Boolean Function, so that I can substitute reusable constraints safely.
14. As a caller, I want existential quantification, so that I can project a relation while preserving any satisfying value of eliminated Variables.
15. As a caller, I want universal quantification, so that I can require a relation to hold for every value of eliminated Variables.
16. As a caller, I want to inspect the support of a Boolean Function, so that I know which Variables materially affect it.
17. As a caller, I want one satisfying Model, so that I can produce an actionable witness.
18. As a caller, I want bounded Model enumeration, so that I can inspect several witnesses without risking unbounded output.
19. As a caller, I want UInt64 Model Count with explicit overflow reporting, so that the fast path never returns a wrong count.
20. As a caller, I want an exact decimal Model Count, so that large solution spaces remain measurable without external big-integer dependencies.
21. As a caller, I want Model Count to include skipped Variables correctly, so that reduced paths do not undercount complete assignments.
22. As a user, I want deterministic statistics, so that I can compare formulas and runs in CI.
23. As a user, I want deterministic DOT export, so that I can inspect or render an ROBDD graph.
24. As a user, I want deterministic versioned JSON export, so that an ROBDD can be stored, diffed, and exchanged.
25. As a user, I want strict JSON import, so that malformed topology, invalid Variable references, duplicate nodes, and incompatible roots are rejected.
26. As a user, I want JSON import to enforce Resource Budgets, so that untrusted artifacts cannot force unreasonable allocation.
27. As a caller, I want an equivalent ROBDD under a new Variable Order, so that I can reduce node count when the original order is poor.
28. As a caller, I want reordering to create a new Manager, so that existing BDD Handles remain valid.
29. As a caller, I want deterministic adjacent-window reordering, so that optimisation results are reproducible.
30. As a caller, I want reordering statistics, so that I can decide whether the extra construction cost was worthwhile.
31. As a protocol author, I want to encode a finite set of states as a Boolean Function, so that large state sets can be represented symbolically.
32. As a protocol author, I want to encode a Transition Relation over current and next Variables, so that successor states can be computed symbolically.
33. As a protocol author, I want bounded fixed-point reachability, so that I can discover all reachable finite states or receive a budget error.
34. As a protocol author, I want a reachable counterexample Model when an invariant fails, so that the analysis is actionable.
35. As a CLI user, I want to compile an expression, so that I can create an inspectable ROBDD artifact without writing MoonBit code.
36. As a CLI user, I want statistics, satisfiability, counting, DOT, reordering, and reachability commands, so that core library capabilities are scriptable.
37. As a CLI user, I want documented exit codes and machine-readable errors, so that automation can distinguish invalid input, budget exhaustion, and internal failure.
38. As a CLI user, I want stdin and explicit file inputs where appropriate, so that commands compose with other tools.
39. As a security-conscious user, I want explicit limits on input bytes, expression depth, nodes, cache entries, Model enumeration, and reorder attempts, so that worst cases are controlled.
40. As a user, I want budget exhaustion to leave existing Managers and BDD Handles valid, so that a failed operation cannot corrupt later work.
41. As a new user, I want runnable feature-constraint, digital-logic, and mutual-exclusion examples, so that I can understand realistic integration patterns.
42. As a maintainer, I want truth-table differential tests for small formulas, so that canonical operations are checked against an independent oracle.
43. As a maintainer, I want algebraic property tests, so that identities and quantification laws catch broad classes of regressions.
44. As a maintainer, I want deterministic random test seeds and replayable failures, so that CI failures can be reproduced locally.
45. As a maintainer, I want mutation tests for serialized artifacts and parser inputs, so that rejection paths remain robust.
46. As a maintainer, I want performance baselines for representative good and bad Variable Orders, so that regressions and exponential behaviour are visible.
47. As a MoonBit ecosystem user, I want the portable core checked on all supported targets, so that the package is not accidentally Native-only.
48. As a contributor, I want clear architecture, domain, contribution, testing, security, and limitation documentation, so that the project remains maintainable.
49. As an OSC 2026 reviewer, I want meaningful MoonBit implementation, tests, examples, CI, provenance, and an OSI license, so that the submission is reproducible and compliant.
50. As an OSC 2026 reviewer, I want the project isolated from MoonOCI with its own repository history and package identity, so that its independent contribution is unambiguous.
51. As a package consumer, I want mooncakes.io metadata and a reproducible release checklist, so that I can install a reviewed version.
52. As the contestant, I want a concise project proposal matching the established MoonOCI proposal style, so that submission materials remain consistent and complete.

## Implementation Decisions

- The project name is MoonBDD and the intended module namespace is `oyjh0381/moonbdd`.
- MoonBDD is an independent project and repository. It must not be implemented in, committed as part of, or published as MoonOCI.
- The implementation is original and based on publicly described ROBDD algorithms and Boolean algebra. It will not port source code from CUDD, BuDDy, Sylvan, or another implementation.
- Apache License 2.0 is the project license. Public papers, specifications, tools, fixtures, and conceptual prior art will be disclosed separately from code authorship.
- The core abstraction is an explicit Manager that owns one Variable Order, a canonical node universe, uniqueness state, and computed-operation caches.
- A BDD Handle identifies its owning Manager and one root. Operations reject BDD Handles from another Manager.
- There is no global mutable Manager and no implicit cross-Manager conversion.
- A Decision Node is canonical only inside its Manager. The reduction rules merge nodes with equal Variable, Low, and High successors and eliminate nodes whose Low and High successors are equal.
- Variable Order is stable for the life of a Manager. Variable names are unique and their declared positions define decision ordering.
- Reordering is non-destructive. It creates a new Manager and translated roots; it never mutates the old Manager or invalidates existing BDD Handles.
- The first optimisation strategy is deterministic adjacent-window reordering invoked explicitly by the caller. Automatic background reordering is not provided.
- ITE is the primitive general Boolean operation. Convenience operations include negation, conjunction, disjunction, exclusive-or, implication, and equivalence.
- Transformations include Restriction, Composition, support discovery, existential Quantification, and universal Quantification.
- Satisfiability capabilities include one Model, budgeted Model enumeration, UInt64 Model Count with overflow detection, and exact decimal Model Count backed by an internal non-negative big integer.
- The parser accepts identifiers, `true`, `false`, `!`, `&`, `|`, `^`, `->`, `<->`, and parentheses with documented precedence and associativity.
- Stable CLI command names are `compile`, `stats`, `sat-one`, `count`, `dot`, `reorder`, and `reach`.
- The only persistent interoperability format in version 0.1 is deterministic, versioned JSON Schema v1. No stable binary format is promised.
- JSON decoding validates schema version, Variable Order, canonical topology, node references, root references, and configured Resource Budgets before returning a usable artifact.
- DOT output is deterministic and intended for inspection and external rendering, not as a persistence format.
- Symbolic reachability represents states as Models, Transition Relations over paired current and next Variables, and successors through conjunction, Quantification, and renaming.
- Reachability is bounded finite-state fixed-point analysis. When an invariant fails, the result should include a witness Model when one is available within the budget.
- Resource Budgets are part of public construction, parsing, import, Model enumeration, reordering, and reachability contracts. Exhaustion is a structured error, never silent truncation.
- The portable library core must not depend on host files, clocks, randomness, processes, sockets, or threads. Native filesystem orchestration belongs to the CLI.
- Public errors distinguish invalid arguments, ownership violations, parse diagnostics, malformed artifacts, unsupported versions, arithmetic overflow, budget exhaustion, and I/O or CLI failures.
- The competition proposal follows the structure and concise style of the existing MoonOCI proposal and the official template. Contestant and contact fields remain explicit placeholders until supplied by the user.
- Effective MoonBit source scale is expected to be approximately 5,000–9,000 lines, but real functionality and clarity take priority over line-count padding.

## Testing Decisions

- Tests assert observable behaviour through two approved seams: the public Manager/BDD API and the CLI process contract.
- Tests do not depend on internal node numbering, unique-table layout, cache eviction details, or private helper structure unless an exported deterministic artifact explicitly defines the representation.
- Small formulas are evaluated by an independent truth-table oracle and compared with ROBDD results for every assignment.
- Algebraic properties cover commutativity, associativity where applicable, identity, annihilation, idempotence, complement, implication, equivalence, Shannon expansion, Restriction, Composition, and Quantification laws.
- Canonicality tests verify that equivalent construction paths produce equal handles inside one Manager and that incompatible Managers are rejected.
- Model tests cover unsatisfiable, tautological, fully constrained, partially constrained, skipped-variable, zero-variable, overflow, and exact large-count cases.
- Parser tests cover precedence, associativity, whitespace, Unicode or invalid identifiers according to the documented lexical policy, incomplete operators, unmatched parentheses, excessive depth, and precise diagnostics.
- Serialization tests cover deterministic golden output, round trips, version rejection, topological violations, duplicate or dangling references, invalid orders, unreachable data policy, size limits, and mutation-generated malformed inputs.
- Reordering tests compare truth tables before and after translation, ensure old handles remain usable, confirm deterministic results, and demonstrate at least one case with a smaller node count.
- Reachability tests cover empty, singleton, cyclic, convergent, invariant-preserving, invariant-violating, and budget-exhausting finite systems.
- CLI tests execute complete commands and assert exit category, stdout, stderr, and artifact results without depending on internal functions.
- Performance tests record representative node counts and operation work for favourable and adverse Variable Orders. They document expected exponential worst cases rather than claiming universal polynomial behaviour.
- Strict validation includes formatting, generated interface consistency, warning-free checks, warning-free tests, portable targets, Native CLI tests, and repository cleanliness.
- Prior art for testing style comes from the independent MoonOCI, MoonLab, and MoonIPFIX projects: deterministic artifacts, boundary matrices, malformed-input testing, replayable generated cases, process exit contracts, and multi-target checks. No production code is shared with those projects.

## Out of Scope

- A complete CTL, LTL, mu-calculus, SAT, SMT, theorem-proving, or unbounded model-checking system.
- Proof of liveness or correctness for infinite-state or unbounded systems.
- Parallel node construction, concurrent Manager mutation, lock-free tables, distributed execution, or parallel garbage collection.
- Automatic background Variable reordering or a promise that reordering always reduces size.
- Stable binary persistence, memory-mapped node stores, databases, or remote artifact services.
- Arbitrary non-Boolean decision diagrams such as MDD, ADD, ZDD, or weighted diagrams in version 0.1.
- A general workflow engine or runtime state-machine executor.
- Graphviz rendering or a bundled GUI; MoonBDD emits DOT only.
- Execution of untrusted MoonBit callbacks in a sandbox.
- Silent recovery from invalid input, silent Model truncation, or hidden resource-limit defaults.
- Direct inclusion in or publication under the MoonOCI project.

## Further Notes

- Ecosystem duplication research was performed on 2026-08-17 across public GitHub results and indexed Mooncakes material. No ROBDD or binary-decision-diagram project was found, but absence from search is not proof of absolute non-existence. Repeat the search immediately before proposal submission and publication.
- Nearby but distinct MoonBit projects include general state-machine and workflow libraries. MoonBDD's boundary is canonical Boolean Functions and Symbolic State Sets, not event-driven workflow execution.
- Final OSC 2026 acceptance additionally depends on external facts that cannot be proven from local files alone: a public GitHub and Gitlink repository, meaningful history, a passing recent CI run, and successful mooncakes.io publication.
- The applicant name and contact information are intentionally not fabricated and remain human-supplied proposal fields.
