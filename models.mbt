///|
/// One complete assignment in the Manager's Variable Order.
pub(all) struct Model {
  values : Array[(String, Bool)]
} derive(Debug, Eq)

///|
/// Bounded Model enumeration result. `complete` is false when more Models exist.
pub(all) struct ModelEnumeration {
  models : Array[Model]
  complete : Bool
} derive(Debug, Eq)

///|
priv struct CountKey {
  root : Int
  level : Int
} derive(Eq, Hash)

///|
/// Minimal exact non-negative integer used by Model Count. Digits are
/// little-endian base 1,000,000,000 and never exposed publicly.
priv struct DecimalNat {
  digits : Array[Int]
}

///|
fn DecimalNat::zero() -> DecimalNat {
  { digits: [0] }
}

///|
fn DecimalNat::one() -> DecimalNat {
  { digits: [1] }
}

///|
fn DecimalNat::add(self : DecimalNat, other : DecimalNat) -> DecimalNat {
  let digits : Array[Int] = []
  let mut carry = 0
  let length = if self.digits.length() > other.digits.length() {
    self.digits.length()
  } else {
    other.digits.length()
  }
  for i = 0; i < length; i = i + 1 {
    let left = if i < self.digits.length() { self.digits[i] } else { 0 }
    let right = if i < other.digits.length() { other.digits[i] } else { 0 }
    let sum = left + right + carry
    if sum >= 1000000000 {
      digits.push(sum - 1000000000)
      carry = 1
    } else {
      digits.push(sum)
      carry = 0
    }
  }
  if carry > 0 {
    digits.push(carry)
  }
  { digits, }
}

///|
fn DecimalNat::times_two(self : DecimalNat) -> DecimalNat {
  let digits : Array[Int] = []
  let mut carry = 0
  for digit in self.digits {
    let product = digit * 2 + carry
    if product >= 1000000000 {
      digits.push(product - 1000000000)
      carry = 1
    } else {
      digits.push(product)
      carry = 0
    }
  }
  if carry > 0 {
    digits.push(carry)
  }
  { digits, }
}

///|
fn DecimalNat::times_power_of_two(
  self : DecimalNat,
  exponent : Int,
  work : WorkCounter,
) -> Result[DecimalNat, BddError] {
  let mut value = self
  for i = 0; i < exponent; i = i + 1 {
    match work.step() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    value = value.times_two()
  }
  Ok(value)
}

///|
fn DecimalNat::to_decimal(self : DecimalNat) -> String {
  let builder = StringBuilder::new()
  let last = self.digits.length() - 1
  builder.write_string(self.digits[last].to_string())
  for i = last - 1; i >= 0; i = i - 1 {
    let text = self.digits[i].to_string()
    for padding = text.length(); padding < 9; padding = padding + 1 {
      builder.write_char('0')
    }
    builder.write_string(text)
  }
  builder.to_string()
}

///|
fn DecimalNat::decimal_length(self : DecimalNat) -> Int {
  let last = self.digits.length() - 1
  self.digits[last].to_string().length() + last * 9
}

///|
fn DecimalNat::to_u64(self : DecimalNat) -> Result[UInt64, BddError] {
  let maximum = 0xffff_ffff_ffff_ffffUL
  let base = 1000000000UL
  let mut value = 0UL
  for i = self.digits.length() - 1; i >= 0; i = i - 1 {
    let digit = self.digits[i].to_uint64()
    if value > (maximum - digit) / base {
      return Err(ArithmeticOverflow)
    }
    value = value * base + digit
  }
  Ok(value)
}

