///|
pub let artifact_schema_version : Int32 = 1

///|
fn json_quote(value : String) -> String {
  Json::string(value).stringify()
}

///|
fn Manager::postorder_visit(
  self : Manager,
  root : Int32,
  seen : @hashmap.HashMap[Int32, Unit],
  ordered : Array[Int32],
  work : WorkCounter,
  depth : Int32,
) -> Result[Unit, BddError] {
  if root <= 1 || seen.get(root) is Some(_) {
    return Ok(())
  }
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  seen.set(root, ())
  let node = self.nodes[root]
  match self.postorder_visit(node.low, seen, ordered, work, depth + 1) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  match self.postorder_visit(node.high, seen, ordered, work, depth + 1) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  ordered.push(root)
  Ok(())
}

///|
/// Encode one BDD Handle as deterministic JSON Schema v1. Artifact node IDs
/// are compact and independent from unreachable Manager-retained nodes.
pub fn Manager::encode_json(
  self : Manager,
  value : Bdd,
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
  let variables : Array[String] = []
  for name in self.variables {
    variables.push(json_quote(name))
  }
  let nodes : Array[String] = []
  for index, old_id in ordered {
    let node = self.nodes[old_id]
    let low = remap.get(node.low).unwrap()
    let high = remap.get(node.high).unwrap()
    nodes.push(
      "{\"id\":" +
      (index + 2).to_string() +
      ",\"variable\":" +
      node.variable.to_string() +
      ",\"low\":" +
      low.to_string() +
      ",\"high\":" +
      high.to_string() +
      "}",
    )
  }
  let root = remap.get(value.root).unwrap()
  let encoded = "{\"schema_version\":" +
    artifact_schema_version.to_string() +
    ",\"variables\":[" +
    variables.join(",") +
    "],\"nodes\":[" +
    nodes.join(",") +
    "],\"root\":" +
    root.to_string() +
    "}"
  if encoded.length() > self.budget.max_output_bytes {
    Err(OutputBudgetExceeded(self.budget.max_output_bytes))
  } else {
    Ok(encoded)
  }
}

///|
fn json_object(
  value : Json,
  context : String,
) -> Result[Map[String, Json], BddError] {
  match value {
    Object(fields) => Ok(fields)
    _ => Err(InvalidArtifact(context + " must be an object"))
  }
}

///|
fn json_required(
  fields : Map[String, Json],
  name : String,
) -> Result[Json, BddError] {
  match fields.get(name) {
    Some(value) => Ok(value)
    None => Err(InvalidArtifact("missing field: " + name))
  }
}

///|
fn json_int(
  fields : Map[String, Json],
  name : String,
) -> Result[Int32, BddError] {
  let value = match json_required(fields, name) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let decoded : Int32 = @json.from_json(value) catch {
    _ => return Err(InvalidArtifact(name + " must be an integer"))
  }
  Ok(decoded)
}

///|
fn json_string_array(
  fields : Map[String, Json],
  name : String,
) -> Result[Array[String], BddError] {
  match json_required(fields, name) {
    Err(error) => Err(error)
    Ok(Array(items)) => {
      let result : Array[String] = []
      for item in items {
        match item {
          String(value) => result.push(value)
          _ => return Err(InvalidArtifact(name + " must contain only strings"))
        }
      }
      Ok(result)
    }
    Ok(_) => Err(InvalidArtifact(name + " must be an array"))
  }
}

///|
/// Decode a strict deterministic JSON Schema v1 artifact into a fresh Manager.
pub fn Manager::decode_json(
  text : String,
  budget : ResourceBudget,
) -> Result[(Manager, Bdd), BddError] {
  match validate_budget(budget) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if text.length() > budget.max_input_bytes {
    return Err(InputBudgetExceeded(budget.max_input_bytes))
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(InvalidArtifact("invalid JSON document"))
  }
  let fields = match json_object(parsed, "artifact root") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let version = match json_int(fields, "schema_version") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if version != artifact_schema_version {
    return Err(UnsupportedVersion(version))
  }
  let variables = match json_string_array(fields, "variables") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manager = match Manager::new(variables, budget) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let node_items = match json_required(fields, "nodes") {
    Ok(Array(items)) => items
    Ok(_) => return Err(InvalidArtifact("nodes must be an array"))
    Err(error) => return Err(error)
  }
  if node_items.length() + 2 > budget.max_nodes {
    return Err(NodeBudgetExceeded(budget.max_nodes))
  }
  let work = WorkCounter::new(budget.max_work)
  for index, item in node_items {
    let node_fields = match json_object(item, "node") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let expected_id = index + 2
    let id = match json_int(node_fields, "id") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let variable = match json_int(node_fields, "variable") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let low = match json_int(node_fields, "low") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    let high = match json_int(node_fields, "high") {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if id != expected_id ||
      variable < 0 ||
      variable >= manager.variables.length() {
      return Err(InvalidArtifact("node identity or variable is invalid"))
    }
    if low < 0 || high < 0 || low >= id || high >= id {
      return Err(InvalidArtifact("node children must precede their parent"))
    }
    if low > 1 && manager.nodes[low].variable <= variable {
      return Err(InvalidArtifact("low child violates Variable Order"))
    }
    if high > 1 && manager.nodes[high].variable <= variable {
      return Err(InvalidArtifact("high child violates Variable Order"))
    }
    let created = match manager.mk(variable, low, high, work) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if created != id {
      return Err(InvalidArtifact("nodes are not canonical"))
    }
  }
  let root = match json_int(fields, "root") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if root < 0 || root >= manager.nodes.length() {
    return Err(InvalidArtifact("root does not reference a node"))
  }
  Ok((manager, { owner: manager, root, }))
}
