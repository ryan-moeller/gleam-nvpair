// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/int

pub fn align(x: Int, mask: Int) -> Int {
  int.bitwise_and(x + mask, int.bitwise_not(mask))
}

pub fn align8(x: Int) -> Int {
  align(x, 7)
}

pub fn align4(x: Int) -> Int {
  align(x, 3)
}
