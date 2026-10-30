///|
extern "C" fn process_exit(code : Int32) = "exit"

///|
fn usage() -> String {
  (
    #|MoonBDD 0.1.0
    #|
    #|Usage:
    #|  moonbdd compile  VARIABLES EXPRESSION
    #|  moonbdd stats    VARIABLES EXPRESSION
    #|  moonbdd sat-one  VARIABLES EXPRESSION
    #|  moonbdd count    VARIABLES EXPRESSION
    #|  moonbdd backbone VARIABLES EXPRESSION
    #|  moonbdd truth-table VARIABLES EXPRESSION [MAX_ROWS]
    #|  moonbdd cubes VARIABLES EXPRESSION [MAX_CUBES]
    #|  moonbdd diagnose VARIABLES NAME=EXPRESSION[;NAME=EXPRESSION...]
    #|  moonbdd dot      VARIABLES EXPRESSION [ROOT_NAME]
    #|  moonbdd reorder  VARIABLES NEW_ORDER EXPRESSION
    #|  moonbdd reach
    #|
    #|VARIABLES and NEW_ORDER are comma-separated names. Use '-' as EXPRESSION
    #|to read UTF-8 text from stdin, or '@PATH' to read an explicit file.
    #|
  )
}

///|
fn split_names(text : String) -> Result[Array[String], String] {
  let data = @utf8.encode(text)
  let result : Array[String] = []
  let mut start = 0
  for index = 0; index <= data.length(); index = index + 1 {
    if index == data.length() || data[index] == b',' {
      if index == start {
        return Err("InvalidArgument: variable list contains an empty name")
      }
      let name = @utf8.decode(data[start:index]) catch {
        _ => return Err("InvalidArgument: variable list is not valid UTF-8")
      }
      result.push(name)
      start = index + 1
    }
  }
  Ok(result)
}

///|
async fn expression_input(argument : String) -> Result[String, String] {
  if argument == "-" {
    Ok(@stdio.stdin.read_all().text()) catch {
      _ => Err("IoFailure: unable to read expression from stdin")
    }
  } else if argument.has_prefix("@") {
    let path = argument[1:].to_owned()
    if path == "" {
      Err("InvalidArgument: '@PATH' requires a non-empty path")
    } else {
      Ok(@fs.read_file(path).text()) catch {
        _ => Err("IoFailure: unable to read expression file: " + path)
      }
    }
  } else {
    Ok(argument)
  }
}

///|
fn classify_error(message : String) -> (String, Int32) {
  if message.has_prefix("Usage:") {
    ("usage", 2)
  } else if message.contains("ParseFailure") {
    ("parse", 3)
  } else if message.contains("InvalidArtifact") ||
    message.contains("UnsupportedVersion") {
    ("artifact", 5)
  } else if message.contains("BudgetExceeded") ||
    message.contains("IterationBudgetExceeded") {
    ("resource_budget", 6)
  } else if message.contains("ArithmeticOverflow") {
    ("arithmetic", 7)
  } else if message.has_prefix("IoFailure:") {
    ("io", 8)
  } else if message.contains("InvalidArgument") ||
    message.contains("InvalidVariable") ||
    message.contains("ConstraintName") ||
    message.contains("DuplicateVariable") ||
    message.contains("UnknownVariable") ||
    message.contains("EmptyVariable") ||
    message.contains("ForeignHandle") {
    ("invalid_input", 4)
  } else {
    ("internal", 70)
  }
}

///|
fn machine_error(message : String) -> (String, Int32) {
  let (code, exit_code) = classify_error(message)
  let payload = "{\"code\":" +
    Json::string(code).stringify() +
    ",\"message\":" +
    Json::string(message).stringify() +
    "}"
  ("MOONBDD_ERROR " + payload + "\n", exit_code)
}

///|
fn error_text(error : @bdd.BddError) -> String {
  @debug.to_string(error)
}

