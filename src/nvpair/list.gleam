// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/set

import iv.{type Array}

import nvpair/data_type.{type DataType}
import nvpair/stream/decode.{type ScalarResult}

pub const version: Int = 0

pub fn check_version(v: Int) -> Result(Int, decode.Error) {
  case v == version {
    True -> Ok(version)
    False -> Error(decode.Message("unsupported version"))
  }
}

pub type Flag {
  UniqueName
  UniqueNameType
}

pub fn flag_index(flag: Flag) -> Int {
  case flag {
    UniqueName -> 0
    UniqueNameType -> 1
  }
}

pub fn index_flag(index: Int) -> Option(Flag) {
  case index {
    0 -> Some(UniqueName)
    1 -> Some(UniqueNameType)
    _ -> None
  }
}

fn int_flags_impl(
  ok: List(Flag),
  bad: Int,
  flags: Int,
  index: Int,
) -> #(List(Flag), Int) {
  let mask = int.bitwise_shift_left(1, index)
  let next = index + 1
  case mask > flags {
    True -> #(ok, bad)
    False ->
      case int.bitwise_and(flags, mask) {
        0 -> int_flags_impl(ok, bad, flags, next)
        _ ->
          case index_flag(index) {
            Some(flag) -> int_flags_impl([flag, ..ok], bad, flags, next)
            None -> int_flags_impl(ok, int.bitwise_and(bad, mask), flags, next)
          }
      }
  }
}

pub fn int_flags(flags: Int) -> #(List(Flag), Int) {
  int_flags_impl([], 0, flags, 0)
}

fn apply_flag(acc: Int, flag: Flag) -> Int {
  let index = flag_index(flag)
  let i = int.bitwise_shift_left(1, index)
  int.bitwise_or(acc, i)
}

pub fn flags(flags: List(Flag)) -> Int {
  list.fold(flags, 0, apply_flag)
}

pub fn check_flags(flags: Int) -> Result(List(Flag), decode.Error) {
  case int_flags(flags) {
    #(flags, 0) -> Ok(flags)
    #(_flags, _bogus) -> Error(decode.Message("invalid flags"))
  }
}

pub type Header {
  Header(version: Int, flags: List(Flag))
}

pub type Pair {
  Dontcare(String)
  Unknown(String)
  Boolean(String)
  Byte(String, Int)
  Int16(String, Int)
  Uint16(String, Int)
  Int32(String, Int)
  Uint32(String, Int)
  Int64(String, Int)
  Uint64(String, Int)
  String(String, String)
  ByteArray(String, BitArray)
  Int16Array(String, Array(Int))
  Uint16Array(String, Array(Int))
  Int32Array(String, Array(Int))
  Uint32Array(String, Array(Int))
  Int64Array(String, Array(Int))
  Uint64Array(String, Array(Int))
  StringArray(String, Array(String))
  Hrtime(String, Int)
  Nvlist(String, NvList)
  NvlistArray(String, Array(NvList))
  BooleanValue(String, Bool)
  Int8(String, Int)
  Uint8(String, Int)
  BooleanArray(String, Array(Bool))
  Int8Array(String, Array(Int))
  Uint8Array(String, Array(Int))
  Double(String, Float)
}

pub fn pair_name(pair: Pair) -> String {
  case pair {
    Dontcare(name) -> name
    Unknown(name) -> name
    Boolean(name) -> name
    Byte(name, _) -> name
    Int16(name, _) -> name
    Uint16(name, _) -> name
    Int32(name, _) -> name
    Uint32(name, _) -> name
    Int64(name, _) -> name
    Uint64(name, _) -> name
    String(name, _) -> name
    ByteArray(name, _) -> name
    Int16Array(name, _) -> name
    Uint16Array(name, _) -> name
    Int32Array(name, _) -> name
    Uint32Array(name, _) -> name
    Int64Array(name, _) -> name
    Uint64Array(name, _) -> name
    StringArray(name, _) -> name
    Hrtime(name, _) -> name
    Nvlist(name, _) -> name
    NvlistArray(name, _) -> name
    BooleanValue(name, _) -> name
    Int8(name, _) -> name
    Uint8(name, _) -> name
    BooleanArray(name, _) -> name
    Int8Array(name, _) -> name
    Uint8Array(name, _) -> name
    Double(name, _) -> name
  }
}

