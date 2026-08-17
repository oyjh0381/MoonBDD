# MoonBDD Task Plan

This plan decomposes the approved specification into tracer-bullet tickets. Each ticket delivers behaviour that can be demonstrated or verified independently. Detailed acceptance criteria are staged under `.scratch/moonbdd/issues/` until the independent MoonBDD GitHub tracker exists.

| ID | Ticket | Blocked by |
| --- | --- | --- |
| 01 | Establish the smallest runnable MoonBDD slice | None |
| 02 | Deliver canonical Boolean operations | 01 |
| 03 | Compile Boolean expressions end to end | 02 |
| 04 | Transform Boolean Functions | 02 |
| 05 | Find and count Models exactly | 02, 04 |
| 06 | Round-trip deterministic JSON artifacts | 02 |
| 07 | Inspect ROBDDs through DOT and statistics | 02 |
| 08 | Reorder without invalidating BDD Handles | 02, 04 |
| 09 | Analyse finite symbolic reachability | 03, 04, 05 |
| 10 | Enforce Resource Budgets across public entry points | 03–09 |
| 11 | Establish strict correctness and performance evidence | 03–10 |
| 12 | Complete ecosystem-facing documentation | 09–11 |
| 13 | Prepare CI, competition submission, and publication | 11, 12 |

## Execution frontiers

1. Start with ticket 01.
2. Complete ticket 02 after 01.
3. After 02, tickets 03, 04, 06, and 07 can proceed independently.
4. Ticket 05 starts after 04; ticket 08 also starts after 04.
5. Ticket 09 starts after 03, 04, and 05.
6. Ticket 10 integrates safety behaviour after all feature slices from 03 through 09 exist.
7. Ticket 11 establishes full evidence after feature and safety work.
8. Ticket 12 completes public documentation after reachability and validation behaviour are stable.
9. Ticket 13 is the final local and remote readiness gate.

## Definition of completion

The plan is complete only when all ticket acceptance criteria pass, standard and strict MoonBit commands succeed, examples run as documented, repository evidence is clean, the proposal accurately describes implemented scope, CI is green on the independent remote repository, and the package is published to mooncakes.io. External publication steps require the user's authenticated accounts and explicit approval at execution time.
