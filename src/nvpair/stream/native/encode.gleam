// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/bit_array
import gleam/int

import iv.{type Array}

import nvpair/data_type
import nvpair/list.{type Header, type NvList, type Pair, Header} as nvl
import nvpair/stream/align.{align8}
import nvpair/stream/encode.{type ArrayEncoder, type ScalarEncoder}

fn header(header: Header) -> BitArray {
  let int_flags = nvl.flags(header.flags)
  <<header.version:native-size(32), int_flags:native-size(32)>>
}

fn embedded_header(header: Header) -> BitArray {
  let int_flags = nvl.flags(header.flags)
  <<
    header.version:native-size(32),
    int_flags:native-size(32),
    0:size(64),
    // priv
    0:size(32),
    // flag
    0:size(32),
  >>
  // pad
}

fn bool_value(value: Bool) -> BitArray {
  int(32)(case value {
    False -> 0
    True -> 1
  })
}

fn bool_array(values: Array(Bool)) -> BitArray {
  values
  |> iv.map(bool_value)
  |> iv.to_list
  |> bit_array.concat
}

fn int(size: Int) -> ScalarEncoder(Int) {
  fn(value: Int) -> BitArray { <<value:native-size(size)>> }
}

fn int_array(size: Int) -> ArrayEncoder(Int) {
  fn(values: Array(Int)) -> BitArray {
    values
    |> iv.map(int(size))
    |> iv.to_list
    |> bit_array.concat
  }
}

fn string(value: String) -> BitArray {
  <<value:utf8, 0:size(8)>>
}

fn string_array(values: Array(String)) -> BitArray {
  let nulled_pointers = 64 * iv.size(values)
  let strings =
    values
    |> iv.map(string)
    |> iv.to_list
    |> bit_array.concat
  <<0:size(nulled_pointers), strings:bits>>
}

const embedded_header_size: Int = 24

const pair_header_size: Int = 16

const ptr_size: Int = 8

