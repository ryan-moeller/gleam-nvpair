import iv.{type Array}

pub type ArrayEncoder(t) = fn(Array(t)) -> BitArray
pub type ScalarEncoder(t) = fn(t) -> BitArray
