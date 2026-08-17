///|
/// Result of evaluating a Boolean Function under a potentially incomplete
/// assignment. `Undetermined` means both outcomes remain possible.
pub(all) enum PartialValue {
  AlwaysFalse
  AlwaysTrue
  Undetermined
} derive(Debug, Eq)

///|
/// One complete row in Manager Variable Order.
pub(all) struct TruthRow {
  values : Array[(String, Bool)]
  result : Bool
} derive(Debug, Eq)

///|
/// Bounded deterministic Truth Table. `complete` is false when the caller's
/// row limit stopped enumeration before all complete assignments were emitted.
pub(all) struct TruthTable {
  rows : Array[TruthRow]
  complete : Bool
} derive(Debug, Eq)

///|
/// One partial assignment that guarantees the represented function is true.
/// Variables absent from `values` are don't-care dimensions.
pub(all) struct Cube {
  values : Array[(String, Bool)]
} derive(Debug, Eq)

///|
/// Bounded deterministic enumeration of pairwise-disjoint satisfying Cubes.
pub(all) struct CubeEnumeration {
  cubes : Array[Cube]
  complete : Bool
} derive(Debug, Eq)

///|
/// Outcome of a Boolean relation check. When `holds` is false, `witness`
/// contains a complete assignment demonstrating the failure.
pub(all) struct RelationCheck {
  holds : Bool
  witness : Model?
} derive(Debug, Eq)

///|
/// One named Boolean expression in a Constraint Set.
pub(all) struct NamedConstraint {
  name : String
  expression : String
} derive(Debug, Eq)

///|
/// Stable failures specific to compiling and diagnosing named Constraint Sets.
pub(all) enum ConstraintError {
  EmptyConstraintName
  DuplicateConstraintName(String)
  ConstraintCompileFailure(String, ExpressionError)
  ConstraintAnalysisFailure(BddError)
} derive(Debug, Eq)

///|
/// Deterministic Constraint Set diagnosis. Satisfiable sets provide a witness
/// and constraints removable without changing the conjunction. Unsatisfiable
/// sets provide a deletion-minimal conflict in input order.
pub struct ConstraintReport {
  combined : Bdd
  satisfiable : Bool
  witness : Model?
  minimal_conflict : Array[String]
  redundant : Array[String]
}

///|
priv struct AnalysisCounter {
  mut used : Int
  maximum : Int
}

///|
fn AnalysisCounter::new(maximum : Int) -> AnalysisCounter {
  { used: 0, maximum }
}

///|
fn AnalysisCounter::step(self : AnalysisCounter) -> Result[Unit, BddError] {
  if self.used >= self.maximum {
    Err(AnalysisBudgetExceeded(self.maximum))
  } else {
    self.used += 1
    Ok(())
  }
}

///|
pub fn Manager::evaluate_partial(
  self : Manager,
  value : Bdd,
  assignment : Array[(String, Bool)],
) -> Result[PartialValue, BddError] {
  let remaining = match self.restrict(value, assignment) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if self.is_false(remaining) {
    Ok(AlwaysFalse)
  } else if self.is_true(remaining) {
    Ok(AlwaysTrue)
  } else {
    Ok(Undetermined)
  }
}

///|
fn Manager::truth_rows(
  self : Manager,
  root : Int,
  variable : Int,
  current : Array[(String, Bool)],
  rows : Array[TruthRow],
  limit : Int,
  work : WorkCounter,
) -> Result[Bool, BddError] {
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if variable > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  if variable == self.variables.length() {
    rows.push({ values: current.copy(), result: root == 1 })
    return Ok(true)
  }
  let mut low = root
  let mut high = root
  if root > 1 {
    let node = self.nodes[root]
    if node.variable == variable {
      low = node.low
      high = node.high
    }
  }
  current.push((self.variables[variable], false))
  let low_complete = match
    self.truth_rows(low, variable + 1, current, rows, limit, work) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  ignore(current.pop())
  if !low_complete {
    return Ok(false)
  }
  if rows.length() >= limit {
    return Ok(false)
  }
  current.push((self.variables[variable], true))
  let high_complete = match
    self.truth_rows(high, variable + 1, current, rows, limit, work) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  ignore(current.pop())
  Ok(high_complete)
}

