# MoonBDD

Canonical ROBDDs and bounded symbolic finite-state reachability for MoonBit.

```moonbit nocheck
///|
let manager = @moonbdd.Manager::new(
  ["a", "b"],
  @moonbdd.ResourceBudget::default(),
).unwrap()

///|
let value = manager.compile("a -> b").unwrap()

///|
let count = manager.sat_count_decimal(value).unwrap()
```

The core is portable across Wasm, Wasm-GC, JavaScript, and Native. All BDD
Handles are owned by one explicit Manager and explosive entry points use
Resource Budgets. See the repository README for the full contract.
