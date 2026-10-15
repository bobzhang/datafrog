# Datafrog for MoonBit

A pure MoonBit port of [Rust Datafrog](https://github.com/rust-lang/datafrog):
small, typed building blocks for monotone relational fixed-point computation.
Use it for graph reachability, program analysis, permissions, and recursive rules.
The module is `bobzhang/datafrog`, with no external MoonBit dependencies.

```mbt check
///|
test "transitive permissions" {
  let iteration = @datafrog.Iteration()
  let permissions : @datafrog.Variable[(String, String)] = iteration.variable(
    "permissions",
  )
  let parents = @datafrog.Relation([("editors", "alice"), ("staff", "editors")])
  permissions.insert_all([("staff", "read dashboard")])
  while iteration.changed() {
    permissions.from_join(permissions, parents.as_input(), fn(
      _,
      permission,
      person,
    ) {
      (person, permission)
    })
  }
  assert_eq(permissions.complete().to_array(), [
    ("alice", "read dashboard"),
    ("staff", "read dashboard"),
    ("editors", "read dashboard"),
  ])
}
```

## Model and API

`Relation(tuples)` sorts and deduplicates a copy of its input. Relations are
immutable sets; `to_array()` returns a copy. Tuple values themselves must be
immutable and have a consistent total `Compare` order.

`Iteration()` creates variables with `iteration.variable("name")`.
`insert(relation)` or `insert_all(tuples)` queues facts. Each `changed()` call
moves the old frontier into stable batches and exposes new, previously unseen
facts through `recent()`. Always call every rule inside the loop. A variable may
be both input and output of a rule.

- `from_map` and `from_map_filtered` transform only the new frontier.
- `from_join` and `from_join_filtered` join a variable with a dynamic variable
  or fixed relation using `as_input()`. Dynamic joins process recent × stable,
  stable × recent, and recent × recent; old × old pairs are skipped.
- `from_antijoin` excludes keys from a **fixed** relation.
- `from_leapjoin` combines an array of multiway constraints. `extend_with`
  proposes values, `extend_anti` excludes values, and `filter_with`/`filter_anti`
  test prefix membership. `Leaper::filter` and `prefix_filter` accept pure
  predicates. At least one leaper must propose values; use
  `Leaper::passthrough()` to propose `Unit` for a prefix-only filter chain.
- `Relation::from_*` variants evaluate the same operations over full relations.
- `complete()` returns a non-consuming snapshot after the variable stabilizes.
  You can insert more facts and resume the same iteration. `stats()` exposes
  stable/recent/pending tuple counts; `round()` counts calls to `changed()`.
- `variable("name", distinct=false)` allows repeated frontiers. Every recursive
  cycle must include a distinct variable to ensure duplicate suppression.
- `dispose()` unregisters stages and invalidates variable handles. There is no
  internal iteration/variable reference cycle, including on the native backend.

## Contracts and limits

This engine **adds facts**. It does not retract facts, track timestamps or support
concurrent execution. For deletion-aware updates use a differential engine.
Static relations used by rules must stay fixed throughout an incremental run.
Callbacks must be deterministic and must not mutate or advance the iteration.
All variables participating in a rule must belong to the same iteration.

Finite input does not guarantee termination when rules generate new values.
Applications must impose round/resource limits appropriate to their domain.
No production-readiness or Rust performance-parity claim is made. See
[PORTING.md](PORTING.md) for algorithm and API differences.

## Validation

```sh
moon fmt --check
moon check --target all --warn-list +unnecessary_annotation --deny-warn
moon test --target all
moon run cmd/demo
# Restore pinned reference using UPSTREAM.md first:
python3 validation/compare.py
```

Tests cover round visibility, duplicate suppression, joins, antijoins, multiway
constraints, ownership checks, 80 seeded graphs with four insertion phases, and
three 10,000-step fixed-point runs. The Rust harness checks 512 seeds × two
insertion phases × three join strategies against pinned upstream and an
independent Python graph-search oracle. Results are in
[validation/results.json](validation/results.json).

CI runs all four backends on Linux and macOS, pinned and latest MoonBit, plus the
Rust differential harness. Developed with MoonBit `0.10.15+943464bfa`.

Dual licensed under MIT or Apache-2.0; upstream notices are retained.
