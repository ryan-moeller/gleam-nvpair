import gleam/option.{type Option, Some, None}

pub type DataType {
  Dontcare
  Unknown
  Boolean
  Byte
  Int16
  Uint16
  Int32
  Uint32
  Int64
  Uint64
  String
  ByteArray
  Int16Array
  Uint16Array
  Int32Array
  Uint32Array
  Int64Array
  Uint64Array
  StringArray
  Hrtime
  Nvlist
  NvlistArray
  BooleanValue
  Int8
  Uint8
  BooleanArray
  Int8Array
  Uint8Array
  Double
}

pub fn data_type_index(data_type: DataType) -> Int {
  case data_type {
    Dontcare -> -1
    Unknown -> 0
    Boolean -> 1
    Byte -> 2
    Int16 -> 3
    Uint16 -> 4
    Int32 -> 5
    Uint32 -> 6
    Int64 -> 7
    Uint64 -> 8
    String -> 9
    ByteArray -> 10
    Int16Array -> 11
    Uint16Array -> 12
    Int32Array -> 13
    Uint32Array -> 14
    Int64Array -> 15
    Uint64Array -> 16
    StringArray -> 17
    Hrtime -> 18
    Nvlist -> 19
    NvlistArray -> 20
    BooleanValue -> 21
    Int8 -> 22
    Uint8 -> 23
    BooleanArray -> 24
    Int8Array -> 25
    Uint8Array -> 26
    Double -> 27
  }
}

pub fn index_data_type(index: Int) -> Option(DataType) {
  case index {
    -1 -> Some(Dontcare)
    0 -> Some(Unknown)
    1 -> Some(Boolean)
    2 -> Some(Byte)
    3 -> Some(Int16)
    4 -> Some(Uint16)
    5 -> Some(Int32)
    6 -> Some(Uint32)
    7 -> Some(Int64)
    8 -> Some(Uint64)
    9 -> Some(String)
    10 -> Some(ByteArray)
    11 -> Some(Int16Array)
    12 -> Some(Uint16Array)
    13 -> Some(Int32Array)
    14 -> Some(Uint32Array)
    15 -> Some(Int64Array)
    16 -> Some(Uint64Array)
    17 -> Some(StringArray)
    18 -> Some(Hrtime)
    19 -> Some(Nvlist)
    20 -> Some(NvlistArray)
    21 -> Some(BooleanValue)
    22 -> Some(Int8)
    23 -> Some(Uint8)
    24 -> Some(BooleanArray)
    25 -> Some(Int8Array)
    26 -> Some(Uint8Array)
    27 -> Some(Double)
    _ -> None
  }
}

pub fn is_array_type(data_type: DataType) -> Bool {
  case data_type {
    Dontcare | Unknown
    | Boolean
    | BooleanValue
    | Byte
    | Int8 | Uint8
    | Int16 | Uint16
    | Int32 | Uint32
    | Int64 | Uint64
    | String
    | Hrtime
    | Nvlist
    | Double -> False

    BooleanArray
    | ByteArray
    | Int8Array | Uint8Array
    | Int16Array | Uint16Array
    | Int32Array | Uint32Array
    | Int64Array | Uint64Array
    | StringArray
    | NvlistArray -> True
  }
}
