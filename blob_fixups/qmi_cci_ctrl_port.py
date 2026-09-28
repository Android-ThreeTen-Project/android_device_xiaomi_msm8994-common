#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Clear ctrl_port after failed initialization in the legacy ARM64 QMI blob.

The original failure path frees ctrl_port without clearing its global, so the
next attempt treats freed memory as an initialized transport. This applies the
same cleanup used in Qualcomm's qcci_xport_qrtr.c, without changing the legacy
QMI client ABI or the modern libraries used by other services.

Only the pinned blob is accepted. A 12-byte trampoline occupies zero padding
after the RX segment, still within its existing final page. No sections, imports
or data addresses move. The original free, return value and epilogue remain.
"""

import argparse
import hashlib
from pathlib import Path
import struct


ORIGINAL_SHA256 = "6f9310fb1f4b9f756c5db9ece9fdad743e16c1e566f1825e53943d8efd24757e"
CALL_OFFSET = 0x675C
FREE_PLT = 0x2150
RETURN_OFFSET = 0x6760
STUB_OFFSET = 0xA28C
STUB_SIZE = 12


def branch(source, target, link=False):
    delta = target - source
    if delta % 4 or not -(1 << 27) <= delta < (1 << 27):
        raise ValueError("AArch64 branch target out of range")
    return struct.pack("<I", (0x94000000 if link else 0x14000000)
                       | ((delta // 4) & 0x03FFFFFF))


OLD_CALL = branch(CALL_OFFSET, FREE_PLT, link=True)
NEW_CALL = branch(CALL_OFFSET, STUB_OFFSET)
STUB = (branch(STUB_OFFSET, FREE_PLT, link=True)
        + struct.pack("<I", 0xF9023A7F)  # str xzr, [x19, #0x470]
        + branch(STUB_OFFSET + 8, RETURN_OFFSET))


def patch(data):
    if data[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 183:
        raise ValueError("Expected little-endian AArch64 ELF64")
    phoff = struct.unpack_from("<Q", data, 32)[0]
    phentsize, phnum = struct.unpack_from("<HH", data, 54)
    if phentsize != 56:
        raise ValueError("Unexpected ELF program header size")
    loads = []
    for index in range(phnum):
        offset = phoff + index * phentsize
        header = struct.unpack_from("<IIQQQQQQ", data, offset)
        if header[0] == 1:
            loads.append((offset, header))
    if len(loads) != 2:
        raise ValueError("Unexpected load segments")
    ph, header = loads[0]
    if header[1:5] != (5, 0, 0, 0) or header[7] != 0x1000:
        raise ValueError("Unexpected RX segment layout")
    if loads[1][1][2] < STUB_OFFSET + STUB_SIZE:
        raise ValueError("Trampoline overlaps the data segment")

    already_patched = data[CALL_OFFSET:CALL_OFFSET + 4] == NEW_CALL
    normalized = bytearray(data)
    if already_patched:
        if data[STUB_OFFSET:STUB_OFFSET + STUB_SIZE] != STUB:
            raise ValueError("Unrecognized trampoline")
        if header[5:7] != (STUB_OFFSET + STUB_SIZE,) * 2:
            raise ValueError("Unexpected patched RX segment size")
        normalized[CALL_OFFSET:CALL_OFFSET + 4] = OLD_CALL
        normalized[STUB_OFFSET:STUB_OFFSET + STUB_SIZE] = bytes(STUB_SIZE)
        struct.pack_into("<QQ", normalized, ph + 32, STUB_OFFSET, STUB_OFFSET)
    elif (header[5:7] != (STUB_OFFSET,) * 2
          or data[CALL_OFFSET:CALL_OFFSET + 4] != OLD_CALL
          or any(data[STUB_OFFSET:STUB_OFFSET + STUB_SIZE])):
        raise ValueError("Unexpected original instructions or RX padding")
    if hashlib.sha256(normalized).hexdigest() != ORIGINAL_SHA256:
        raise ValueError("Unsupported blob; SHA256 does not match the legacy baseline")
    if already_patched:
        return data, False
    normalized[CALL_OFFSET:CALL_OFFSET + 4] = NEW_CALL
    normalized[STUB_OFFSET:STUB_OFFSET + STUB_SIZE] = STUB
    struct.pack_into("<QQ", normalized, ph + 32,
                     STUB_OFFSET + STUB_SIZE, STUB_OFFSET + STUB_SIZE)
    return bytes(normalized), True


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("blob", type=Path)
    args = parser.parse_args()
    try:
        fixed, changed = patch(args.blob.read_bytes())
    except (ValueError, struct.error) as exc:
        parser.error(str(exc))
    if changed:
        args.blob.write_bytes(fixed)
    print(f"{'patched' if changed else 'already patched'}: {args.blob}")
    print(f"sha256: {hashlib.sha256(fixed).hexdigest()}")


if __name__ == "__main__":
    main()
