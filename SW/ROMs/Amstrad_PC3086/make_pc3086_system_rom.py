#!/usr/bin/env python3
"""Build a PCXT-EGA system-ROM upload image from a PC3086 ROS dump.

The PC3086 ROS is a 16 KiB image physically decoded at FC000h.  PCXT-EGA's
system-ROM upload starts at F0000h and spans 64 KiB, so the first 48 KiB must
remain erased and the ROS belongs in the final 16 KiB.

This script never downloads or includes Amstrad firmware.  Supply a dump you
are entitled to use (the known PC3086 dump is named fc00.bin).
"""

from __future__ import annotations

import argparse
import hashlib
from pathlib import Path


ROS_SIZE = 16 * 1024
SYSTEM_ROM_SIZE = 64 * 1024
ROS_OFFSET = 0xC000
EXPECTED_SHA1 = "98c344831cc4dc59ebb39bbb1961964a8d39fe20"
EXPECTED_RESET_VECTOR = bytes((0xEA, 0x5B, 0x20, 0x00, 0xFC))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", type=Path, help="PC3086 16 KiB fc00.bin dump")
    parser.add_argument(
        "output",
        type=Path,
        nargs="?",
        default=Path("pc3086-system.rom"),
        help="64 KiB PCXT-EGA system-ROM upload image (default: %(default)s)",
    )
    args = parser.parse_args()

    ros = args.input.read_bytes()
    if len(ros) != ROS_SIZE:
        raise SystemExit(f"{args.input}: expected {ROS_SIZE} bytes, got {len(ros)}")
    if sum(ros) & 0xFF:
        raise SystemExit(f"{args.input}: invalid 8-bit ROM checksum")
    if ros[-16:-11] != EXPECTED_RESET_VECTOR:
        raise SystemExit(f"{args.input}: unexpected PC3086 reset vector")

    digest = hashlib.sha1(ros).hexdigest()
    if digest != EXPECTED_SHA1:
        print(f"warning: SHA-1 is {digest}, not the documented PC3086 dump")

    image = bytes([0xFF]) * ROS_OFFSET + ros
    assert len(image) == SYSTEM_ROM_SIZE
    assert image[0xFFF0:0xFFF5] == EXPECTED_RESET_VECTOR
    args.output.write_bytes(image)
    print(f"wrote {args.output} ({len(image)} bytes)")
    print("reset vector at FFFF:0000 -> FC00:205B (physical FE05B)")


if __name__ == "__main__":
    main()
