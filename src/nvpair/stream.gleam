import gleam/bit_array
import gleam/option.{type Option, Some, None}
import gleam/order
import gleam/result

import nvpair/list.{type NvList}
import nvpair/stream/decode.{type ScalarResult}
import nvpair/stream/native/decode as native_decode
import nvpair/stream/native/encode as native_encode
import nvpair/stream/xdr/decode as xdr_decode
import nvpair/stream/xdr/encode as xdr_encode

pub type Encoding {
  Native
  Xdr
}

pub fn encoding_index(encoding: Encoding) -> Int {
  case encoding {
    Native -> 0
    Xdr -> 1
  }
}

pub fn index_encoding(index: Int) -> Option(Encoding) {
  case index {
    0 -> Some(Native)
    1 -> Some(Xdr)
    _ -> None
  }
}

// XXX: This should not exist but it does.  Only native endianness should ever
// be applicable in practice.  Persistently stored nvlists should always be XDR
// encoded for byte order independence.
pub type Endian {
  Big
  Little
}

pub fn endian_index(endian: Endian) -> Int {
  case endian {
    Big -> 0
    Little -> 1
  }
}

pub fn index_endian(index: Int) -> Option(Endian) {
  case index {
    0 -> Some(Big)
    1 -> Some(Little)
    _ -> None
  }
}

pub fn native_endian() -> Endian {
  case bit_array.compare(<<1:native-size(16)>>, <<1:big-size(16)>>) {
    order.Eq -> Big
    _ -> Little
  }
}

pub type Header {
  Header(encoding: Encoding, endian: Endian)
}

pub fn encode_header(header: Header) -> BitArray {
  let encoding = encoding_index(header.encoding)
  let endian = endian_index(header.endian)
  <<encoding:size(8), endian:size(8), 0:size(16)>>
}

pub fn decode_header(input: BitArray) -> decode.ScalarResult(Header) {
  case input {
    <<encoding:int-size(8), endian:int-size(8), 0:size(16), rest:bits>> ->
      case index_encoding(encoding), index_endian(endian) {
        Some(encoding), Some(endian) -> Ok(#(Header(encoding, endian), rest))
        _, _ -> Error(decode.Message("invalid header"))
      }
    _ -> Error(decode.Message("invalid stream"))
  }
}

// XXX: returning a BitArray might not be ideal
pub fn pack(nvl: NvList, encoding: Encoding) -> BitArray {
  let header = encode_header(Header(encoding, native_endian()))
  let encode = case encoding {
    Native -> native_encode.pack
    Xdr -> xdr_encode.pack
  }
  let stream = encode(nvl)
  <<header:bits, stream:bits>>
}

pub fn unpack(packed: BitArray) -> ScalarResult(NvList) {
  use #(header, stream) <- result.try(decode_header(packed))
  let decode = case header.encoding {
    Native -> native_decode.unpack
    Xdr -> xdr_decode.unpack
  }
  decode(stream)
}
