///|
/// Sorted, duplicate-free tuples. Tuples and their comparison order must be immutable.
pub struct Relation[T] {
  priv elements : Array[T]
}

///|
pub fn[T : Compare] Relation::Relation(elements : Array[T]) -> Relation[T] {
  let sorted = elements.copy()
  sorted.sort()
  let unique = []
  for value in sorted {
    if unique.last() is None || (unique.last() is Some(last) && last != value) {
      unique.push(value)
    }
  }
  { elements: unique, }
}

///|
pub fn[T] Relation::to_array(self : Relation[T]) -> Array[T] {
  self.elements.copy()
}

///|
pub fn[T] Relation::length(self : Relation[T]) -> Int32 {
  self.elements.length()
}

///|
pub fn[T] Relation::is_empty(self : Relation[T]) -> Bool {
  self.elements.is_empty()
}

///|
pub fn[T : Compare] Relation::contains(self : Relation[T], value : T) -> Bool {
  let i = lower_bound(self.elements, value)
  i < self.length() && self.elements[i] == value
}

///|
fn[T : Compare] lower_bound(values : Array[T], value : T) -> Int32 {
  for lo = 0, hi = values.length(); lo < hi; {
    let mid = lo + (hi - lo) / 2
    if values[mid] < value {
      continue mid + 1, hi
    } else {
      continue lo, mid
    }
  } nobreak {
    lo
  }
}

///|
pub fn[T : Compare] Relation::merge(
  self : Relation[T],
  other : Relation[T],
) -> Relation[T] {
  let result = []
  let mut i = 0
  let mut j = 0
  while i < self.length() && j < other.length() {
    let a = self.elements[i]
    let b = other.elements[j]
    if a < b {
      result.push(a)
      i += 1
    } else if b < a {
      result.push(b)
      j += 1
    } else {
      result.push(a)
      i += 1
      j += 1
    }
  }
  while i < self.length() {
    result.push(self.elements[i])
    i += 1
  }
  while j < other.length() {
    result.push(other.elements[j])
    j += 1
  }
  { elements: result, }
}

///|
fn[T : Compare] Relation::difference(
  self : Relation[T],
  other : Relation[T],
) -> Relation[T] {
  let result = []
  let mut j = 0
  for a in self.elements {
    while j < other.length() && other.elements[j] < a {
      j += 1
    }
    if j == other.length() || other.elements[j] != a {
      result.push(a)
    }
  }
  { elements: result, }
}

///|
pub fn[A, B : Compare] Relation::from_map(
  input : Relation[A],
  logic : (A) -> B,
) -> Relation[B] {
  Relation(input.elements.map(logic))
}

///|
pub fn[A, B : Compare] Relation::from_map_filtered(
  input : Relation[A],
  logic : (A) -> B?,
) -> Relation[B] {
  let values = []
  for a in input.elements {
    if logic(a) is Some(b) {
      values.push(b)
    }
  }
  Relation(values)
}
