///|
test "relations own sorted unique arrays and merge immutably" {
  let values = [3, 1, 2, 1]
  let r = @datafrog.Relation(values)
  values[0] = 99
  let copy = r.to_array()
  copy[0] = 99
  assert_eq(r.to_array(), [1, 2, 3])
  assert_eq(r.merge(Relation([2, 4])).to_array(), [1, 2, 3, 4])
  assert_true(r.contains(2))
  assert_false(r.contains(0))
  assert_false(r.contains(4))
  assert_eq(@datafrog.Relation::from_map(r, fn(x) { x % 2 }).to_array(), [0, 1])
}

///|
test "staged frontiers, all variables advance, and resume after quiescence" {
  let iteration = @datafrog.Iteration()
  let a : @datafrog.Variable[Int32] = iteration.variable("a")
  let b : @datafrog.Variable[Int32] = iteration.variable("b")
  a.insert_all([1, 2, 2])
  b.insert_all([9])
  assert_true(a.recent().is_empty())
  assert_true(iteration.changed())
  assert_eq(a.recent().to_array(), [1, 2])
  assert_eq(b.recent().to_array(), [9])
  b.from_map(a, fn(x) { x * 2 })
  assert_true(iteration.changed())
  assert_eq(b.recent().to_array(), [2, 4])
  assert_false(iteration.changed())
  let snapshot = b.complete()
  a.insert_all([1, 3])
  assert_true(iteration.changed())
  assert_eq(a.recent().to_array(), [3])
  b.from_map(a, fn(x) { x * 2 })
  assert_true(iteration.changed())
  assert_false(iteration.changed())
  assert_eq(snapshot.to_array(), [2, 4, 9])
  assert_eq(b.complete().to_array(), [2, 4, 6, 9])
  assert_eq(iteration.round(), 6)
  assert_eq(iteration.stats()[0].stable, 3)
  assert_eq(a.name(), "a")
}

///|
test "indistinct variables can repeat a frontier" {
  let iteration = @datafrog.Iteration()
  let v : @datafrog.Variable[Int32] = iteration.variable(
    "repeat",
    distinct=false,
  )
  v.insert_all([1])
  for _ in 0..<4 {
    assert_true(iteration.changed())
    v.from_map(v, fn(x) { x })
  }
  assert_true(iteration.changed())
  assert_false(iteration.changed())
  assert_eq(v.complete().to_array(), [1])
  iteration.dispose()
}

///|
test "panic complete before quiescence" {
  let i = @datafrog.Iteration()
  let v : @datafrog.Variable[Int32] = i.variable("v")
  v.insert_all([1])
  let _ = v.complete()
}

///|
test "panic cross iteration map" {
  let i = @datafrog.Iteration()
  let j = @datafrog.Iteration()
  let a : @datafrog.Variable[Int32] = i.variable("a")
  let b : @datafrog.Variable[Int32] = j.variable("b")
  b.from_map(a, fn(x) { x })
}

///|
test "panic disposed iteration" {
  let i = @datafrog.Iteration()
  let v : @datafrog.Variable[Int32] = i.variable("v")
  i.dispose()
  v.insert_all([1])
}
