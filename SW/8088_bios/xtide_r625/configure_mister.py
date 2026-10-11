#!/usr/bin/env python3
"""Configure bundled r625 XT/XT+ ROMs for MiSTer's XTIDE rev-1 interface."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent

for cpu in ("xt", "xtp"):
    source = ROOT / f"ide_{cpu}-cf-lite_300h.bin"
    rom = bytearray(source.read_bytes())
    # r625 ROMVARS.ideVars0: command base, control base, device type, IRQ.
    # DEVICE_8BIT_XTIDE_REV1=6; XT-CF PIO8 with BIU offload=14.
    if len(rom) != 8192 or rom[:3] != b"\x55\xaa\x10" or sum(rom) % 256:
        raise SystemExit(f"Invalid source ROM: {source}")
    if rom[0x4e:0x54] != bytes.fromhex("00 03 08 03 0e 00"):
        raise SystemExit(f"Unexpected r625 controller configuration: {source}")
    rom[0x52] = 6
    rom[-1] = (rom[-1] - sum(rom)) & 0xff
    target = ROOT / f"ide_{cpu}-xtide-rev1_300h.bin"
    target.write_bytes(rom)
    print(f"Created {target.name}: XTIDE rev-1, command 300h, control 308h")
