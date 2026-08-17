///|
fn Manager::top_variable(self : Manager, root : Int) -> Int {
  if root <= 1 {
    self.variables.length()
  } else {
    self.nodes[root].variable
  }
}

///|
fn Manager::cofactor(
  self : Manager,
  root : Int,
  variable : Int,
  high : Bool,
) -> Int {
  if root <= 1 {
    root
  } else {
    let node = self.nodes[root]
    if node.variable == variable {
      if high { node.high } else { node.low }
    } else {
      root
    }
  }
}

///|
fn minimum3(first : Int, second : Int, third : Int) -> Int {
  let left = if first < second { first } else { second }
  if left < third { left } else { third }
}

///|
fn Manager::ite_root(
  self : Manager,
  condition : Int,
  then_root : Int,
  else_root : Int,
  work : WorkCounter,
  depth : Int,
) -> Result[Int, BddError] {
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if condition == 1 {
    return Ok(then_root)
  }
  if condition == 0 {
    return Ok(else_root)
  }
  if then_root == else_root {
    return Ok(then_root)
  }
  if then_root == 1 && else_root == 0 {
    return Ok(condition)
  }
  let key : IteKey = { condition, then_root, else_root }
  match self.ite_cache.get(key) {
    Some(root) => return Ok(root)
    None => ()
  }
  let variable = minimum3(
    self.top_variable(condition),
    self.top_variable(then_root),
    self.top_variable(else_root),
  )
  let low = match self.ite_root(
    self.cofactor(condition, variable, false),
    self.cofactor(then_root, variable, false),
    self.cofactor(else_root, variable, false),
    work,
    depth + 1,
  ) {
    Ok(root) => root
    Err(error) => return Err(error)
  }
  let high = match self.ite_root(
    self.cofactor(condition, variable, true),
    self.cofactor(then_root, variable, true),
    self.cofactor(else_root, variable, true),
    work,
    depth + 1,
  ) {
    Ok(root) => root
    Err(error) => return Err(error)
  }
  let root = match self.mk(variable, low, high, work) {
    Ok(root) => root
    Err(error) => return Err(error)
  }
  self.ite_cache.set(key, root)
  Ok(root)
}

///|
pub fn Manager::ite(
  self : Manager,
  condition : Bdd,
  then_value : Bdd,
  else_value : Bdd,
) -> Result[Bdd, BddError] {
  for value in [condition, then_value, else_value] {
    match self.validate(value) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  let work = WorkCounter::new(self.budget.max_work)
  match self.ite_root(
    condition.root,
    then_value.root,
    else_value.root,
    work,
    0,
  ) {
    Ok(root) => Ok({ owner: self, root })
    Err(error) => Err(error)
  }
}

///|
pub fn Manager::not_bdd(self : Manager, value : Bdd) -> Result[Bdd, BddError] {
  self.ite(value, self.false_bdd(), self.true_bdd())
}

///|
pub fn Manager::and_bdd(
  self : Manager,
  left : Bdd,
  right : Bdd,
) -> Result[Bdd, BddError] {
  self.ite(left, right, self.false_bdd())
}

///|
pub fn Manager::or_bdd(
  self : Manager,
  left : Bdd,
  right : Bdd,
) -> Result[Bdd, BddError] {
  self.ite(left, self.true_bdd(), right)
}

///|
pub fn Manager::xor_bdd(
  self : Manager,
  left : Bdd,
  right : Bdd,
) -> Result[Bdd, BddError] {
  let not_right = match self.not_bdd(right) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.ite(left, not_right, right)
}

///|
pub fn Manager::implies(
  self : Manager,
  premise : Bdd,
  conclusion : Bdd,
) -> Result[Bdd, BddError] {
  self.ite(premise, conclusion, self.true_bdd())
}

///|
pub fn Manager::equivalent(
  self : Manager,
  left : Bdd,
  right : Bdd,
) -> Result[Bdd, BddError] {
  let different = match self.xor_bdd(left, right) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  self.not_bdd(different)
}

///|
pub fn Manager::evaluate(
  self : Manager,
  value : Bdd,
  assignment : Array[(String, Bool)],
) -> Result[Bool, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let values : @hashmap.HashMap[Int, Bool] = @hashmap.HashMap([])
  for pair in assignment {
    let (name, selected) = pair
    match self.variable_index.get(name) {
      None => return Err(UnknownVariable(name))
      Some(variable) => values.set(variable, selected)
    }
  }
  let mut root = value.root
  let mut steps = 0
  while root > 1 {
    if steps >= self.budget.max_work {
      return Err(WorkBudgetExceeded(self.budget.max_work))
    }
    let node = self.nodes[root]
    match values.get(node.variable) {
      None => return Err(InvalidArgument("incomplete assignment"))
      Some(false) => root = node.low
      Some(true) => root = node.high
    }
    steps += 1
  }
  Ok(root == 1)
}
