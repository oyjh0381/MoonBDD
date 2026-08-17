///|
fn validate_budget(budget : ResourceBudget) -> Result[Unit, BddError] {
  let checks = [
    ("max_nodes", budget.max_nodes),
    ("max_cache_entries", budget.max_cache_entries),
    ("max_work", budget.max_work),
    ("max_input_bytes", budget.max_input_bytes),
    ("max_depth", budget.max_depth),
    ("max_models", budget.max_models),
    ("max_constraints", budget.max_constraints),
    ("max_analysis_steps", budget.max_analysis_steps),
    ("max_output_bytes", budget.max_output_bytes),
    ("max_reorder_attempts", budget.max_reorder_attempts),
    ("max_iterations", budget.max_iterations),
  ]
  for check in checks {
    let (name, value) = check
    if value <= 0 {
      return Err(InvalidBudget(name, value))
    }
  }
  if budget.max_nodes < 2 {
    return Err(InvalidBudget("max_nodes", budget.max_nodes))
  }
  Ok(())
}

///|
pub fn Manager::new(
  variable_names : Array[String],
  budget : ResourceBudget,
) -> Result[Manager, BddError] {
  match validate_budget(budget) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let names = variable_names.copy()
  let index : @hashmap.HashMap[String, Int] = @hashmap.HashMap([])
  for i, name in names {
    if name.length() == 0 {
      return Err(EmptyVariable)
    }
    if !valid_variable_name(name) {
      return Err(InvalidVariableName(name))
    }
    if index.get(name) is Some(_) {
      return Err(DuplicateVariable(name))
    }
    index.set(name, i)
  }
  Ok({
    variables: names,
    variable_index: index,
    budget,
    nodes: [
      { variable: -1, low: 0, high: 0 },
      { variable: -1, low: 1, high: 1 },
    ],
    unique: @hashmap.HashMap([]),
    ite_cache: @hashmap.HashMap([]),
  })
}

///|
pub fn Manager::variable_names(self : Manager) -> Array[String] {
  self.variables.copy()
}

///|
pub fn Manager::variable_count(self : Manager) -> Int {
  self.variables.length()
}

///|
pub fn Manager::false_bdd(self : Manager) -> Bdd {
  { owner: self, root: 0 }
}

///|
pub fn Manager::true_bdd(self : Manager) -> Bdd {
  { owner: self, root: 1 }
}

///|
pub fn Manager::validate(self : Manager, value : Bdd) -> Result[Unit, BddError] {
  if physical_equal(self, value.owner) {
    Ok(())
  } else {
    Err(ForeignHandle)
  }
}

///|
pub fn Manager::is_false(self : Manager, value : Bdd) -> Bool {
  physical_equal(self, value.owner) && value.root == 0
}

///|
pub fn Manager::is_true(self : Manager, value : Bdd) -> Bool {
  physical_equal(self, value.owner) && value.root == 1
}

///|
pub fn Manager::is_terminal(self : Manager, value : Bdd) -> Bool {
  physical_equal(self, value.owner) && value.root <= 1
}

///|
pub fn Bdd::same(self : Bdd, other : Bdd) -> Bool {
  physical_equal(self.owner, other.owner) && self.root == other.root
}

///|
fn Manager::mk(
  self : Manager,
  variable : Int,
  low : Int,
  high : Int,
  work : WorkCounter,
) -> Result[Int, BddError] {
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if low == high {
    return Ok(low)
  }
  let key : NodeKey = { variable, low, high }
  match self.unique.get(key) {
    Some(existing) => Ok(existing)
    None => {
      if self.nodes.length() >= self.budget.max_nodes {
        return Err(NodeBudgetExceeded(self.budget.max_nodes))
      }
      let id = self.nodes.length()
      self.nodes.push({ variable, low, high })
      self.unique.set(key, id)
      Ok(id)
    }
  }
}

///|
pub fn Manager::variable(
  self : Manager,
  name : String,
) -> Result[Bdd, BddError] {
  match self.variable_index.get(name) {
    None => Err(UnknownVariable(name))
    Some(variable) => {
      let work = WorkCounter::new(self.budget.max_work)
      match self.mk(variable, 0, 1, work) {
        Ok(root) => Ok({ owner: self, root })
        Err(error) => Err(error)
      }
    }
  }
}

///|
pub fn Manager::reachable_node_count(
  self : Manager,
  value : Bdd,
) -> Result[Int, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let seen : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
  let pending = [value.root]
  let work = WorkCounter::new(self.budget.max_work)
  while pending.length() > 0 {
    match work.step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let root = pending.pop().unwrap()
    if root > 1 && seen.get(root) is None {
      seen.set(root, ())
      let node = self.nodes[root]
      pending.push(node.low)
      pending.push(node.high)
    }
  }
  Ok(seen.length())
}

///|
pub fn Manager::retained_node_count(self : Manager) -> Int {
  self.nodes.length() - 2
}
