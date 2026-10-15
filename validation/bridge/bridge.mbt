///|
fn encode(values : Array[(Int32, Int32)]) -> String {
  values.map(fn(p) { "\{p.0},\{p.1}" }).join(";")
}

///|
fn closure(edges : Array[(Int32, Int32)], mode : Int32) -> String {
  let i = @datafrog.Iteration()
  let paths : @datafrog.Variable[(Int32, Int32)] = i.variable("paths")
  let incoming = @datafrog.Relation(edges.map(fn(e) { (e.1, e.0) }))
  paths.insert_all(edges)
  while i.changed() {
    if mode == 1 {
      paths.from_join(paths, incoming.as_input(), fn(_, c, a) { (a, c) })
    } else {
      paths.from_leapjoin(paths, [incoming.extend_with(fn(p) { p.0 })], fn(
        p,
        a,
      ) {
        (a, p.1)
      })
    }
    guard i.round() < 100 else { abort("convergence bound exceeded") }
  }
  encode(paths.complete().to_array())
}

///|
#export_name("evaluate")
pub fn evaluate(seed : Int32) -> String {
  let n = 3 + seed % 22
  let mut random = seed.reinterpret_as_uint()
  let edges = []
  let i = @datafrog.Iteration()
  let paths : @datafrog.Variable[(Int32, Int32)] = i.variable("paths")
  let incoming : @datafrog.Variable[(Int32, Int32)] = i.variable("incoming")
  let results = []
  for phase in 0..<2 {
    let batch = []
    let count = if phase == 0 { seed % (n * 2) + 1 } else { n / 2 + 1 }
    for _ in 0..<count {
      random = random * 1664525U + 1013904223U
      let a = ((random >> 8) % n.reinterpret_as_uint()).reinterpret_as_int()
      random = random * 1664525U + 1013904223U
      let b = ((random >> 8) % n.reinterpret_as_uint()).reinterpret_as_int()
      batch.push((a, b))
      edges.push((a, b))
    }
    paths.insert_all(batch)
    incoming.insert_all(batch.map(fn(e) { (e.1, e.0) }))
    while i.changed() {
      paths.from_join(paths, incoming.as_input(), fn(_, c, a) { (a, c) })
      guard i.round() < 100 else { abort("convergence bound exceeded") }
    }
    results.push(encode(paths.complete().to_array()))
    results.push(closure(edges, 1))
    results.push(closure(edges, 2))
  }
  results.join("|")
}
