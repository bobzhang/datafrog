///|
fn main {
  let iteration = @datafrog.Iteration()
  let grants : @datafrog.Variable[(String, String)] = iteration.variable(
    "grants",
  )
  let membership : @datafrog.Variable[(String, String)] = iteration.variable(
    "membership",
  )
  grants.insert_all([("staff", "read dashboard"), ("admins", "deploy")])
  membership.insert_all([
    ("staff", "editors"),
    ("editors", "alice"),
    ("admins", "bob"),
  ])
  for phase in 0..<2 {
    if phase == 1 {
      membership.insert_all([("admins", "editors")])
    }
    while iteration.changed() {
      println(
        "round \{iteration.round()}: \{grants.recent().length()} new grants",
      )
      grants.from_join(grants, membership.as_input(), fn(
        _,
        permission,
        person,
      ) {
        (person, permission)
      })
    }
    println("phase \{phase + 1}:")
    for (who, permission) in grants.complete().to_array() {
      println("  \{who}: \{permission}")
    }
  }
}
