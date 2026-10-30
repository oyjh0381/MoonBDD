///|
test "manager creates stable terminals and variables" {
  let budget = @moonbdd.ResourceBudget::default()
  let manager = match @moonbdd.Manager::new(["a", "b"], budget) {
    Ok(manager) => manager
    Err(_) => fail("unexpected manager error")
  }
  let false_bdd = manager.false_bdd()
  let true_bdd = manager.true_bdd()
  let a = match manager.variable("a") {
    Ok(value) => value
    Err(_) => fail("unexpected variable error")
  }
  assert_eq(manager.variable_names(), ["a", "b"])
  assert_true(manager.is_false(false_bdd))
  assert_true(manager.is_true(true_bdd))
  assert_false(manager.is_terminal(a))
  assert_eq(manager.reachable_node_count(a), Ok(1))
}

///|
test "manager rejects duplicate variables and foreign handles" {
  let budget = @moonbdd.ResourceBudget::default()
  assert_true(
    @moonbdd.Manager::new(["a", "a"], budget) is Err(DuplicateVariable("a")),
  )
  assert_true(
    @moonbdd.Manager::new(["a b"], budget) is Err(InvalidVariableName("a b")),
  )
  assert_true(
    @moonbdd.Manager::new(["true"], budget) is Err(InvalidVariableName("true")),
  )
  let first = match @moonbdd.Manager::new(["a"], budget) {
    Ok(manager) => manager
    Err(_) => fail("unexpected manager error")
  }
  let second = match @moonbdd.Manager::new(["a"], budget) {
    Ok(manager) => manager
    Err(_) => fail("unexpected manager error")
  }
  let foreign = match first.variable("a") {
    Ok(value) => value
    Err(_) => fail("unexpected variable error")
  }
  assert_true(second.validate(foreign) is Err(ForeignHandle))
}

///|
test "canonical Boolean operations agree with a truth table" {
  let manager = match
    @moonbdd.Manager::new(["a", "b"], @moonbdd.ResourceBudget::default()) {
    Ok(manager) => manager
    Err(_) => fail("unexpected manager error")
  }
  let a = manager.variable("a").unwrap()
  let b = manager.variable("b").unwrap()
  let both = manager.and_bdd(a, b).unwrap()
  let either = manager.or_bdd(a, b).unwrap()
  let different = manager.xor_bdd(a, b).unwrap()
  let implied = manager.implies(a, b).unwrap()
  let equivalent = manager.equivalent(a, b).unwrap()
  assert_true(manager.and_bdd(b, a).unwrap().same(both))
  assert_true(manager.and_bdd(a, manager.true_bdd()).unwrap().same(a))
  assert_true(manager.or_bdd(a, manager.false_bdd()).unwrap().same(a))
  let rows = [
    ([false, false], [false, false, false, true, true]),
    ([false, true], [false, true, true, true, false]),
    ([true, false], [false, true, true, false, false]),
    ([true, true], [true, true, false, true, true]),
  ]
  for row in rows {
    let (values, expected) = row
    let assignment = [("a", values[0]), ("b", values[1])]
    let actual = [both, either, different, implied, equivalent].map(value => {
      manager.evaluate(value, assignment).unwrap()
    })
    assert_eq(actual, expected)
  }
}

///|
test "ITE and negation are canonical and ownership checked" {
  let budget = @moonbdd.ResourceBudget::default()
  let manager = @moonbdd.Manager::new(["a", "b"], budget).unwrap()
  let foreign_manager = @moonbdd.Manager::new(["a", "b"], budget).unwrap()
  let a = manager.variable("a").unwrap()
  let b = manager.variable("b").unwrap()
  let foreign = foreign_manager.variable("a").unwrap()
  let selected = manager.ite(a, b, manager.not_bdd(b).unwrap()).unwrap()
  assert_eq(manager.evaluate(selected, [("a", true), ("b", true)]), Ok(true))
  assert_eq(manager.evaluate(selected, [("a", false), ("b", true)]), Ok(false))
  assert_true(manager.and_bdd(a, foreign) is Err(ForeignHandle))
}

