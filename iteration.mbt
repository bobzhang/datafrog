///|
priv struct Owner {
  mut active : Bool
}

///|
/// Advances all registered variables together, exposing one new frontier per round.
pub struct Iteration {
  priv owner : Owner
  priv stages : Array[() -> Bool]
  priv reports : Array[() -> VariableStats]
  priv mut rounds : Int32
}

///|
pub struct VariableStats {
  name : String
  stable : Int32
  recent : Int32
  pending : Int32
  batches : Int32
}

///|
pub fn Iteration::Iteration() -> Iteration {
  { owner: { active: true, }, stages: [], reports: [], rounds: 0, }
}

///|
pub fn Iteration::changed(self : Iteration) -> Bool {
  guard self.owner.active else { abort("iteration is disposed") }
  let mut changed = false
  for advance in self.stages {
    // Do not short circuit: every variable must advance in the same round.
    if advance() {
      changed = true
    }
  }
  self.rounds += 1
  changed
}

///|
pub fn Iteration::round(self : Iteration) -> Int32 {
  self.rounds
}

///|
pub fn Iteration::stats(self : Iteration) -> Array[VariableStats] {
  self.reports.map(fn(report) { report() })
}

///|
/// Unregister all stages. Existing variable handles can no longer be used.
pub fn Iteration::dispose(self : Iteration) -> Unit {
  self.owner.active = false
  self.stages.clear()
  self.reports.clear()
}

///|
pub fn[T : Compare] Iteration::variable(
  self : Iteration,
  name : String,
  distinct~ : Bool = true,
) -> Variable[T] {
  guard self.owner.active else { abort("iteration is disposed") }
  let state : Variable[T] = {
    owner: self.owner,
    name,
    distinct,
    stable: [],
    recent: Relation([]),
    pending: [],
  }
  // Capture the variable, never the iteration: no reference-counted ownership cycle.
  self.stages.push(fn() { state.advance() })
  self.reports.push(fn() { state.stats() })
  state
}
