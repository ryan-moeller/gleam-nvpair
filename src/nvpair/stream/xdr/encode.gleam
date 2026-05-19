// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/bit_array
import gleam/string

import iv.{type Array}

import nvpair/data_type
import nvpair/list.{type Header, type NvList, type Pair, Header} as nvl
import nvpair/stream/align.{align4, align8}
import nvpair/stream/encode.{type ScalarEncoder}

fn array(encoder: ScalarEncoder(t), values: Array(t)) -> BitArray {
  case iv.size(values) {
    0 -> <<>>
    nelem -> {
      let nelem = nelem |> int(32)
      let elements =
        values
        |> iv.map(encoder)
        |> iv.to_list
        |> bit_array.concat
      <<nelem:bits, elements:bits>>
    }
  }
}

fn header(header: Header) -> BitArray {
  let int_flags = nvl.flags(header.flags)
  bit_array.append(int(32)(header.version), int(32)(int_flags))
}

fn bool_value(value: Bool) -> BitArray {
  int(32)(case value {
    False -> 0
    True -> 1
  })
}

fn int(size: Int) -> ScalarEncoder(Int) {
  fn(value: Int) -> BitArray { <<value:big-size(size)>> }
}

fn widen(f: fn(Int) -> ScalarEncoder(t), size: Int) -> ScalarEncoder(t) {
  let len = size / 8
  let pad = 8 * { align4(len) - len }
  let encode = f(size)
  fn(value: t) -> BitArray { <<0:size(pad), encode(value):bits>> }
}

fn string(value: String) -> BitArray {
  let s = <<value:utf8>>
  let len = bit_array.byte_size(s)
  let pad = 8 * { align4(len) - len }
  <<len:big-size(32), s:bits, 0:size(pad)>>
}

fn string_array(values: Array(String)) -> BitArray {
  iv.fold(values, from: <<>>, with: fn(acc, value) {
    <<acc:bits, string(value):bits>>
  })
}

const sizeof_nvpair_t: Int = 16

fn size_calc(name_len: Int, data_len: Int) -> Int {
  align8(sizeof_nvpair_t + name_len) + align8(data_len)
}

const sizeof_nvlist_t: Int = 24

fn pair(pair: Pair) -> BitArray {
  let #(name, t, value, array_len, data_len) = case pair {
    nvl.Dontcare(name) -> #(name, data_type.Dontcare, <<>>, 0, 0)
    nvl.Unknown(name) -> #(name, data_type.Unknown, <<>>, 0, 0)
    nvl.Boolean(name) -> #(name, data_type.Boolean, <<>>, 0, 0)
    nvl.Byte(name, value) -> #(name, data_type.Byte, widen(int, 8)(value), 1, 1)
    nvl.Int16(name, value) -> #(name, data_type.Int16, int(32)(value), 1, 2)
    nvl.Uint16(name, value) -> #(
      name,
      data_type.Uint16,
      widen(int, 16)(value),
      1,
      2,
    )
    nvl.Int32(name, value) -> #(name, data_type.Int32, int(32)(value), 1, 4)
    nvl.Uint32(name, value) -> #(name, data_type.Uint32, int(32)(value), 1, 4)
    nvl.Int64(name, value) -> #(name, data_type.Int64, int(64)(value), 1, 8)
    nvl.Uint64(name, value) -> #(name, data_type.Uint64, int(64)(value), 1, 8)
    nvl.String(name, value) -> {
      let data = string(value)
      #(name, data_type.String, data, 1, bit_array.byte_size(data) + 1)
    }
    nvl.ByteArray(name, values) -> {
      let data = values |> iv.map(int(8)) |> iv.to_list |> bit_array.concat
      let nelem = iv.size(values)
      #(name, data_type.ByteArray, data, nelem, nelem)
    }
    nvl.Int16Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Int16Array, array(int(32), values), nelem, nelem * 2)
    }
    nvl.Uint16Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Uint16Array, array(int(32), values), nelem, nelem * 2)
    }
    nvl.Int32Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Int32Array, array(int(32), values), nelem, nelem * 4)
    }
    nvl.Uint32Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Uint32Array, array(int(32), values), nelem, nelem * 4)
    }
    nvl.Int64Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Int64Array, array(int(64), values), nelem, nelem * 8)
    }
    nvl.Uint64Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Uint64Array, array(int(64), values), nelem, nelem * 8)
    }
    nvl.StringArray(name, values) -> {
      let nelem = iv.size(values)
      let data_size =
        iv.fold(values, nelem * 8, fn(acc, s) { acc + string.byte_size(s) + 1 })
      #(name, data_type.StringArray, string_array(values), nelem, data_size)
    }
    nvl.Hrtime(name, value) -> #(name, data_type.Hrtime, int(64)(value), 1, 8)
    nvl.Nvlist(name, value) -> #(
      name,
      data_type.Nvlist,
      nvlist(value),
      1,
      align8(sizeof_nvlist_t),
    )
    nvl.NvlistArray(name, values) -> {
      let nelem = iv.size(values)
      let data_size = nelem * { 8 + align8(sizeof_nvlist_t) }
      let data =
        iv.fold(values, from: <<>>, with: fn(acc, value) {
          <<acc:bits, nvlist(value):bits>>
        })
      #(name, data_type.NvlistArray, data, nelem, data_size)
    }
    nvl.BooleanValue(name, value) -> #(
      name,
      data_type.BooleanValue,
      bool_value(value),
      1,
      4,
    )
    nvl.Int8(name, value) -> #(name, data_type.Int8, widen(int, 8)(value), 1, 1)
    nvl.Uint8(name, value) -> #(
      name,
      data_type.Uint8,
      widen(int, 8)(value),
      1,
      1,
    )
    nvl.BooleanArray(name, values) -> {
      let data = array(bool_value, values)
      let nelem = iv.size(values)
      #(name, data_type.BooleanArray, data, nelem, nelem * 4)
    }
    nvl.Int8Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Int8Array, array(widen(int, 8), values), nelem, nelem)
    }
    nvl.Uint8Array(name, values) -> {
      let nelem = iv.size(values)
      #(name, data_type.Uint8Array, array(widen(int, 8), values), nelem, nelem)
    }
    nvl.Double(name, value) -> #(name, data_type.Double, double(value), 1, 8)
  }
  let name_len = string.byte_size(name) + 1
  let name = name |> string
  let data_type = data_type.data_type_index(t) |> int(32)
  let array_len = array_len |> int(32)
  let value_size = bit_array.byte_size(value)
  let value_pad_size = 8 * { align4(value_size) - value_size }
  // XXX: Encoded length doesn't matter in libnvpair, it isn't correct or used.
  let encoded_len = align4(5 * 4 + name_len) + align4(value_size) |> int(32)
  let decoded_len = size_calc(name_len, data_len) |> int(32)
  <<
    encoded_len:bits,
    decoded_len:bits,
    name:bits,
    data_type:bits,
    array_len:bits,
    value:bits,
    0:size(value_pad_size),
  >>
}

fn pairs(nvl: NvList) -> BitArray {
  let pairs =
    nvl.pairs
    |> iv.map(pair)
    |> iv.to_list
    |> bit_array.concat
  <<pairs:bits, 0:size(64)>>
}

fn nvlist(value: NvList) -> BitArray {
  let header = header(Header(nvl.version, value.flags))
  let pairs = pairs(value)
  <<header:bits, pairs:bits>>
}

fn double(value: Float) -> BitArray {
  <<value:big-float>>
}

pub fn pack(nvl: NvList) -> BitArray {
  nvlist(nvl)
}
