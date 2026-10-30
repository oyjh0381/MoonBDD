///|
// Explicit method exports for the MoonBit 0.10.16 trait migration.
pub extend PartialValue with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend PartialValue with Eq::{not_equal, equal}

///|
pub extend TruthRow with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TruthRow with Eq::{not_equal, equal}

///|
pub extend TruthTable with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend TruthTable with Eq::{not_equal, equal}

///|
pub extend Cube with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Cube with Eq::{not_equal, equal}

///|
pub extend CubeEnumeration with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend CubeEnumeration with Eq::{not_equal, equal}

///|
pub extend RelationCheck with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend RelationCheck with Eq::{not_equal, equal}

///|
pub extend NamedConstraint with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend NamedConstraint with Eq::{not_equal, equal}

///|
pub extend ConstraintError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ConstraintError with Eq::{not_equal, equal}

///|
pub extend BddStatistics with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BddStatistics with Eq::{not_equal, equal}

///|
pub extend Model with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Model with Eq::{not_equal, equal}

///|
pub extend ModelEnumeration with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ModelEnumeration with Eq::{not_equal, equal}

///|
pub extend ParseDiagnostic with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ParseDiagnostic with Eq::{not_equal, equal}

///|
pub extend ExpressionError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ExpressionError with Eq::{not_equal, equal}

///|
pub extend ResourceBudget with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend ResourceBudget with Eq::{not_equal, equal}

///|
pub extend BddError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend BddError with Eq::{not_equal, equal}

///|
pub extend DecisionNode with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend DecisionNode with Eq::{not_equal, equal}

///|
pub extend NodeKey with Eq::{not_equal, equal}

///|
pub extend NodeKey with Hash::{hash, hash_combine}
