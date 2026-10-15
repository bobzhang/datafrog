///|
/// One constraint in a multiway join. Callbacks must be pure.
pub struct Leaper[P, V] {
  priv generates : Bool
  priv count : (P) -> Int32?
  priv propose : (P) -> Array[V]
  priv accepts : (P, V) -> Bool
}

///|
fn[K : Compare, V] key_range(
  relation : Relation[(K, V)],
  key : K,
) -> (Int32, Int32) {
  let start = for lo = 0, hi = relation.length(); lo < hi; {
    let mid = lo + (hi - lo) / 2
    if relation.elements[mid].0 < key {
      continue mid + 1, hi
    } else {
      continue lo, mid
    }
  } nobreak {
    lo
  }
  let end = for lo = start, hi = relation.length(); lo < hi; {
    let mid = lo + (hi - lo) / 2
    if relation.elements[mid].0 <= key {
      continue mid + 1, hi
    } else {
      continue lo, mid
    }
  } nobreak {
    lo
  }
  (start, end)
}

///|
pub fn[K : Compare, V : Compare, P] Relation::extend_with(
  self : Relation[(K, V)],
  key : (P) -> K,
) -> Leaper[P, V] {
  {
    generates: true,
    count: fn(prefix) {
      let (lo, hi) = key_range(self, key(prefix))
      Some(hi - lo)
    },
    propose: fn(prefix) {
      let (lo, hi) = key_range(self, key(prefix))
      [
        for i in lo..<hi => self.elements[i].1
      ]
    },
    accepts: fn(prefix, value) { self.contains((key(prefix), value)) },
  }
}

///|
pub fn[K : Compare, V : Compare, P] Relation::extend_anti(
  self : Relation[(K, V)],
  key : (P) -> K,
) -> Leaper[P, V] {
  Leaper::filter(fn(prefix, value) { !self.contains((key(prefix), value)) })
}

///|
pub fn[T : Compare, P, V] Relation::filter_with(
  self : Relation[T],
  key : (P) -> T,
) -> Leaper[P, V] {
  Leaper::prefix_filter(fn(prefix) { self.contains(key(prefix)) })
}

///|
pub fn[T : Compare, P, V] Relation::filter_anti(
  self : Relation[T],
  key : (P) -> T,
) -> Leaper[P, V] {
  Leaper::prefix_filter(fn(prefix) { !self.contains(key(prefix)) })
}

///|
pub fn[P, V] Leaper::filter(predicate : (P, V) -> Bool) -> Leaper[P, V] {
  {
    generates: false,
    count: fn(_) { None },
    propose: fn(_) { [] },
    accepts: predicate,
  }
}

///|
pub fn[P, V] Leaper::prefix_filter(predicate : (P) -> Bool) -> Leaper[P, V] {
  {
    generates: false,
    count: fn(prefix) { if predicate(prefix) { None } else { Some(0) } },
    propose: fn(_) { [] },
    accepts: fn(prefix, _) { predicate(prefix) },
  }
}

///|
/// Supplies the unit value when all other leapers only filter prefixes.
pub fn[P] Leaper::passthrough() -> Leaper[P, Unit] {
  {
    generates: true,
    count: fn(_) { Some(1) },
    propose: fn(_) { [()] },
    accepts: fn(_, _) { true },
  }
}

///|
pub fn[P, V, O : Compare] Relation::from_leapjoin(
  input : Relation[P],
  leapers : Array[Leaper[P, V]],
  logic : (P, V) -> O,
) -> Relation[O] {
  guard leapers.iter().any(fn(l) { l.generates }) else {
    abort("leapjoin requires a proposing leaper")
  }
  let output = []
  for prefix in input.elements {
    let mut best : Int32? = None
    let mut count = 2147483647
    let mut empty = false
    for index, leaper in leapers {
      if (leaper.count)(prefix) is Some(size) {
        if size == 0 {
          empty = true
          break
        }
        if leaper.generates && (best is None || size < count) {
          best = Some(index)
          count = size
        }
      }
    }
    if !empty && best is Some(index) {
      for value in (leapers[index].propose)(prefix) {
        let mut accepted = true
        for other, leaper in leapers {
          if other != index && !(leaper.accepts)(prefix, value) {
            accepted = false
            break
          }
        }
        if accepted {
          output.push(logic(prefix, value))
        }
      }
    }
  }
  Relation(output)
}

///|
pub fn[P, V, O : Compare] Variable::from_leapjoin(
  self : Variable[O],
  input : Variable[P],
  leapers : Array[Leaper[P, V]],
  logic : (P, V) -> O,
) -> Unit {
  same_iteration(self, input)
  self.insert(Relation::from_leapjoin(input.recent, leapers, logic))
}