///|
test "expression compiler honours precedence and associativity" {
  let manager = @moonbdd.Manager::new(
    ["a", "b", "c"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let value = manager.compile("!a | b & c -> a ^ c").unwrap()
  assert_eq(
    manager.evaluate(value, [("a", false), ("b", false), ("c", false)]),
    Ok(false),
  )
  assert_eq(
    manager.evaluate(value, [("a", true), ("b", true), ("c", false)]),
    Ok(true),
  )
  let forward = manager.compile("a -> b -> c").unwrap()
  let explicit = manager.compile("a -> (b -> c)").unwrap()
  assert_true(forward.same(explicit))
}

///|
test "expression compiler reports stable source positions" {
  let manager = @moonbdd.Manager::new(
    ["a", "b"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  match manager.compile("a & )") {
    Err(ParseFailure(diagnostic)) => assert_eq(diagnostic.offset, 4)
    _ => fail("expected parse failure")
  }
  assert_true(
    manager.compile("a & missing")
    is Err(CompileFailure(UnknownVariable("missing"))),
  )
}

///|
test "restriction composition and quantification preserve Boolean meaning" {
  let manager = @moonbdd.Manager::new(
    ["a", "b", "c"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let formula = manager.compile("(a & b) | (!a & c)").unwrap()
  assert_eq(manager.support(formula).unwrap(), ["a", "b", "c"])
  let restricted = manager.restrict(formula, [("a", true)]).unwrap()
  assert_true(restricted.same(manager.variable("b").unwrap()))
  let composed = manager
    .compose(formula, "a", manager.variable("c").unwrap())
    .unwrap()
  let expected = manager.compile("(c & b) | (!c & c)").unwrap()
  assert_true(composed.same(expected))
  let exists_a = manager.exists(formula, ["a"]).unwrap()
  assert_true(exists_a.same(manager.compile("b | c").unwrap()))
  let forall_a = manager.forall(formula, ["a"]).unwrap()
  assert_true(forall_a.same(manager.compile("b & c").unwrap()))
}

///|
test "transformations reject unknown variables and foreign replacements" {
  let budget = @moonbdd.ResourceBudget::default()
  let manager = @moonbdd.Manager::new(["a"], budget).unwrap()
  let foreign_manager = @moonbdd.Manager::new(["a"], budget).unwrap()
  let a = manager.variable("a").unwrap()
  let foreign = foreign_manager.variable("a").unwrap()
  assert_true(
    manager.restrict(a, [("missing", true)]) is Err(UnknownVariable(_)),
  )
  assert_true(manager.exists(a, ["missing"]) is Err(UnknownVariable(_)))
  assert_true(manager.compose(a, "a", foreign) is Err(ForeignHandle))
}

///|
test "models and counts include variables skipped by reduced paths" {
  let manager = @moonbdd.Manager::new(
    ["a", "b", "unused"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let formula = manager.compile("a | b").unwrap()
  assert_eq(manager.sat_count_u64(formula), Ok(6UL))
  assert_eq(manager.sat_count_decimal(formula), Ok("6"))
  let witness = manager.sat_one(formula).unwrap().unwrap()
  assert_eq(manager.evaluate(formula, witness.values), Ok(true))
  let enumeration = manager.enumerate_models(formula, 2).unwrap()
  assert_eq(enumeration.models.length(), 2)
  assert_false(enumeration.complete)
}

///|
test "exact model count exceeds UInt64 without losing precision" {
  let names : Array[String] = []
  for i = 0; i < 70; i = i + 1 {
    names.push("x\{i}")
  }
  let manager = @moonbdd.Manager::new(names, @moonbdd.ResourceBudget::default()).unwrap()
  let tautology = manager.true_bdd()
  assert_true(manager.sat_count_u64(tautology) is Err(ArithmeticOverflow))
  assert_eq(manager.sat_count_decimal(tautology), Ok("1180591620717411303424"))
  assert_eq(manager.sat_one(manager.false_bdd()), Ok(None))
}

///|
test "versioned JSON is deterministic and round-trips Boolean meaning" {
  let budget = @moonbdd.ResourceBudget::default()
  let manager = @moonbdd.Manager::new(["a", "b"], budget).unwrap()
  let formula = manager.compile("a ^ b").unwrap()
  let encoded = manager.encode_json(formula).unwrap()
  assert_eq(encoded, manager.encode_json(formula).unwrap())
  let (restored_manager, restored) = @moonbdd.Manager::decode_json(
    encoded, budget,
  ).unwrap()
  for
    assignment in [
      [("a", false), ("b", false)],
      [("a", false), ("b", true)],
      [("a", true), ("b", false)],
      [("a", true), ("b", true)],
    ] {
    assert_eq(
      restored_manager.evaluate(restored, assignment),
      manager.evaluate(formula, assignment),
    )
  }
}

///|
test "JSON decoder rejects incompatible and malformed topology" {
  let budget = @moonbdd.ResourceBudget::default()
  assert_true(
    @moonbdd.Manager::decode_json(
      "{\"schema_version\":2,\"variables\":[],\"nodes\":[],\"root\":1}", budget,
    )
    is Err(UnsupportedVersion(2)),
  )
  assert_true(
    @moonbdd.Manager::decode_json(
      "{\"schema_version\":1,\"variables\":[\"a\"],\"nodes\":[{\"id\":2,\"variable\":0,\"low\":2,\"high\":1}],\"root\":2}",
      budget,
    )
    is Err(InvalidArtifact(_)),
  )
}

///|
test "statistics and DOT inspect only reachable ROBDD structure" {
  let manager = @moonbdd.Manager::new(
    ["a", "b", "unused"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let formula = manager.compile("a & b").unwrap()
  ignore(manager.variable("unused"))
  let stats = manager.statistics(formula).unwrap()
  assert_eq(stats.reachable_nodes, 2)
  assert_eq(stats.support_variables, 2)
  assert_true(stats.retained_nodes >= stats.reachable_nodes)
  let dot = manager.to_dot(formula, "constraint").unwrap()
  assert_eq(dot, manager.to_dot(formula, "constraint").unwrap())
  assert_true(dot.contains("digraph MoonBDD"))
  assert_true(dot.contains("constraint"))
  assert_false(dot.contains("unused"))
  let canonical = manager.canonical_expression(formula).unwrap()
  assert_true(manager.compile(canonical).unwrap().same(formula))
  assert_eq(
    canonical,
    manager.canonical_expression(manager.compile("b & a").unwrap()).unwrap(),
  )
}

///|
test "reordering is non-destructive and preserves Boolean meaning" {
  let budget = @moonbdd.ResourceBudget::default()
  let manager = @moonbdd.Manager::new(["a", "c", "b", "d"], budget).unwrap()
  let formula = manager.compile("(a & b) | (c & d)").unwrap()
  let before = manager.reachable_node_count(formula).unwrap()
  let reordered = manager.reorder(formula, ["a", "b", "c", "d"]).unwrap()
  assert_eq(reordered.before_nodes, before)
  assert_true(reordered.after_nodes <= reordered.manager.retained_node_count())
  for
    bits in [
      [false, false, false, false],
      [true, false, true, false],
      [false, true, false, true],
      [true, true, false, false],
    ] {
    let source_assignment = [
      ("a", bits[0]),
      ("c", bits[1]),
      ("b", bits[2]),
      ("d", bits[3]),
    ]
    let target_assignment = [
      ("a", bits[0]),
      ("b", bits[2]),
      ("c", bits[1]),
      ("d", bits[3]),
    ]
    assert_eq(
      manager.evaluate(formula, source_assignment),
      reordered.manager.evaluate(reordered.root, target_assignment),
    )
  }
  assert_eq(
    manager.evaluate(formula, [
      ("a", true),
      ("c", false),
      ("b", true),
      ("d", false),
    ]),
    Ok(true),
  )
  assert_true(manager.and_bdd(formula, reordered.root) is Err(ForeignHandle))
}

///|
test "reordering rejects non-permutations" {
  let manager = @moonbdd.Manager::new(
    ["a", "b"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let value = manager.compile("a | b").unwrap()
  assert_true(manager.reorder(value, ["a", "a"]) is Err(InvalidArgument(_)))
  assert_true(manager.reorder(value, ["a"]) is Err(InvalidArgument(_)))
}

///|
test "symbolic reachability computes a finite fixed point and invariant witness" {
  let manager = @moonbdd.Manager::new(
    ["p", "q", "p_next", "q_next"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let encoding = manager
    .state_encoding(["p", "q"], ["p_next", "q_next"])
    .unwrap()
  let initial = manager.compile("!p & !q").unwrap()
  let transition = manager
    .compile(
      "(!p & !q & ((!p_next & !q_next) | (p_next & !q_next) | (!p_next & q_next))) | (p & !q & ((!p_next & !q_next) | (p_next & !q_next))) | (!p & q & ((!p_next & !q_next) | (!p_next & q_next)))",
    )
    .unwrap()
  let safe = manager.compile("!(p & q)").unwrap()
  let result = manager.reach(initial, transition, encoding, Some(safe)).unwrap()
  assert_true(result.fixed_point)
  assert_true(result.invariant_holds)
  assert_eq(manager.support(result.reachable).unwrap(), ["p", "q"])
  let too_strict = manager.compile("!p").unwrap()
  let failed = manager
    .reach(initial, transition, encoding, Some(too_strict))
    .unwrap()
  assert_false(failed.invariant_holds)
  assert_true(failed.witness is Some(_))
}

///|
test "state encoding validates disjoint complete variable pairs" {
  let manager = @moonbdd.Manager::new(
    ["x", "x_next"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  assert_true(manager.state_encoding(["x"], []) is Err(InvalidArgument(_)))
  assert_true(manager.state_encoding(["x"], ["x"]) is Err(InvalidArgument(_)))
}

///|
test "reachability covers empty singleton and iteration budget boundaries" {
  let manager = @moonbdd.Manager::new(
    ["x", "x_next"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let encoding = manager.state_encoding(["x"], ["x_next"]).unwrap()
  let empty = manager
    .reach(manager.false_bdd(), manager.true_bdd(), encoding, None)
    .unwrap()
  assert_true(empty.fixed_point)
  assert_true(manager.is_false(empty.reachable))
  let singleton = manager
    .reach(
      manager.compile("!x").unwrap(),
      manager.compile("x <-> x_next").unwrap(),
      encoding,
      None,
    )
    .unwrap()
  assert_true(singleton.fixed_point)
  assert_eq(manager.sat_count_u64(singleton.reachable), Ok(2UL))
  let limited = @moonbdd.Manager::new(["x", "x_next"], {
    ..@moonbdd.ResourceBudget::default(),
    max_iterations: 1,
  }).unwrap()
  let limited_encoding = limited.state_encoding(["x"], ["x_next"]).unwrap()
  assert_true(
    limited.reach(
      limited.compile("!x").unwrap(),
      limited.true_bdd(),
      limited_encoding,
      None,
    )
    is Err(IterationBudgetExceeded(1)),
  )
}

///|
test "Resource Budgets reject work before unsafe growth" {
  let node_budget = { ..@moonbdd.ResourceBudget::default(), max_nodes: 2, }
  let node_manager = @moonbdd.Manager::new(["a"], node_budget).unwrap()
  assert_true(node_manager.variable("a") is Err(NodeBudgetExceeded(2)))
  let input_budget = {
    ..@moonbdd.ResourceBudget::default(),
    max_input_bytes: 3,
  }
  let input_manager = @moonbdd.Manager::new(["abcd"], input_budget).unwrap()
  assert_true(
    input_manager.compile("abcd") is Err(CompileFailure(InputBudgetExceeded(3))),
  )
  let model_budget = { ..@moonbdd.ResourceBudget::default(), max_models: 1, }
  let model_manager = @moonbdd.Manager::new(["a"], model_budget).unwrap()
  assert_true(
    model_manager.enumerate_models(model_manager.true_bdd(), 2)
    is Err(ModelBudgetExceeded(1)),
  )
  let count_budget = { ..@moonbdd.ResourceBudget::default(), max_work: 4, }
  let count_manager = @moonbdd.Manager::new(
    ["a", "b", "c", "d", "e"],
    count_budget,
  ).unwrap()
  assert_true(
    count_manager.sat_count_decimal(count_manager.true_bdd())
    is Err(WorkBudgetExceeded(4)),
  )
  assert_true(
    @moonbdd.Manager::new(["a"], {
      ..@moonbdd.ResourceBudget::default(),
      max_cache_entries: 0,
    })
    is Err(InvalidBudget("max_cache_entries", 0)),
  )
}

///|
test "failed bounded operations preserve existing BDD Handles" {
  let budget = { ..@moonbdd.ResourceBudget::default(), max_output_bytes: 16, }
  let manager = @moonbdd.Manager::new(["a"], budget).unwrap()
  let a = manager.variable("a").unwrap()
  assert_true(manager.encode_json(a) is Err(OutputBudgetExceeded(16)))
  assert_eq(manager.evaluate(a, [("a", true)]), Ok(true))
  let count_manager = @moonbdd.Manager::new(["a", "b", "c", "d", "e"], {
    ..@moonbdd.ResourceBudget::default(),
    max_output_bytes: 1,
  }).unwrap()
  assert_true(
    count_manager.sat_count_decimal(count_manager.true_bdd())
    is Err(OutputBudgetExceeded(1)),
  )
}
