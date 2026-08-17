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
