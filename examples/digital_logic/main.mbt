///|
fn main {
  let manager = @bdd.Manager::new(
    ["a", "b", "carry_in"],
    @bdd.ResourceBudget::default(),
  ).unwrap()
  let sum = manager.compile("a ^ b ^ carry_in").unwrap()
  let carry = manager.compile("(a & b) | (carry_in & (a ^ b))").unwrap()
  for
    input in [
      [("a", false), ("b", false), ("carry_in", false)],
      [("a", true), ("b", true), ("carry_in", false)],
      [("a", true), ("b", false), ("carry_in", true)],
    ] {
    let sum_value = manager.evaluate(sum, input).unwrap()
    let carry_value = manager.evaluate(carry, input).unwrap()
    println(
      "input=" +
      @debug.to_string(input) +
      " sum=\{sum_value} carry=\{carry_value}",
    )
  }
}
