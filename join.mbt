///|
/// The right input of a semi-naive join is either changing or fixed.
pub(all) enum JoinInput[T] {
  Dynamic(Variable[T])
  Static(Relation[T])
}

///|
pub fn[T] Variable::as_input(self : Variable[T]) -> JoinInput[T] {
  Dynamic(self)
}

///|
pub fn[T] Relation::as_input(self : Relation[T]) -> JoinInput[T] {
  Static(self)
}

///|
fn[K : Compare, A, B, C] join_into(
  left : Relation[(K, A)],
  right : Relation[(K, B)],
  logic : (K, A, B) -> C?,
  output : Array[C],
) -> Unit {
  let mut i = 0
  let mut j = 0
  while i < left.length() && j < right.length() {
    let key = left.elements[i].0
    let other = right.elements[j].0
    if key < other {
      i += 1
    } else if other < key {
      j += 1
    } else {
      let mut end_i = i + 1
      let mut end_j = j + 1
      while end_i < left.length() && left.elements[end_i].0 == key {
        end_i += 1
      }
      while end_j < right.length() && right.elements[end_j].0 == key {
        end_j += 1
      }
      for a in i..<end_i {
        for b in j..<end_j {
          if logic(key, left.elements[a].1, right.elements[b].1) is Some(value) {
            output.push(value)
          }
        }
      }
      i = end_i
      j = end_j
    }
  }
}

///|
pub fn[K : Compare, A, B, C : Compare] Relation::from_join_filtered(
  left : Relation[(K, A)],
  right : Relation[(K, B)],
  logic : (K, A, B) -> C?,
) -> Relation[C] {
  let output = []
  join_into(left, right, logic, output)
  Relation(output)
}

///|
pub fn[K : Compare, A, B, C : Compare] Relation::from_join(
  left : Relation[(K, A)],
  right : Relation[(K, B)],
  logic : (K, A, B) -> C,
) -> Relation[C] {
  Relation::from_join_filtered(left, right, fn(k, a, b) { Some(logic(k, a, b)) })
}

///|
pub fn[K : Compare, A, B, C : Compare] Variable::from_join_filtered(
  self : Variable[C],
  left : Variable[(K, A)],
  right : JoinInput[(K, B)],
  logic : (K, A, B) -> C?,
) -> Unit {
  same_iteration(self, left)
  let output = []
  match right {
    Static(relation) => join_into(left.recent, relation, logic, output)
    Dynamic(variable) => {
      same_iteration(self, variable)
      for stable in variable.stable {
        join_into(left.recent, stable, logic, output)
      }
      for stable in left.stable {
        join_into(stable, variable.recent, logic, output)
      }
      join_into(left.recent, variable.recent, logic, output)
    }
  }
  self.insert(Relation(output))
}

///|
pub fn[K : Compare, A, B, C : Compare] Variable::from_join(
  self : Variable[C],
  left : Variable[(K, A)],
  right : JoinInput[(K, B)],
  logic : (K, A, B) -> C,
) -> Unit {
  self.from_join_filtered(left, right, fn(k, a, b) { Some(logic(k, a, b)) })
}

///|
/// Negation is only sound against a fixed relation of keys.
pub fn[K : Compare, A, C : Compare] Relation::from_antijoin(
  input : Relation[(K, A)],
  excluded : Relation[K],
  logic : (K, A) -> C,
) -> Relation[C] {
  let output = []
  let mut j = 0
  for (key, value) in input.elements {
    while j < excluded.length() && excluded.elements[j] < key {
      j += 1
    }
    if j == excluded.length() || excluded.elements[j] != key {
      output.push(logic(key, value))
    }
  }
  Relation(output)
}

///|
pub fn[K : Compare, A, C : Compare] Variable::from_antijoin(
  self : Variable[C],
  input : Variable[(K, A)],
  excluded : Relation[K],
  logic : (K, A) -> C,
) -> Unit {
  same_iteration(self, input)
  self.insert(Relation::from_antijoin(input.recent, excluded, logic))
}
