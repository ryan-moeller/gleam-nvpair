// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/bit_array
import gleam/option
import gleam/result

import iv

import nvpair/data_type
import nvpair/list.{type Flag, type Header, type NvList, type Pair, Header} as nvl
import nvpair/stream/align.{align4}
import nvpair/stream/decode.{
  type ArrayDecoder, type ArrayResult, type ScalarDecoder, type ScalarResult,
}

// TODO: someone write a full xdr module

fn array(decoder: ScalarDecoder(t)) -> ArrayDecoder(t) {
  fn(input: BitArray, len: Int) -> ArrayResult(t) {
    case len {
      0 -> Ok(#(iv.new(), input))
      _ -> {
        use #(count, rest) <- result.try(uint(32)(input))
        case count == len {
          True -> decode.array(decoder)(rest, len)
          False -> Error(decode.Message("invalid array"))
        }
      }
    }
  }
}

fn header(input: BitArray) -> ScalarResult(Header) {
  use #(version, rest) <- result.try(int(32)(input))
  use #(flags, rest) <- result.try(uint(32)(rest))
  use version <- result.try(nvl.check_version(version))
  use flags <- result.try(nvl.check_flags(flags))
  Ok(#(Header(version, flags), rest))
}

fn bool_value(input: BitArray) -> ScalarResult(Bool) {
  use #(value, rest) <- result.try(int(32)(input))
  Ok(#(value == 1, rest))
}

fn int(size: Int) -> ScalarDecoder(Int) {
  fn(input: BitArray) -> ScalarResult(Int) {
    case input {
      <<value:big-signed-size(size), rest:bytes>> -> Ok(#(value, rest))
      _ -> Error(decode.Message("invalid integer"))
    }
  }
}

fn uint(size: Int) -> ScalarDecoder(Int) {
  fn(input: BitArray) -> ScalarResult(Int) {
    case input {
      <<value:big-unsigned-size(size), rest:bytes>> -> Ok(#(value, rest))
      _ -> Error(decode.Message("invalid integer"))
    }
  }
}

fn widen(f: fn(Int) -> ScalarDecoder(t), size: Int) -> ScalarDecoder(t) {
  let decoder = f(size)
  fn(input: BitArray) -> ScalarResult(t) {
    use rest <- result.try(realign(input, size / 8))
    decoder(rest)
  }
}

fn string(input: BitArray) -> ScalarResult(String) {
  use #(size, rest) <- result.try(uint(32)(input))
  let pad_size = 8 * { align4(size) - size }
  case rest {
    <<s:bytes-size(size), 0:size(pad_size), rest:bytes>> ->
      case bit_array.to_string(s) {
        Ok(value) -> Ok(#(value, rest))
        Error(Nil) -> Error(decode.Message("invalid string"))
      }
    _ -> Error(decode.Message("invalid string size"))
  }
}

fn realign(input: BitArray, offset: Int) -> Result(BitArray, decode.Error) {
  decode.skip(input, align4(offset) - offset)
}

fn pairs(
  acc: List(Pair),
  input: BitArray,
  flags: List(Flag),
) -> ScalarResult(NvList) {
  let len = bit_array.byte_size(input)
  use #(_encode_len, rest) <- result.try(int(32)(input))
  use #(decode_len, rest) <- result.try(int(32)(rest))
  case decode_len == 0 {
    True -> nvl.validate(acc, flags, rest)

    False -> {
      use #(name, rest) <- result.try(string(rest))
      use #(data_type, rest) <- result.try(int(32)(rest))
      use #(array_len, rest) <- result.try(int(32)(rest))
      use data_type <- result.try(
        data_type.index_data_type(data_type)
        |> option.to_result(decode.Message("invalid data type")),
      )
      use #(pair, rest) <- result.try(case data_type {
        data_type.Dontcare -> Ok(#(nvl.Dontcare(name), rest))
        data_type.Unknown -> Ok(#(nvl.Unknown(name), rest))
        data_type.Boolean -> Ok(#(nvl.Boolean(name), rest))
        data_type.Byte -> {
          use #(value, rest) <- result.try(widen(uint, 8)(rest))
          Ok(#(nvl.Byte(name, value), rest))
        }
        data_type.Int16 -> {
          use #(value, rest) <- result.try(int(32)(rest))
          Ok(#(nvl.Int16(name, value), rest))
        }
        data_type.Uint16 -> {
          use #(value, rest) <- result.try(widen(uint, 16)(rest))
          Ok(#(nvl.Uint16(name, value), rest))
        }
        data_type.Int32 -> {
          use #(value, rest) <- result.try(int(32)(rest))
          Ok(#(nvl.Int32(name, value), rest))
        }
        data_type.Uint32 -> {
          use #(value, rest) <- result.try(uint(32)(rest))
          Ok(#(nvl.Uint32(name, value), rest))
        }
        data_type.Int64 -> {
          use #(value, rest) <- result.try(int(64)(rest))
          Ok(#(nvl.Int64(name, value), rest))
        }
        data_type.Uint64 -> {
          use #(value, rest) <- result.try(uint(64)(rest))
          Ok(#(nvl.Uint64(name, value), rest))
        }
        data_type.String -> {
          use #(value, rest) <- result.try(string(rest))
          Ok(#(nvl.String(name, value), rest))
        }
        data_type.ByteArray -> {
          // TODO: ByteArray should be a BitArray of bytes not an Array(Int)
          // NOTE: xdr_opaque, not xdr_array.
          use #(values, rest) <- result.try(decode.array(uint(8))(
            rest,
            array_len,
          ))
          Ok(#(nvl.ByteArray(name, values), rest))
        }
        data_type.Int16Array -> {
          use #(values, rest) <- result.try(array(int(32))(rest, array_len))
          Ok(#(nvl.Int16Array(name, values), rest))
        }
        data_type.Uint16Array -> {
          use #(values, rest) <- result.try(array(uint(32))(rest, array_len))
          Ok(#(nvl.Uint16Array(name, values), rest))
        }
        data_type.Int32Array -> {
          use #(values, rest) <- result.try(array(int(32))(rest, array_len))
          Ok(#(nvl.Int32Array(name, values), rest))
        }
        data_type.Uint32Array -> {
          use #(values, rest) <- result.try(array(uint(32))(rest, array_len))
          Ok(#(nvl.Uint32Array(name, values), rest))
        }
        data_type.Int64Array -> {
          use #(values, rest) <- result.try(array(int(64))(rest, array_len))
          Ok(#(nvl.Int64Array(name, values), rest))
        }
        data_type.Uint64Array -> {
          use #(values, rest) <- result.try(array(uint(64))(rest, array_len))
          Ok(#(nvl.Uint64Array(name, values), rest))
        }
        data_type.StringArray -> {
          use #(values, rest) <- result.try(decode.array(string)(
            rest,
            array_len,
          ))
          Ok(#(nvl.StringArray(name, values), rest))
        }
        data_type.Hrtime -> {
          use #(value, rest) <- result.try(uint(64)(rest))
          Ok(#(nvl.Hrtime(name, value), rest))
        }
        data_type.Nvlist -> {
          use #(value, rest) <- result.try(unpack(rest))
          Ok(#(nvl.Nvlist(name, value), rest))
        }
        data_type.NvlistArray -> {
          use #(values, rest) <- result.try(decode.array(unpack)(
            rest,
            array_len,
          ))
          Ok(#(nvl.NvlistArray(name, values), rest))
        }
        data_type.BooleanValue -> {
          use #(value, rest) <- result.try(bool_value(rest))
          Ok(#(nvl.BooleanValue(name, value), rest))
        }
        data_type.Int8 -> {
          use #(value, rest) <- result.try(widen(int, 8)(rest))
          Ok(#(nvl.Int8(name, value), rest))
        }
        data_type.Uint8 -> {
          use #(value, rest) <- result.try(widen(uint, 8)(rest))
          Ok(#(nvl.Uint8(name, value), rest))
        }
        data_type.BooleanArray -> {
          use #(values, rest) <- result.try(array(bool_value)(rest, array_len))
          Ok(#(nvl.BooleanArray(name, values), rest))
        }
        data_type.Int8Array -> {
          use #(values, rest) <- result.try(array(widen(int, 8))(
            rest,
            array_len,
          ))
          Ok(#(nvl.Int8Array(name, values), rest))
        }
        data_type.Uint8Array -> {
          use #(values, rest) <- result.try(array(widen(uint, 8))(
            rest,
            array_len,
          ))
          Ok(#(nvl.Uint8Array(name, values), rest))
        }
        data_type.Double -> {
          use #(value, rest) <- result.try(double(rest))
          Ok(#(nvl.Double(name, value), rest))
        }
      })
      let pair_size = len - bit_array.byte_size(rest)
      use rest <- result.try(realign(rest, pair_size))
      // XXX: The "encoded size" is not actually the encoded size, there are a
      // variety of deviations and errors.  We could only assert that we are
      // able to fabricate the same number using the same math, not anything
      // measurement based.
      //assert compensated_pair_size == encode_len as "invalid pair size"
      pairs([pair, ..acc], rest, flags)
    }
  }
}

fn double(input: BitArray) -> ScalarResult(Float) {
  case input {
    <<value:big-float, rest:bytes>> -> Ok(#(value, rest))
    _ -> Error(decode.Message("invalid double"))
  }
}

pub fn unpack(input: BitArray) -> ScalarResult(NvList) {
  use #(header, rest) <- result.try(header(input))
  pairs([], rest, header.flags)
}
