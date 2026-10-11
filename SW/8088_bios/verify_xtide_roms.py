#!/usr/bin/env python3
"""Check MiSTer XTIDE ROM payloads, checksums, BIOS placement and padding."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent
# name, XTIDE offset, system BIOS name/offset, total image size, XTIDE variant
XT = "ide_xt-xtide-rev1_300h.bin"
XTP = "ide_xtp-xtide-rev1_300h.bin"
LAYOUTS = (
    ("bios-micro8088-xtide.rom", 0, "bios-micro8088.bin", 40 * 1024, 128 * 1024, XT),
    ("bios-xi8088-xtide.rom", 0, "bios-xi8088.bin", 32 * 1024, 128 * 1024, XT),
    ("bios-sergey-xt-xtide.rom", 64 * 1024, "bios-xi8088.bin", 96 * 1024, 128 * 1024, XT),
    ("bios-book8088-xtide.rom", 0, "bios-book8088.bin", 48 * 1024, 64 * 1024, XT),
    ("bios-book8088-xtide-v20.rom", 0, "bios-book8088.bin", 48 * 1024, 64 * 1024, XTP),
)


def verify(directory):
    for name, xt_offset, bios_name, bios_offset, size, variant in LAYOUTS:
        xtide = (ROOT / "xtide_r625" / variant).read_bytes()
        if xtide[:2] != b"\x55\xaa" or xtide[2] * 512 != len(xtide):
            raise ValueError(f"{variant}: invalid option ROM header/size")
        if sum(xtide) % 256:
            raise ValueError(f"{variant}: invalid option ROM checksum")
        if xtide[0x4e:0x54] != bytes.fromhex("00 03 08 03 06 00"):
            raise ValueError(f"{variant}: expected 300h/308h, XTIDE rev-1, polling")
        bios = (directory / bios_name).read_bytes()
        expected = bytearray(b"\xff" * size)
        expected[xt_offset:xt_offset + len(xtide)] = xtide
        expected[bios_offset:bios_offset + len(bios)] = bios
        actual = (directory / name).read_bytes()
        if len(expected) != size or actual != expected:
            raise ValueError(f"{name}: incorrect XTIDE payload, BIOS placement, size or padding")
        print(f"PASS {name}: {size} bytes, 300h XTIDE rev-1, valid checksum and layout")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", nargs="?", type=Path, default=ROOT / "binaries")
    args = parser.parse_args()
    try:
        verify(args.directory)
    except (OSError, ValueError) as error:
        parser.exit(1, f"FAIL {error}\n")
