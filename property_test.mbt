///|
fn property_manager() -> @moonbdd.Manager {
  @moonbdd.Manager::new(["a", "b", "c"], @moonbdd.ResourceBudget::default()).unwrap()
}

///|
fn all_three_assignments() -> Array[Array[(String, Bool)]] {
  let rows : Array[Array[(String, Bool)]] = []
  for mask = 0; mask < 8; mask = mask + 1 {
    rows.push([
      ("a", (mask & 1) != 0),
      ("b", (mask & 2) != 0),
      ("c", (mask & 4) != 0),
    ])
  }
  rows
}

///|
fn assert_same_truth_table(
  manager : @moonbdd.Manager,
  left : @moonbdd.Bdd,
  right : @moonbdd.Bdd,
) -> Unit raise {
  for assignment in all_three_assignments() {
    assert_eq(
      manager.evaluate(left, assignment),
      manager.evaluate(right, assignment),
    )
  }
}

///|
test "Boolean algebra laws hold through the public API" {
  let manager = property_manager()
  let a = manager.variable("a").unwrap()
  let b = manager.variable("b").unwrap()
  let c = manager.variable("c").unwrap()
  let zero = manager.false_bdd()
  let one = manager.true_bdd()
  assert_true(manager.and_bdd(a, a).unwrap().same(a))
  assert_true(manager.or_bdd(a, a).unwrap().same(a))
  assert_true(manager.and_bdd(a, one).unwrap().same(a))
  assert_true(manager.or_bdd(a, zero).unwrap().same(a))
  assert_true(manager.and_bdd(a, zero).unwrap().same(zero))
  assert_true(manager.or_bdd(a, one).unwrap().same(one))
  assert_true(manager.not_bdd(manager.not_bdd(a).unwrap()).unwrap().same(a))
  assert_true(
    manager.and_bdd(a, b).unwrap().same(manager.and_bdd(b, a).unwrap()),
  )
  assert_true(manager.or_bdd(a, b).unwrap().same(manager.or_bdd(b, a).unwrap()))
  let and_left = manager.and_bdd(manager.and_bdd(a, b).unwrap(), c).unwrap()
  let and_right = manager.and_bdd(a, manager.and_bdd(b, c).unwrap()).unwrap()
  assert_true(and_left.same(and_right))
  let or_left = manager.or_bdd(manager.or_bdd(a, b).unwrap(), c).unwrap()
  let or_right = manager.or_bdd(a, manager.or_bdd(b, c).unwrap()).unwrap()
  assert_true(or_left.same(or_right))
  let distributed = manager.and_bdd(a, manager.or_bdd(b, c).unwrap()).unwrap()
  let expanded = manager
    .or_bdd(manager.and_bdd(a, b).unwrap(), manager.and_bdd(a, c).unwrap())
    .unwrap()
  assert_true(distributed.same(expanded))
}

///|
test "parser precedence matrix has independently worked expectations" {
  let manager = property_manager()
  let cases = [
    ("a | b & c", [false, true, false, true, false, true, true, true]),
    ("a ^ b | c", [false, true, true, false, true, true, true, true]),
    ("a -> b", [true, false, true, true, true, false, true, true]),
    ("a <-> b", [true, false, false, true, true, false, false, true]),
    ("!(a | b)", [true, false, false, false, true, false, false, false]),
  ]
  for item in cases {
    let (source, expected) = item
    let value = manager.compile(source).unwrap()
    for index, assignment in all_three_assignments() {
      assert_eq(manager.evaluate(value, assignment), Ok(expected[index]))
    }
  }
}

///|
test "Shannon expansion is canonical for every generated small formula" {
  let manager = property_manager()
  let atoms = [
    manager.false_bdd(),
    manager.true_bdd(),
    manager.variable("a").unwrap(),
    manager.variable("b").unwrap(),
    manager.variable("c").unwrap(),
  ]
  let formulas : Array[@moonbdd.Bdd] = atoms.copy()
  for left in atoms {
    formulas.push(manager.not_bdd(left).unwrap())
    for right in atoms {
      formulas.push(manager.and_bdd(left, right).unwrap())
      formulas.push(manager.or_bdd(left, right).unwrap())
      formulas.push(manager.xor_bdd(left, right).unwrap())
      formulas.push(manager.implies(left, right).unwrap())
    }
  }
  for formula in formulas {
    let printed = manager.canonical_expression(formula).unwrap()
    let reparsed = manager.compile(printed).unwrap()
    assert_true(formula.same(reparsed))
  }
}

