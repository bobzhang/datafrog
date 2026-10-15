# Port coverage

Reference: Datafrog 2.0.1, pinned in [UPSTREAM.md](UPSTREAM.md).

| Upstream facility | MoonBit port |
| --- | --- |
| Sorted unique relations, map, merge | Implemented with private arrays and defensive shallow copies |
| Iteration, distinct/indistinct variables | Implemented with registered typed state closures |
| Recent/stable/pending staging | Implemented, including size-tiered stable batch merging |
| Dynamic and static binary joins | Implemented semi-naive frontier combinations |
| Filtered maps and joins | Implemented with optional callback results |
| Static antijoin | Implemented |
| Treefrog multiway leapjoin | Implemented smallest-proposal selection and constraints |
| ExtendWith / ExtendAnti | Implemented via relation methods |
| FilterWith / FilterAnti | Implemented for arbitrary relation tuple types |
| PrefixFilter / ValueFilter / Passthrough | Implemented as Leaper factories |
| Variable diagnostics | Structured stats instead of CSV writer/debug flags |
| Consuming complete() | Non-consuming snapshot; safe staged resumption |
| Rust lifetimes / Rc / RefCell / tuple trait arities | MoonBit types, private state, closure registration, arrays of leapers |
| Galloping joins and adaptive dedup scans | Linear merge scans; relation membership and proposal ranges use binary search |
| Custom user-defined Leaper traits | Pure value/prefix predicates supported; custom proposal implementations not exposed |

Storage arrays are never exposed for mutation. Relation tuples and callback
captures remain the caller's responsibility: shallow copying cannot make a
mutable custom tuple immutable. The port checks iteration identity for dynamic
rules; callback purity and total ordering are contractual requirements.

Leapjoin recomputes binary-search ranges for proposal and checks remaining
constraints by binary membership; upstream caches ranges and uses galloping
intersection. The semantics are preserved for pure callbacks, but performance
and callback invocation counts differ. No performance comparison has been run.

The differential harness exercises reachability through dynamic joins, static
joins and leapjoins against actual Rust and an independent graph-search oracle.
Multiway filters, antijoins and proposal order are covered by MoonBit regression
tests, not yet by the Rust harness. This is validation evidence, not a proof of
full semantic equivalence or production readiness.

Sorted output follows MoonBit `Compare`, which can differ from Rust ordering: for
example, built-in MoonBit strings compare length before code units. Set semantics
are unaffected; use a custom immutable wrapper for a specific presentation order.
