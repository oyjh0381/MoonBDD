///|
/// Result of non-destructive Variable reordering.
pub(all) struct ReorderResult {
  manager : Manager
  root : Bdd
  before_nodes : Int32
  after_nodes : Int32
  attempted_orders : Int32
}

///|
fn Manager::validate_permutation(
  self : Manager,
  order : Array[String],
) -> Result[Unit, BddError] {
  if order.length() != self.variables.length() {
    return Err(InvalidArgument("new Variable Order has a different length"))
  }
  let seen : @hashmap.HashMap[String, Unit] = @hashmap.HashMap([])
  for name in order {
    if self.variable_index.get(name) is None {
      return Err(UnknownVariable(name))
    }
    if seen.get(name) is Some(_) {
      return Err(InvalidArgument("new Variable Order contains a duplicate"))
    }
    seen.set(name, ())
  }
  Ok(())
}

///|
fn Manager::translate_root(
  self : Manager,
  root : Int32,
  target : Manager,
  memo : @hashmap.HashMap[Int32, Int32],
  work : WorkCounter,
  depth : Int32,
) -> Result[Int32, BddError] {
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
  let low = match self.translate_root(node.low, target, memo, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let high = match
    self.translate_root(node.high, target, memo, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let selector = match target.variable(self.variables[node.variable]) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let translated = match
    target.ite(selector, { owner: target, root: high, }, {
      owner: target,
      root: low,
    }) {
    Ok(value) => value.root
    Err(error) => return Err(error)
  }
  memo.set(root, translated)
  Ok(translated)
}

///|
pub fn Manager::reorder(
  self : Manager,
  value : Bdd,
  order : Array[String],
) -> Result[ReorderResult, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match self.validate_permutation(order) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let target = match Manager::new(order, self.budget) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let translated = match
    self.translate_root(
      value.root,
      target,
      @hashmap.HashMap([]),
      WorkCounter::new(self.budget.max_work),
      0,
    ) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let root : Bdd = { owner: target, root: translated, }
  let before_nodes = match self.reachable_node_count(value) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let after_nodes = match target.reachable_node_count(root) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({ manager: target, root, before_nodes, after_nodes, attempted_orders: 1, })
}

///|
/// Deterministically accept adjacent swaps that strictly reduce reachable
/// Decision Nodes. The source Manager and BDD Handle are never modified.
pub fn Manager::optimize_order(
  self : Manager,
  value : Bdd,
) -> Result[ReorderResult, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let original_nodes = match self.reachable_node_count(value) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let mut current_manager = self
  let mut current_root = value
  let mut current_nodes = original_nodes
  let mut attempts = 0
  let mut improved = true
  while improved && attempts < self.budget.max_reorder_attempts {
    improved = false
    for index = 0
        index + 1 < current_manager.variables.length() &&
       attempts < self.budget.max_reorder_attempts
        index = index + 1 {
      let candidate_order = current_manager.variables.copy()
      let left = candidate_order[index]
      candidate_order[index] = candidate_order[index + 1]
      candidate_order[index + 1] = left
      let candidate = match
        current_manager.reorder(current_root, candidate_order) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      attempts += 1
      if candidate.after_nodes < current_nodes {
        current_manager = candidate.manager
        current_root = candidate.root
        current_nodes = candidate.after_nodes
        improved = true
        break
      }
    }
  }
  Ok({
    manager: current_manager,
    root: current_root,
    before_nodes: original_nodes,
    after_nodes: current_nodes,
    attempted_orders: attempts,
  })
}
