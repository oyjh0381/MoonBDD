# Security Policy

MoonBDD processes potentially adversarial expressions and JSON artifacts but is
not a sandbox. Primary risks are exponential node growth, deep expressions,
oversized output, enumeration, and reordering. Use explicit Resource Budgets and
treat exhaustion errors as expected outcomes. The decoder validates topology
and canonicality before returning a Manager.

The portable core performs no filesystem, network, clock, random, process, or
thread operation. Native I/O exists only in the CLI. Report vulnerabilities
privately to the repository owner before public disclosure.
