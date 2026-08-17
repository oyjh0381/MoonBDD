# CLI Contract

Run `moon run cmd/moonbdd --target native -- ...`. Commands are `compile`,
`stats`, `sat-one`, `count`, `dot`, `reorder`, and `reach`. Formula commands
accept a comma-separated Variable Order and expression. `reorder` also accepts
a new order. `reach` runs the deterministic mutual-exclusion demonstration.

Use `-` as the expression to read UTF-8 stdin, or `@PATH` to read one explicit
UTF-8 file. A literal expression beginning with `@` is outside the expression
grammar and therefore unambiguous. Success writes JSON, decimal, or DOT to
stdout. Help and version exit 0. The CLI performs no network or Graphviz
rendering.

Failures write exactly one line to stderr as `MOONBDD_ERROR {json}`. The JSON
object has stable string fields `code` and `message`; stdout remains empty.

| Exit | `code` | Meaning |
| ---: | --- | --- |
| 2 | `usage` | Invalid command shape or option count |
| 3 | `parse` | Invalid Boolean expression |
| 4 | `invalid_input` | Invalid Variable, order, or ownership input |
| 5 | `artifact` | Malformed or unsupported persistent artifact |
| 6 | `resource_budget` | A configured finite limit was exhausted |
| 7 | `arithmetic` | Exact result cannot fit the requested numeric type |
| 8 | `io` | Explicit file or stream I/O failed |
| 70 | `internal` | Unclassified CLI failure |
