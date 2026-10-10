# PC3086 RTC / system-status investigation

## Hardware symptom

Changing the PC3086 LPT status read at 379h from DEh to DFh produced
`Error: Faulty SYSTEM status register` on hardware. The failed RBF SHA-256 was
`212a34cde5452b1d0bfa81ea94feb16ed8824af343618137f836a8f83ed06b90`.

## ROM control flow

The locally held mirrored system ROM boots with CS=FC00. Addresses below are
physical ROM offsets in its 64 KiB F0000h mapping.

- C0D5: read 379h; bit 0 clear goes to C0F3, the CMOS initialization path.
  Bit 0 set reads CMOS register 0Dh via CB1A and may skip initialization.
  Thus setting bit 0 does not unconditionally guarantee preservation.
- C13D: read 379h again. Bit 0 clear takes the optional E000 option-ROM
  path or C170; bit 0 set checks the system ROM checksum and goes to C1AF.
- C170: initialize peripherals from the table at CS:0A5C, then jump to C4A0.
  This path bypasses the DMA, interval-timer, system-status, and RTC POST
  tests between C1AF and C448.
- Consequently DFh exposes system-status POST that DEh bypasses. The LPT
  bit is not solely a CMOS-initialization selector.

## Status-2 error

The ROM's routine at C2FD writes Status-2 at 65h and reconstructs its five bits:

1. Write 30h to PPI port B (PB2=0).
2. Read port C, rotate left four, mask with 10h: PC0 must supply RAM4.
3. Write 34h to PPI port B (PB2=1).
4. Read port C, mask with 0Fh: PC3..0 must supply RAM3..0.
5. Combine and compare with the written pattern.

The production mapping was reversed. For pattern FFh, it returned 0Fh for
PB=30h and 01h for PB=34h; the BIOS reconstructs 11h, not the expected 1Fh.
This reaches error 07 at C2F8. The corrected mapping is:

- PB2=0: `{3'b000, status2_write[4]}`
- PB2=1: `status2_write[3:0]`

Only the PC3086 compatibility mapping is changed; ordinary PCXT is unaffected.

## Regression gaps and results

The previous CPU fixture started at F000:C277, rather than FC00:0277. Although
these fetch the same initial physical bytes, absolute near jumps land in other
ROM mirrors. In addition, the fixture declared an early pass on a port-A read
instead of reaching the final ROM success marker.

The fixture now uses FC00:0277 and only passes after the ROM finishes the
Status-1 patterns, all Status-2 patterns, and the PC5/PIT terminal-count check.

- Correct CS and full test, original Status-2 mapping: reproduces error 07.
- Same test with corrected PB2 mapping: passes after 76,192 core cycles.

Run from the sibling build-tools repository with PCXT_PROJECT_DIR set:

```bash
bash scripts/test-i8088-pc3086-system-status.sh
```

The CPU fixture uses production CPU/PPI/PIT RTL with a testbench model of the
Status-2 wiring; it does not instantiate the whole Peripherals module. Hardware
validation is still required. No new RBF has been built for the mux correction
at the time of this investigation. Keep DFh for that experiment, but do not
claim RTC persistence until the DOS date/time reset-vector test passes. CMOS
validity/checksum handling may still force initialization independently.

## Mouse-coordinate POST follow-up

The rebuilt Status-2 correction progressed on hardware to error 0Ch,
`Faulty mouse coordinate registers`. At FC00:0483 the BIOS writes zero to
78h and requires a zero readback, then repeats at 7Ah. The core did not claim
these coordinate ports.

`PC3086_MOUSE_COORDINATES` now supplies zero coordinates for a stationary
mouse, with writes ignored, only under `PC3086_LEGACY_PPI`. It qualifies I/O
and AEN and claims only 78h and 7Ah, not the adjacent bytes or high-byte
aliases. It does not implement movement or change the serial mouse wrapper.

```bash
bash rtl/8088/TESTBENCH/run_mouse_post.sh
```

The decoder tests pass in both normal and compatibility builds. The actual
ROM coordinate POST passes after 3,364 CPU core cycles using the production
decoder, with both writes and reads observed. Existing normal/PC3086 I/O decode
and corrected full system-status ROM regressions also pass. Hardware boot
and RTC persistence remain separate validation steps.

## Latest FPGA build (2026-10-10)

Full synthesis/merge/fit/STA/assembler completed successfully with the LPT,
Status-2 and stationary-mouse fixes, `PC3086_LEGACY_RTC=1`, and
`NUM_PARALLEL_PROCESSORS=ALL` (10 detected processors).

```text
output_files/PCXT-EGA-PC3086.rbf
mtime: 2026-10-10 17:58:31 +1100
size: 4,077,244 bytes
SHA256: c06147af42f06d012dbf64080a6ed770deb7ce08f63b4c5a4df35107872a5bad
```

Timing requirements remain unmet. This is an experimental artifact, not a
timing-closed or hardware-validated RTC fix. Hardware had progressed beyond
system-status POST to mouse-coordinate POST with the preceding mux-fixed
build; the latest mouse-fixed RBF still needs boot and date/time persistence
validation. RBFs and ROM binaries are not committed.
