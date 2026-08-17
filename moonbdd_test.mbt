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
