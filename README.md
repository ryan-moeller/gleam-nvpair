# nvpair

This project is a work in progress.  The library is functional, but lacks
documentation, useful conversions, and general polish.

The nvpair module provides serialization and deserialization of the nvlist
native and xdr packed formats, such as is used by ZFS on-disk, stream, and
ioctl interfaces.  It is not compatible with the in-memory layout used by
libzfs or libzfs_core.

## Development

```sh
gleam test  # Run the tests
```
