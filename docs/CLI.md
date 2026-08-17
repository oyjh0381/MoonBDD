# CLI Contract

Run `moon run cmd/moonbdd --target native -- ...`. Commands are `compile`,
`stats`, `sat-one`, `count`, `dot`, `reorder`, and `reach`. Formula commands
accept a comma-separated Variable Order and expression. `reorder` also accepts
a new order. `reach` runs the deterministic mutual-exclusion demonstration.

Use `-` as the expression to read UTF-8 stdin. Success writes JSON, decimal, or
DOT to stdout. Errors write one `MOONBDD_ERROR:` prefix to stderr and exit 2.
Help and version exit 0. The CLI performs no network or Graphviz rendering.
