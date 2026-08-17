///|
fn main {
  let manager = @bdd.Manager::new(
    ["database", "cache", "replicas", "single_node"],
    @bdd.ResourceBudget::default(),
  ).unwrap()
  let valid = manager
    .compile("database & (cache -> database) & (replicas -> !single_node)")
    .unwrap()
  println("valid configurations: " + manager.sat_count_decimal(valid).unwrap())
  match manager.sat_one(valid).unwrap() {
    Some(model) => println("one configuration: " + @debug.to_string(model))
    None => println("configuration is unsatisfiable")
  }
}