///|
fn expression_error_text(error : @bdd.ExpressionError) -> String {
  @debug.to_string(error)
}

///|
fn model_json(model : @bdd.Model) -> String {
  let fields : Array[String] = []
  for pair in model.values {
    let (name, value) = pair
    let encoded_value = if value { "true" } else { "false" }
    fields.push(Json::string(name).stringify() + ":" + encoded_value)
  }
  "{" + fields.join(",") + "}"
}

///|
fn string_array_json(values : Array[String]) -> String {
  let encoded : Array[String] = []
  for value in values {
    encoded.push(Json::string(value).stringify())
  }
  "[" + encoded.join(",") + "]"
}

///|
fn assignment_json(values : Array[(String, Bool)]) -> String {
  model_json({ values, })
}

///|
fn truth_table_json(table : @bdd.TruthTable) -> String {
  let rows : Array[String] = []
  for row in table.rows {
    rows.push(
      "{\"values\":" +
      assignment_json(row.values) +
      ",\"result\":" +
      row.result.to_string() +
      "}",
    )
  }
  "{\"complete\":" +
  table.complete.to_string() +
  ",\"rows\":[" +
  rows.join(",") +
  "]}\n"
}

///|
fn cube_enumeration_json(enumeration : @bdd.CubeEnumeration) -> String {
  let cubes : Array[String] = []
  for cube in enumeration.cubes {
    cubes.push(assignment_json(cube.values))
  }
  "{\"complete\":" +
  enumeration.complete.to_string() +
  ",\"cubes\":[" +
  cubes.join(",") +
  "]}\n"
}

///|
fn parse_maximum(text : String, label : String) -> Result[Int32, String] {
  let value = @string.parse_int(text) catch {
    _ => return Err("InvalidArgument: " + label + " must be an integer")
  }
  if value <= 0 {
    Err("InvalidArgument: " + label + " must be positive")
  } else {
    Ok(value)
  }
}

///|
fn bounded_cli_output(output : String) -> Result[String, String] {
  let maximum = @bdd.ResourceBudget::default().max_output_bytes
  if @utf8.encode(output).length() > maximum {
    Err(error_text(@bdd.OutputBudgetExceeded(maximum)))
  } else {
    Ok(output)
  }
}

///|
fn parse_named_constraints(
  text : String,
  budget : @bdd.ResourceBudget,
) -> Result[Array[@bdd.NamedConstraint], String] {
  let data = @utf8.encode(text)
  if data.length() > budget.max_input_bytes {
    return Err(error_text(@bdd.InputBudgetExceeded(budget.max_input_bytes)))
  }
  if data.length() == 0 {
    return Ok([])
  }
  let constraints : Array[@bdd.NamedConstraint] = []
  let mut start = 0
  for end = 0; end <= data.length(); end = end + 1 {
    if end == data.length() || data[end] == b';' {
      if constraints.length() >= budget.max_constraints {
        return Err(
          error_text(@bdd.ConstraintBudgetExceeded(budget.max_constraints)),
        )
      }
      let mut separator = -1
      for index = start; index < end; index = index + 1 {
        if data[index] == b'=' {
          separator = index
          break
        }
      }
      if separator <= start || separator == end - 1 {
        return Err("InvalidArgument: each constraint must be NAME=EXPRESSION")
      }
      let name = @utf8.decode(data[start:separator]) catch {
        _ => return Err("InvalidArgument: constraint name is not UTF-8")
      }
      let expression = @utf8.decode(data[separator + 1:end]) catch {
        _ => return Err("InvalidArgument: constraint expression is not UTF-8")
      }
      constraints.push({ name, expression, })
      start = end + 1
    }
  }
  Ok(constraints)
}

