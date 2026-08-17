///|
fn analysis_manager() -> @moonbdd.Manager {
  @moonbdd.Manager::new(["a", "b", "c"], @moonbdd.ResourceBudget::default()).unwrap()
}

///|
test "partial evaluation distinguishes false true and undetermined" {
  let manager = analysis_manager()
  let formula = manager.compile("a & b").unwrap()
  assert_eq(manager.evaluate_partial(formula, [("a", false)]), Ok(AlwaysFalse))
  assert_eq(manager.evaluate_partial(formula, [("a", true)]), Ok(Undetermined))
  assert_eq(
    manager.evaluate_partial(formula, [("a", true), ("b", true)]),
    Ok(AlwaysTrue),
  )
  assert_true(
    manager.evaluate_partial(formula, [("missing", true)])
    is Err(UnknownVariable("missing")),
  )
}

///|
test "truth tables are deterministic bounded and complete when capacity allows" {
  let manager = @moonbdd.Manager::new(
    ["a", "b"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let formula = manager.compile("a ^ b").unwrap()
  let limited = manager.truth_table(formula, 3).unwrap()
  assert_false(limited.complete)
  assert_eq(limited.rows.length(), 3)
  assert_eq(limited.rows[0], {
    values: [("a", false), ("b", false)],
    result: false,
  })
  assert_eq(limited.rows[1], {
    values: [("a", false), ("b", true)],
    result: true,
  })
  assert_eq(limited.rows[2], {
    values: [("a", true), ("b", false)],
    result: true,
  })
  let complete = manager.truth_table(formula, 4).unwrap()
  assert_true(complete.complete)
  assert_eq(complete.rows.length(), 4)
  assert_true(manager.truth_table(formula, 0) is Err(InvalidArgument(_)))
}

///|
test "truth table generation enforces model and work budgets" {
  let model_limited = @moonbdd.Manager::new(["a"], {
    ..@moonbdd.ResourceBudget::default(),
    max_models: 1,
  }).unwrap()
  assert_true(
    model_limited.truth_table(model_limited.true_bdd(), 2)
    is Err(ModelBudgetExceeded(1)),
  )
  let work_limited = @moonbdd.Manager::new(["a", "b"], {
    ..@moonbdd.ResourceBudget::default(),
    max_work: 2,
  }).unwrap()
  assert_true(
    work_limited.truth_table(work_limited.true_bdd(), 4)
    is Err(WorkBudgetExceeded(2)),
  )
}

///|
test "truth table handles a Manager with no declared variables" {
  let manager = @moonbdd.Manager::new([], @moonbdd.ResourceBudget::default()).unwrap()
  let table = manager.truth_table(manager.true_bdd(), 1).unwrap()
  assert_true(table.complete)
  assert_eq(table.rows, [{ values: [], result: true }])
}

///|
test "disjoint cubes compactly cover satisfying assignments" {
  let manager = analysis_manager()
  let formula = manager.compile("(a & b) | (!a & c)").unwrap()
  let enumeration = manager.enumerate_cubes(formula, 8).unwrap()
  assert_true(enumeration.complete)
  assert_eq(enumeration.cubes, [
    { values: [("a", false), ("c", true)] },
    { values: [("a", true), ("b", true)] },
  ])
  let mut rebuilt = manager.false_bdd()
  for cube in enumeration.cubes {
    let restricted = manager.restrict(formula, cube.values).unwrap()
    assert_true(manager.is_true(restricted))
    let cube_bdd = manager.cube_to_bdd(cube).unwrap()
    assert_true(manager.is_false(manager.and_bdd(rebuilt, cube_bdd).unwrap()))
    rebuilt = manager.or_bdd(rebuilt, cube_bdd).unwrap()
  }
  assert_true(rebuilt.same(formula))
}

///|
test "cube enumeration covers constants truncation and budgets" {
  let manager = analysis_manager()
  let tautology = manager.enumerate_cubes(manager.true_bdd(), 1).unwrap()
  assert_true(tautology.complete)
  assert_eq(tautology.cubes, [{ values: [] }])
  let contradiction = manager.enumerate_cubes(manager.false_bdd(), 1).unwrap()
  assert_true(contradiction.complete)
  assert_eq(contradiction.cubes, [])
  let parity = manager.compile("a ^ b ^ c").unwrap()
  let limited = manager.enumerate_cubes(parity, 2).unwrap()
  assert_false(limited.complete)
  assert_eq(limited.cubes.length(), 2)
  assert_true(manager.enumerate_cubes(parity, 0) is Err(InvalidArgument(_)))
  let budgeted = @moonbdd.Manager::new(["a", "b"], {
    ..@moonbdd.ResourceBudget::default(),
    max_models: 1,
  }).unwrap()
  assert_true(
    budgeted.enumerate_cubes(budgeted.true_bdd(), 2)
    is Err(ModelBudgetExceeded(1)),
  )
  assert_true(
    manager.cube_to_bdd({ values: [("missing", true)] })
    is Err(UnknownVariable("missing")),
  )
  assert_true(
    manager.cube_to_bdd({ values: [("a", true), ("a", false)] })
    is Err(InvalidArgument(_)),
  )
  let analysis_limited = @moonbdd.Manager::new(["a"], {
    ..@moonbdd.ResourceBudget::default(),
    max_analysis_steps: 1,
  }).unwrap()
  assert_true(
    analysis_limited.cube_to_bdd({ values: [("a", true)] })
    is Err(AnalysisBudgetExceeded(1)),
  )
  let scan_limited = @moonbdd.Manager::new(["a", "b"], {
    ..@moonbdd.ResourceBudget::default(),
    max_analysis_steps: 2,
  }).unwrap()
  assert_true(
    scan_limited.cube_to_bdd({ values: [("b", true)] })
    is Err(AnalysisBudgetExceeded(2)),
  )
}

///|
test "Boolean relation checks return actionable counterexamples" {
  let manager = analysis_manager()
  let a = manager.variable("a").unwrap()
  let b = manager.variable("b").unwrap()
  let both = manager.and_bdd(a, b).unwrap()
  let entails = manager.check_entailment(both, a).unwrap()
  assert_true(entails.holds)
  assert_true(entails.witness is None)
  let does_not_entail = manager.check_entailment(a, both).unwrap()
  assert_false(does_not_entail.holds)
  let entailment_witness = does_not_entail.witness.unwrap()
  assert_eq(manager.evaluate(a, entailment_witness.values), Ok(true))
  assert_eq(manager.evaluate(both, entailment_witness.values), Ok(false))
  let unequal = manager.check_equivalence(a, b).unwrap()
  assert_false(unequal.holds)
  assert_true(unequal.witness is Some(_))
  let not_a = manager.not_bdd(a).unwrap()
  let disjoint = manager.check_disjoint(a, not_a).unwrap()
  assert_true(disjoint.holds)
  assert_true(disjoint.witness is None)
  let overlap = manager.check_disjoint(a, b).unwrap()
  assert_false(overlap.holds)
  let overlap_witness = overlap.witness.unwrap()
  assert_eq(manager.evaluate(a, overlap_witness.values), Ok(true))
  assert_eq(manager.evaluate(b, overlap_witness.values), Ok(true))
}

///|
test "backbone reports exactly the assignments forced by every model" {
  let manager = analysis_manager()
  let formula = manager.compile("a & !b").unwrap()
  assert_eq(manager.backbone(formula), Ok([("a", true), ("b", false)]))
  assert_eq(manager.backbone(manager.true_bdd()), Ok([]))
  assert_true(
    manager.backbone(manager.false_bdd())
    is Err(
      InvalidArgument("backbone is undefined for an unsatisfiable function")
    ),
  )
}

///|
test "backbone enforces the high-level analysis step budget" {
  let manager = @moonbdd.Manager::new(["a", "b"], {
    ..@moonbdd.ResourceBudget::default(),
    max_analysis_steps: 1,
  }).unwrap()
  let formula = manager.compile("a & b").unwrap()
  assert_true(manager.backbone(formula) is Err(AnalysisBudgetExceeded(1)))
}

///|
test "constraint diagnosis reports witnesses and redundant constraints" {
  let manager = @moonbdd.Manager::new(
    ["database", "cache"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let report = manager
    .diagnose_constraints([
      { name: "database-required", expression: "database" },
      { name: "cache-safe", expression: "cache -> database" },
      { name: "weak-policy", expression: "database | cache" },
    ])
    .unwrap()
  assert_true(report.satisfiable)
  assert_true(report.witness is Some(_))
  assert_eq(report.minimal_conflict, [])
  assert_eq(report.redundant, ["cache-safe", "weak-policy"])
  assert_eq(manager.sat_count_u64(report.combined), Ok(2UL))
}

///|
test "constraint diagnosis computes a deletion-minimal conflict" {
  let manager = analysis_manager()
  let report = manager
    .diagnose_constraints([
      { name: "enable-a", expression: "a" },
      { name: "a-needs-b", expression: "!a | b" },
      { name: "disable-b", expression: "!b" },
      { name: "irrelevant", expression: "c | !c" },
    ])
    .unwrap()
  assert_false(report.satisfiable)
  assert_true(report.witness is None)
  assert_eq(report.minimal_conflict, ["enable-a", "a-needs-b", "disable-b"])
  assert_eq(report.redundant, [])
  assert_true(manager.is_false(report.combined))
}

///|
test "constraint diagnosis validates names expressions and analysis budgets" {
  let manager = analysis_manager()
  assert_true(
    manager.diagnose_constraints([
      { name: "same", expression: "a" },
      { name: "same", expression: "b" },
    ])
    is Err(DuplicateConstraintName("same")),
  )
  assert_true(
    manager.diagnose_constraints([{ name: "", expression: "a" }])
    is Err(EmptyConstraintName),
  )
  assert_true(
    manager.diagnose_constraints([{ name: "broken", expression: "a & )" }])
    is Err(ConstraintCompileFailure("broken", ParseFailure(_))),
  )
  let limited = @moonbdd.Manager::new(["a"], {
    ..@moonbdd.ResourceBudget::default(),
    max_constraints: 1,
  }).unwrap()
  assert_true(
    limited.diagnose_constraints([
      { name: "one", expression: "a" },
      { name: "two", expression: "!a" },
    ])
    is Err(ConstraintAnalysisFailure(ConstraintBudgetExceeded(1))),
  )
}

///|
test "empty constraint sets are satisfiable identity conjunctions" {
  let manager = analysis_manager()
  let report = manager.diagnose_constraints([]).unwrap()
  assert_true(report.satisfiable)
  assert_true(manager.is_true(report.combined))
  assert_true(report.witness is Some(_))
  assert_eq(report.minimal_conflict, [])
  assert_eq(report.redundant, [])
}

///|
test "constraint diagnosis charges semantic checks to analysis steps" {
  let manager = @moonbdd.Manager::new(["a"], {
    ..@moonbdd.ResourceBudget::default(),
    max_analysis_steps: 2,
  }).unwrap()
  assert_true(
    manager.diagnose_constraints([{ name: "one", expression: "a" }])
    is Err(ConstraintAnalysisFailure(AnalysisBudgetExceeded(2))),
  )
  let redundancy_limited = @moonbdd.Manager::new(["a"], {
    ..@moonbdd.ResourceBudget::default(),
    max_analysis_steps: 3,
  }).unwrap()
  assert_true(
    redundancy_limited.diagnose_constraints([{ name: "one", expression: "a" }])
    is Err(ConstraintAnalysisFailure(AnalysisBudgetExceeded(3))),
  )
  let conflict_limited = @moonbdd.Manager::new(["a"], {
    ..@moonbdd.ResourceBudget::default(),
    max_analysis_steps: 6,
  }).unwrap()
  assert_true(
    conflict_limited.diagnose_constraints([
      { name: "positive", expression: "a" },
      { name: "negative", expression: "!a" },
    ])
    is Err(ConstraintAnalysisFailure(AnalysisBudgetExceeded(6))),
  )
}
