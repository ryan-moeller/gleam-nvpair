// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/result

import iv.{type Array}

pub type Error {
  Message(String)
}

pub type ScalarResult(t) =
  Result(#(t, BitArray), Error)

pub type ScalarDecoder(t) =
  fn(BitArray) -> ScalarResult(t)

pub type ArrayResult(t) =
  Result(#(Array(t), BitArray), Error)

pub type ArrayDecoder(t) =
  fn(BitArray, Int) -> ArrayResult(t)

fn array_impl(
  acc: List(t),
  input: BitArray,
  len: Int,
  decode: ScalarDecoder(t),
) -> ArrayResult(t) {
  case len {
    0 -> Ok(#(iv.from_reverse_list(acc), input))
    _ -> {
      use #(value, rest) <- result.try(decode(input))
      array_impl([value, ..acc], rest, len - 1, decode)
    }
  }
}

pub fn array(decode: ScalarDecoder(t)) -> ArrayDecoder(t) {
  fn(input: BitArray, len: Int) -> ArrayResult(t) {
    array_impl([], input, len, decode)
  }
}

pub fn skip(input: BitArray, len: Int) -> Result(BitArray, Error) {
  case input {
    <<_:bytes-size(len), rest:bytes>> -> Ok(rest)
    _ -> Error(Message("invalid input"))
  }
}
