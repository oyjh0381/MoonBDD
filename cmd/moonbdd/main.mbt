///|
extern "C" fn process_exit(code : Int) = "exit"

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
    #|  moonbdd dot      VARIABLES EXPRESSION [ROOT_NAME]
    #|  moonbdd reorder  VARIABLES NEW_ORDER EXPRESSION
    #|  moonbdd reach
    #|
    #|VARIABLES and NEW_ORDER are comma-separated names. Use '-' as EXPRESSION
    #|to read UTF-8 text from stdin.
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
        return Err("Variable list contains an empty name")
      }
      let name = @utf8.decode(data[start:index]) catch {
        _ => return Err("Variable list is not valid UTF-8")
      }
      result.push(name)
      start = index + 1
    }
  }
  Ok(result)
}

///|
async fn expression_input(argument : String) -> String {
  if argument == "-" {
    @stdio.stdin.read_all().text()
  } else {
    argument
  }
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
    fields.push(
      Json::string(name).stringify() + ":" + encoded_value,
    )
  }
  "{" + fields.join(",") + "}"
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
  let manager = match @bdd.Manager::new(variables, @bdd.ResourceBudget::default()) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let expression = expression_input(expression_argument)
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
  let manager = match @bdd.Manager::new(variables, @bdd.ResourceBudget::default()) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let value = match manager.compile(expression_input(expression_argument)) {
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
  let manager = match @bdd.Manager::new(
    ["p", "q", "p_next", "q_next"],
    @bdd.ResourceBudget::default(),
  ) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let encoding = match manager.state_encoding(
    ["p", "q"],
    ["p_next", "q_next"],
  ) {
    Ok(value) => value
    Err(error) => return Err(error_text(error))
  }
  let initial = match manager.compile("!p & !q") {
    Ok(value) => value
    Err(error) => return Err(expression_error_text(error))
  }
  let transition = match manager.compile(
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
  } else if
    (args[1] == "compile" ||
      args[1] == "stats" ||
      args[1] == "sat-one" ||
      args[1] == "count") &&
    args.length() == 4 {
    run_formula_command(args[1], args[2], args[3], "root")
  } else if args[1] == "dot" && (args.length() == 4 || args.length() == 5) {
    let name = if args.length() == 5 { args[4] } else { "root" }
    run_formula_command(args[1], args[2], args[3], name)
  } else {
    Err("invalid arguments\n" + usage())
  }
  match result {
    Ok(output) => @stdio.stdout.write(output)
    Err(message) => {
      @stdio.stderr.write("MOONBDD_ERROR: " + message + "\n") catch {
        _ => ()
      }
      process_exit(2)
    }
  }
}