///|
fn Manager::count_root(
  self : Manager,
  root : Int,
  level : Int,
  memo : @hashmap.HashMap[CountKey, DecimalNat],
  work : WorkCounter,
  depth : Int,
) -> Result[DecimalNat, BddError] {
  if depth > self.budget.max_depth {
    return Err(DepthBudgetExceeded(self.budget.max_depth))
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if root == 0 {
    return Ok(DecimalNat::zero())
  }
  if root == 1 {
    return DecimalNat::one().times_power_of_two(
      self.variables.length() - level,
      work,
    )
  }
  let key : CountKey = { root, level }
  match memo.get(key) {
    Some(value) => return Ok(value)
    None => ()
  }
  let node = self.nodes[root]
  let low = match
    self.count_root(node.low, node.variable + 1, memo, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let high = match
    self.count_root(node.high, node.variable + 1, memo, work, depth + 1) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let value = match
    low.add(high).times_power_of_two(node.variable - level, work) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  memo.set(key, value)
  Ok(value)
}

///|
fn Manager::exact_count(
  self : Manager,
  value : Bdd,
) -> Result[DecimalNat, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  self.count_root(
    value.root,
    0,
    @hashmap.HashMap([]),
    WorkCounter::new(self.budget.max_work),
    0,
  )
}

///|
pub fn Manager::sat_count_u64(
  self : Manager,
  value : Bdd,
) -> Result[UInt64, BddError] {
  match self.exact_count(value) {
    Ok(count) => count.to_u64()
    Err(error) => Err(error)
  }
}

///|
pub fn Manager::sat_count_decimal(
  self : Manager,
  value : Bdd,
) -> Result[String, BddError] {
  match self.exact_count(value) {
    Ok(count) =>
      if count.decimal_length() > self.budget.max_output_bytes {
        Err(OutputBudgetExceeded(self.budget.max_output_bytes))
      } else {
        Ok(count.to_decimal())
      }
    Err(error) => Err(error)
  }
}

///|
pub fn Manager::sat_one(
  self : Manager,
  value : Bdd,
) -> Result[Model?, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if value.root == 0 {
    return Ok(None)
  }
  let assignments : Array[(String, Bool)] = []
  let mut root = value.root
  let mut level = 0
  let mut work = 0
  while root > 1 {
    if work >= self.budget.max_work {
      return Err(WorkBudgetExceeded(self.budget.max_work))
    }
    let node = self.nodes[root]
    while level < node.variable {
      assignments.push((self.variables[level], false))
      level += 1
    }
    if node.low != 0 {
      assignments.push((self.variables[level], false))
      root = node.low
    } else {
      assignments.push((self.variables[level], true))
      root = node.high
    }
    level += 1
    work += 1
  }
  while level < self.variables.length() {
    assignments.push((self.variables[level], false))
    level += 1
  }
  Ok(Some({ values: assignments }))
}

///|
fn Manager::enumerate_assignments(
  self : Manager,
  value : Bdd,
  index : Int,
  current : Array[(String, Bool)],
  output : Array[Model],
  limit : Int,
  work : WorkCounter,
) -> Result[Unit, BddError] {
  if output.length() >= limit {
    return Ok(())
  }
  match work.step() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if index == self.variables.length() {
    match self.evaluate(value, current) {
      Ok(true) => output.push({ values: current.copy() })
      Ok(false) => ()
      Err(error) => return Err(error)
    }
    return Ok(())
  }
  current.push((self.variables[index], false))
  match
    self.enumerate_assignments(value, index + 1, current, output, limit, work) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  ignore(current.pop())
  if output.length() < limit {
    current.push((self.variables[index], true))
    match
      self.enumerate_assignments(value, index + 1, current, output, limit, work) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    ignore(current.pop())
  }
  Ok(())
}

///|
pub fn Manager::enumerate_models(
  self : Manager,
  value : Bdd,
  maximum : Int,
) -> Result[ModelEnumeration, BddError] {
  match self.validate(value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if maximum <= 0 {
    return Err(InvalidArgument("maximum models must be positive"))
  }
  if maximum > self.budget.max_models {
    return Err(ModelBudgetExceeded(self.budget.max_models))
  }
  let models : Array[Model] = []
  match
    self.enumerate_assignments(
      value,
      0,
      [],
      models,
      maximum,
      WorkCounter::new(self.budget.max_work),
    ) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let complete = match self.sat_count_u64(value) {
    Ok(count) => count <= maximum.to_uint64()
    Err(ArithmeticOverflow) => false
    Err(error) => return Err(error)
  }
  Ok({ models, complete })
}
