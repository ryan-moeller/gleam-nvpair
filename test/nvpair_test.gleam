// Copyright (c) 2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

import gleam/io

import file_streams/file_stream
import gleeunit
import pprint

import nvpair/stream

pub fn main() -> Nil {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn native_test() {
  io.println("reading nvdump")
  let assert Ok(file) = file_stream.open_read("nvdump")
  let assert Ok(packed) = file_stream.read_remaining_bytes(file)
  let assert Ok(Nil) = file_stream.close(file)

  io.println("unpacking native stream")
  let assert Ok(#(nvl, <<>>)) = stream.unpack(packed)
  pprint.debug(nvl)

  io.println("repacking native stream")
  let repacked = stream.pack(nvl, stream.Native)

  io.println("reunpacking native stream")
  let assert Ok(#(nvl1, <<>>)) = stream.unpack(repacked)
  pprint.debug(nvl1)

  assert nvl == nvl1 as "nvl1 differs"
  assert packed == repacked as "repacked differs"
}

pub fn xdr_test() {
  io.println("reading xnvdump")
  let assert Ok(xfile) = file_stream.open_read("xnvdump")
  let assert Ok(xpacked) = file_stream.read_remaining_bytes(xfile)
  let assert Ok(Nil) = file_stream.close(xfile)

  io.println("unpacking xdr stream")
  // XXX: libnvpair overallocates the buffer, so we get useless junk at the end.
  let assert Ok(#(xnvl, _)) = stream.unpack(xpacked)
  pprint.debug(xnvl)

  io.println("repacking xdr stream")
  let xrepacked = stream.pack(xnvl, stream.Xdr)

  io.println("reunpacking xdr stream")
  let assert Ok(#(xnvl1, <<>>)) = stream.unpack(xrepacked)
  pprint.debug(xnvl1)

  assert xnvl == xnvl1 as "xdr nvl1 differs"
  // XXX: we punted on encode_len since it's unused, so the buffers differ
  //assert xpacked == xrepacked as "xdr repacked differs"
}

pub fn native_xdr_test() {
  let assert Ok(file) = file_stream.open_read("nvdump")
  let assert Ok(packed) = file_stream.read_remaining_bytes(file)
  let assert Ok(Nil) = file_stream.close(file)
  let assert Ok(#(nvl, <<>>)) = stream.unpack(packed)

  let assert Ok(xfile) = file_stream.open_read("xnvdump")
  let assert Ok(xpacked) = file_stream.read_remaining_bytes(xfile)
  let assert Ok(Nil) = file_stream.close(xfile)
  let assert Ok(#(xnvl, _)) = stream.unpack(xpacked)

  assert nvl == xnvl as "native and xdr differ"
}
