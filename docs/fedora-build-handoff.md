# PCXT-EGA: Fedora build handoff

## Goal

Build a test `PCXT-EGA.rbf` that lets MiSTer mount virtual IDE images for this
core. The symptom before the change was XTIDE Universal BIOS reporting `Error
1h` (no master drive at `300h`), even when `Freedos_HD.vhd` was selected.

## Identified cause

The core advertised its internal MiSTer configuration-string ID as `PCXT-EGA`:

```systemverilog
`define CONF_STR_SYSTEM "PCXT-EGA;UART115200:115200;"
```

MiSTer Main's PC-XT-specific virtual-IDE support is selected only when that
internal ID is `PCXT`. With `PCXT-EGA`, MiSTer used generic `S2` image mounting
instead. This core consumes the PC-XT extended virtual-IDE protocol, so no
virtual drive was presented to XTIDE. The rebuilt RBF is the required hardware
test of this conclusion.

## Source change already made

In `PCXT-EGA.sv`, the value is now:

```systemverilog
// MiSTer Main identifies PC-XT cores by this internal ID and selects its
// x86 virtual-IDE transport accordingly.  The RBF filename remains PCXT-EGA.
`define CONF_STR_SYSTEM "PCXT;UART115200:115200;"
```

Keep the output file named `PCXT-EGA.rbf`. It can coexist with the normal
`PCXT.rbf`; MiSTer selects the core by RBF filename/path. The two cores may
share the saved PC-XT image selection because both internally identify as
`PCXT`.

## Toolchain

* Target device: `5CSEBA6U23I7` (Cyclone V SoC).
* Project records `Quartus Prime Lite 17.0.2` in `PCXT-EGA.qsf`.
* Available installer: `Quartus-lite-17.0.0.595-linux.tar`.
  This is acceptable for this one-line test and includes
  `components/cyclonev-17.0.0.595.qdz`.
* Quartus 17 officially supports RHEL/CentOS 7-era Linux. On Fedora 44,
  prefer an x86_64 CentOS 7 container if a direct install fails because of
  missing legacy libraries. Unlike an Apple Silicon Mac, an x86_64 Fedora host
  can expose the CPU instructions Quartus needs.

## Build

1. Copy/clone the repository to the Fedora machine **including the uncommitted
   `PCXT-EGA.sv` change above**.
2. Install Quartus Prime Lite 17.0.0.595 and Cyclone V device support, or run
   that installer in an x86_64 CentOS 7 container.
3. From the repository root, build:

   ```bash
   quartus_sh --flow compile PCXT-EGA
   ```

4. Expected output:

   ```text
   output_files/PCXT-EGA.rbf
   ```

## MiSTer test

1. Copy the built RBF to `/media/fat/_Computer/PCXT-EGA.rbf`.
2. Keep `Freedos_HD.vhd` at `/media/fat/games/PCXT/Freedos_HD.vhd`.
3. Load `PCXT-EGA` and set:
   * Main BIOS: `bios-micro8088-noide.rom`
   * EC00 BIOS: `ide_xt-cf-lite_300h.bin`
   * EGA BIOS: `ega_bios.rom`
   * IDE 0-0: `Freedos_HD.vhd`
4. Reset/apply settings and boot. XTIDE should find the master at `300h`.

`*.VHD` shown by an unmodified generic OSD entry is a file filter, not a
reliable indication that an image is mounted. The rebuilt core should instead
activate MiSTer's PC-XT path and show/use the selected image properly.

## Notes

* No completed RBF was produced on the M1 Mac. Podman/libkrun's amd64
  emulation made Quartus terminate because the expected Intel CPU extensions
  were not exposed.
* `SW/ROMs/EGA/ega_bios.rom` and `SW/ROMs/Amstrad_PC3086/` are local untracked
  artifacts from earlier experiments. They are not required to compile the
  configuration-ID fix.

## PC3086 follow-up: black-screen investigation

The Amstrad PC3086 experiment remains separate from the generic PC-XT IDE
fix. Its system BIOS is available as:

```text
SW/ROMs/Amstrad_PC3086/pc3086-system.rom
```

That 64 KiB upload image correctly positions the original 16 KiB `fc00.bin`
system ROM at `FC000h`; its reset vector is valid.

The matching PC3086 Paradise PVGA1A video dump is located outside this repo:

```text
/Users/mwhite/dev/roms/machines/pc3086/c000.bin
```

Load the original **full 32 KiB** `c000.bin` into **System & BIOS -> EGA
BIOS**, which maps it at `C0000h`. Do not trim it to the 24 KiB size declared
in its option-ROM header: inspection established that the final 8 KiB contains
nonblank Paradise data.

### Result so far

Using `pc3086-system.rom` with the full matching `c000.bin` still produces a
black screen. Therefore the next useful experiment is not a different ROM
packing scheme, but a debug RBF that traces early POST activity.

### Next task: POST-trace RBF

Add a temporary, user-visible diagnostic to determine where the PC3086 BIOS
stalls before video output. The trace should capture at least:

* recent I/O port reads and writes;
* the last I/O port repeatedly read (common for hardware polling loops);
* optionally the current CPU address at each I/O transaction.

The debug output must remain visible even when normal VGA output is black.
Suitable options are a small fixed on-screen diagnostic overlay, a visible
border/colour code, or a documented LED pattern. An overlay is preferred
because it can report both a port and address.

Build the temporary RBF with the Quartus workflow above, install it as a
separate RBF (for example `PCXT-EGA-PC3086-debug.rbf`), and boot the PC3086 ROM
pair. Use the captured port/address to decide whether the next change is a
Paradise VGA compatibility shim, Amstrad keyboard/controller emulation,
RTC/configuration emulation, or another motherboard device.