///|
test "restriction matches direct evaluation for every assignment" {
  let manager = property_manager()
  let formula = manager.compile("(a ^ b) | (a & c)").unwrap()
  for a_value in [false, true] {
    let restricted = manager.restrict(formula, [("a", a_value)]).unwrap()
    for b_value in [false, true] {
      for c_value in [false, true] {
        assert_eq(
          manager.evaluate(formula, [
            ("a", a_value),
            ("b", b_value),
            ("c", c_value),
          ]),
          manager.evaluate(restricted, [
            ("a", a_value),
            ("b", b_value),
            ("c", c_value),
          ]),
        )
      }
    }
  }
}

///|
test "quantification matches explicit Boolean expansion" {
  let manager = property_manager()
  let formula = manager.compile("(a & b) | (!a & c)").unwrap()
  let when_false = manager.restrict(formula, [("a", false)]).unwrap()
  let when_true = manager.restrict(formula, [("a", true)]).unwrap()
  let expected_exists = manager.or_bdd(when_false, when_true).unwrap()
  let expected_forall = manager.and_bdd(when_false, when_true).unwrap()
  assert_true(manager.exists(formula, ["a"]).unwrap().same(expected_exists))
  assert_true(manager.forall(formula, ["a"]).unwrap().same(expected_forall))
}

///|
test "model enumeration returns distinct satisfying complete assignments" {
  let manager = property_manager()
  let formula = manager.compile("a ^ b ^ c").unwrap()
  let enumeration = manager.enumerate_models(formula, 8).unwrap()
  assert_true(enumeration.complete)
  assert_eq(enumeration.models.length(), 4)
  let encoded : Array[String] = []
  for model in enumeration.models {
    assert_eq(manager.evaluate(formula, model.values), Ok(true))
    encoded.push(@debug.to_string(model.values))
  }
  encoded.sort()
  for index = 1; index < encoded.length(); index = index + 1 {
    assert_true(encoded[index - 1] != encoded[index])
  }
}

///|
test "artifact mutations are rejected at the public decoder seam" {
  let budget = @moonbdd.ResourceBudget::default()
  let invalid = [
    "", "null", "{}", "{\"schema_version\":1}", "{\"schema_version\":1,\"variables\":{},\"nodes\":[],\"root\":0}",
    "{\"schema_version\":1,\"variables\":[\"a\",\"a\"],\"nodes\":[],\"root\":0}",
    "{\"schema_version\":1,\"variables\":[\"a\"],\"nodes\":{},\"root\":0}", "{\"schema_version\":1,\"variables\":[\"a\"],\"nodes\":[],\"root\":9}",
    "{\"schema_version\":1,\"variables\":[\"a\"],\"nodes\":[null],\"root\":2}", "{\"schema_version\":1,\"variables\":[\"a\"],\"nodes\":[{\"id\":3,\"variable\":0,\"low\":0,\"high\":1}],\"root\":2}",
    "{\"schema_version\":1,\"variables\":[\"a\"],\"nodes\":[{\"id\":2,\"variable\":9,\"low\":0,\"high\":1}],\"root\":2}",
    "{\"schema_version\":1,\"variables\":[\"a\"],\"nodes\":[{\"id\":2,\"variable\":0,\"low\":1,\"high\":1}],\"root\":2}",
  ]
  for artifact in invalid {
    assert_true(@moonbdd.Manager::decode_json(artifact, budget) is Err(_))
  }
}

///|
test "reorder translation preserves all assignments for every permutation" {
  let manager = property_manager()
  let formula = manager.compile("(a & b) | (!a & c)").unwrap()
  let orders = [
    ["a", "b", "c"],
    ["a", "c", "b"],
    ["b", "a", "c"],
    ["b", "c", "a"],
    ["c", "a", "b"],
    ["c", "b", "a"],
  ]
  for order in orders {
    let reordered = manager.reorder(formula, order).unwrap()
    for assignment in all_three_assignments() {
      assert_eq(
        manager.evaluate(formula, assignment),
        reordered.manager.evaluate(reordered.root, assignment),
      )
    }
  }
}

///|
test "public operations preserve source Handles after bounded failures" {
  let tiny = { ..@moonbdd.ResourceBudget::default(), max_work: 2 }
  let manager = @moonbdd.Manager::new(["a", "b"], tiny).unwrap()
  let a = manager.variable("a").unwrap()
  let b = manager.variable("b").unwrap()
  ignore(manager.and_bdd(a, b))
  assert_eq(manager.evaluate(a, [("a", true), ("b", false)]), Ok(true))
  assert_eq(manager.evaluate(b, [("a", false), ("b", true)]), Ok(true))
}

///|
test "truth table helper itself covers every three-variable assignment" {
  let rows = all_three_assignments()
  assert_eq(rows.length(), 8)
  let manager = property_manager()
  let parity = manager.compile("a ^ b ^ c").unwrap()
  let complement = manager.not_bdd(parity).unwrap()
  assert_same_truth_table(
    manager,
    manager.or_bdd(parity, complement).unwrap(),
    manager.true_bdd(),
  )
}
