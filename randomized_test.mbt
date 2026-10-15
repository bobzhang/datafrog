///|
test "randomized staged reachability against independent Floyd Warshall oracle" {
  for seed in 1..<81 {
    let n = 3 + seed % 17
    let matrix = Array::makei(n, fn(_) { Array::make(n, false) })
    let i = @datafrog.Iteration()
    let paths : @datafrog.Variable[(Int32, Int32)] = i.variable("paths")
    let incoming : @datafrog.Variable[(Int32, Int32)] = i.variable("incoming")
    let mut random = seed.reinterpret_as_uint()
    for _phase in 0..<4 {
      let edges = []
      for _ in 0..<(n / 2 + 1) {
        random = random * 1664525U + 1013904223U
        let a = ((random >> 8) % n.reinterpret_as_uint()).reinterpret_as_int()
        random = random * 1664525U + 1013904223U
        let b = ((random >> 8) % n.reinterpret_as_uint()).reinterpret_as_int()
        edges.push((a, b))
        matrix[a][b] = true
      }
      paths.insert_all(edges)
      incoming.insert_all(edges.map(fn(e) { (e.1, e.0) }))
      while i.changed() {
        paths.from_join(paths, incoming.as_input(), fn(_, c, a) { (a, c) })
        assert_true(i.round() < 100)
      }
      for k in 0..<n {
        for a in 0..<n {
          for b in 0..<n {
            matrix[a][b] = matrix[a][b] || (matrix[a][k] && matrix[k][b])
          }
        }
      }
      let expected = []
      for a in 0..<n {
        for b in 0..<n {
          if matrix[a][b] {
            expected.push((a, b))
          }
        }
      }
      assert_eq(paths.complete().to_array(), expected)
    }
  }
}

///|
test "ten thousand fixed point rounds and repeated engine lifetimes" {
  for _ in 0..<3 {
    let i = @datafrog.Iteration()
    let v : @datafrog.Variable[Int32] = i.variable("chain")
    v.insert_all([0])
    while i.changed() {
      v.from_map_filtered(v, fn(x) {
        if x < 10000 {
          Some(x + 1)
        } else {
          None
        }
      })
      assert_true(i.round() <= 10001)
      assert_true(v.stats().batches < 32)
    }
    let result = v.complete()
    assert_eq(result.length(), 10001)
    assert_eq(result.to_array()[10000], 10000)
    assert_eq(v.stats().pending, 0)
    i.dispose()
  }
}