fn pair(pair: Pair) -> BitArray {
  let #(name, t, value, array_len) = case pair {
    nvl.Dontcare(name) -> #(name, data_type.Dontcare, <<>>, 0)
    nvl.Unknown(name) -> #(name, data_type.Unknown, <<>>, 0)
    nvl.Boolean(name) -> #(name, data_type.Boolean, <<>>, 0)
    nvl.Byte(name, value) -> #(name, data_type.Byte, int(8)(value), 1)
    nvl.Int16(name, value) -> #(name, data_type.Int16, int(16)(value), 1)
    nvl.Uint16(name, value) -> #(name, data_type.Uint16, int(16)(value), 1)
    nvl.Int32(name, value) -> #(name, data_type.Int32, int(32)(value), 1)
    nvl.Uint32(name, value) -> #(name, data_type.Uint32, int(32)(value), 1)
    nvl.Int64(name, value) -> #(name, data_type.Int64, int(64)(value), 1)
    nvl.Uint64(name, value) -> #(name, data_type.Uint64, int(64)(value), 1)
    nvl.String(name, value) -> #(name, data_type.String, string(value), 1)
    nvl.ByteArray(name, values) -> #(
      name,
      data_type.ByteArray,
      values,
      bit_array.byte_size(values),
    )
    nvl.Int16Array(name, values) -> #(
      name,
      data_type.Int16Array,
      int_array(16)(values),
      iv.size(values),
    )
    nvl.Uint16Array(name, values) -> #(
      name,
      data_type.Uint16Array,
      int_array(16)(values),
      iv.size(values),
    )
    nvl.Int32Array(name, values) -> #(
      name,
      data_type.Int32Array,
      int_array(32)(values),
      iv.size(values),
    )
    nvl.Uint32Array(name, values) -> #(
      name,
      data_type.Uint32Array,
      int_array(32)(values),
      iv.size(values),
    )
    nvl.Int64Array(name, values) -> #(
      name,
      data_type.Int64Array,
      int_array(64)(values),
      iv.size(values),
    )
    nvl.Uint64Array(name, values) -> #(
      name,
      data_type.Uint64Array,
      int_array(64)(values),
      iv.size(values),
    )
    nvl.StringArray(name, values) -> #(
      name,
      data_type.StringArray,
      string_array(values),
      iv.size(values),
    )
    nvl.Hrtime(name, value) -> #(name, data_type.Hrtime, int(64)(value), 1)
    nvl.Nvlist(name, value) -> #(name, data_type.Nvlist, nvlist(value), 1)
    nvl.NvlistArray(name, values) -> #(
      name,
      data_type.NvlistArray,
      nvlist_array(values),
      iv.size(values),
    )
    nvl.BooleanValue(name, value) -> #(
      name,
      data_type.BooleanValue,
      bool_value(value),
      1,
    )
    nvl.Int8(name, value) -> #(name, data_type.Int8, int(8)(value), 1)
    nvl.Uint8(name, value) -> #(name, data_type.Uint8, int(8)(value), 1)
    nvl.BooleanArray(name, values) -> #(
      name,
      data_type.BooleanArray,
      bool_array(values),
      iv.size(values),
    )
    nvl.Int8Array(name, values) -> #(
      name,
      data_type.Int8Array,
      int_array(8)(values),
      iv.size(values),
    )
    nvl.Uint8Array(name, values) -> #(
      name,
      data_type.Uint8Array,
      int_array(8)(values),
      iv.size(values),
    )
    nvl.Double(name, value) -> #(name, data_type.Double, double(value), 1)
  }
  let name = string(name)
  let name_size = bit_array.byte_size(name)
  assert name_size < int.bitwise_shift_left(1, 16) as "name too long"
  let header_size = pair_header_size + name_size
  let header_pad_size = align8(header_size) - header_size
  let size =
    header_size
    + header_pad_size
    + case t {
      data_type.Nvlist -> align8(embedded_header_size)
      data_type.NvlistArray ->
        { ptr_size + align8(embedded_header_size) } * array_len
      _ -> bit_array.byte_size(value)
    }
  let value_pad_size = case t {
    data_type.Nvlist -> 0
    _ -> align8(size) - size
  }
  let padded_size = size + value_pad_size
  assert padded_size < int.bitwise_shift_left(1, 32) as "size too big"
  let data_type = data_type.data_type_index(t)
  <<
    padded_size:native-size(32),
    name_size:native-size(16),
    0:size(16),
    array_len:native-size(32),
    data_type:native-size(32),
    name:bits,
    0:size({ 8 * header_pad_size }),
    value:bits,
    0:size({ 8 * value_pad_size }),
  >>
}

fn pairs(nvl: NvList) -> BitArray {
  let pairs =
    nvl.pairs
    |> iv.map(pair)
    |> iv.to_list
    |> bit_array.concat
  <<pairs:bits, 0:size(32)>>
}

fn nvlist(value: NvList) -> BitArray {
  let header = embedded_header(Header(nvl.version, value.flags))
  let pairs = pairs(value)
  <<header:bits, pairs:bits>>
}

fn nvlist_header(nvl: NvList) -> BitArray {
  embedded_header(Header(nvl.version, nvl.flags))
}

fn nvlist_array(values: Array(NvList)) -> BitArray {
  let headers =
    values
    |> iv.map(nvlist_header)
    |> iv.to_list
    |> bit_array.concat
  let lists =
    values
    |> iv.map(pairs)
    |> iv.to_list
    |> bit_array.concat
  <<0:size({ 64 * iv.size(values) }), headers:bits, lists:bits>>
}

fn double(value: Float) -> BitArray {
  <<value:float>>
}

pub fn pack(nvl: NvList) -> BitArray {
  let header = header(Header(nvl.version, nvl.flags))
  let pairs = pairs(nvl)
  <<header:bits, pairs:bits>>
}
