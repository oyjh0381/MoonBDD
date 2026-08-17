///|
fn Manager::validated_variable_set(
  self : Manager,
  names : Array[String],
) -> Result[@hashmap.HashMap[Int, Unit], BddError] {
  let result : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
  for name in names {
    match self.variable_index.get(name) {
      None => return Err(UnknownVariable(name))
      Some(variable) => result.set(variable, ())
    }
  }
  Ok(result)
}

///|
fn Manager::restrict_root(
  self : Manager,
  root : Int,
  assignments : @hashmap.HashMap[Int, Bool],
  memo : @hashmap.HashMap[Int, Int],
  work : WorkCounter,
  depth : Int,
) -> Result[Int, BddError] {
  if root <= 1 {
    return Ok(root)
  }
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match memo.get(root) {
    Some(value) => return Ok(value)
    None => ()
  }
  let node = self.nodes[root]
  let result = match assignments.get(node.variable) {
    Some(false) => self.restrict_root(
      node.low,
      assignments,
      memo,
      work,
      depth + 1,
    )
    Some(true) => self.restrict_root(
      node.high,
      assignments,
      memo,
      work,
      depth + 1,
    )
    None => {
      let low = match self.restrict_root(
        node.low,
        assignments,
        memo,
        work,
        depth + 1,
      ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let high = match self.restrict_root(
        node.high,
        assignments,
        memo,
        work,
        depth + 1,
      ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      self.mk(node.variable, low, high, work)
    }
  }
  match result {
    Ok(value) => {
      memo.set(root, value)
      Ok(value)
    }
    Err(error) => Err(error)
  }
}

///|
pub fn Manager::restrict(
  self : Manager,
  value : Bdd,
  assignments : Array[(String, Bool)],
) -> Result[Bdd, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let selected : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap([])
  for pair in assignments {
    let (name, choice) = pair
    match self.variable_index.get(name) {
      None => return Err(UnknownVariable(name))
      Some(variable) => selected.set(variable, choice)
    }
  }
  let memo : @hashmap.HashMap[Int, Int] = @hashmap.HashMap([])
  let work = WorkCounter::new(self.budget.max_work)
  match self.restrict_root(value.root, selected, memo, work, 0) {
    Ok(root) => Ok({ owner: self, root })
    Err(error) => Err(error)
  }
}

///|
fn Manager::compose_root(
  self : Manager,
  root : Int,
  target : Int,
  replacement : Int,
  memo : @hashmap.HashMap[Int, Int],
  work : WorkCounter,
  depth : Int,
) -> Result[Int, BddError] {
  if root <= 1 {
    return Ok(root)
  }
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match memo.get(root) {
    Some(value) => return Ok(value)
    None => ()
  }
  let node = self.nodes[root]
  let low = match self.compose_root(
    node.low,
    target,
    replacement,
    memo,
    work,
    depth + 1,
  ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let high = match self.compose_root(
    node.high,
    target,
    replacement,
    memo,
    work,
    depth + 1,
  ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let result = if node.variable == target {
    self.ite_root(replacement, high, low, work, depth + 1)
  } else {
    self.mk(node.variable, low, high, work)
  }
  match result {
    Ok(value) => {
      memo.set(root, value)
      Ok(value)
    }
    Err(error) => Err(error)
  }
}

///|
pub fn Manager::compose(
  self : Manager,
  value : Bdd,
  variable_name : String,
  replacement : Bdd,
) -> Result[Bdd, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match self.validate(replacement) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let target = match self.variable_index.get(variable_name) {
    None => return Err(UnknownVariable(variable_name))
    Some(variable) => variable
  }
  let memo : @hashmap.HashMap[Int, Int] = @hashmap.HashMap([])
  let work = WorkCounter::new(self.budget.max_work)
  match self.compose_root(value.root, target, replacement.root, memo, work, 0) {
    Ok(root) => Ok({ owner: self, root })
    Err(error) => Err(error)
  }
}

///|
fn Manager::quantify_root(
  self : Manager,
  root : Int,
  selected : @hashmap.HashMap[Int, Unit],
  existential : Bool,
  memo : @hashmap.HashMap[Int, Int],
  work : WorkCounter,
  depth : Int,
) -> Result[Int, BddError] {
  if root <= 1 {
    return Ok(root)
  }
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match memo.get(root) {
    Some(value) => return Ok(value)
    None => ()
  }
  let node = self.nodes[root]
  let low = match self.quantify_root(
    node.low,
    selected,
    existential,
    memo,
    work,
    depth + 1,
  ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let high = match self.quantify_root(
    node.high,
    selected,
    existential,
    memo,
    work,
    depth + 1,
  ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let result = if selected.get(node.variable) is Some(_) {
    if existential {
      self.ite_root(low, 1, high, work, depth + 1)
    } else {
      self.ite_root(low, high, 0, work, depth + 1)
    }
  } else {
    self.mk(node.variable, low, high, work)
  }
  match result {
    Ok(value) => {
      memo.set(root, value)
      Ok(value)
    }
    Err(error) => Err(error)
  }
}

///|
fn Manager::quantify(
  self : Manager,
  value : Bdd,
  variables : Array[String],
  existential : Bool,
) -> Result[Bdd, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let selected = match self.validated_variable_set(variables) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let memo : @hashmap.HashMap[Int, Int] = @hashmap.HashMap([])
  let work = WorkCounter::new(self.budget.max_work)
  match self.quantify_root(value.root, selected, existential, memo, work, 0) {
    Ok(root) => Ok({ owner: self, root })
    Err(error) => Err(error)
  }
}

///|
pub fn Manager::exists(
  self : Manager,
  value : Bdd,
  variables : Array[String],
) -> Result[Bdd, BddError] {
  self.quantify(value, variables, true)
}

///|
pub fn Manager::forall(
  self : Manager,
  value : Bdd,
  variables : Array[String],
) -> Result[Bdd, BddError] {
  self.quantify(value, variables, false)
}

///|
pub fn Manager::support(
  self : Manager,
  value : Bdd,
) -> Result[Array[String], BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let seen_nodes : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
  let seen_variables : @hashmap.HashMap[Int, Unit] = @hashmap.HashMap([])
  let pending = [value.root]
  let mut work = 0
  while pending.length() > 0 {
    if work >= self.budget.max_work {
      return Err(WorkBudgetExceeded(self.budget.max_work))
    }
    let root = pending.pop().unwrap()
    if root > 1 && seen_nodes.get(root) is None {
      seen_nodes.set(root, ())
      let node = self.nodes[root]
      seen_variables.set(node.variable, ())
      pending.push(node.low)
      pending.push(node.high)
    }
    work += 1
  }
  let names : Array[String] = []
  for index, name in self.variables {
    if seen_variables.get(index) is Some(_) {
      names.push(name)
    }
  }
  Ok(names)
}
