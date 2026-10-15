///|
pub struct Variable[T] {
  priv owner : Owner
  priv name : String
  priv distinct : Bool
  priv stable : Array[Relation[T]]
  priv mut recent : Relation[T]
  priv pending : Array[Relation[T]]
}

///|
fn[T] Variable::check(self : Variable[T]) -> Unit {
  guard self.owner.active else {
    abort("variable belongs to a disposed iteration")
  }
}

///|
fn[A, B] same_iteration(a : Variable[A], b : Variable[B]) -> Unit {
  a.check()
  b.check()
  guard physical_equal(a.owner, b.owner) else {
    abort("variables belong to different iterations")
  }
}

///|
pub fn[T] Variable::name(self : Variable[T]) -> String {
  self.name
}

///|
pub fn[T] Variable::stats(self : Variable[T]) -> VariableStats {
  self.check()
  let mut stable = 0
  let mut pending = 0
  for batch in self.stable {
    stable += batch.length()
  }
  for batch in self.pending {
    pending += batch.length()
  }
  {
    name: self.name,
    stable,
    recent: self.recent.length(),
    pending,
    batches: self.stable.length(),
  }
}

///|
pub fn[T] Variable::is_stable(self : Variable[T]) -> Bool {
  self.check()
  self.recent.is_empty() && self.pending.is_empty()
}

///|
pub fn[T] Variable::recent(self : Variable[T]) -> Relation[T] {
  self.check()
  self.recent
}

///|
pub fn[T] Variable::insert(self : Variable[T], relation : Relation[T]) -> Unit {
  self.check()
  if !relation.is_empty() {
    self.pending.push(relation)
  }
}

///|
pub fn[T : Compare] Variable::insert_all(
  self : Variable[T],
  tuples : Array[T],
) -> Unit {
  self.insert(Relation(tuples))
}

///|
/// Return a non-consuming snapshot after quiescence. More facts may be inserted later.
pub fn[T : Compare] Variable::complete(self : Variable[T]) -> Relation[T] {
  guard self.is_stable() else { abort("complete requires a stable variable") }
  let mut result = Relation([])
  for batch in self.stable {
    result = result.merge(batch)
  }
  result
}

///|
fn[T : Compare] Variable::advance(self : Variable[T]) -> Bool {
  if !self.recent.is_empty() {
    let mut batch = self.recent
    self.recent = Relation([])
    while self.stable.last() is Some(last) &&
          last.length().to_int64() <= 2L * batch.length().to_int64() {
      let _ = self.stable.pop()
      batch = batch.merge(last)
    }
    self.stable.push(batch)
  }
  if self.pending.pop() is Some(first) {
    let mut next = first
    while self.pending.pop() is Some(batch) {
      next = next.merge(batch)
    }
    if self.distinct {
      for batch in self.stable {
        next = next.difference(batch)
      }
    }
    self.recent = next
  }
  !self.recent.is_empty()
}

///|
pub fn[A, B : Compare] Variable::from_map(
  self : Variable[B],
  input : Variable[A],
  logic : (A) -> B,
) -> Unit {
  same_iteration(self, input)
  self.insert(Relation::from_map(input.recent, logic))
}

///|
pub fn[A, B : Compare] Variable::from_map_filtered(
  self : Variable[B],
  input : Variable[A],
  logic : (A) -> B?,
) -> Unit {
  same_iteration(self, input)
  self.insert(Relation::from_map_filtered(input.recent, logic))
}
