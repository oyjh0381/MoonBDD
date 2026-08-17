///|
/// Validated pairing of current-state and next-state Boolean Variables.
pub struct StateEncoding {
  owner : Manager
  current : Array[String]
  next : Array[String]
}

///|
/// Result of bounded finite symbolic reachability.
pub(all) struct ReachabilityResult {
  reachable : Bdd
  iterations : Int
  fixed_point : Bool
  invariant_holds : Bool
  witness : Model?
}

///|
pub fn Manager::state_encoding(
  self : Manager,
  current : Array[String],
  next : Array[String],
) -> Result[StateEncoding, BddError] {
  if current.length() == 0 || current.length() != next.length() {
    return Err(
      InvalidArgument("state Variable pairs must be non-empty and equal length"),
    )
  }
  let seen : @hashmap.HashMap[String, Unit] = @hashmap.HashMap([])
  for name in current {
    if self.variable_index.get(name) is None {
      return Err(UnknownVariable(name))
    }
    if seen.get(name) is Some(_) {
      return Err(
        InvalidArgument("state encoding contains a duplicate Variable"),
      )
    }
    seen.set(name, ())
  }
  for name in next {
    if self.variable_index.get(name) is None {
      return Err(UnknownVariable(name))
    }
    if seen.get(name) is Some(_) {
      return Err(InvalidArgument("current and next Variables must be disjoint"))
    }
    seen.set(name, ())
  }
  Ok({ owner: self, current: current.copy(), next: next.copy() })
}

///|
pub fn StateEncoding::current_variables(self : StateEncoding) -> Array[String] {
  self.current.copy()
}

///|
pub fn StateEncoding::next_variables(self : StateEncoding) -> Array[String] {
  self.next.copy()
}

///|
fn Manager::rename_next_to_current(
  self : Manager,
  value : Bdd,
  encoding : StateEncoding,
) -> Result[Bdd, BddError] {
  let mut renamed = value
  for index, next_name in encoding.next {
    let current_value = match self.variable(encoding.current[index]) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    renamed = match self.compose(renamed, next_name, current_value) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
  }
  Ok(renamed)
}

///|
/// Compute the least finite Reachability Fixed Point. The Transition Relation
/// is interpreted over the paired current and next Variables in `encoding`.
pub fn Manager::reach(
  self : Manager,
  initial : Bdd,
  transition : Bdd,
  encoding : StateEncoding,
  invariant : Bdd?,
) -> Result[ReachabilityResult, BddError] {
  for value in [initial, transition] {
    match self.validate(value) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  if !physical_equal(self, encoding.owner) {
    return Err(ForeignHandle)
  }
  match invariant {
    Some(value) =>
      match self.validate(value) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    None => ()
  }
  let mut reachable = initial
  let mut iterations = 0
  let mut fixed = false
  while iterations < self.budget.max_iterations {
    let joined = match self.and_bdd(reachable, transition) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let projected = match self.exists(joined, encoding.current) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let successors = match self.rename_next_to_current(projected, encoding) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let expanded = match self.or_bdd(reachable, successors) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    iterations += 1
    if expanded.same(reachable) {
      fixed = true
      break
    }
    reachable = expanded
  }
  if !fixed {
    return Err(IterationBudgetExceeded(self.budget.max_iterations))
  }
  let mut invariant_holds = true
  let mut witness : Model? = None
  match invariant {
    None => ()
    Some(required) => {
      let not_required = match self.not_bdd(required) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let bad = match self.and_bdd(reachable, not_required) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      match self.sat_one(bad) {
        Ok(None) => ()
        Ok(Some(model)) => {
          invariant_holds = false
          witness = Some(model)
        }
        Err(error) => return Err(error)
      }
    }
  }
  Ok({ reachable, iterations, fixed_point: fixed, invariant_holds, witness })
}
