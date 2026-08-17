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
  assert_eq(manager.reachable_node_count(a), 1)
}

///|
test "manager rejects duplicate variables and foreign handles" {
  let budget = @moonbdd.ResourceBudget::default()
  assert_true(
    @moonbdd.Manager::new(["a", "a"], budget) is
    Err(DuplicateVariable("a")),
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
  let manager = match @moonbdd.Manager::new(
    ["a", "b"],
    @moonbdd.ResourceBudget::default(),
  ) {
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
    let actual = [both, either, different, implied, equivalent].map(
      value => manager.evaluate(value, assignment).unwrap(),
    )
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
  assert_eq(
    manager.evaluate(selected, [("a", false), ("b", true)]),
    Ok(false),
  )
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
    manager.compile("a & missing") is Err(CompileFailure(UnknownVariable("missing"))),
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
  let composed = manager.compose(formula, "a", manager.variable("c").unwrap()).unwrap()
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
  assert_true(manager.restrict(a, [("missing", true)]) is Err(UnknownVariable(_)))
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
  let manager = @moonbdd.Manager::new(
    names,
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let tautology = manager.true_bdd()
  assert_true(manager.sat_count_u64(tautology) is Err(ArithmeticOverflow))
  assert_eq(
    manager.sat_count_decimal(tautology),
    Ok("1180591620717411303424"),
  )
  assert_eq(manager.sat_one(manager.false_bdd()), Ok(None))
}
