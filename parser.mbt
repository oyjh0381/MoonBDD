///|
/// One stable source-positioned expression diagnostic.
pub(all) struct ParseDiagnostic {
  offset : Int
  message : String
} derive(Debug, Eq)

///|
pub(all) enum ExpressionError {
  ParseFailure(ParseDiagnostic)
  CompileFailure(BddError)
} derive(Debug, Eq)

///|
priv struct ExpressionParser {
  manager : Manager
  data : Bytes
  mut cursor : Int
  mut nesting : Int
}

///|
fn ExpressionParser::failure(
  self : ExpressionParser,
  message : String,
) -> Result[Bdd, ExpressionError] {
  Err(ParseFailure({ offset: self.cursor, message }))
}

///|
fn ExpressionParser::skip_space(self : ExpressionParser) -> Unit {
  while self.cursor < self.data.length() {
    let byte = self.data[self.cursor]
    if byte == b' ' || byte == b'\t' || byte == b'\r' || byte == b'\n' {
      self.cursor += 1
    } else {
      return
    }
  }
}

///|
fn ExpressionParser::consume_byte(
  self : ExpressionParser,
  expected : Byte,
) -> Bool {
  self.skip_space()
  if self.cursor < self.data.length() && self.data[self.cursor] == expected {
    self.cursor += 1
    true
  } else {
    false
  }
}

///|
fn ExpressionParser::consume_arrow(self : ExpressionParser) -> Bool {
  self.skip_space()
  if self.cursor + 1 < self.data.length() &&
    self.data[self.cursor] == b'-' &&
    self.data[self.cursor + 1] == b'>' {
    self.cursor += 2
    true
  } else {
    false
  }
}

///|
fn ExpressionParser::consume_equivalence(self : ExpressionParser) -> Bool {
  self.skip_space()
  if self.cursor + 2 < self.data.length() &&
    self.data[self.cursor] == b'<' &&
    self.data[self.cursor + 1] == b'-' &&
    self.data[self.cursor + 2] == b'>' {
    self.cursor += 3
    true
  } else {
    false
  }
}

///|
fn identifier_start(byte : Byte) -> Bool {
  (byte >= b'a' && byte <= b'z') ||
  (byte >= b'A' && byte <= b'Z') ||
  byte == b'_'
}

///|
fn identifier_continue(byte : Byte) -> Bool {
  identifier_start(byte) || (byte >= b'0' && byte <= b'9') || byte == b'.'
}

///|
fn from_bdd_result(
  result : Result[Bdd, BddError],
) -> Result[Bdd, ExpressionError] {
  match result {
    Ok(value) => Ok(value)
    Err(error) => Err(CompileFailure(error))
  }
}

///|
fn ExpressionParser::enter(
  self : ExpressionParser,
) -> Result[Unit, ExpressionError] {
  if self.nesting >= self.manager.budget.max_depth {
    Err(CompileFailure(DepthBudgetExceeded(self.manager.budget.max_depth)))
  } else {
    self.nesting += 1
    Ok(())
  }
}

///|
fn ExpressionParser::parse_primary(
  self : ExpressionParser,
) -> Result[Bdd, ExpressionError] {
  self.skip_space()
  if self.cursor >= self.data.length() {
    return self.failure("expected expression")
  }
  if self.consume_byte(b'(') {
    match self.enter() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let value = match self.parse_equivalence() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    if !self.consume_byte(b')') {
      return self.failure("expected ')' to close expression")
    }
    self.nesting -= 1
    return Ok(value)
  }
  let start = self.cursor
  if !identifier_start(self.data[self.cursor]) {
    return self.failure("expected identifier, literal, '!', or '('")
  }
  self.cursor += 1
  while self.cursor < self.data.length() &&
        identifier_continue(self.data[self.cursor]) {
    self.cursor += 1
  }
  let name = @utf8.decode(self.data[start:self.cursor]) catch {
    _ => return self.failure("identifier is not valid UTF-8")
  }
  if name == "true" {
    Ok(self.manager.true_bdd())
  } else if name == "false" {
    Ok(self.manager.false_bdd())
  } else {
    from_bdd_result(self.manager.variable(name))
  }
}

///|
fn ExpressionParser::parse_unary(
  self : ExpressionParser,
) -> Result[Bdd, ExpressionError] {
  if self.consume_byte(b'!') {
    match self.enter() {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    let inner = match self.parse_unary() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    self.nesting -= 1
    from_bdd_result(self.manager.not_bdd(inner))
  } else {
    self.parse_primary()
  }
}

///|
fn ExpressionParser::parse_and(
  self : ExpressionParser,
) -> Result[Bdd, ExpressionError] {
  let mut left = match self.parse_unary() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  while self.consume_byte(b'&') {
    let right = match self.parse_unary() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    left = match self.manager.and_bdd(left, right) {
      Ok(value) => value
      Err(error) => return Err(CompileFailure(error))
    }
  }
  Ok(left)
}

///|
fn ExpressionParser::parse_xor(
  self : ExpressionParser,
) -> Result[Bdd, ExpressionError] {
  let mut left = match self.parse_and() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  while self.consume_byte(b'^') {
    let right = match self.parse_and() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    left = match self.manager.xor_bdd(left, right) {
      Ok(value) => value
      Err(error) => return Err(CompileFailure(error))
    }
  }
  Ok(left)
}

///|
fn ExpressionParser::parse_or(
  self : ExpressionParser,
) -> Result[Bdd, ExpressionError] {
  let mut left = match self.parse_xor() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  while self.consume_byte(b'|') {
    let right = match self.parse_xor() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    left = match self.manager.or_bdd(left, right) {
      Ok(value) => value
      Err(error) => return Err(CompileFailure(error))
    }
  }
  Ok(left)
}

///|
fn ExpressionParser::parse_implication(
  self : ExpressionParser,
) -> Result[Bdd, ExpressionError] {
  let left = match self.parse_or() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  if self.consume_arrow() {
    let right = match self.parse_implication() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    from_bdd_result(self.manager.implies(left, right))
  } else {
    Ok(left)
  }
}

///|
fn ExpressionParser::parse_equivalence(
  self : ExpressionParser,
) -> Result[Bdd, ExpressionError] {
  let mut left = match self.parse_implication() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  while self.consume_equivalence() {
    let right = match self.parse_implication() {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    left = match self.manager.equivalent(left, right) {
      Ok(value) => value
      Err(error) => return Err(CompileFailure(error))
    }
  }
  Ok(left)
}

///|
pub fn Manager::compile(
  self : Manager,
  source : String,
) -> Result[Bdd, ExpressionError] {
  let data = @utf8.encode(source)
  if data.length() > self.budget.max_input_bytes {
    return Err(CompileFailure(InputBudgetExceeded(self.budget.max_input_bytes)))
  }
  let parser : ExpressionParser = { manager: self, data, cursor: 0, nesting: 0 }
  let value = match parser.parse_equivalence() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  parser.skip_space()
  if parser.cursor != data.length() {
    parser.failure("unexpected trailing input")
  } else {
    Ok(value)
  }
}
