///|
/// Explicit limits for operations whose time or retained state can grow
/// exponentially. Every value must be positive.
pub(all) struct ResourceBudget {
  max_nodes : Int
  max_work : Int
  max_input_bytes : Int
  max_depth : Int
  max_models : Int
  max_output_bytes : Int
  max_reorder_attempts : Int
  max_iterations : Int
} derive(Debug, Eq)

///|
pub fn ResourceBudget::default() -> ResourceBudget {
  {
    max_nodes: 100000,
    max_work: 1000000,
    max_input_bytes: 1048576,
    max_depth: 1024,
    max_models: 10000,
    max_output_bytes: 8388608,
    max_reorder_attempts: 256,
    max_iterations: 10000,
  }
}

///|
/// Stable public error categories. Errors never encode private node-table
/// layout and are suitable for mapping to CLI exit categories.
pub(all) enum BddError {
  InvalidBudget(String, Int)
  EmptyVariable
  DuplicateVariable(String)
  UnknownVariable(String)
  ForeignHandle
  NodeBudgetExceeded(Int)
  WorkBudgetExceeded(Int)
  InputBudgetExceeded(Int)
  DepthBudgetExceeded(Int)
  ModelBudgetExceeded(Int)
  OutputBudgetExceeded(Int)
  ArithmeticOverflow
  InvalidArgument(String)
  InvalidArtifact(String)
  UnsupportedVersion(Int)
} derive(Debug, Eq)

///|
/// A Manager-owned reference to one canonical Boolean Function.
pub struct Bdd {
  owner : Manager
  root : Int
}

///|
struct DecisionNode {
  variable : Int
  low : Int
  high : Int
} derive(Debug, Eq)

///|
struct NodeKey {
  variable : Int
  low : Int
  high : Int
} derive(Eq, Hash)

///|
priv struct IteKey {
  condition : Int
  then_root : Int
  else_root : Int
} derive(Eq, Hash)

///|
/// Owner of one Variable Order and one canonical ROBDD node universe.
pub struct Manager {
  variables : Array[String]
  variable_index : @hashmap.HashMap[String, Int]
  budget : ResourceBudget
  priv nodes : Array[DecisionNode]
  priv unique : @hashmap.HashMap[NodeKey, Int]
  priv ite_cache : @hashmap.HashMap[IteKey, Int]
}

///|
priv struct WorkCounter {
  mut used : Int
  maximum : Int
}

///|
fn WorkCounter::new(maximum : Int) -> WorkCounter {
  { used: 0, maximum, }
}

///|
fn WorkCounter::step(self : WorkCounter) -> Result[Unit, BddError] {
  if self.used >= self.maximum {
    Err(WorkBudgetExceeded(self.maximum))
  } else {
    self.used += 1
    Ok(())
  }
}
