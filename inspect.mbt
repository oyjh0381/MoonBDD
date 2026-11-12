///|
/// Deterministic public statistics for one BDD Handle.
#derive(Debug, Eq)
pub(all) struct BddStatistics {
  declared_variables : Int32
  support_variables : Int32
  reachable_nodes : Int32
  retained_nodes : Int32
  model_count_decimal : String
}

///|
pub fn Manager::statistics(
  self : Manager,
  value : Bdd,
) -> Result[BddStatistics, BddError] {
  let support = match self.support(value) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let count = match self.sat_count_decimal(value) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let reachable = match self.reachable_node_count(value) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  Ok({
    declared_variables: self.variables.length(),
    support_variables: support.length(),
    reachable_nodes: reachable,
    retained_nodes: self.retained_node_count(),
    model_count_decimal: count,
  })
}

///|
fn dot_node_name(id : Int32) -> String {
  if id == 0 {
    "false_terminal"
  } else if id == 1 {
    "true_terminal"
  } else {
    "n" + id.to_string()
  }
}

///|
/// Export reachable structure as deterministic Graphviz DOT.
pub fn Manager::to_dot(
  self : Manager,
  value : Bdd,
  root_name : String,
) -> Result[String, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let ordered : Array[Int32] = []
  match
    self.postorder_visit(
      value.root,
      @hashmap.HashMap([]),
      ordered,
      WorkCounter::new(self.budget.max_work),
      0,
    ) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let remap : @hashmap.HashMap[Int32, Int32] = @hashmap.HashMap([(0, 0), (1, 1)])
  for index, old_id in ordered {
    remap.set(old_id, index + 2)
  }
  let lines : Array[String] = [
    "digraph MoonBDD {",
    "  rankdir=TB;",
    "  label=" + json_quote(root_name) + ";",
    "  false_terminal [shape=box,label=\"false\"];",
    "  true_terminal [shape=box,label=\"true\"];",
  ]
  for index, old_id in ordered {
    let id = index + 2
    let node = self.nodes[old_id]
    let low = remap.get(node.low).unwrap()
    let high = remap.get(node.high).unwrap()
    lines.push(
      "  n" +
      id.to_string() +
      " [label=" +
      json_quote(self.variables[node.variable]) +
      "];",
    )
    lines.push(
      "  n" +
      id.to_string() +
      " -> " +
      dot_node_name(low) +
      " [style=dashed,label=\"0\"];",
    )
    lines.push(
      "  n" +
      id.to_string() +
      " -> " +
      dot_node_name(high) +
      " [style=solid,label=\"1\"];",
    )
  }
  let root = remap.get(value.root).unwrap()
  lines.push("  root [shape=plaintext,label=" + json_quote(root_name) + "];")
  lines.push("  root -> " + dot_node_name(root) + ";")
  lines.push("}")
  let encoded = lines.join("\n") + "\n"
  if encoded.length() > self.budget.max_output_bytes {
    Err(OutputBudgetExceeded(self.budget.max_output_bytes))
  } else {
    Ok(encoded)
  }
}

///|
fn Manager::canonical_expression_root(
  self : Manager,
  root : Int32,
  memo : @hashmap.HashMap[Int32, String],
  work : WorkCounter,
  depth : Int32,
) -> Result[String, BddError] {
  if root == 0 {
    return Ok("false")
  }
  if root == 1 {
    return Ok("true")
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
  let low = match
    self.canonical_expression_root(node.low, memo, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let high = match
    self.canonical_expression_root(node.high, memo, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let name = self.variables[node.variable]
  let encoded = "((!" +
    name +
    " & " +
    low +
    ") | (" +
    name +
    " & " +
    high +
    "))"
  if encoded.length() > self.budget.max_output_bytes {
    return Err(OutputBudgetExceeded(self.budget.max_output_bytes))
  }
  memo.set(root, encoded)
  Ok(encoded)
}

///|
/// Produce a deterministic parser-compatible Shannon expansion. Equivalent
/// BDD Handles in one Manager produce byte-identical text.
pub fn Manager::canonical_expression(
  self : Manager,
  value : Bdd,
) -> Result[String, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  self.canonical_expression_root(
    value.root,
    @hashmap.HashMap([]),
    WorkCounter::new(self.budget.max_work),
    0,
  )
}
