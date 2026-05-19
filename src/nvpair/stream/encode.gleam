// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import iv.{type Array}

pub type ArrayEncoder(t) =
  fn(Array(t)) -> BitArray

pub type ScalarEncoder(t) =
  fn(t) -> BitArray
