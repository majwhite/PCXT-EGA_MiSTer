# XTIDE configuration and validation

## Required configuration

The core implements **XTIDE revision-1 at 300h–30Fh**:

- ATA command/status: 307h.
- High data byte latch: 308h.
- Device control/alternate status: 30Eh.

The original Micro8088, Xi8088 and Sergey XT ROM recipes selected 320h.
All five bundled XTIDE-bearing 8088 BIOS images also used XT-CF-Lite, whose
register offsets and data-transfer protocol do not match `XT2IDE.sv` with
`high_speed=0`. Changing the port alone to 300h did not resolve detection.

XT-CF writes IDENTIFY (`ECh`) to 30Eh, which this core treats as device
control rather than command. EC's bit 2 asserts software reset. The
focused regression reproduces this mismatch.

## Fix

Both Makefiles and CMake now select these r625 payloads:

- `SW/8088_bios/xtide_r625/ide_xt-xtide-rev1_300h.bin`
- `SW/8088_bios/xtide_r625/ide_xtp-xtide-rev1_300h.bin`

`configure_mister.py` generates them from the original checksum-valid 300h
XT-CF images. At offset 0052h it changes device type 0Eh (XT-CF PIO8 with
BIU offload) to 06h (XTIDE rev-1), then adjusts the final checksum byte.
Command base 300h, control base 308h, polling mode and all executable code
remain unchanged. The original payloads are retained.

The five updated prebuilt ROMs retain their original system BIOS, size,
placement and padding. They were repackaged using the Make recipes and
checked-in system BIOS `.bin` files; no system BIOS source or production RTL
was changed.

## Validation and recommended BIOS

The user confirmed disk detection and FreeDOS boot with the corrected
Micro8088 ROM, but that BIOS has a separate keyboard compatibility issue.
Keyboard input works with **`SW/ROMs/pcxt_pcxt31.rom`**, which already embeds
XTIDE rev-1 at 300h. Use it as the recommended system BIOS; further
Micro8088 compatibility work is outside this fix. The other 8088 BIOS
variants have not been hardware-validated.

Leave EC00 BIOS empty when using a system BIOS with embedded XTIDE. For
initial testing use 8088 at 4.77 MHz, `ega_bios.rom`, `FreeDOS_HD.img` in
IDE 0-0, IDE 0-1 empty, and the second SD card disabled. Reset/apply after
selecting the files.

## Reproduce and check

From the repository root:

```sh
python3 SW/8088_bios/xtide_r625/configure_mister.py
python3 SW/8088_bios/verify_xtide_roms.py
bash rtl/KFPC-XT/TESTBENCH/run_tests.sh xtide
```

For a complete system BIOS rebuild, install NASM and GNU Make, then run:

```sh
make -C SW/8088_bios/src -B
python3 SW/8088_bios/verify_xtide_roms.py SW/8088_bios/src
```

The verifier checks controller type, ports, option-ROM checksum, payload,
system BIOS placement, size and padding. The Verilator regression exercises
production `XT2IDE.sv`, `ide.v` and `hps_ext.v` with a small wrapper mirroring
the Peripherals IDE glue and a synchronous RAM model. It checks HPS presence
updates, the XT-CF mismatch, rev-1 IDENTIFY/READ SECTORS, byte ordering,
write latching and unmount. It is not a full CPU/BIOS or real HPS service
simulation.
