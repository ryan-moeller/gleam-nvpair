import gleam/bit_array
import gleam/option
import gleam/result

import iv

import nvpair/data_type
import nvpair/list.{
  type Flag,
  type Header,
  type NvList,
  type Pair,
  Header,
} as nvl
import nvpair/stream/align.{align8}
import nvpair/stream/decode.{type ScalarDecoder, type ScalarResult, array}

fn header(input: BitArray) -> ScalarResult(Header) {
  case input {
    <<version:native-signed-size(32),
      flags:native-signed-size(32),
      rest:bytes>> -> {
      use version <- result.try(nvl.check_version(version))
      use flags <- result.try(nvl.check_flags(flags))
      Ok(#(Header(version, flags), rest))
    }
    _ -> Error(decode.Message("invalid nvlist header"))
  }
}

fn embedded_header(input: BitArray) -> ScalarResult(Header) {
  case input {
    <<version:native-signed-size(32),
      flags:native-signed-size(32),
      _priv:native-unsigned-size(64),
      _flag:native-unsigned-size(32),
      _pad:native-signed-size(32),
      rest:bytes>> -> {
      use version <- result.try(nvl.check_version(version))
      use flags <- result.try(nvl.check_flags(flags))
      Ok(#(Header(version, flags), rest))
    }
    _ -> Error(decode.Message("invalid embedded nvlist header"))
  }
}

fn bool_value(input: BitArray) -> ScalarResult(Bool) {
  case input {
    <<0:size(32), rest:bytes>> -> Ok(#(False, rest))
    <<1:native-signed-size(32), rest:bytes>> -> Ok(#(True, rest))
    _ -> Error(decode.Message("invalid boolean"))
  }
}

fn int(size: Int) -> ScalarDecoder(Int) {
  fn (input: BitArray) -> ScalarResult(Int) {
    case input {
      <<value:native-signed-size(size), rest:bytes>> -> Ok(#(value, rest))
      _ -> Error(decode.Message("invalid integer"))
    }
  }
}

fn uint(size: Int) -> ScalarDecoder(Int) {
  fn (input: BitArray) -> ScalarResult(Int) {
    case input {
      <<value:native-unsigned-size(size), rest:bytes>> -> Ok(#(value, rest))
      _ -> Error(decode.Message("invalid integer"))
    }
  }
}

fn string_impl(input: BitArray, len: Int) -> ScalarResult(String) {
  case input {
    <<_:bytes-size(len)>> -> Error(decode.Message("unterminated string"))

    <<s:bytes-size(len), 0:size(8), rest:bytes>> ->
      case bit_array.to_string(s) {
        Ok(value) -> Ok(#(value, rest))
        Error(Nil) -> Error(decode.Message("invalid string"))
      }

    _ -> string_impl(input, len + 1)
  }
}

fn string(input: BitArray) -> ScalarResult(String) {
  string_impl(input, 0)
}

fn realign(input: BitArray, offset: Int) -> Result(BitArray, decode.Error) {
  decode.skip(input, align8(offset) - offset)
}

fn pairs(acc: List(Pair), input: BitArray, flags: List(Flag))
  -> ScalarResult(NvList) {
  let input_len = bit_array.byte_size(input)
  case input {
    <<0:size(32), rest:bytes>> -> nvl.validate(acc, flags, rest)

    <<size:native-signed-size(32),
      name_size:native-signed-size(16),
      _reserved:native-signed-size(16),
      array_len:native-signed-size(32),
      data_type:native-signed-size(32),
      name:bytes-size(name_size - 1),
      0:size(8),
      rest:bytes>> -> {
      let rest_len = bit_array.byte_size(rest)
      let pair_header_len = input_len - rest_len
      assert pair_header_len <= size as "invalid pair size"
      use rest <- result.try(realign(rest, pair_header_len))
      use name <- result.try(result.replace_error(bit_array.to_string(name),
        decode.Message("invalid name")))
      use data_type <- result.try(data_type.index_data_type(data_type)
        |> option.to_result(decode.Message("invalid data type")))
      use #(pair, rest) <- result.try(case data_type {
        data_type.Dontcare ->
          Ok(#(nvl.Dontcare(name), rest))
        data_type.Unknown ->
          Ok(#(nvl.Unknown(name), rest))
        data_type.Boolean ->
          Ok(#(nvl.Boolean(name), rest))
        data_type.Byte -> {
          use #(value, rest) <- result.try(uint(8)(rest))
          Ok(#(nvl.Byte(name, value), rest))
        }
        data_type.Int16 -> {
          use #(value, rest) <- result.try(int(16)(rest))
          Ok(#(nvl.Int16(name, value), rest))
        }
        data_type.Uint16 -> {
          use #(value, rest) <- result.try(uint(16)(rest))
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
          use #(values, rest) <- result.try(array(uint(8))(rest, array_len))
          Ok(#(nvl.ByteArray(name, values), rest))
        }
        data_type.Int16Array -> {
          use #(values, rest) <- result.try(array(int(16))(rest, array_len))
          Ok(#(nvl.Int16Array(name, values), rest))
        }
        data_type.Uint16Array -> {
          use #(values, rest) <- result.try(array(uint(16))(rest, array_len))
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
          use rest <- result.try(decode.skip(rest, 8 * array_len))
          use #(values, rest) <- result.try(array(string)(rest, array_len))
          Ok(#(nvl.StringArray(name, values), rest))
        }
        data_type.Hrtime -> {
          use #(value, rest) <- result.try(uint(64)(rest))
          Ok(#(nvl.Hrtime(name, value), rest))
        }
        data_type.Nvlist -> {
          use #(header, rest) <- result.try(embedded_header(rest))
          use #(value, rest) <- result.try(pairs([], rest, header.flags))
          Ok(#(nvl.Nvlist(name, value), rest))
        }
        data_type.NvlistArray -> {
          use rest <- result.try(decode.skip(rest, 8 * array_len))
          use #(headers, rest) <-
            result.try(array(embedded_header)(rest, array_len))
          use #(values, rest) <- result.try(iv.try_fold(headers, #([], rest),
            fn (state, header) {
              let #(acc, rest) = state
              use #(nvl, rest) <- result.try(pairs([], rest, header.flags))
              Ok(#([nvl, ..acc], rest))
            }
          ))
          Ok(#(nvl.NvlistArray(name, iv.from_reverse_list(values)), rest))
        }
        data_type.BooleanValue -> {
          use #(value, rest) <- result.try(bool_value(rest))
          Ok(#(nvl.BooleanValue(name, value), rest))
        }
        data_type.Int8 -> {
          use #(value, rest) <- result.try(int(8)(rest))
          Ok(#(nvl.Int8(name, value), rest))
        }
        data_type.Uint8 -> {
          use #(value, rest) <- result.try(uint(8)(rest))
          Ok(#(nvl.Uint8(name, value), rest))
        }
        data_type.BooleanArray -> {
          use #(values, rest) <- result.try(array(bool_value)(rest, array_len))
          Ok(#(nvl.BooleanArray(name, values), rest))
        }
        data_type.Int8Array -> {
          use #(values, rest) <- result.try(array(int(8))(rest, array_len))
          Ok(#(nvl.Int8Array(name, values), rest))
        }
        data_type.Uint8Array -> {
          use #(values, rest) <- result.try(array(uint(8))(rest, array_len))
          Ok(#(nvl.Uint8Array(name, values), rest))
        }
        data_type.Double -> {
          use #(value, rest) <- result.try(double(rest))
          Ok(#(nvl.Double(name, value), rest))
        }
      })
      use rest <- result.try(case data_type {
        // XXX: Embedded nvlists are the one exception that break alignment.
        data_type.Nvlist | data_type.NvlistArray -> Ok(rest)
        _ -> {
          let pair_size = input_len - bit_array.byte_size(rest)
          realign(rest, pair_size)
        }
      })
      pairs([pair, ..acc], rest, flags)
    }
    _ -> Error(decode.Message("invalid pair"))
  }
}

fn double(input: BitArray) -> ScalarResult(Float) {
  case input {
    <<value:native-float, rest:bytes>> -> Ok(#(value, rest))
    _ -> Error(decode.Message("invalid double"))
  }
}

pub fn unpack(input: BitArray) -> ScalarResult(NvList) {
  use #(header, rest) <- result.try(header(input))
  pairs([], rest, header.flags)
}
