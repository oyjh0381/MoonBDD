///|
/// Explicit limits for operations whose time or retained state can grow
/// exponentially. Every value must be positive.
#derive(Debug, Eq)
pub(all) struct ResourceBudget {
  max_nodes : Int32
  max_cache_entries : Int32
  max_work : Int32
  max_input_bytes : Int32
  max_depth : Int32
  max_models : Int32
  max_constraints : Int32
  max_analysis_steps : Int32
  max_output_bytes : Int32
  max_reorder_attempts : Int32
  max_iterations : Int32
}

///|
pub fn ResourceBudget::default() -> ResourceBudget {
  {
    max_nodes: 100000,
    max_cache_entries: 100000,
    max_work: 1000000,
    max_input_bytes: 1048576,
    max_depth: 1024,
    max_models: 10000,
    max_constraints: 256,
    max_analysis_steps: 10000,
    max_output_bytes: 8388608,
    max_reorder_attempts: 256,
    max_iterations: 10000,
  }
}

///|
/// Stable public error categories. Errors never encode private node-table
/// layout and are suitable for mapping to CLI exit categories.
#derive(Debug, Eq)
pub(all) enum BddError {
  InvalidBudget(String, Int32)
  EmptyVariable
  InvalidVariableName(String)
  DuplicateVariable(String)
  UnknownVariable(String)
  ForeignHandle
  NodeBudgetExceeded(Int32)
  WorkBudgetExceeded(Int32)
  InputBudgetExceeded(Int32)
  DepthBudgetExceeded(Int32)
  ModelBudgetExceeded(Int32)
  ConstraintBudgetExceeded(Int32)
  AnalysisBudgetExceeded(Int32)
  OutputBudgetExceeded(Int32)
  IterationBudgetExceeded(Int32)
  ArithmeticOverflow
  InvalidArgument(String)
  InvalidArtifact(String)
  UnsupportedVersion(Int32)
}

///|
/// A Manager-owned reference to one canonical Boolean Function.
pub struct Bdd {
  priv owner : Manager
  priv root : Int32
}

///|
#derive(Debug, Eq)
struct DecisionNode {
  variable : Int32
  low : Int32
  high : Int32
}

///|
#derive(Eq, Hash)
struct NodeKey {
  variable : Int32
  low : Int32
  high : Int32
}

///|
#derive(Eq, Hash)
priv struct IteKey {
  condition : Int32
  then_root : Int32
  else_root : Int32
}

///|
/// Owner of one Variable Order and one canonical ROBDD node universe.
pub struct Manager {
  priv variables : Array[String]
  priv variable_index : @hashmap.HashMap[String, Int32]
  budget : ResourceBudget
  priv nodes : Array[DecisionNode]
  priv unique : @hashmap.HashMap[NodeKey, Int32]
  priv ite_cache : @hashmap.HashMap[IteKey, Int32]
}

///|
priv struct WorkCounter {
  mut used : Int32
  maximum : Int32
}

///|
fn WorkCounter::new(maximum : Int32) -> WorkCounter {
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
