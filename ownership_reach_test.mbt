///|
test "manager and state encoding keep variable-order inputs and views detached" {
  let names = ["s", "n"]
  let manager = @moonbdd.Manager::new(names, @moonbdd.ResourceBudget::default()).unwrap()
  names.clear()
  let exported = manager.variable_names()
  exported[0] = "changed"
  let current = ["s"]
  let next = ["n"]
  let encoding = manager.state_encoding(current, next).unwrap()
  current.clear()
  next[0] = "changed"
  encoding.current_variables().clear()
  encoding.next_variables().clear()
  assert_eq(manager.variable_names(), ["s", "n"])
  assert_eq(encoding.current_variables(), ["s"])
  assert_eq(encoding.next_variables(), ["n"])
  let initial = manager.compile("!s").unwrap()
  let toggle = manager.compile("n <-> !s").unwrap()
  let reached = manager.reach(initial, toggle, encoding, None).unwrap()
  assert_true(manager.is_true(reached.reachable))
}

///|
test "reach rejects next-state initial conditions and unpaired dimensions" {
  let manager = @moonbdd.Manager::new(
    ["s", "n", "env"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let encoding = manager.state_encoding(["s"], ["n"]).unwrap()
  let initial = manager.compile("!s").unwrap()
  let transition = manager.compile("n <-> !s").unwrap()
  // A next-state condition in the initial set used to become an accidental
  // free dimension of the fixed point instead of being rejected.
  assert_true(
    manager.reach(manager.variable("n").unwrap(), transition, encoding, None)
    is Err(InvalidArgument(_)),
  )
  assert_true(
    manager.reach(
      initial,
      manager.compile("n <-> env").unwrap(),
      encoding,
      None,
    )
    is Err(InvalidArgument(_)),
  )
  assert_true(
    manager.reach(
      initial,
      transition,
      encoding,
      Some(manager.variable("n").unwrap()),
    )
    is Err(InvalidArgument(_)),
  )
  assert_true(
    manager.reach(manager.variable("env").unwrap(), transition, encoding, None)
    is Err(InvalidArgument(_)),
  )
  let valid = manager
    .reach(initial, transition, encoding, Some(manager.true_bdd()))
    .unwrap()
  assert_true(valid.fixed_point)
  assert_true(valid.invariant_holds)
}

///|
test "symbolic toggling matches explicit finite-state graph for every initial subset" {
  let manager = @moonbdd.Manager::new(
    ["a", "b", "an", "bn"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let encoding = manager.state_encoding(["a", "b"], ["an", "bn"]).unwrap()
  let relation = manager.compile("(an <-> !a) & (bn <-> b)").unwrap()
  for mask = 0; mask < 16; mask = mask + 1 {
    let mut initial = manager.false_bdd()
    for state = 0; state < 4; state = state + 1 {
      if (mask & (1 << state)) != 0 {
        let cube : @moonbdd.Cube = {
          values: [("a", (state & 1) != 0), ("b", (state & 2) != 0)],
        }
        initial = manager
          .or_bdd(initial, manager.cube_to_bdd(cube).unwrap())
          .unwrap()
      }
    }
    let reached = manager.reach(initial, relation, encoding, None).unwrap()
    for state = 0; state < 4; state = state + 1 {
      let expected = (mask & (1 << state)) != 0 ||
        (mask & (1 << (state ^ 1))) != 0
      assert_eq(
        manager.evaluate(reached.reachable, [
          ("a", (state & 1) != 0),
          ("b", (state & 2) != 0),
        ]),
        Ok(expected),
      )
    }
  }
}