///|
async fn run_truth_table(
  variables_text : String,
  expression_argument : String,
  maximum_text : String,
) -> Result[String, String] {
  let variables = match split_names(variables_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let maximum = match parse_maximum(maximum_text, "MAX_ROWS") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manager = match
    @bdd.Manager::new(variables, @bdd.ResourceBudget::default()) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let source = match expression_input(expression_argument) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let value = match manager.compile(source) {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  match manager.truth_table(value, maximum) {
    Ok(table) => bounded_cli_output(truth_table_json(table))
    Err(error) => Err(error_text(error))
  }
}

///|
async fn run_cubes(
  variables_text : String,
  expression_argument : String,
  maximum_text : String,
) -> Result[String, String] {
  let variables = match split_names(variables_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let maximum = match parse_maximum(maximum_text, "MAX_CUBES") {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manager = match
    @bdd.Manager::new(variables, @bdd.ResourceBudget::default()) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let source = match expression_input(expression_argument) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let value = match manager.compile(source) {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  match manager.enumerate_cubes(value, maximum) {
    Ok(enumeration) => bounded_cli_output(cube_enumeration_json(enumeration))
    Err(error) => Err(error_text(error))
  }
}

///|
async fn run_diagnose(
  variables_text : String,
  constraints_argument : String,
) -> Result[String, String] {
  let variables = match split_names(variables_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let source = match expression_input(constraints_argument) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let budget = @bdd.ResourceBudget::default()
  let constraints = match parse_named_constraints(source, budget) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manager = match @bdd.Manager::new(variables, budget) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  match manager.diagnose_constraints(constraints) {
    Err(error) => Err(@debug.to_string(error))
    Ok(report) => {
      let witness = match report.witness {
        None => "null"
        Some(model) => model_json(model)
      }
      bounded_cli_output(
        "{\"satisfiable\":" +
        report.satisfiable.to_string() +
        ",\"witness\":" +
        witness +
        ",\"minimal_conflict\":" +
        string_array_json(report.minimal_conflict) +
        ",\"redundant\":" +
        string_array_json(report.redundant) +
        "}\n",
      )
    }
  }
}

///|
async fn run_formula_command(
  command : String,
  variables_text : String,
  expression_argument : String,
  root_name : String,
) -> Result[String, String] {
  let variables = match split_names(variables_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manager = match
    @bdd.Manager::new(variables, @bdd.ResourceBudget::default()) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let expression = match expression_input(expression_argument) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let value = match manager.compile(expression) {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  match command {
    "compile" =>
      match manager.encode_json(value) {
        Ok(output) => Ok(output + "\n")
        Err(error) => Err(error_text(error))
      }
    "stats" =>
      match manager.statistics(value) {
        Ok(stats) =>
          Ok(
            "{\"declared_variables\":" +
            stats.declared_variables.to_string() +
            ",\"support_variables\":" +
            stats.support_variables.to_string() +
            ",\"reachable_nodes\":" +
            stats.reachable_nodes.to_string() +
            ",\"retained_nodes\":" +
            stats.retained_nodes.to_string() +
            ",\"model_count\":\"" +
            stats.model_count_decimal +
            "\"}\n",
          )
        Err(error) => Err(error_text(error))
      }
    "sat-one" =>
      match manager.sat_one(value) {
        Ok(Some(model)) => Ok(model_json(model) + "\n")
        Ok(None) => Ok("null\n")
        Err(error) => Err(error_text(error))
      }
    "count" =>
      match manager.sat_count_decimal(value) {
        Ok(count) => Ok(count + "\n")
        Err(error) => Err(error_text(error))
      }
    "backbone" =>
      match manager.backbone(value) {
        Ok(assignments) =>
          bounded_cli_output(assignment_json(assignments) + "\n")
        Err(error) => Err(error_text(error))
      }
    "dot" =>
      match manager.to_dot(value, root_name) {
        Ok(output) => Ok(output)
        Err(error) => Err(error_text(error))
      }
    _ => Err("unknown formula command")
  }
}

///|
async fn run_reorder(
  variables_text : String,
  order_text : String,
  expression_argument : String,
) -> Result[String, String] {
  let variables = match split_names(variables_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let order = match split_names(order_text) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let manager = match
    @bdd.Manager::new(variables, @bdd.ResourceBudget::default()) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let expression = match expression_input(expression_argument) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let value = match manager.compile(expression) {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  let reordered = match manager.reorder(value, order) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  match reordered.manager.encode_json(reordered.root) {
    Ok(artifact) =>
      Ok(
        "{\"before_nodes\":" +
        reordered.before_nodes.to_string() +
        ",\"after_nodes\":" +
        reordered.after_nodes.to_string() +
        ",\"artifact\":" +
        artifact +
        "}\n",
      )
    Err(error) => Err(error_text(error))
  }
}

///|
fn reach_demo() -> Result[String, String] {
  let manager = match
    @bdd.Manager::new(
      ["p", "q", "p_next", "q_next"],
      @bdd.ResourceBudget::default(),
    ) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let encoding = match
    manager.state_encoding(["p", "q"], ["p_next", "q_next"]) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let initial = match manager.compile("!p & !q") {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  let transition = match
    manager.compile(
      "(!p & !q & ((!p_next & !q_next) | (p_next & !q_next) | (!p_next & q_next))) | (p & !q & ((!p_next & !q_next) | (p_next & !q_next))) | (!p & q & ((!p_next & !q_next) | (!p_next & q_next)))",
    ) {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  let invariant = match manager.compile("!(p & q)") {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  match manager.reach(initial, transition, encoding, Some(invariant)) {
    Ok(result) =>
      Ok(
        "{\"fixed_point\":" +
        result.fixed_point.to_string() +
        ",\"iterations\":" +
        result.iterations.to_string() +
        ",\"invariant_holds\":" +
        result.invariant_holds.to_string() +
        "}\n",
      )
    Err(error) => Err(error_text(error))
  }
}

///|
async fn main {
  let args = @env.args()
  if args.length() == 1 ||
    (args.length() == 2 && (args[1] == "help" || args[1] == "--help")) {
    @stdio.stdout.write(usage())
    return
  }
  if args.length() == 2 && (args[1] == "version" || args[1] == "--version") {
    @stdio.stdout.write("MoonBDD 0.1.0 (artifact schema 1)\n")
    return
  }
  let result = if args[1] == "reach" && args.length() == 2 {
    reach_demo()
  } else if args[1] == "reorder" && args.length() == 5 {
    run_reorder(args[2], args[3], args[4])
  } else if args[1] == "truth-table" &&
    (args.length() == 4 || args.length() == 5) {
    let maximum = if args.length() == 5 { args[4] } else { "16" }
    run_truth_table(args[2], args[3], maximum)
  } else if args[1] == "cubes" && (args.length() == 4 || args.length() == 5) {
    let maximum = if args.length() == 5 { args[4] } else { "16" }
    run_cubes(args[2], args[3], maximum)
  } else if args[1] == "diagnose" && args.length() == 4 {
    run_diagnose(args[2], args[3])
  } else if (
      args[1] == "compile" ||
      args[1] == "stats" ||
      args[1] == "sat-one" ||
      args[1] == "count" ||
      args[1] == "backbone"
    ) &&
    args.length() == 4 {
    run_formula_command(args[1], args[2], args[3], "root")
  } else if args[1] == "dot" && (args.length() == 4 || args.length() == 5) {
    let name = if args.length() == 5 { args[4] } else { "root" }
    run_formula_command(args[1], args[2], args[3], name)
  } else {
    Err("Usage: invalid arguments\n" + usage())
  }
  match result {
    Ok(output) => @stdio.stdout.write(output)
    Err(message) => {
      let (output, exit_code) = machine_error(message)
      @stdio.stderr.write(output) catch {
        _ => ()
      }
      process_exit(exit_code)
    }
  }
}
