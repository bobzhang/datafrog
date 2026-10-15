///|
test "semi naive joins include each frontier combination exactly once" {
  let i = @datafrog.Iteration()
  let a : @datafrog.Variable[(Int32, Int32)] = i.variable("a")
  let b : @datafrog.Variable[(Int32, Int32)] = i.variable("b")
  let out : @datafrog.Variable[(Int32, Int32, Int32)] = i.variable("out")
  let mut calls = 0
  let join = fn() {
    out.from_join(a, b.as_input(), fn(k, x, y) {
      calls += 1
      (k, x, y)
    })
  }
  a.insert_all([(0, 1), (0, 2)])
  b.insert_all([(0, 3), (1, 100)])
  assert_true(i.changed())
  join()
  a.insert_all([(0, 4)])
  b.insert_all([(0, 5)])
  assert_true(i.changed())
  join()
  while i.changed() {
    join()
  }
  assert_eq(calls, 6)
  assert_eq(out.complete().to_array(), [
    (0, 1, 3),
    (0, 1, 5),
    (0, 2, 3),
    (0, 2, 5),
    (0, 4, 3),
    (0, 4, 5),
  ])
}

///|
test "recursive reachability agrees for static and dynamic right inputs" {
  let edges = @datafrog.Relation([(0, 1), (1, 2), (2, 0), (2, 3)])
  let inverse = @datafrog.Relation::from_map(edges, fn(edge) {
    (edge.1, edge.0)
  })
  let i = @datafrog.Iteration()
  let fixed : @datafrog.Variable[(Int32, Int32)] = i.variable("fixed")
  let dynamic : @datafrog.Variable[(Int32, Int32)] = i.variable("dynamic")
  let rhs : @datafrog.Variable[(Int32, Int32)] = i.variable("rhs")
  rhs.insert(inverse)
  fixed.insert(edges)
  dynamic.insert(edges)
  while i.changed() {
    fixed.from_join(fixed, inverse.as_input(), fn(_, c, a) { (a, c) })
    dynamic.from_join(dynamic, rhs.as_input(), fn(_, c, a) { (a, c) })
    assert_true(i.round() < 10)
  }
  assert_eq(fixed.complete().length(), 12)
  assert_eq(fixed.complete().to_array(), dynamic.complete().to_array())
}

///|
test "static joins filtering and anti join" {
  let a = @datafrog.Relation([(1, 10), (1, 20), (2, 30)])
  let b = @datafrog.Relation([(1, 3), (1, 4), (3, 5)])
  let joined = @datafrog.Relation::from_join(a, b, fn(k, x, y) { (k, x + y) })
  assert_eq(joined.to_array(), [(1, 13), (1, 14), (1, 23), (1, 24)])
  let i = @datafrog.Iteration()
  let input : @datafrog.Variable[(Int32, Int32)] = i.variable("input")
  let out : @datafrog.Variable[Int32] = i.variable("filtered")
  let anti : @datafrog.Variable[Int32] = i.variable("anti")
  input.insert(a)
  while i.changed() {
    out.from_join_filtered(input, b.as_input(), fn(_, x, y) {
      if y == 3 {
        Some(x + y)
      } else {
        None
      }
    })
    anti.from_antijoin(input, Relation([1]), fn(_, value) { value })
  }
  assert_eq(out.complete().to_array(), [13, 23])
  assert_eq(anti.complete().to_array(), [30])
  assert_eq(
    @datafrog.Relation::from_antijoin(a, Relation([2]), fn(k, _) { k }).to_array(),
    [1],
  )
  assert_eq(
    @datafrog.Relation::from_map_filtered(a, fn(pair) {
      if pair.0 == 2 {
        Some(pair.1)
      } else {
        None
      }
    }).to_array(),
    [30],
  )
}
