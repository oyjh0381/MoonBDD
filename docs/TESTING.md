# Testing

Approved seams are the public Manager/BDD API and Native CLI process contract.
Tests do not assert private IDs, hash buckets, or cache layout.

```sh
moon fmt --check
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
python tools/test_cli.py
python tools/benchmark.py
python tools/count_moonbit_loc.py
python -m unittest discover -s tools -p test_repo_quality.py
python tools/repo_quality.py --history
moon info
git diff --exit-code
```

Evidence includes independent truth tables, algebra laws, parser precedence,
transformation identities, exact counts above UInt64, Model uniqueness,
malformed JSON and parser mutations, all three-Variable reorder permutations,
empty/singleton/budgeted reachability, invariant witnesses, and Resource Budget
boundaries. Analysis tests additionally cover partial assignments, bounded
Truth Tables, relation counterexamples, Backbones, redundant constraints, and
disjoint Cube coverage, deletion-minimal conflicts, and their truncation/budget
boundaries. Generated formulas use the explicit replay seed `20260817` in the
test name and source. The benchmark records interleaved versus grouped
equality-variable orders and rejects a loss of the expected node-count gap.

Reachability regressions reject next-state initial/invariant predicates and
unpaired dimensions, protect variable-array ownership, and compare symbolic
results with an independent explicit graph for all 16 initial subsets of a
two-bit system. A failure was reproduced before applying the input-domain fix.

On Windows, first run `./tools/windows/build-shim.ps1`. Use
`./tools/windows/moon.ps1` in place of `moon` if the official driver's extended
DOS paths are rejected by its compiler/formatter. For Python CLI tools, set the
four process-local `MOONC_OVERRIDE`, `MOONFMT_OVERRIDE`, `MOONINFO_OVERRIDE`, and
`MOONDOC_OVERRIDE` variables to the matching executables in
`_build/windows-path-shims/`. MSVC with Windows SDK is required by the adapter
and Native async dependency. The adapter preserves the original official tools.

`repo_quality.py` scans tracked working/index content and, with `--history`,
every reachable historical blob. It detects common credential signatures,
credential assignments, contact addresses, and RFC 1918 addresses without
printing matched values. Local proposals/reports are excluded from the current
tracked tree; prior history is retained. Synthetic example-domain contacts
and Apache license contacts are allowed. These heuristics cannot identify all
customer data or prove human participation; maintainers must review provenance
and any findings. CI must check out full history (`fetch-depth: 0`).