///|
pub fn Manager::truth_table(
  self : Manager,
  value : Bdd,
  maximum_rows : Int,
) -> Result[TruthTable, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if maximum_rows <= 0 {
    return Err(InvalidArgument("maximum truth-table rows must be positive"))
  }
  if maximum_rows > self.budget.max_models {
    return Err(ModelBudgetExceeded(self.budget.max_models))
  }
  let rows : Array[TruthRow] = []
  let complete = match
    self.truth_rows(
      value.root,
      0,
      [],
      rows,
      maximum_rows,
      WorkCounter::new(self.budget.max_work),
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({ rows, complete })
}

///|
fn Manager::enumerate_cube_roots(
  self : Manager,
  root : Int,
  current : Array[(String, Bool)],
  cubes : Array[Cube],
  limit : Int,
  work : WorkCounter,
  depth : Int,
) -> Result[Bool, BddError] {
  if root == 0 {
    return Ok(true)
  }
  if cubes.length() >= limit {
    return Ok(false)
  }
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if root == 1 {
    cubes.push({ values: current.copy() })
    return Ok(true)
  }
  let node = self.nodes[root]
  let name = self.variables[node.variable]
  current.push((name, false))
  let low_complete = match
    self.enumerate_cube_roots(node.low, current, cubes, limit, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  ignore(current.pop())
  if !low_complete {
    return Ok(false)
  }
  if cubes.length() >= limit {
    return Ok(node.high == 0)
  }
  current.push((name, true))
  let high_complete = match
    self.enumerate_cube_roots(node.high, current, cubes, limit, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  ignore(current.pop())
  Ok(high_complete)
}

///|
/// Enumerate true-terminal paths as disjoint partial assignments. Cubes are
/// returned in low-before-high Variable Order and may omit don't-care names.
pub fn Manager::enumerate_cubes(
  self : Manager,
  value : Bdd,
  maximum_cubes : Int,
) -> Result[CubeEnumeration, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if maximum_cubes <= 0 {
    return Err(InvalidArgument("maximum cubes must be positive"))
  }
  if maximum_cubes > self.budget.max_models {
    return Err(ModelBudgetExceeded(self.budget.max_models))
  }
  let cubes : Array[Cube] = []
  let complete = match
    self.enumerate_cube_roots(
      value.root,
      [],
      cubes,
      maximum_cubes,
      WorkCounter::new(self.budget.max_work),
      0,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({ cubes, complete })
}

///|
/// Convert a partial assignment into its conjunction. Input order is ignored;
/// the resulting BDD always follows Manager Variable Order.
pub fn Manager::cube_to_bdd(
  self : Manager,
  cube : Cube,
) -> Result[Bdd, BddError] {
  let selected : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap([])
  let counter = AnalysisCounter::new(self.budget.max_analysis_steps)
  for pair in cube.values {
    match counter.step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let (name, choice) = pair
    let variable = match self.variable_index.get(name) {
      None => return Err(UnknownVariable(name))
      Some(value) => value
    }
    if selected.get(variable) is Some(_) {
      return Err(InvalidArgument("cube contains a duplicate Variable"))
    }
    selected.set(variable, choice)
  }
  let mut result = self.true_bdd()
  if selected.length() == 0 {
    return Ok(result)
  }
  let mut remaining = selected.length()
  for variable, name in self.variables {
    match counter.step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    match selected.get(variable) {
      None => ()
      Some(choice) => {
        let positive = match self.variable(name) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        let literal = if choice {
          positive
        } else {
          match self.not_bdd(positive) {
            Ok(value) => value
            Err(error) => return Err(error)
          }
        }
        result = match self.and_bdd(result, literal) {
          Ok(value) => value
          Err(error) => return Err(error)
        }
        remaining -= 1
        if remaining == 0 {
          return Ok(result)
        }
      }
    }
  }
  Ok(result)
}

///|
fn Manager::relation_result(
  self : Manager,
  counterexample : Bdd,
) -> Result[RelationCheck, BddError] {
  match self.sat_one(counterexample) {
    Ok(None) => Ok({ holds: true, witness: None })
    Ok(Some(model)) => Ok({ holds: false, witness: Some(model) })
    Err(error) => Err(error)
  }
}

///|
/// Check whether every Model of `premise` is also a Model of `conclusion`.
pub fn Manager::check_entailment(
  self : Manager,
  premise : Bdd,
  conclusion : Bdd,
) -> Result[RelationCheck, BddError] {
  let not_conclusion = match self.not_bdd(conclusion) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let counterexample = match self.and_bdd(premise, not_conclusion) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.relation_result(counterexample)
}

///|
/// Check semantic equivalence and return a Model of the exclusive-or on
/// failure.
pub fn Manager::check_equivalence(
  self : Manager,
  left : Bdd,
  right : Bdd,
) -> Result[RelationCheck, BddError] {
  let counterexample = match self.xor_bdd(left, right) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.relation_result(counterexample)
}

///|
/// Check that two Boolean Functions have no common Model.
pub fn Manager::check_disjoint(
  self : Manager,
  left : Bdd,
  right : Bdd,
) -> Result[RelationCheck, BddError] {
  let overlap = match self.and_bdd(left, right) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.relation_result(overlap)
}

///|
/// Return assignments forced in every satisfying Model, in Variable Order.
pub fn Manager::backbone(
  self : Manager,
  value : Bdd,
) -> Result[Array[(String, Bool)], BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if self.is_false(value) {
    return Err(
      InvalidArgument("backbone is undefined for an unsatisfiable function"),
    )
  }
  let support = match self.support(value) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let counter = AnalysisCounter::new(self.budget.max_analysis_steps)
  let result : Array[(String, Bool)] = []
  for name in support {
    match counter.step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let when_false = match self.restrict(value, [(name, false)]) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let when_true = match self.restrict(value, [(name, true)]) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if self.is_false(when_false) {
      result.push((name, true))
    } else if self.is_false(when_true) {
      result.push((name, false))
    }
  }
  Ok(result)
}

///|
fn constraint_failure(error : BddError) -> ConstraintError {
  ConstraintAnalysisFailure(error)
}

///|
fn AnalysisCounter::constraint_step(
  self : AnalysisCounter,
) -> Result[Unit, ConstraintError] {
  match self.step() {
    Ok(_) => Ok(())
    Err(error) => Err(constraint_failure(error))
  }
}

///|
fn Manager::conjoin_constraints(
  self : Manager,
  constraints : Array[(String, Bdd)],
  counter : AnalysisCounter,
) -> Result[Bdd, ConstraintError] {
  let mut combined = self.true_bdd()
  for item in constraints {
    let (_, constraint) = item
    match counter.constraint_step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    combined = match self.and_bdd(combined, constraint) {
      Ok(value) => value
      Err(error) => return Err(constraint_failure(error))
    }
  }
  Ok(combined)
}

///|
fn without_constraint(
  constraints : Array[(String, Bdd)],
  removed : Int,
) -> Array[(String, Bdd)] {
  let result : Array[(String, Bdd)] = []
  for index, item in constraints {
    if index != removed {
      result.push(item)
    }
  }
  result
}

///|
fn Manager::diagnose_satisfiable(
  self : Manager,
  compiled : Array[(String, Bdd)],
  combined : Bdd,
  witness : Model,
  counter : AnalysisCounter,
) -> Result[ConstraintReport, ConstraintError] {
  let retained = compiled.copy()
  let redundant_reverse : Array[String] = []
  let mut index = retained.length() - 1
  while index >= 0 {
    let candidate = without_constraint(retained, index)
    let without = match self.conjoin_constraints(candidate, counter) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match counter.constraint_step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let check = match self.check_entailment(without, retained[index].1) {
      Ok(value) => value
      Err(error) => return Err(constraint_failure(error))
    }
    if check.holds {
      redundant_reverse.push(retained[index].0)
      ignore(retained.remove(index))
    }
    index -= 1
  }
  redundant_reverse.rev_in_place()
  Ok({
    combined,
    satisfiable: true,
    witness: Some(witness),
    minimal_conflict: [],
    redundant: redundant_reverse,
  })
}

///|
fn Manager::diagnose_unsatisfiable(
  self : Manager,
  compiled : Array[(String, Bdd)],
  combined : Bdd,
  counter : AnalysisCounter,
) -> Result[ConstraintReport, ConstraintError] {
  let core = compiled.copy()
  let mut index = 0
  while index < core.length() {
    let candidate = without_constraint(core, index)
    let without = match self.conjoin_constraints(candidate, counter) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    match counter.constraint_step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    if self.is_false(without) {
      ignore(core.remove(index))
    } else {
      index += 1
    }
  }
  let names : Array[String] = []
  for item in core {
    names.push(item.0)
  }
  Ok({
    combined,
    satisfiable: false,
    witness: None,
    minimal_conflict: names,
    redundant: [],
  })
}

///|
/// Compile and diagnose a deterministic set of named constraints. Redundancy
/// elimination scans from the end so earlier policy declarations win.
pub fn Manager::diagnose_constraints(
  self : Manager,
  constraints : Array[NamedConstraint],
) -> Result[ConstraintReport, ConstraintError] {
  if constraints.length() > self.budget.max_constraints {
    return Err(
      constraint_failure(ConstraintBudgetExceeded(self.budget.max_constraints)),
    )
  }
  let names : @hashmap.HashMap[String, Unit] = @hashmap.HashMap([])
  let compiled : Array[(String, Bdd)] = []
  let counter = AnalysisCounter::new(self.budget.max_analysis_steps)
  for constraint in constraints {
    if constraint.name == "" {
      return Err(EmptyConstraintName)
    }
    if names.get(constraint.name) is Some(_) {
      return Err(DuplicateConstraintName(constraint.name))
    }
    names.set(constraint.name, ())
    match counter.constraint_step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let value = match self.compile(constraint.expression) {
      Ok(value) => value
      Err(error) => return Err(ConstraintCompileFailure(constraint.name, error))
    }
    compiled.push((constraint.name, value))
  }
  let combined = match self.conjoin_constraints(compiled, counter) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match counter.constraint_step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match self.sat_one(combined) {
    Err(error) => Err(constraint_failure(error))
    Ok(Some(witness)) =>
      self.diagnose_satisfiable(compiled, combined, witness, counter)
    Ok(None) => self.diagnose_unsatisfiable(compiled, combined, counter)
  }
}
