# Testing

Approved seams are the public Manager/BDD API and Native CLI process contract.
Tests do not assert private IDs, hash buckets, or cache layout.

```sh
moon fmt --check
moon check --target all --deny-warn
moon test --target all --deny-warn
python tools/test_cli.py
moon info
git diff --exit-code
```

Evidence includes independent truth tables, algebra laws, parser precedence,
transformation identities, exact counts above UInt64, Model uniqueness,
malformed JSON mutations, all three-Variable reorder permutations, finite
reachability, invariant witnesses, and Resource Budget boundaries.