pub fn pair_type(pair: Pair) -> DataType {
  case pair {
    Dontcare(_) -> data_type.Dontcare
    Unknown(_) -> data_type.Unknown
    Boolean(_) -> data_type.Boolean
    Byte(_, _) -> data_type.Byte
    Int16(_, _) -> data_type.Int16
    Uint16(_, _) -> data_type.Uint16
    Int32(_, _) -> data_type.Int32
    Uint32(_, _) -> data_type.Uint32
    Int64(_, _) -> data_type.Int64
    Uint64(_, _) -> data_type.Uint64
    String(_, _) -> data_type.String
    ByteArray(_, _) -> data_type.ByteArray
    Int16Array(_, _) -> data_type.Int16Array
    Uint16Array(_, _) -> data_type.Uint16Array
    Int32Array(_, _) -> data_type.Int32Array
    Uint32Array(_, _) -> data_type.Uint32Array
    Int64Array(_, _) -> data_type.Int64Array
    Uint64Array(_, _) -> data_type.Uint64Array
    StringArray(_, _) -> data_type.StringArray
    Hrtime(_, _) -> data_type.Hrtime
    Nvlist(_, _) -> data_type.Nvlist
    NvlistArray(_, _) -> data_type.NvlistArray
    BooleanValue(_, _) -> data_type.BooleanValue
    Int8(_, _) -> data_type.Int8
    Uint8(_, _) -> data_type.Uint8
    BooleanArray(_, _) -> data_type.BooleanArray
    Int8Array(_, _) -> data_type.Int8Array
    Uint8Array(_, _) -> data_type.Uint8Array
    Double(_, _) -> data_type.Double
  }
}

pub type NvList {
  NvList(flags: List(Flag), pairs: Array(Pair))
}

fn validate_unique_name_type(pairs: List(Pair)) -> Bool {
  let nametypes =
    pairs
    |> list.map(fn(pair) { #(pair_name(pair), pair_type(pair)) })
    |> set.from_list
  set.size(nametypes) == list.length(pairs)
}

fn validate_unique_name(pairs: List(Pair)) -> Bool {
  let names =
    pairs
    |> list.map(pair_name)
    |> set.from_list
  set.size(names) == list.length(pairs)
}

pub fn from_list(pairs: List(Pair), flags: List(Flag)) -> Option(NvList) {
  // XXX: flags is interpreted as a bit field, but the two valid flags are
  // incompatible, so UniqueNameType gets higher priority.
  let valid = case list.contains(flags, UniqueNameType) {
    True -> validate_unique_name_type(pairs)
    False ->
      case list.contains(flags, UniqueName) {
        True -> validate_unique_name(pairs)
        False -> True
      }
  }
  case valid {
    True -> Some(NvList(flags, iv.from_reverse_list(pairs)))
    False -> None
  }
}

pub fn validate(
  pairs: List(Pair),
  flags: List(Flag),
  rest: BitArray,
) -> ScalarResult(NvList) {
  case from_list(pairs, flags) {
    Some(nvl) -> Ok(#(nvl, rest))
    None -> Error(decode.Message("pairs incompatible with flags"))
  }
}

pub fn lookup(nvl: NvList, name: String) -> Option(Pair) {
  iv.find(nvl.pairs, fn(pair) { pair_name(pair) == name })
  |> option.from_result
}

pub fn is_empty(nvl: NvList) -> Bool {
  iv.is_empty(nvl.pairs)
}
