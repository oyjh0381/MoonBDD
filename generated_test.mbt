///|
fn next_seed(state : Int) -> Int {
  (state * 25173 + 13849) % 65521
}

///|
fn generated_formula(state : Int, depth : Int) -> (String, Int) {
  let state = next_seed(state)
  if depth == 0 {
    let atoms = ["false", "true", "a", "b", "c"]
    return (atoms[state % atoms.length()], state)
  }
  if state % 5 == 0 {
    let (inner, after) = generated_formula(state, depth - 1)
    return ("!(" + inner + ")", after)
  }
  let (left, after_left) = generated_formula(state, depth - 1)
  let (right, after_right) = generated_formula(after_left, depth - 1)
  let operators = [" & ", " | ", " ^ ", " -> ", " <-> "]
  (
    "(" + left + operators[after_right % operators.length()] + right + ")",
    after_right,
  )
}

///|
fn generated_assignments() -> Array[Array[(String, Bool)]] {
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
test "seed 20260817 generates replayable formula properties" {
  let manager = @moonbdd.Manager::new(
    ["a", "b", "c"],
    @moonbdd.ResourceBudget::default(),
  ).unwrap()
  let mut seed = 20260817 % 65521
  for case_index = 0; case_index < 64; case_index = case_index + 1 {
    let (source, next) = generated_formula(seed, 3)
    seed = next
    let value = manager.compile(source).unwrap()
    let canonical = manager.canonical_expression(value).unwrap()
    let reparsed = manager.compile(canonical).unwrap()
    assert_true(value.same(reparsed))
    let mut expected_count = 0UL
    for assignment in generated_assignments() {
      if manager.evaluate(value, assignment) == Ok(true) {
        expected_count += 1
      }
    }
    assert_eq(manager.sat_count_u64(value), Ok(expected_count))
  }
}
