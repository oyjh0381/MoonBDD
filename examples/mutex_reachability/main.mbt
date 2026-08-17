///|
fn main {
  let manager = @bdd.Manager::new(
    ["p", "q", "p_next", "q_next"],
    @bdd.ResourceBudget::default(),
  ).unwrap()
  let encoding = manager.state_encoding(
    ["p", "q"],
    ["p_next", "q_next"],
  ).unwrap()
  let initial = manager.compile("!p & !q").unwrap()
  let transition = manager.compile(
    "(!p & !q & ((!p_next & !q_next) | (p_next & !q_next) | (!p_next & q_next))) | (p & !q & ((!p_next & !q_next) | (p_next & !q_next))) | (!p & q & ((!p_next & !q_next) | (!p_next & q_next)))",
  ).unwrap()
  let invariant = manager.compile("!(p & q)").unwrap()
  let result = manager.reach(initial, transition, encoding, Some(invariant)).unwrap()
  println(
    "fixed_point=\{result.fixed_point} iterations=\{result.iterations} invariant_holds=\{result.invariant_holds}",
  )
}
