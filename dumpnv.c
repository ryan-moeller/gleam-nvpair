// Copyright (c) 2020-2026 Ryan Moeller
// SPDX-License-Identifier: BSD-2-Clause

#include <sys/param.h>
#include <assert.h>
#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <stdint.h>
#include <string.h>

typedef enum { B_FALSE, B_TRUE } boolean_t;
typedef unsigned int uint_t;
typedef unsigned char uchar_t;
typedef struct hrtime hrtime_t;

#include <libnvpair.h>

void
usage(char const * const arg0)
{
    printf("usage: %s [-x] FILENAME\n", arg0);
    exit(1);
}

int
main(int argc, char **argv)
{
    const char *progname = argv[0];
    int xflag, ch;

    xflag = 0;
    while ((ch = getopt(argc, argv, "hx")) != -1) {
        switch (ch) {
        case 'x':
            xflag = 1;
            break;
        case 'h':
        default:
            usage(progname);
        }
    }
    argc -= optind;
    argv += optind;

    if (argc != 1)
        usage(progname);

    const char * const path = argv[0];

    nvlist_t *nvl = fnvlist_alloc();

    fnvlist_add_boolean(nvl, "boolean");
    fnvlist_add_boolean_value(nvl, "boolean value", B_FALSE);
    fnvlist_add_byte(nvl, "byte", 0xbe);
    fnvlist_add_int8(nvl, "int8", -0x18);
    fnvlist_add_uint8(nvl, "uint8", 0x08);
    fnvlist_add_int16(nvl, "int16", -0x1ff6);
    fnvlist_add_uint16(nvl, "uint16", 0x1ff6);
    fnvlist_add_int32(nvl, "int32", -0x1fffff32);
    fnvlist_add_uint32(nvl, "uint32", 0x1fffff32);
    fnvlist_add_int64(nvl, "int64", -0x1fffffffffffff64);
    fnvlist_add_uint64(nvl, "uint64", 0x1fffffffffffff64);
    fnvlist_add_string(nvl, "string", "hello world");
    nvlist_t *nnvl = fnvlist_alloc();
    fnvlist_add_string(nnvl, "nested", "nvlist");
    fnvlist_add_nvlist(nvl, "nvlist", nnvl);
#if 0
    /* XXX: is this bogus? altering nnvl after adding to nvl? */
    fnvlist_add_string(nnvl, "nvpair", "string");
    nvpair_t *nvp = fnvlist_lookup_nvpair(nnvl, "nvpair");
    fnvlist_add_nvpair(nvl, nvp);
#endif
    boolean_t bools[] = { B_TRUE, B_FALSE, B_TRUE, B_TRUE, B_FALSE, B_FALSE };
    fnvlist_add_boolean_array(nvl, "boolean array", bools, nitems(bools));
    fnvlist_add_boolean_array(nvl, "empty boolean array", bools, 0);
    uchar_t bytes[] = { 0xff, 0xfe, 0xfd, 0x03, 0x02, 0x01, 0x00 };
    fnvlist_add_byte_array(nvl, "byte array", bytes, nitems(bytes));
    fnvlist_add_byte_array(nvl, "empty byte array", bytes, 0);
    int8_t int8s[] = { -3, -2, -1, 0, 1 };
    fnvlist_add_int8_array(nvl, "int8 array", int8s, nitems(int8s));
    fnvlist_add_int8_array(nvl, "empty int8 array", int8s, 0);
    uint8_t uint8s[] = { 0xff, 0x00, 0xfe, 0x01, 0xfd, 0x02, 0xfc, 0x03 };
    fnvlist_add_uint8_array(nvl, "uint8 array", uint8s, nitems(uint8s));
    fnvlist_add_uint8_array(nvl, "empty uint8 array", uint8s, 0);
    int16_t int16s[] = { -0x1234, -0x4321, 0x1234, 0x4321 };
    fnvlist_add_int16_array(nvl, "int16 array", int16s, nitems(int16s));
    fnvlist_add_int16_array(nvl, "empty int16 array", int16s, 0);
    uint16_t uint16s[] = { 0x1234, 0x4321, 0x5678, 0x8765, 0xffff };
    fnvlist_add_uint16_array(nvl, "uint16 array", uint16s, nitems(uint16s));
    fnvlist_add_uint16_array(nvl, "empty uint16 array", uint16s, 0);
    int32_t int32s[] = { -0x12345678, -0x87654321, 0x1 };
    fnvlist_add_int32_array(nvl, "int32 array", int32s, nitems(int32s));
    fnvlist_add_int32_array(nvl, "empty int32 array", int32s, 0);
    uint32_t uint32s[] = { 0xffffffff, 0x0 };
    fnvlist_add_uint32_array(nvl, "uint32 array", uint32s, nitems(uint32s));
    fnvlist_add_uint32_array(nvl, "empty uint32 array", uint32s, 0);
    int64_t int64s[] = { -0x1234567812345678, 0x87654321 };
    fnvlist_add_int64_array(nvl, "int64 array", int64s, nitems(int64s));
    fnvlist_add_int64_array(nvl, "empty int64 array", int64s, 0);
    uint64_t uint64s[] = { 0xffffffffffffffff };
    fnvlist_add_uint64_array(nvl, "uint64 array", uint64s, nitems(uint64s));
    fnvlist_add_uint64_array(nvl, "empty uint64 array", uint64s, 0);
    const char *strings[] = { "foo", "bar", "baz" };
    fnvlist_add_string_array(nvl, "string array", strings, nitems(strings));
    fnvlist_add_string_array(nvl, "empty string array", strings, 0);
    nvlist_t *nvls[] = { fnvlist_alloc(), nnvl };
    fnvlist_add_string_array(nvls[0], "nested string array", strings, nitems(strings));
    fnvlist_add_nvlist_array(nvl, "nvlist array", nvls, nitems(nvls));
    fnvlist_add_nvlist_array(nvl, "empty nvlist array", &nnvl, 0);
    size_t buflen;
    char *buf = NULL;
    int encoding = xflag == 0 ? NV_ENCODE_NATIVE : NV_ENCODE_XDR;
    assert(nvlist_pack(nvl, &buf, &buflen, encoding, 0) == 0);
    int fd = open(path, O_WRONLY|O_CREAT, 0644);
    if (fd < 0)
        return 1;
    if (write(fd, buf, buflen) != buflen)
        return 2;
    return 0;
}
