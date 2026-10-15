///|
test "multiway intersection and value anti extension" {
  let source = @datafrog.Relation([0, 1, 2])
  let a = @datafrog.Relation([(0, 1), (0, 2), (0, 3), (1, 4), (2, 5)])
  let b = @datafrog.Relation([(0, 2), (0, 3), (1, 4), (2, 6)])
  let forbidden = @datafrog.Relation([(0, 3)])
  let leapers = [
    a.extend_with(fn(x) { x }),
    b.extend_with(fn(x) { x }),
    forbidden.extend_anti(fn(x) { x }),
  ]
  let result = @datafrog.Relation::from_leapjoin(source, leapers, fn(p, v) {
    (p, v)
  })
  assert_eq(result.to_array(), [(0, 2), (1, 4)])
  assert_eq(
    @datafrog.Relation::from_leapjoin(source, leapers.rev(), fn(p, v) { (p, v) }).to_array(),
    result.to_array(),
  )
  let filtered = @datafrog.Relation::from_leapjoin(
    source,
    [
      a.extend_with(fn(x) { x }),
      @datafrog.Leaper::filter(fn(p, v) { p == 0 && v % 2 == 1 }),
    ],
    fn(p, v) { (p, v) },
  )
  assert_eq(filtered.to_array(), [(0, 1), (0, 3)])
}

///|
test "prefix membership, anti membership and passthrough" {
  let source = @datafrog.Relation([0, 1, 2, 3])
  let allowed = @datafrog.Relation([0, 1, 2])
  let denied = @datafrog.Relation([1])
  let result = @datafrog.Relation::from_leapjoin(
    source,
    [
      @datafrog.Leaper::passthrough(),
      allowed.filter_with(fn(x) { x }),
      denied.filter_anti(fn(x) { x }),
      @datafrog.Leaper::prefix_filter(fn(x) { x > 0 }),
    ],
    fn(p, _) { p },
  )
  assert_eq(result.to_array(), [2])
}

///|
test "leapjoin recursive reachability" {
  let i = @datafrog.Iteration()
  let path : @datafrog.Variable[(Int32, Int32)] = i.variable("path")
  let edges = @datafrog.Relation([(0, 1), (1, 2), (2, 0), (2, 3)])
  let incoming = @datafrog.Relation::from_map(edges, fn(e) { (e.1, e.0) })
  path.insert(edges)
  while i.changed() {
    path.from_leapjoin(path, [incoming.extend_with(fn(p) { p.0 })], fn(p, a) {
      (a, p.1)
    })
    assert_true(i.round() < 10)
  }
  assert_eq(path.complete().length(), 12)
}

///|
test "panic leapjoin requires proposer" {
  let _ : @datafrog.Relation[Int32] = @datafrog.Relation::from_leapjoin(
    Relation([1]),
    [@datafrog.Leaper::filter(fn(_ : Int32, _ : Int32) { true })],
    fn(p, _) { p },
  )
}
