# MoonBDD

MoonBDD defines the domain language for representing Boolean functions canonically and analysing finite symbolic state spaces with reduced ordered binary decision diagrams.

## Language

**Boolean Function**:
A mapping from a finite set of Boolean Variables to a Boolean result.
_Avoid_: Formula tree, expression result

**Boolean Variable**:
A named binary dimension placed at one stable position in a Variable Order.
_Avoid_: Symbol, flag bit

**Variable Order**:
The total order in which Boolean Variables may occur along every decision path.
_Avoid_: Sort order, declaration list

**ROBDD**:
The canonical reduced ordered binary decision diagram of a Boolean Function under one Variable Order.
_Avoid_: Expression tree, generic BDD

**Decision Node**:
A non-terminal ROBDD node that selects a Low or High successor according to one Boolean Variable.
_Avoid_: AST node, branch object

**Terminal**:
One of the two canonical ROBDD leaves representing false or true.
_Avoid_: Constant node, leaf value

**Manager**:
The owner of one Variable Order and the canonical Decision Nodes valid under that order.
_Avoid_: Global context, node factory

**BDD Handle**:
A reference to one ROBDD root together with the identity of its owning Manager.
_Avoid_: Node ID, expression

**Model**:
An assignment of Boolean values that makes a Boolean Function true.
_Avoid_: Row, solution object

**Model Count**:
The exact number of complete Models over a declared Variable Order.
_Avoid_: Node count, path count

**Quantification**:
Elimination of selected Boolean Variables by existential or universal combination of their outcomes.
_Avoid_: Variable deletion, simplification

**Restriction**:
Specialisation of a Boolean Function by fixing selected Boolean Variables to concrete values.
_Avoid_: Filtering, quantification

**Composition**:
Replacement of a Boolean Variable with another Boolean Function.
_Avoid_: Substitution text, conjunction

**Reordering**:
Construction of an equivalent ROBDD under a different Variable Order without invalidating the original Manager or its BDD Handles.
_Avoid_: Renaming, in-place sorting

**Resource Budget**:
An explicit upper bound on work or retained state for one operation, whose exhaustion produces a structured error.
_Avoid_: Timeout, best-effort limit

**Symbolic State Set**:
A Boolean Function whose Models encode a set of finite system states.
_Avoid_: State list, workflow state

**Transition Relation**:
A Boolean Function relating current-state variables to next-state variables.
_Avoid_: Event handler, transition table

**Reachability Fixed Point**:
The stable Symbolic State Set obtained by repeatedly adding successors until no new state is discovered.
_Avoid_: Graph traversal result, model checking proof
